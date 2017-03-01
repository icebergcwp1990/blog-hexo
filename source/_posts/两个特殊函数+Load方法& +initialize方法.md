title: 两个特殊函数+load & +initialize
date: 2015-04-01 23:50:07
tags: 
- Category
categories: 
- Objective-C
keywords: Category
decription: 分析两个特殊函数+load和+initialize

---

记得还在上一家公司任职的时候，在研发部的探讨会会上就“+load的加载过程”这一议题有过激烈的讨论，大家各执一词，争得面红耳赤。最终是部门老大专门做了一期讲解，才平息了这场争执。但是那时候的讲解并未涉及到源代码分析，而是基于测试代码做的分析，故我并没有完全理解。

在苹果开发文档中提及到：+load是在类或者分类被添加到runtime的时候被调用，而+initialize则是在类或者子类第一次调用实例方法或者类方法之前被调用。

上面的说明只是说明了这两个函数调用时机，但是并没有涉及父类、子类和分类之间的调用顺序和相互影响，于是试着结合apple公司的开源代码分析一下这两个函数的加载过程，以加深理解。

#### +load ####

#### +initialize ####

#### 小结 ####

在上一篇博客[Objective-C Category 深入浅出系列之实现原理](http://icebergcwp.com/2015/03/25/Objective-C%20Category%20%E6%B7%B1%E5%85%A5%E6%B5%85%E5%87%BA%E7%B3%BB%E5%88%97%E4%B9%8B%E5%AE%9E%E7%8E%B0%E5%8E%9F%E7%90%86/)中结合源代码分析了Category的实现原理。其中有一个重要的知识点就是分类Category中函数会覆盖主类中同名的函数。然而这种情况发生的前提是函数必须是通过runtime机制（使用objc_msgSend发送消息）调用，因为这样才会通过遍历类的方法列表去获得方法对应的实现。