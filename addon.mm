// addon.mm — 触控板/鼠标滚轮来源识别模块（优化版）
// 依赖: node-addon-api, AppKit

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#include <napi.h>

#include <atomic>
#include <memory>
#include <mutex>

// ============================================================
// 线程安全的 ThreadSafeFunction 持有器
// - 通过 shared_ptr 保证 BlockingCall/NonBlockingCall 路径上 TSFN
//   生命周期稳定；Rebind 时旧 TSFN 正确 Release。
// ============================================================
class TsfnSlot {
 public:
  // 在 JS 线程调用：替换/清除回调
  void Rebind(Napi::Env env, Napi::Value maybeFn, const char* name) {
    std::shared_ptr<Napi::ThreadSafeFunction> fresh;
    if (maybeFn.IsFunction()) {
      fresh = std::make_shared<Napi::ThreadSafeFunction>(
          Napi::ThreadSafeFunction::New(
              env, maybeFn.As<Napi::Function>(), name, 0, 1));
    }
    std::shared_ptr<Napi::ThreadSafeFunction> old;
    {
      std::lock_guard<std::mutex> lk(mu_);
      old = std::move(tsfn_);
      tsfn_ = std::move(fresh);
    }
    if (old) {
      old->Release();  // 释放旧 TSFN，避免泄漏
    }
  }

  // 任意线程调用：取出当前 TSFN 的快照
  std::shared_ptr<Napi::ThreadSafeFunction> Snapshot() {
    std::lock_guard<std::mutex> lk(mu_);
    return tsfn_;
  }

  // 进程退出或模块卸载时调用
  void Clear() {
    std::shared_ptr<Napi::ThreadSafeFunction> old;
    {
      std::lock_guard<std::mutex> lk(mu_);
      old = std::move(tsfn_);
    }
    if (old) old->Release();
  }

 private:
  std::mutex mu_;
  std::shared_ptr<Napi::ThreadSafeFunction> tsfn_;
};

// ============================================================
// 全局状态（只放 POD / atomic）
// ============================================================
static TsfnSlot g_tsfnBegan;
static TsfnSlot g_tsfnEnded;
static TsfnSlot g_tsfnGesture;
static TsfnSlot g_tsfnForceClick;

// 用 CFAbsoluteTime(double) 代替 NSDate*，彻底去掉 ARC 竞态
static std::atomic<double> g_lastBeganTime{0.0};
static std::atomic<double> g_lastEndedTime{0.0};
static std::atomic<bool>   g_inScrollPhase{false};
static std::atomic<int>    g_lastPressureStage{0};

// AppKit 事件监听器句柄（仅主线程读写）
static id g_scrollMonitor   = nil;
static id g_magnifyMonitor  = nil;
static id g_rotateMonitor   = nil;
static id g_pressureMonitor = nil;
static std::once_flag g_installOnce;

// ============================================================
// 工具：投递一个带 payload 的手势事件
// ============================================================
struct GesturePayload {
  int    deltaX = 0;
  int    deltaY = 0;
  bool   isTrackpad = false;
  bool   isScale = false;
  bool   isScroll = false;
  bool   isRotate = false;
  double magnification = 0.0;
  double deltaAngle = 0.0;
};

static void PostGesture(const GesturePayload& p) {
  auto tsfn = g_tsfnGesture.Snapshot();
  if (!tsfn) return;
  // 复制到堆，在 JS 回调里再取（避免引用已析构的栈对象）
  auto boxed = new GesturePayload(p);
  auto status = tsfn->NonBlockingCall(
      boxed, [](Napi::Env env, Napi::Function jsCallback, GesturePayload* data) {
        std::unique_ptr<GesturePayload> guard(data);
        Napi::Object obj = Napi::Object::New(env);
        obj.Set("deltaX",        Napi::Number::New(env, data->deltaX));
        obj.Set("deltaY",        Napi::Number::New(env, data->deltaY));
        obj.Set("isTrackpad",    Napi::Boolean::New(env, data->isTrackpad));
        obj.Set("isScale",       Napi::Boolean::New(env, data->isScale));
        obj.Set("isScroll",      Napi::Boolean::New(env, data->isScroll));
        obj.Set("isRotate",      Napi::Boolean::New(env, data->isRotate));
        obj.Set("magnification", Napi::Number::New(env, data->magnification));
        obj.Set("deltaAngle",    Napi::Number::New(env, data->deltaAngle));
        jsCallback.Call({obj});
      });
  if (status != napi_ok) {
    // 队列满或 TSFN 已关闭：释放 payload，保证无泄漏
    delete boxed;
  }
}

static void PostSimple(TsfnSlot& slot) {
  auto tsfn = slot.Snapshot();
  if (!tsfn) return;
  tsfn->NonBlockingCall(
      [](Napi::Env env, Napi::Function jsCallback) { jsCallback.Call({}); });
}

// ============================================================
// 安装 AppKit 事件监听器（不再 swizzle，改用 local monitor）
// 仅主线程执行一次
// ============================================================
static void InstallMonitorsOnMain() {
  // 1. 滚轮事件：区分触控板 vs 鼠标滚轮
  g_scrollMonitor = [NSEvent
      addLocalMonitorForEventsMatchingMask:NSEventMaskScrollWheel
                                   handler:^NSEvent* _Nullable(NSEvent* event) {
                                     @autoreleasepool {
                                       CGFloat dx, dy;
                                       if ([event hasPreciseScrollingDeltas]) {
                                         dx = [event scrollingDeltaX];
                                         dy = [event scrollingDeltaY];
                                       } else {
                                         dx = [event deltaX] * 10;
                                         dy = [event deltaY] * 10;
                                       }
                                       int ix = (int)llround(dx);
                                       int iy = (int)llround(dy);
                                       BOOL isTrackpad =
                                           [event phase] != NSEventPhaseNone ||
                                           [event momentumPhase] != NSEventPhaseNone;

                                       if (ix != 0 || iy != 0) {
                                         GesturePayload p;
                                         p.deltaX = ix;
                                         p.deltaY = iy;
                                         p.isTrackpad = isTrackpad;
                                         p.isScroll = true;
                                         PostGesture(p);
                                       }

                                       const double now = CFAbsoluteTimeGetCurrent();
                                       if ([event phase] == NSEventPhaseBegan) {
                                         double last = g_lastBeganTime.load(std::memory_order_relaxed);
                                         if (last == 0.0 || (now - last) > 0.002) {
                                           PostSimple(g_tsfnBegan);
                                         }
                                         g_lastBeganTime.store(now, std::memory_order_relaxed);
                                         g_inScrollPhase.store(true, std::memory_order_relaxed);
                                       } else if ([event phase] == NSEventPhaseEnded &&
                                                  g_inScrollPhase.load(std::memory_order_relaxed)) {
                                         double last = g_lastEndedTime.load(std::memory_order_relaxed);
                                         if (last == 0.0 || (now - last) > 0.002) {
                                           PostSimple(g_tsfnEnded);
                                         }
                                         g_lastEndedTime.store(now, std::memory_order_relaxed);
                                         g_inScrollPhase.store(false, std::memory_order_relaxed);
                                       }
                                     }
                                     return event;  // 不吞事件，交给下游
                                   }];

  // 2. 双指捏合（缩放）
  g_magnifyMonitor = [NSEvent
      addLocalMonitorForEventsMatchingMask:NSEventMaskMagnify
                                   handler:^NSEvent* _Nullable(NSEvent* event) {
                                     GesturePayload p;
                                     p.isTrackpad = true;
                                     p.isScale = true;
                                     p.magnification = [event magnification];
                                     PostGesture(p);
                                     return event;
                                   }];

  // 3. 双指旋转
  g_rotateMonitor = [NSEvent
      addLocalMonitorForEventsMatchingMask:NSEventMaskRotate
                                   handler:^NSEvent* _Nullable(NSEvent* event) {
                                     GesturePayload p;
                                     p.isTrackpad = true;
                                     p.isRotate = true;
                                     p.deltaAngle = [event rotation];
                                     PostGesture(p);
                                     return event;
                                   }];

  // 4. Force Click（重按）
  g_pressureMonitor = [NSEvent
      addLocalMonitorForEventsMatchingMask:NSEventMaskPressure
                                   handler:^NSEvent* _Nullable(NSEvent* event) {
                                     if (event.pressureBehavior == NSPressureBehaviorPrimaryDeepClick) {
                                       int last = g_lastPressureStage.load(std::memory_order_relaxed);
                                       if (last == 1 && event.stage == 2) {
                                         PostSimple(g_tsfnForceClick);
                                       }
                                       g_lastPressureStage.store((int)event.stage,
                                                                 std::memory_order_relaxed);
                                     }
                                     return event;
                                   }];
}

static void EnsureMonitorsInstalled() {
  std::call_once(g_installOnce, []() {
    if ([NSThread isMainThread]) {
      InstallMonitorsOnMain();
    } else {
      dispatch_sync(dispatch_get_main_queue(), ^{
        InstallMonitorsOnMain();
      });
    }
  });
}

static void RemoveMonitors() {
  dispatch_block_t work = ^{
    if (g_scrollMonitor)   { [NSEvent removeMonitor:g_scrollMonitor];   g_scrollMonitor = nil; }
    if (g_magnifyMonitor)  { [NSEvent removeMonitor:g_magnifyMonitor];  g_magnifyMonitor = nil; }
    if (g_rotateMonitor)   { [NSEvent removeMonitor:g_rotateMonitor];   g_rotateMonitor = nil; }
    if (g_pressureMonitor) { [NSEvent removeMonitor:g_pressureMonitor]; g_pressureMonitor = nil; }
  };
  if ([NSThread isMainThread]) work();
  else dispatch_sync(dispatch_get_main_queue(), work);
}

// ============================================================
// N-API 导出
// ============================================================
static void setupBegan(const Napi::CallbackInfo& info) {
  EnsureMonitorsInstalled();
  g_tsfnBegan.Rebind(info.Env(), info.Length() > 0 ? info[0] : info.Env().Null(), "Began");
}

static void setupEnded(const Napi::CallbackInfo& info) {
  EnsureMonitorsInstalled();
  g_tsfnEnded.Rebind(info.Env(), info.Length() > 0 ? info[0] : info.Env().Null(), "Ended");
}

static void setupGesture(const Napi::CallbackInfo& info) {
  EnsureMonitorsInstalled();
  g_tsfnGesture.Rebind(info.Env(), info.Length() > 0 ? info[0] : info.Env().Null(), "Gesture");
}

static void setupForceClick(const Napi::CallbackInfo& info) {
  EnsureMonitorsInstalled();
  g_tsfnForceClick.Rebind(info.Env(), info.Length() > 0 ? info[0] : info.Env().Null(), "ForceClick");
}

static void triggerFeedback(const Napi::CallbackInfo& /*info*/) {
  dispatch_block_t work = ^{
    [[NSHapticFeedbackManager defaultPerformer]
        performFeedbackPattern:NSHapticFeedbackPatternAlignment
               performanceTime:NSHapticFeedbackPerformanceTimeNow];
  };
  if ([NSThread isMainThread]) work();
  else dispatch_async(dispatch_get_main_queue(), work);
}

static void teardown(const Napi::CallbackInfo& /*info*/) {
  g_tsfnBegan.Clear();
  g_tsfnEnded.Clear();
  g_tsfnGesture.Clear();
  g_tsfnForceClick.Clear();
  RemoveMonitors();
}

static Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports.Set("onTrackpadScrollBegan", Napi::Function::New(env, setupBegan));
  exports.Set("onTrackpadScrollEnded", Napi::Function::New(env, setupEnded));
  exports.Set("onGesture",             Napi::Function::New(env, setupGesture));
  exports.Set("onForceClick",          Napi::Function::New(env, setupForceClick));
  exports.Set("triggerFeedback",       Napi::Function::New(env, triggerFeedback));
  exports.Set("teardown",              Napi::Function::New(env, teardown));

  // 可选：进程退出时自动清理，避免野引用
  napi_add_env_cleanup_hook(
      env, [](void*) {
        g_tsfnBegan.Clear();
        g_tsfnEnded.Clear();
        g_tsfnGesture.Clear();
        g_tsfnForceClick.Clear();
        RemoveMonitors();
      },
      nullptr);
  return exports;
}

NODE_API_MODULE(addon, Init);