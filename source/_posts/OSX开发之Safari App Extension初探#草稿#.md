title: OSX开发之Safari App Extension初探
date: 2018-08-06 23:04:07
tags: 
- OSX
categories: 
- 专业
- OSX
keywords: 
- Safari
- Extension

---

#### 什么是Safari App Extension？

1. 能做什么？
2. 包含哪些部分：extension-containing app-host app [参考资料](https://developer.apple.com/documentation/safariservices/safari_app_extensions?language=objc)
3. 与 Safari Extension 的异同 [参考资料](https://developer.apple.com/documentation/safariservices/safari_app_extensions/converting_a_legacy_safari_extension_to_a_safari_app_extension?language=objc)

#### 创建一个Safari App Extension

1.  创建
2. App配置
3. 运行 （Safari配置以及在Xcode中运行host app并不会加载Safari App Extension，但是如果双击启动host app则会加载）
4. 调试 [参考资料](https://medium.com/@euginedubinin/ios-debugging-application-extension-without-a-host-app-89abf35a36af)

#### 核心代码讲解

1.  Extension 与 containing app 以及 containing app 与 host app 之间的通信实现 [参考资料](https://developer.apple.com/documentation/safariservices/safari_app_extensions/passing_messages_between_safari_app_extensions_and_injected_scripts?language=objc)
2. SFSafariApplication等几个核心类介绍

[GitHub Demo](https://github.com/icebergcwp1990/SafariAppExtensionDemo)

[Extending your App with Safari App Extensions WWDC 2016](https://developer.apple.com/videos/play/wwdc2016/214/)