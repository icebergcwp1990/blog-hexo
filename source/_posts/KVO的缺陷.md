title: KVO的缺陷
date: 2015-05-10 23:50:07
tags: 
- KVO
categories: 
- 专业
- 翻译
keywords: 
- Category
- KVO
decription: 翻译大神Mike Ash关于KVO缺陷的一篇博客

---

> 最近在学习和研究Cocoa库的KVO特性，期间发现大神Mike Ash的一篇关于讲述KVO缺陷的博客，觉得很有学习价值，遂想试着翻译以加深理解。

[原文地址](https://www.mikeash.com/pyblog/key-value-observing-done-right.html)

#### 翻译 ####

Cocoa的KVO特性强大和实用。可惜它的API真的有点糟糕，一些实现方式存在着固有的缺陷。我想探讨一下缺陷所在以及提供一套完善的方案。

##### 缺陷何在？ #####

KVO的API中存在三个主要的问题，全部都与类的多重继承结构注册监听器相关。这很重要，因为即便是基类NSObject（通过实现函数-bind:toObject:withKeyPath:options:）也会创建监听。

1、-addObserver:forKeyPath:options:context:函数不接受一个自定义的回调函数

如果你查阅过相似的APIs，比如NSNotificationCenter，你会发现在为一个指定的消息注册监听器时通常涉及到传入一个回调函数作为注册函数的参数。这样可以很容易将当前类的监听事件与父类进行区分，因为你可以直接将消息导向你自己的回调方法。然而，你使用KVO则不得不重载-observeValueForKeyPath:ofObject:change:context:函数，然后在其中处理你监听的事件或者调用父类实现。判断是否需要处理一个消息或是传递给继承链的上一层处理是个复杂的问题，事实上父类也有可能监听了同样的键值路径或者对象。

2、上下文指针变成鸡肋

这个是上一个问题的推论。因为你不能自定义监听的回调函数，也无法通过检测键值路径或者对象来判断父类是否也监听了某个消息。你需要采取其他途径来区分一个消息对象是否属于当前类或是其父类。上下文指针就是为此而生的。你必须创建一个唯一的指针且不会被父类使用，然后做完上下文参数传入函数-addObserver:forKeyPath:options:context:中。随后，你必须在回调函数-observeValueForKeyPath:ofObject:change:context:中检测参数context是否属于当前类。因此，你不能用上下文指针指向一个上下文，也意味着失去了其本该有的功能。

3、-removeObserver:forKeyPath:接受的参数不完善

这个函数不能传入上下文指针。这意味着如果当前类和父类在不同时期都监听了同样的对象或是键值路径，你没办法移除你自己的监听。调用这个函数可能注销你的监听，也可能是注销父类的，或是甚至同时注销两者。

很可惜一个如此强大的工具会有这么严重的缺陷。尤其Apple开始在新的APIs中弱化NSNotification和代理回调的功能，取而代之的是KVO。一个典型的例子是NSOperation：获知一个NSOperation任务完成的唯一途径是通过使用KVO监听它的“isFinished”属性。

##### 完善方案 #####

那么我们能为此做点什么？我不想一味地抱怨，所以我写了一个类来解决这个问题。你可以从我的[public svn repository](https://github.com/mikeash/mikeash.com-svn/tree/master/)获取它，使用如下方式：

svn co [http://www.mikeash.com/svn/MAKVONotificationCenter/](http://www.mikeash.com/svn/MAKVONotificationCenter/)

你也可以点击上面的链接查看源代码。

那么这个类具体实现是怎么样的？它利用了一个可以保证唯一性的指针：self指针。它不再直接使用目标对象注册某个监听通知（键值路径或者对象），取而代之的是为每个通知创建一个唯一的helper对象并且注册消息监听。随后，这个helper对象接收消息并派发给原有的监听者。因为helper对象对每一个监听者而言是唯一的，所以它可以以实例变量的方式持有关于监听者的元数据，而不需要依赖于上下文指针，至此上下文指针也完全作为函数所需的唯一指针。由于helper对象的职责就是监听KVO通知，监听者持有helper对象的生命周期，我们可以假设父类，NSObject，要么没有注册任何监听，要么监听同样持有一个helper作为监听助手。

MAKVONotificationCenter避开了上述的三个缺陷：

1、函数-addObserver:...中接受自定义回调函数作为参数，当被监听的键值路径发生变化时，自定义的回调函数会被调用。由于父类的回调函数是另外一个不同的函数，所以确保二者的监听不会互相干扰。

2、注册监听的函数中提供一个userinfo参数。可以是一个包含监听者任意信息的对象。

3、函数-removeObserver:...不再仅仅接受监听者和键值路径，还可以接受一个回调函数。这样即便子类和父类注册了同一键值路径或者同样的对象，二者都可以通过指定的回调函数注销监听，而不会影响彼此。

代码中一些值得注意的特征：

函数+defaultCenter中使用了[a simple lockless atomic call](https://www.mikeash.com/pyblog/late-night-cocoa.html)保证了单例模式的线程安全，不需要每次访问时进行加锁处理。这是一个不错的技术，创建一个安全的单例对象，不需要在每次被访问时提前初始化或是进行加解锁处理。

以NSObjct分类的方式提供一组更为轻便和更优的API。这是一个相比于直接访问MAKVONotificationCenter类的单例更好的方式。在一个极端的情况，MAKVONotificationCenter类可能会从头文件移除，留下的只有NSObject的分类实现。

这份代码压根没有被测试过。我所做过的测试都在代码Tester.m中。在你使用之前不要轻易相信这份代码。150行代码并不算多，但是使用的后果自负。

如果你希望在你的项目里使用它，你也许只要注明代码出处就可以了。如果发现了代码的不足欢迎提供补丁。








