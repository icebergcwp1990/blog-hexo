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

#### Safari App Extension简介

##### 什么是Safari App Extension
	
Safari App Extension，即Safari浏览器应用拓展。它是苹果新推出的一种Safari扩展开发技术，最低支持Safari10.0，主要由三个部分组成分别是：
	
- Safari App Axtension: 扩展app本身，使用JS、CSS等前端脚本语言。主要功能是包括两方面：
	1. 在插件运行之前注入js和css代码到当前的Safari浏览器页面，进而实现对页面的增删改查等功能
	2. 调用Safari提供的JS API接口与Containing app进行交互通信。
	
- Containing App: 扩展app的容器，属于Native App。主要功能包括四方面：
	1. 配置和加载扩展app
	2. 与扩展app进行通信
	3. 提供可在Safari工具栏显示的原生界面
	4. 与Host App进行交互通信和共享数据

- Host App: 主程序，也属于Native App。主要功能包括三方面：
	1. 加载Containing App
	2. 与Containing app通信交互
	3. 发布Safari App Extension到Apple App Store
	
结合上述的分析，Safari App Extension可使用两种组合的形式发布产品。一种是三个部分的App同时存在；另外一种是Host App只是作为发布工具，仅在第一次打开并完成扩展app安装之后就不再需要，因为安装好的扩展可在Safari->偏好设置->扩展中找到。
	 
3. 与 Safari Extension 的异同 [参考资料](https://developer.apple.com/documentation/safariservices/safari_app_extensions/converting_a_legacy_safari_extension_to_a_safari_app_extension?language=objc)

#### 创建一个Safari App Extension

1. 创建
2. App配置
3. 运行 （Safari配置以及在Xcode中运行host app并不会加载Safari App Extension，但是如果双击启动host app则会加载）
4. 调试 [参考资料](https://medium.com/@euginedubinin/ios-debugging-application-extension-without-a-host-app-89abf35a36af)

#### 核心代码讲解

1.  Extension 与 containing app 以及 containing app 与 host app 之间的通信实现 [参考资料](https://developer.apple.com/documentation/safariservices/safari_app_extensions/passing_messages_between_safari_app_extensions_and_injected_scripts?language=objc)
2. SFSafariApplication等几个核心类介绍

[GitHub Demo](https://github.com/icebergcwp1990/SafariAppExtensionDemo)

[Extending your App with Safari App Extensions WWDC 2016](https://developer.apple.com/videos/play/wwdc2016/214/)