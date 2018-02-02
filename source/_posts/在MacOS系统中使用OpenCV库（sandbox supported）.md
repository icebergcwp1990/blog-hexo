title: 在MacOS系统中使用OpenCV库（sandbox supported）
date: 2017-12-24 17:47:07
tags: 
- OpenCV
categories: 
- 专业
keywords: 
- install_name_tool
- OpenCV
decription: 使用install_name_tool修改动态库之间的依赖关系（以opencv库为例）

---

最近因工作需要研究图片格式转换相关的知识点，其中使用到OpenCV库（一个基于BSD许可（开源）发行的跨平台计算机视觉库，很强大）中的ssim（结构相似性）算法实现来计算两张图片的相似度，用以做图片转换前后的对比。因此需要在Xcode中配置OpenCV库并且能在沙盒下使用，这一过程花费了将近一天的工作时间才配置成功，由于网上大多数资料基本上都是在非沙盒条件下的配置教程，对我没有太多实质性的帮助，这也是笔者写这篇博客的意义所在。

### 安装OpenCV库 ###

在Mac下，安装OpenCV库的方式一般有两种：使用brew命令或者使用make编译源代码。笔者用的是第一种：在终端执行命令：brew insall opencv，即可安装opencv库及其所依赖的动态库。安装成功之后，会在命令行终端的最后一行显示当前OpenCV库的安装路径和版本号，笔者电脑上的安装路径为：/usr/local/Cellar/opencv/3.4.0\_1，版本号为3.4.0\_1。

在/usr/local/Cellar/opencv/3.4.0\_1/include目录下有两个文件夹：opencv和opencv2，里面是OpenCV相关的头文件。/usr/local/Cellar/opencv/3.4.0\_1/lib/下有许多前缀为libopencv_的dylib文件，这些都是OpenCV的链接库文件。

### 在MacOS下配置并使用OpenCV库 ###

笔者项目中用到OpenCV库中的libopencv\_imgproc.3.4.0.dylib库。因此下文以这个库为例进行展开，其他的库类似操作即可。

#### 使用otool查看库依赖关系 ####

首先使用otool命令查看libopencv\_imgproc.3.4.0.dylib的依赖关系，必须确保其这些依赖的库在系统中能够找到。

```objc
$ otool -L /usr/local/Cellar/opencv/3.4.0_1/lib/libopencv_imgproc.3.4.0.dylib 
/usr/local/Cellar/opencv/3.4.0_1/lib/libopencv_imgproc.3.4.0.dylib:
	/usr/local/opt/opencv/lib/libopencv_imgproc.3.4.dylib (compatibility version 3.4.0, current version 3.4.0)
	@rpath/libopencv_core.3.4.dylib (compatibility version 3.4.0, current version 3.4.0)
	/usr/local/opt/tbb/lib/libtbb.dylib (compatibility version 0.0.0, current version 0.0.0)
	/usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 120.1.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1226.10.1)

```

可以看到libopencv\_imgproc.3.4.0.dylib一共依赖了4个库，忽略系统自带的libc++.1.dylib和libSystem.B.dylib，因为这两个库任何Mac电脑上都可以找到。另外两个库分别是@rpath/libopencv\_core.3.4.dylib和/usr/local/opt/tbb/lib/libtbb.dylib，分别查看这两个库所依赖的库。

查看libopencv\_core.3.4.dylib库的依赖关系。这个库是以libopencv_开头的，与libopencv\_imgproc.3.4.0.dylib在同一个目录下。

```objc
$ otool -L  /usr/local/Cellar/opencv/3.4.0_1/lib/libopencv_core.3.4.0.dylib 
/usr/local/Cellar/opencv/3.4.0_1/lib/libopencv_core.3.4.0.dylib:
	/usr/local/opt/opencv/lib/libopencv_core.3.4.dylib (compatibility version 3.4.0, current version 3.4.0)
	/usr/local/opt/tbb/lib/libtbb.dylib (compatibility version 0.0.0, current version 0.0.0)
	/usr/lib/libz.1.dylib (compatibility version 1.0.0, current version 1.2.5)
	/System/Library/Frameworks/OpenCL.framework/Versions/A/OpenCL (compatibility version 1.0.0, current version 1.0.0)
	/System/Library/Frameworks/Accelerate.framework/Versions/A/Accelerate (compatibility version 1.0.0, current version 4.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1226.10.1)
	/usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 120.1.0)
```

可以看到，忽略系统自带的库之后其所依赖的库只有一个：/usr/local/opt/tbb/lib/libtbb.dylib。说明libtbb.dylib这个库同时被libopencv\_core.3.4.dylib和libopencv\_imgproc.3.4.0.dylib引用到。

查看libtbb.dylib库的依赖关系，在目录/usr/local/opt/tbb/lib/目录下可找到这个库。

```objc
$ otool -L /usr/local/opt/tbb/lib/libtbb.dylib
/usr/local/opt/tbb/lib/libtbb.dylib:
	/usr/local/opt/tbb/lib/libtbb.dylib (compatibility version 0.0.0, current version 0.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1226.10.1)
	/usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 120.1.0)
```

可以看到libtbb.dylib库所依赖的都是系统自带的库，所以库依赖关系遍历到此结束。如果当前库还依赖于其他非系统自带库，则需要继续查找下去。

弄清楚库之间的依赖关系之后，接下来将库配置到Xcode中。

#### 无沙盒 ####

如果是无沙盒条件下使用OpenCV还是很简单的，因为使用brew命令安装OpenCV过程中所有依赖的库都已帮你配置好了，只需要配置好头文件和库文件即可，不需要关心库之间的依赖关系。

首先配置OpenCV库头文件的查找路径，在Xcode->Target->Build Settings中找到“Header Search Paths”选项，新添加一项：/usr/local/Cellar/opencv/3.4.0\_1/include。

配置OpenCV库文件的查找路径：在Xcode->Target->Build Settings中找到“Lib Search Paths”，新添加一项：/usr/local/Cellar/opencv/3.4.0\_1/lib。

![无沙盒配置头文件](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/originality/opencv/1.png)

接着切换到Xcode->Target->Build Phases的tab下，在“Link Binary With Libraries”中，将软件依赖的OpenCV链接库拖拽其中。笔者只用到了libopencv\_imgproc.3.4.0.dylib库，因此只需要拖拽这一个库即可。

![无沙盒配置库文件](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/originality/opencv/2.png)

对于 Lion 操作系统，需要在Xcode->Target->Build Settings中，将“C++ Language Dialect”设置成 C++11，将“C++ Standard Library”设置成libstdc++ ，如下图所示。个人感觉是由于Xcode默认设置的GNU++11、libc++与OpenCV库有一些兼容性问题，我在更改该设置前老是出现编译错误。后续版本在Montain Lion系统中解决了这个问题，因此不需要此操作。

![无沙盒配置编译器](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/originality/opencv/3.png)

注意，如果使用OpenCV库函数的源文件扩展名是.m的，你还需要改成.mm，这样编译器才知道该文件混合使用C++语言和Objective-C语言。

以上，无沙盒条件下配置完成。这种配置存在一个严重的缺陷，即如果想要编译后的软件在其他电脑上正常运行则必须确保其他电脑在同样系统目录下安装了OpenCV库，即OpenCV库头文件与链接库文件目录与编译电脑一致，显然这是不能接受的。常规的解决方法是将软件所依赖的库一并打包到软件中，具体配置过程可见于下文的有沙盒配置过程。

#### 有沙盒 ####

有沙盒与无沙盒的区别出来签名之外，还有一个重要的区别就是访问权限。无沙盒条件下，软件和Xcode一样拥有当前用户下的最高权限，可以访问当前用户下的任何目录，这也是为什么在Xcode的配置项中可以直接使用当前用户的系统路径的原因。

一旦为添加沙盒条件后，软件所能访问的目录局限于自己的沙盒下，不再有访问当前用户系统目录的权限。此时，只有将软件所依赖的库一并打包到软件中，才能使软件正常运行。具体步骤如下所示。

首先，将软件所依赖的库文件和头文件拷贝到项目工程下的OpenCV目录中，分别存放于lib目录和include目录中：

![有沙盒配置拷贝库相关文件](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/originality/opencv/4.png)

然后，配置OpenCV库头文件的查找路径，在Xcode->Target->Build Settings中找到“Header Search Paths”选项，新添加一项：\$(PROJECT_DIR)/OpenCV/include。

![有沙盒配置头文件](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/originality/opencv/5.png)

接着，配置OpenCV库文件的查找路径：在Xcode->Target->Build Settings中找到“Lib Search Paths”，新添加一项：\$(PROJECT_DIR)/OpenCV/lib。

![有沙盒配置库文件](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/originality/opencv/6.png)

其中PROJECT_DIR宏是Xcode自带的，表示xxx.xcodeproj文件所在的目录路径。

然后，切换到Xcode->Target->Build Phases的tab下，在“Link Binary With Libraries”中，将软件用到依赖的OpenCV链接库拖拽其中。笔者只用到了libopencv\_imgproc.3.4.0.dylib库，因此只需要拖拽这一个库即可。

![有沙盒配置关联库文件](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/originality/opencv/2.png)

接着，切换到Xcode->Target->Build Phases的tab下，在“Copy Files”中，将libopencv\_imgproc.3.4.0.dylib库及其所依赖的库拷贝到软件目录下的Frameworks中。

![有沙盒配置关联库文件](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/originality/opencv/7.png)

最后一步，使用install_name_tool命令修改依赖库之间、软件与依赖库的依赖关系。因为使用brew安装，库之间的依赖关系以及库本身的加载路径都是系统路径，在沙盒条件下是无效的。

切换到Xcode->Target->Build Phases的tab下，点击左上角的“+”，选择“New Run Script Phase”，新建一个“Run Script”项目，里面是一个shell脚本文件，在Xcode编译运行前执行。

![有沙盒配置修改库依赖关系](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/originality/opencv/8.png)

修改依赖关系的顺序很重要，如果依赖关系是：软件->dylibA->dylibB->dylibC，则修改依赖关系的顺序是：dylibC->dylibB->dylibA->软件。

笔者当前软件中的依赖关系是：软件->libopencv\_imgproc.3.4.0.dylib->libopencv\_core.3.4.0.dylib->libtbb.dylib。

由于libtbb.dylib库所依赖的都是系统自带库，因此不需要修改。

修改命令与参数简单介绍，详细使用方式可通过终端执行命令：man install\_name\_tool查看：
install\_name\_tool -change oldPath newPath lib(or executable file)

**1. 修改libopencv\_core.3.4.0.dylib对libtbb.dylib的依赖关系**

```objc
install_name_tool -change "/usr/local/opt/tbb/lib/libtbb.dylib" "@loader_path/libtbb.dylib" "$TARGET_BUILD_DIR/$PRODUCT_NAME.app/Contents/Frameworks/libopencv_core.3.4.0.dylib"
```
其中@loader\_path是Xcode自带的宏，表示库加载路径，即libopencv\_core.3.4.0.dylib的加载路径，因为libtbb.dylib与libopencv\_core.3.4.0.dylib是在同一目录，因此@loader\_path/libtbb.dylib表示告诉libopencv\_core.3.4.0.dylib在自身所在目录中加载libtbb.dylib。

$TARGET\_BUILD\_DIR是Xcode自带的宏，表示Xcode编译目录，即编译后的软件存放的目录。PRODUCT\_NAME宏也是Xcode自带的，表示软件名称。因为笔者项目中是先拷贝库文件到软件目录中，再修改依赖关系。因此libopencv\_core.3.4.0.dylib库所在路径为：$TARGET\_BUILD\_DIR/$PRODUCT\_NAME.app/Contents/Frameworks/libopencv\_core.3.4.0.dylib。

以下修改命令类似，不再赘述。

**2. 修改libopencv\_imgproc.3.4.0.dylib对libtbb.dylib和libopencv\_core.3.4.0.dylib的依赖关系**

```objc
install_name_tool -change "/usr/local/opt/tbb/lib/libtbb.dylib" "@loader_path/libtbb.dylib" "$TARGET_BUILD_DIR/$PRODUCT_NAME.app/Contents/Frameworks/libopencv_imgproc.3.4.0.dylib"

install_name_tool -change "@rpath/libopencv_core.3.4.dylib" "@loader_path/libopencv_core.3.4.0.dylib" "$TARGET_BUILD_DIR/$PRODUCT_NAME.app/Contents/Frameworks/libopencv_imgproc.3.4.0.dylib"
```

**3.软件对libopencv\_imgproc.3.4.0.dylib库的依赖关系**

```objc
install_name_tool -change "/usr/local/opt/opencv/lib/libopencv_imgproc.3.4.dylib" "@executable_path/../Frameworks/libopencv_imgproc.3.4.0.dylib" "$TARGET_BUILD_DIR/$PRODUCT_NAME.app/Contents/MacOS/$PRODUCT_NAME"
```

值得注意的是，软件路径必须可执行文件的路径$TARGET\_BUILD\_DIR/$PRODUCT\_NAME.app/Contents/MacOS/$PRODUCT\_NAME，而不能是$TARGET\_BUILD\_DIR/$PRODUCT\_NAME.app，因为xxx.app文件本质上的一个目录。

**注意：如果在软件编译后运行时crash，并提示类似ImageLoaderMachO的错误则很可能是因为从系统目录下拷贝过来的库文件没有写的权限。因为OpenCV使用的是brew命令安装，brew使用的是root权限，而Xcode只有当前目录下的最高权限，所以必须确保库文件在当前用户下有读写权限，可以使用chmod +rw /path/to/dylib添加读写权限**

以上，在有沙盒条件下的配置完成。

### 小结 ###
笔者在刚开始配置过程中，由于自身知识储备不足的原因被折腾得够呛。现在看来整个配置过程其实不难，通过博客记录一遍思路和流程显得更为清晰，理解也更为深刻。