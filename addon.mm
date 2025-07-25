#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#include <napi.h>
#import <objc/runtime.h>

Napi::ThreadSafeFunction tsfnBegan = NULL;
void (*callbackBegan)(Napi::Env env, Napi::Function jsCallback);

Napi::ThreadSafeFunction tsfnEnded = NULL;
void (*callbackEnded)(Napi::Env env, Napi::Function jsCallback);

Napi::ThreadSafeFunction tsfnGesture = NULL;

Napi::ThreadSafeFunction tsfnForceClick;
void (*callbackForceClick)(Napi::Env env, Napi::Function jsCallback);

NSDate *lastBeganDate;
NSDate *lastEndedDate;
BOOL began = true;

int lastPressureStage = 0;

@implementation NSEvent (TrackpadScroll)

+ (void)load {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	  Class theClass = [self class];

	  SEL originalSelector = @selector(deltaY);
	  SEL swizzledSelector = @selector(my_deltaY);

	  Method originalMethod = class_getInstanceMethod(theClass, originalSelector);
	  Method swizzledMethod = class_getInstanceMethod(theClass, swizzledSelector);

	  IMP originalImp = method_getImplementation(originalMethod);
	  IMP swizzledImp = method_getImplementation(swizzledMethod);

	  class_replaceMethod(theClass, swizzledSelector, originalImp, method_getTypeEncoding(originalMethod));
	  class_replaceMethod(theClass, originalSelector, swizzledImp, method_getTypeEncoding(swizzledMethod));
	});
}

- (CGFloat)my_deltaY {
	CGFloat deltaY_original = [self my_deltaY];

	if (self.type == NSEventTypeScrollWheel) {
		CGFloat deltaX;
		CGFloat deltaY;

		if ([self hasPreciseScrollingDeltas]) {
			deltaX = [self scrollingDeltaX];
			deltaY = [self scrollingDeltaY];
		} else {
			deltaX = [self deltaX] * 10;
			deltaY = deltaY_original * 10;
		}

		int intDeltaX = round(deltaX);
		int intDeltaY = round(deltaY);

		BOOL isTrackpad = [self phase] != NSEventPhaseNone || [self momentumPhase] != NSEventPhaseNone;

		if (tsfnGesture != NULL && (intDeltaX != 0 || intDeltaY != 0)) {
			tsfnGesture.BlockingCall([=](Napi::Env env, Napi::Function jsCallback) {
			  Napi::Object obj = Napi::Object::New(env);
			  obj.Set("deltaX", Napi::Number::New(env, intDeltaX));
			  obj.Set("deltaY", Napi::Number::New(env, intDeltaY));
			  obj.Set("isTrackpad", Napi::Boolean::New(env, isTrackpad));
			  obj.Set("isScale", Napi::Boolean::New(env, false));
			  obj.Set("isScroll", Napi::Boolean::New(env, true));
			  obj.Set("isRotate", Napi::Boolean::New(env, false));
			  obj.Set("magnification", Napi::Number::New(env, 0));
			  obj.Set("deltaAngle", Napi::Number::New(env, 0));
			  jsCallback.Call({obj});
			});
		}

		if ([self phase] == NSEventPhaseBegan) {
			if (lastBeganDate == nil || [lastBeganDate timeIntervalSinceNow] < -0.002) {
				if (tsfnBegan != NULL) {
					tsfnBegan.BlockingCall(callbackBegan);
				}
			}
			lastBeganDate = [NSDate date];
			began = true;
		} else if ([self phase] == NSEventPhaseEnded && began == true) {
			if (lastEndedDate == nil || [lastEndedDate timeIntervalSinceNow] < -0.002) {
				if (tsfnEnded != NULL) {
					tsfnEnded.BlockingCall(callbackEnded);
				}
			}
			lastEndedDate = [NSDate date];
			began = false;
		}
	}
	return deltaY_original;
}

@end

@implementation NSWindow (TrackpadUtils)

+ (void)load {
	[[NSOperationQueue mainQueue] addOperationWithBlock:^{
	  Class theClass = [self class];

	  SEL originalSelector = @selector(sendEvent:);
	  SEL swizzledSelector = @selector(my_sendEvent:);

	  Method originalMethod = class_getInstanceMethod(theClass, originalSelector);
	  Method swizzledMethod = class_getInstanceMethod(theClass, swizzledSelector);

	  IMP originalImp = method_getImplementation(originalMethod);
	  IMP swizzledImp = method_getImplementation(swizzledMethod);

	  class_replaceMethod(theClass, swizzledSelector, originalImp, method_getTypeEncoding(originalMethod));
	  class_replaceMethod(theClass, originalSelector, swizzledImp, method_getTypeEncoding(swizzledMethod));
	}];
}

- (void)my_sendEvent:(NSEvent *)event {
	if (event.type == NSEventTypeMagnify) {
		if (tsfnGesture != NULL) {
			CGFloat magnification = [event magnification];
			tsfnGesture.BlockingCall([=](Napi::Env env, Napi::Function jsCallback) {
			  Napi::Object obj = Napi::Object::New(env);
			  obj.Set("deltaX", Napi::Number::New(env, 0));
			  obj.Set("deltaY", Napi::Number::New(env, 0));
			  obj.Set("isTrackpad", Napi::Boolean::New(env, true));
			  obj.Set("isScale", Napi::Boolean::New(env, true));
			  obj.Set("isScroll", Napi::Boolean::New(env, false));
			  obj.Set("isRotate", Napi::Boolean::New(env, false));
			  obj.Set("magnification", Napi::Number::New(env, magnification));
			  obj.Set("deltaAngle", Napi::Number::New(env, 0));
			  jsCallback.Call({obj});
			});
		}
	} else if (event.type == NSEventTypeRotate) {
		if (tsfnGesture != NULL) {
			CGFloat rotation = [event rotation];
			tsfnGesture.BlockingCall([=](Napi::Env env, Napi::Function jsCallback) {
			  Napi::Object obj = Napi::Object::New(env);
			  obj.Set("deltaX", Napi::Number::New(env, 0));
			  obj.Set("deltaY", Napi::Number::New(env, 0));
			  obj.Set("isTrackpad", Napi::Boolean::New(env, true));
			  obj.Set("isScale", Napi::Boolean::New(env, false));
			  obj.Set("isScroll", Napi::Boolean::New(env, false));
			  obj.Set("isRotate", Napi::Boolean::New(env, true));
			  obj.Set("magnification", Napi::Number::New(env, 0));
			  obj.Set("deltaAngle", Napi::Number::New(env, rotation));
			  jsCallback.Call({obj});
			});
		}
	}
	if (event.type == NSEventTypePressure && event.pressureBehavior == NSPressureBehaviorPrimaryDeepClick) {
		if (lastPressureStage == 1 && event.stage == 2 && tsfnForceClick != NULL && callbackForceClick != NULL) {
			tsfnForceClick.BlockingCall(callbackForceClick);
		}
		lastPressureStage = event.stage;
	}
	[self my_sendEvent:event];
}

@end

void setupBegan(const Napi::CallbackInfo &info) {
	Napi::Env env = info.Env();
	tsfnBegan = Napi::ThreadSafeFunction::New(env, info[0].As<Napi::Function>(), "Began", 0, 1);
	callbackBegan = [](Napi::Env env, Napi::Function jsCallback) { jsCallback.Call({}); };
}

void setupEnded(const Napi::CallbackInfo &info) {
	Napi::Env env = info.Env();
	tsfnEnded = Napi::ThreadSafeFunction::New(env, info[0].As<Napi::Function>(), "Ended", 0, 1);
	callbackEnded = [](Napi::Env env, Napi::Function jsCallback) { jsCallback.Call({}); };
}

void setupGesture(const Napi::CallbackInfo &info) {
	Napi::Env env = info.Env();
	if (info.Length() > 0 && info[0].IsFunction()) {
		tsfnGesture = Napi::ThreadSafeFunction::New(env, info[0].As<Napi::Function>(), "Gesture", 0, 1);
	} else {
		tsfnGesture = NULL;
	}
}

void setupForceClick(const Napi::CallbackInfo &info) {
	Napi::Env env = info.Env();
	if (info.Length() > 0 && info[0].IsFunction()) {
		tsfnForceClick = Napi::ThreadSafeFunction::New(env, info[0].As<Napi::Function>(), "ForceClick", 0, 1);
		callbackForceClick = [](Napi::Env env, Napi::Function jsCallback) { jsCallback.Call({}); };
	} else {
		tsfnForceClick = NULL;
		callbackForceClick = NULL;
	}
}

void triggerFeedback(const Napi::CallbackInfo &info) {
	[[NSHapticFeedbackManager defaultPerformer] performFeedbackPattern:NSHapticFeedbackPatternAlignment
							   performanceTime:NSHapticFeedbackPerformanceTimeNow];
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
	exports.Set(Napi::String::New(env, "onTrackpadScrollBegan"), Napi::Function::New(env, setupBegan));
	exports.Set(Napi::String::New(env, "onTrackpadScrollEnded"), Napi::Function::New(env, setupEnded));
	exports.Set(Napi::String::New(env, "onGesture"), Napi::Function::New(env, setupGesture));
	exports.Set(Napi::String::New(env, "onForceClick"), Napi::Function::New(env, setupForceClick));
	exports.Set(Napi::String::New(env, "triggerFeedback"), Napi::Function::New(env, triggerFeedback));
	return exports;
};

NODE_API_MODULE(addon, Init);
