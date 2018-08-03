title: iOS开发之真机测试问题：Could not locate device support files
date: 2018-07-25 15:04:07
tags: 
- iOS
categories: 
- 专业
- iOS
keywords: BitCode

---

最近在做iOS真机测试时出现了运行失败的提示：“Could not locate device support files”。原因在于我的iPhone6上的iOS版本上11.4，而Xcode的版本是8.3.3，当前的Xcode过低不能将App安装到iOS11.4上。

在目录**/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport/**下可以查看当前Xcode所能支持的最高iOS版本。在我的电脑上，Xcode8.3.3自带（默认）所能支持最高的iOS版本是10.3.1 (14E8301)，版本号后面的括号时该iOS版本的编译ID，可以忽略。

解决方法一般有两种：

1. 安装与iPhone中iOS版本对应的Xcode版本，或者直接安装最新的Xcode版本。这种虽然简单，但是安装Xcode耗时太长，除非你恰巧有升级Xcode的需求，可以考虑这种方案。

2. 拷贝与iPhone中iOS版本对应的Device Support文档到目录**/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport/**中，然后重启Xcode即可。

至于Device Support文档的来源，我想这个[GitHub仓库](https://github.com/filsv/iPhoneOSDeviceSupport)应该能够满足你的需求。