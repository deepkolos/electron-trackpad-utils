{
    "targets": [
        {
            "target_name": "addon",
            "sources": [],
            "conditions": [
                [
                    "OS==\"mac\"",
                    {
                        "sources": [
                            "addon.mm"
                        ],
                        "xcode_settings": {
                            "MACOSX_DEPLOYMENT_TARGET": "10.15",
                            "CLANG_CXX_LANGUAGE_STANDARD": "c++17",
                            "CLANG_CXX_LIBRARY": "libc++",
                            "CLANG_ENABLE_OBJC_ARC": "YES",
                            "GCC_ENABLE_CPP_EXCEPTIONS": "NO",
                            "OTHER_CPLUSPLUSFLAGS": [
                                "-std=c++17",
                                "-stdlib=libc++",
                                "-fobjc-arc"
                            ],
                            "OTHER_LDFLAGS": [
                                "-framework CoreFoundation",
                                "-framework Foundation",
                                "-framework AppKit"
                            ]
                        },
                        "link_settings": {
                            "libraries": [
                                "$(SDKROOT)/System/Library/Frameworks/CoreFoundation.framework",
                                "$(SDKROOT)/System/Library/Frameworks/Foundation.framework",
                                "$(SDKROOT)/System/Library/Frameworks/AppKit.framework"
                            ]
                        }
                    }
                ]
            ],
            "include_dirs": [
                "<!@(node -p \"require('node-addon-api').include\")"
            ],
            "dependencies": [
                "<!(node -p \"require('node-addon-api').gyp\")"
            ],
            "defines": [
                "NAPI_DISABLE_CPP_EXCEPTIONS"
            ]
        }
    ]
}