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
	 
##### 与 Safari Extension 的异同 
	
Safari App Extension和Safari Extension的名称很相似，以至于在最开始研究的时候，我错以为二者是同一个东西，结果瞎忙活的一天才发现自己南辕北辙。不过，二者确实存在一些相似的地方。[苹果的这篇官方文档](https://developer.apple.com/documentation/safariservices/safari_app_extensions/converting_a_legacy_safari_extension_to_a_safari_app_extension?language=objc)具体介绍了如何将Safari Extension转换为Safari App Extension。简单来说，二者共同点在于js和css代码是完全可以复用的，不同的地方是Safari Extension的配置、开发以及发布平台都是基于Safari浏览器，而Safari App Extension则是基于Xcode，且产品发布平台是Apple App Store。

#### 创建一个Safari App Extension

1. 创建
	
	因为Safari App Extension是以插件（plugin）的形式存在于Host App中的，因此需要首先创建一个Host App，也就是普通的Mac OSX的应用程序。然后再添加一个Safari App Extension的Target即可。
	
2. 配置info.plist
	
	Safari App Extension在被加载之前，Safari浏览器会通过读取info.plist文件以获得扩展的一些基本信息。
	
	**NSExtension**，包括：
	
	- NSExtensionPointIdentifier：定值，必须是com.apple.Safari.extension，表示Safari扩展
	
	- NSExtensionPrincipalClass：扩展的核心类名，默认是SafariExtensionHandler类，里面一些部分实现了NSExtensionRequestHandling和SFSafariExtensionHandling协议，作为与Safari扩展通信和交互的接口。

	- SFSafariContentScript：用于指定注入的js脚本，以数组的形式表示，在扩展加载之前注入Safari浏览器当前的tab页。缺省值是只有一个文件script.js，也可以注入多个js文件，注入顺序依据数组中的顺序。

	- SFSafariToolbarItem：用于配置Safari扩展在工具栏中按钮的类型、图片以及tooltip等。按钮类型包括comman、popover等。

	- SFSafariWebsiteAccess：包括Allowed Domains和Level两个属性，分别表示允许访问的网站域名列表和网页访问权限。其中Level可以是Some和All，分别表示部分访问和无限制访问。

	**NSHumanReadableDescription**
	
	顾名思义，用于向用户阐述扩展基本功能的文字描述。在Safari浏览器的扩展管理器中选择某个插件就会显示对于的描述。
	
3. 运行 

	这里有一个坑，如果是Xcode中运行Host App并不会加载包含于其中的Safari App Extension，解决办法是编辑Safari App Extension的scheme，指定可执行文件为Host App，再编译运行即可。此外，如果是双击的方式打开某个已经编译好的Host App也会自动加载其中的扩展插件。然后在Safari->Preference->Extensions中可看到对应的扩展。值得注意的是，如果扩展插件不是从Apple App Store中下载的，那么是不能正常加载的，即便App在本地已经打包签名也一样。解决方法是勾选Safari Menu->Develop->Allow Unsigend Extensions即可。
	
4. 调试 

	Safari App Extension调试有两个值得注意的地方，第一，因为扩展插件是依附于Host App运行的，因为Xcode默认激活的是Host App进程，因此想要设置断点调试扩展插件，需要手动激活扩展进程。步骤是：在通过Xcode编译运行扩展进程之后，进入Safari Menu->Debug->Attach to process，选择对应的扩展进程。第二，在扩展插件中添加的NSLog调试信息不能在Xcode的终端输出，只能在电脑的控制台中查看。但是，lldb可以正常使用和输出。[更多细节参考这篇博客](https://medium.com/@euginedubinin/ios-debugging-application-extension-without-a-host-app-89abf35a36af)

#### 附录

一个关于Safari App Extensions的Demo:[GitHub Demo](https://github.com/icebergcwp1990/SafariAppExtensionDemo)

苹果2016年WWDC关于Safari App Extensions的介绍：[Extending your App with Safari App Extensions WWDC 2016](https://developer.apple.com/videos/play/wwdc2016/214/)