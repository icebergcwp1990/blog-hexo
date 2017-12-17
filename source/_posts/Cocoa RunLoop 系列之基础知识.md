title: Cocoa RunLoop 系列之基础知识
date: 2015-01-05 10:10:07
tags:
- RunLoop
categories:
- 专业
keywords: RunLoop
decription: 探索RunLoop的实现原理

---

这篇博客主要结合Apple开发者文档和个人的理解，写的一篇关于Cocoa RunLoop基本知识点的文章。在文档的基础上，概况和梳理了RunLoop相关的知识点。

### 一、Event Loop & Cocoa RunLoop

#### 宏观上：Event Loop

1. RunLoop是一个用于循环监听和处理事件或者消息的模型，接收请求，然后派发给相关的处理模块，wikipedia上有更为全面的介绍：[Event_loop](https://en.wikipedia.org/wiki/Event_loop)
2. Cocoa RunLoop属于Event Loop模型在Mac平台的具体实现
3. [其他平台的类似实现](https://en.wikipedia.org/wiki/Event_loop#Implementations)：X Window程序，Windows程序 ，Glib库等

#### 微观上: Cocoa RunLoop

1. Cocoa RunLoop本质上就是一个对象，提供一个入口函数启动事件循环，在满足特点条件后才会退出。
2. Cocoa RunLoop与普通while/for循环不同的是它能监听处理事件和消息，能智能休眠和被唤醒，这些功能的其实现依赖于Mac Port。


### 二、 Cocoa RunLoop的内部结构

但凡说到Cocoa RunLoop内部结构，都离不开下面这张图，来源于Apple开发者文档

![图1-1 RunLoop结构图](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Multithreading/Art/runloop.jpg)

结合上图，可将RunLoop架构划分为四个部分：

1. 事件源
2. 运行模式
3. 循环机制
4. 执行反馈

#### 1. 事件源 

Cocoa RunLoop接受的事件源分为两种类型：Input Sources 和 Timer Sources

##### 1.1. Input Sources 

Input Sources通过异步派发的方式将事件转送到目标线程，事件类别分为两大块：

* Port-Based Sources ：
	
	基于Mach端口的事件源，Cocoa和Core Foundation这两个框架已经提供了内部支持，只需要调用端口相关的对象或者函数就能提供端口进行通信。比如：将NSPort对象部署到RunLoop中，实现两个线程的循环通信。
	
* Custom Input Sources ：

	* 用户自定义的输入源：使用Core Foundation框架中CFRunLoopSourceRef对象的相关函数实现。具体实现可以查看另外一篇博客：[Cocoa RunLoop 系列之Configure Custom InputSource](http://icebergcwp.com/2015/01/10/Cocoa%20RunLoop%E7%B3%BB%E5%88%97%E4%B9%8B%E9%85%8D%E7%BD%AE%E8%87%AA%E5%AE%9A%E4%B9%89%E8%BE%93%E5%85%A5%E6%BA%90/)
	* Cocoa Perform Selector Sources：Cocoa框架内部实现的自定义输入源，可以跨线程调用，实现线程见通信，有点类似于Port-Based事件源，不同的是这种事件源只在RunLoop上部署一次，执行结束后便会自动移除。如果目标线程中没有启动RunLoop也就意味着无法部署这类事件源，因此不会得到预期的结果。
	
		使用Cocoa自定义事件源的函数接口，如下：

 ``` objc 
 
 	//部署在主线程
 	//参数列表：Selector:事件源处理函数,Selector参数,是否阻塞当前线程,指定RunLoop模式
 	performSelectorOnMainThread:withObject:waitUntilDone:
	performSelectorOnMainThread:withObject:waitUntilDone:modes:
	
	//部署在指定线程
	//参数列表：Selector:事件源处理函数,指定线程,Selector参数,是否阻塞当前线程,指定RunLoop模式
	permSelector:onThread:withObject:waitUntilDone:
	performSelector:onThread:withObject:waitUntilDone:modes:
	
	//部署在当前线程
	//参数列表：Selector:事件源处理函数,Selector参数,延时执行时间,指定RunLoop模式
	performSelector:withObject:afterDelay:
	performSelector:withObject:afterDelay:inModes:
	 
	//撤销某个对象通过函数performSelector:withObject:afterDelay:部署在当前线程的全部或者指定事件源
	cancelPreviousPerformRequestsWithTarget:
	cancelPreviousPerformRequestsWithTarget:selector:object:
 
 ```
 综上，Input Sources包括基于Mach端口的事件源和自定义的事件源，二者的唯一区别在于被触发的方式：前者是由内核自动触发，后者则需要在其他线程中手动触发。
 
##### 1.2. Timer Sources 
 
 不同于Input Sources的异步派发，Timer Source是通过同步派发的方式，在预设时间到达时将事件转送到目标线程。这种事件源可用于线程的自我提醒功能，实现周期性的任务。
 
 * 如果RunLoop当前运行模式没有添加Time Sources，则在RunLoop中部署的定时器不会被执行。
 * 设定的间隔时间与真实的触发时间之间没有必然联系，定时器会根据设定的间隔时间周期性的派发消息到RunLoop，但是真实的触发时间由RunLoop决定，假设RunLoop当前正在处理其一个长时间的任务，则触发时间会被延迟，如果在最终触发之前Timer已经派发了N个消息，RunLoop也只会当做一次派发对待，触发一次对应的处理函数。
 
#### 2. 运行模式

运行模式类似于一个过滤器，用于屏蔽那些不关心的事件源，让RunLoop专注于监听和处理指定的事件源和RunLoop Observer。

CFRunLoopMode 和 CFRunLoop 的数据结构大致如下：

``` objc 

	struct __CFRunLoop {
	    CFMutableSetRef _commonModes;     // Set
	    CFMutableSetRef _commonModeItems; // Set<Source/Observer/Timer>
	    CFRunLoopModeRef _currentMode;    // Current Runloop Mode
	    CFMutableSetRef _modes;           // Set
	    ...
	};
	
	struct __CFRunLoopMode {
	    CFStringRef _name;            // Mode Name, 例如 @"kCFRunLoopDefaultMode"
	    CFMutableSetRef _sources0;    // Set
	    CFMutableSetRef _sources1;    // Set
	    CFMutableArrayRef _observers; // Array
	    CFMutableArrayRef _timers;    // Array
	    ...
	};

```
结合以上源码，总结以下几点：

* 每种模式通过name属性作为标识。
* 一种运行模式（Run Loop Mode）就是一个集合，包含需要监听的事件源Input Sources和Timer Soueces以及需要触发的RunLoop observers。
* Cocoa RunLoop包含若干个Mode，调用RunLoop是指定的Mode称之为CurrentMode。RunLoop可以在不同的Mode下切换，切换时退出CurrentMode,并保存相关上下文，再进入新的Mode。
* 在启动Cocoa RunLoop是必须指定一种的运行模式，且如果指定的运行模式没有包含事件源或者observers，RunLoop会立刻退出。
* CFRunLoop结构中的commonModes是Mode集合,将某个Mode的name添加到commonModes集合中，表示这个Mode具有“common”属性。
* CFRunLoop结构中的commonModeItems则是共用源的集合，包括事件源和执行反馈。这些共用源会被自动添加到具有“common”属性的Mode中。

** Note ** : 不同的运行模式区别在于事件源的不同，比如来源于不同端口的事件和端口事件与Timer事件。不能用于区分不同的事件类型，比如鼠标消息事件和键盘消息事件，因为这两种事件都属于基于端口的事件源。
 
以下是苹果预定义好的一些运行模式：
	
* NSDefaultRunLoopMode //默认的运行模式，适用于大部分情况
* NSConnectionReplyMode //Cocoa库用于监听NSConnection对象响应，开发者很少使用
* NSModalPanelRunLoopMode //模态窗口相关事件源
* NSEventTrackingRunLoopMode  //鼠标拖拽或者屏幕滚动时的事件源
* NSRunLoopCommonModes //用于操作RunLoop结构中commonModes和commonModeItems两个属性
	
#### 3. 循环机制

循环机制涉及两方面：

##### 3.1. RunLoop与线程之间的关系 

Apple文档中提到:开发者不需要手动创建RunLoop对象，每个线程包括主线程都关联了一个RunLoop对象。除了主线程的RunLoop在程序启动时被开启，其他线程的RunLoop都需要手动开启。

待解决的疑问：

* 线程中的RunLoop是一直存在还是需要时再创建？
* 线程与RunLoop的是如何建立联系的？
* 线程与RunLoop对象是否是一一对应的关系？

##### 3.2. RunLoop事件处理流程 

弄清楚RunLoop内部处理逻辑是理解RunLoop的关键，将单独写一篇博客进行分析。

待解决的疑问：

* RunLoop如何处理不同事件源？
* RunLoop不同模式切换是如何实现的？

以上两方面，将在下一篇博客[Cocoa RunLoop 系列之源码解析]()中结合源代码来找到答案。

#### 4. 执行反馈

RunLoop Observers机制属于RunLoop一个反馈机制，将RunLoop一次循环划分成若干个节点，当执行到对应的节点调用相应的回调函数，将RunLoop当前的执行状态反馈给用户。

* 用户可以通过Core Foundation框架中的CFRunLoopObserverRef注册 observers。
* 监听节点：

	* The entrance to the run loop. //RunLoop启动
	* When the run loop is about to process a timer. //即将处理Timer事件源
	* When the run loop is about to process an input source. //即将处理Input事件源
	* When the run loop is about to go to sleep. //即将进入休眠
	* When the run loop has woken up, but before it has processed the event that woke it up. //重新被唤醒，且在处理唤醒事件之前
	* The exit from the run loop. //退出RunLoop
	
* 监听类别分为两种：一次性和重复监听。
	
	
### 三、何时使用RunLoop

由于主线程的RunLoop在程序启动时被自动创建并执行，因此只有在其他线程中才需要手动启动RunLoop。很多情况下，对于RunLoop的使用多数情况是在主线程中，包括进行RunLoop模式切换，设置RunLoop Observer等。

在非主线程中，以下几种情况适用于RunLoop:

* 使用基于端口或者自定义的事件源与其他线程进行通信。
* 需要在当前线程中使用Timer，必须部署才RunLoop中才有效。
* 在目标线程中调用performSelector… 函数，因为本质上使用了Cocoa自定义的事件源，依赖于RunLoop才能被触发。
* 线程需要进行周期性的任务，需要长时间存在，而非执行一次。

### 四、总结

一直以来，RunLoop对我来说都属于一个比较模糊的概念，在实际编程中也有用到RunLoop的一些功能，确实感觉到很强大，但是仅仅停留在应用层面，并不是很理解具体含义。因此，为了更好的使用RunLoop，有必要研究和梳理RunLoop相关的知识点。