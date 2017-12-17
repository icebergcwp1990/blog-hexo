title: 揭开ARC的神秘面纱系列-第2话
date: 2015-02-20 23:16:07
tags: 
- ARC
categories: 
- 专业
- 翻译
keywords: ARC
decription: 关于揭秘ARC内部实现的译文

---

[原文地址](http://www.galloway.me.uk/2012/01/a-look-under-arcs-hood-episode-2/)

以下是正文：

写完第一篇关于[揭开ARC神秘面纱](http://icebergcwp.com/2015/02/05/%E6%8F%AD%E5%BC%80ARC%E7%9A%84%E7%A5%9E%E7%A7%98%E9%9D%A2%E7%BA%B1%E7%B3%BB%E5%88%97-%E7%AC%AC1%E8%AF%9D/)的博客，我想和大家分享另外一些有趣的片段。这一次我好奇当你通过函数返回一个存在数组中的对象时会发生什么。非ARC模式，你可能会对这个对象retain一次再返回一个自动释放的对象。ARC模式下，我们虽然可以免去这些内存管理的操作，但还是不放心，觉得别扭。因此，我决定检测一下ARC是否做到位了。

考虑一下这个类：

``` objc

	#import <Foundation/Foundation.h>
	
	@interface ClassA : NSObject
	@property (nonatomic, strong) NSMutableArray *array;
	@end
	
	@implementation ClassA
	
	@synthesize array;
	
	- (id)popObject {
	    id lastObject = [array lastObject];
	    if (lastObject) {
	        [array removeLastObject];
	    }
	    return lastObject;
	}
	
	@end

```

在非ARC模式下，调用函数removeLastObject将会释放数组对对象的持有，如果这是对象的最后一个引用则对象的内存将会被释放，意味着返回的对象是一个已经被回收的对象。所以，我们应当retain一次lastObject并在返回前添加autorelease属性（加入自动释放池）。

尽管我完全明白ARC应该会完成这些工作，但是我还是担忧没有自己添加这些操作。我天真地以为ARC会一行行地解析函数中的代码。如果是这样，我觉得ARC也许没必要在我们引用lastObject对象的时候为它添加一次引用计数，此时ARC并不知道lastObject需要进行retain，所以ARC没必要非得做这些操作。

这就是我错误所在。显然，ARC在我们引用lastObject对象的时候为其添加一次引用计数，并在对象立刻作用域的时候进行了一次release操作，在我们这个例子中，由于我们是通过函数返回这个对象且函数名不是已关键字new或者copy开头，因此需要将对象加入自动释放池。

让我们看看上述代码编译之后的样子：

``` arm

	.thumb_func     "-[ClassA popObject]"
	"-[ClassA popObject]":
	    push    {r4, r5, r6, r7, lr}
	    movw    r6, :lower16:(_OBJC_IVAR_$_ClassA.array-(LPC0_0+4))
	    mov     r4, r0
	    movt    r6, :upper16:(_OBJC_IVAR_$_ClassA.array-(LPC0_0+4))
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_-(LPC0_1+4))
	LPC0_0:
	    add     r6, pc
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_-(LPC0_1+4))
	LPC0_1:
	    add     r1, pc
	    add     r7, sp, #12
	    ldr     r0, [r6]
	    ldr     r1, [r1]
	    ldr     r0, [r4, r0]
	    blx     _objc_msgSend
	    @ InlineAsm Start
	    mov     r7, r7          @ marker for objc_retainAutoreleaseReturnValue
	    @ InlineAsm End
	    blx     _objc_retainAutoreleasedReturnValue
	    mov     r5, r0
	    cbz     r5, LBB0_2
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_2-(LPC0_2+4))
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_2-(LPC0_2+4))
	    ldr     r0, [r6]
	LPC0_2:
	    add     r1, pc
	    ldr     r1, [r1]
	    ldr     r0, [r4, r0]
	    blx     _objc_msgSend
	LBB0_2:
	    mov     r0, r5
	    blx     _objc_autoreleaseReturnValue
	    pop     {r4, r5, r6, r7, pc}

```

好吧，事实如此。ARC已经为我们考虑周全了。ARC在代码中插入了objc_retainAutoreleaseReturnValue调用，这意味着ARC已经觉察到需要给一个已经加入自动释放池的返回值增加引用计数，这个操作属于ARC的一种优化处理，它仅仅是把对象从自动释放池中移除而并非真的添加一次引用计数。接下来在函数结尾处，ARC调用了objc_autoreleaseReturnValue，这个函数将即将返回的对象加入自动释放池。

这仅仅是关于揭开ARC神秘面纱系列的另外一个例子。随着使用ARC的次数增多，我愈发意识它的实用性。ARC减少代码中内存管理相关的错误，并将上述的代码片段进行最佳优化处理。






