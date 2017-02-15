title: 揭开ARC的神秘面纱系列-第1话
date: 2015-02-05 23:16:07
tags: 
- ARC
categories: 
- Objective-C
- 翻译
keywords: ARC
decription: 关于揭秘ARC内部实现的译文

---

这个系列一共有四篇博客，是Matt Galloway大神关于ARC的内部实现的一些探索，看完之后觉得收获不少。因此尝试着翻译出来和大家分享，一定会翻译不当之处，希望大家及时指正。
[原文地址](http://www.galloway.me.uk/2012/01/a-look-under-arcs-hood-episode-1/)

以下是正文：

在Twitter上和[@jacobrelkin](https://twitter.com/jacobrelkin)进行了一次[交流](https://twitter.com/mattjgalloway/status/154478264537194496)之后，我决定写几篇博客关于ARC在神秘的面纱之下是如何运转和如何窥视其内部机制的方法。这篇博客我将解释ARC如何处理retain、release和autorelease这三个关键字对应的内部实现。

我们通过定义一个类作为开始，如下：

``` objc

	#import <Foundation/Foundation.h>
	
	@interface ClassA : NSObject
	@property (nonatomic, retain) NSNumber *foo;
	@end
	
	@implementation ClassA
	
	@synthesize foo;
	
	- (void)changeFooDirect:(NSNumber*)inFoo {
	    foo = inFoo;
	}
	
	- (void)changeFooSetter:(NSNumber*)inFoo {
	    self.foo = inFoo;
	}
	
	- (NSNumber*)newNumber {
	    return [[NSNumber alloc] initWithInt:10];
	}
	
	- (NSNumber*)getNumber {
	    return [[NSNumber alloc] initWithInt:10];
	}
	
	@end	
		
``` 
```

上述代码覆盖了ARC的几个重要的方面，包括直接访问成员变量与通过setter访问这两种方式的比较，以及当不同的函数名的函数返回某个对象时ARC将会如何添加autorelease属性。

让我们首先关注直接访问成员变量与通过setter访问这两种方式的比较。如果我们编译上述代码并查看其汇编代码将会洞悉其中的奥秘。我决定使用ARMv7指令集而非x86指令集是因为前者更容易理解（纯属个人见解！）。我们可以使用编译参数-fobjc-arc和-fno-objc-arc来开启或关闭ARC。在这些实例中我使用的是优化等级是第3级，也就意味着编译器将会移除多余的代码，这些代码我们既不感兴趣同时还会阻碍我们理解核心代码（读者做一个练习，在不设置优化等级的前提下编译上述代码，看看结果是怎样的）。

在非ARC的模式下采用如下指令进行编译上述代码：

	$ /Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/clang -isysroot /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk -arch armv7 -fno-objc-arc -O3 -S -o - test-arc.m

然后，查看changeFooDirect:和changeFooDirect:这个两个函数的汇编码：

``` arm

	.align  2
	    .code   16
	    .thumb_func     "-[ClassA changeFooDirect:]"
	"-[ClassA changeFooDirect:]":
	    movw    r1, :lower16:(_OBJC_IVAR_$_ClassA.foo-(LPC0_0+4))
	    movt    r1, :upper16:(_OBJC_IVAR_$_ClassA.foo-(LPC0_0+4))
	LPC0_0:
	    add     r1, pc
	    ldr     r1, [r1]
	    str     r2, [r0, r1]
	    bx      lr
	
	    .align  2
	    .code   16
	    .thumb_func     "-[ClassA changeFooSetter:]"
	"-[ClassA changeFooSetter:]":
	    push    {r7, lr}
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_-(LPC1_0+4))
	    mov     r7, sp
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_-(LPC1_0+4))
	LPC1_0:
	    add     r1, pc
	    ldr     r1, [r1]
	    blx     _objc_msgSend
	    pop     {r7, pc}

```

继续向前，看看在ARC模式下又是怎样的一副景象。采用如下所示的指令进行编译：

	$ /Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/clang -isysroot /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk -arch armv7 -fobjc-arc -O3 -S -o - test-arc.m


同样，此刻我们只关注changeFooDirect:和changeFooDirect:这两个函数：

``` arm

	.align  2
	    .code   16
	    .thumb_func     "-[ClassA changeFooDirect:]"
	"-[ClassA changeFooDirect:]":
	    push    {r7, lr}
	    movw    r1, :lower16:(_OBJC_IVAR_$_ClassA.foo-(LPC0_0+4))
	    mov     r7, sp
	    movt    r1, :upper16:(_OBJC_IVAR_$_ClassA.foo-(LPC0_0+4))
	LPC0_0:
	    add     r1, pc
	    ldr     r1, [r1]
	    add     r0, r1
	    mov     r1, r2
	    blx     _objc_storeStrong
	    pop     {r7, pc}
	
	    .align  2
	    .code   16
	    .thumb_func     "-[ClassA changeFooSetter:]"
	"-[ClassA changeFooSetter:]":
	    push    {r7, lr}
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_-(LPC1_0+4))
	    mov     r7, sp
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_-(LPC1_0+4))
	LPC1_0:
	    add     r1, pc
	    ldr     r1, [r1]
	    blx     _objc_msgSend
	    pop     {r7, pc}

```

我们可以一目了然地看到两段汇编代码的不同之处。函数changeFooSetter:完全一样，而函数changeFooDirect:已经发生了变化：调用了一次objc_storeStrong函数。有意思的地方就是这里。如果我们查阅[LLVM文档中objc_storeStrong函数的说明](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#runtime.objc_storeStrong)将会看到objc_storeStrong函数里完成一个典型的变量交换，释放旧变量然后持有新变量。然而在非ARC模式下，这个变量仅仅是赋值，并没有任何释放或者持有操作。这就是我们期望的结果，感谢ARC！

接下来是更有趣的地方，newNumber函数对比getNumber函数。这两个函数在非ARC模式下都返回一个引用计数为1的NSNumber对象，也就是说函数调用者持有返回对象。根据Cocoa的命名约定，这个结果似乎符合函数newNumber而不符合函数getNumber。我们期望看到函数getNumber中有调用autorelease。因此，让我们查看非ARC模式下的代码是怎样的：

``` arm

	.align  2
	    .code   16
	    .thumb_func     "-[ClassA newNumber]"
	"-[ClassA newNumber]":
	    push    {r7, lr}
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_2-(LPC2_0+4))
	    mov     r7, sp
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_2-(LPC2_0+4))
	    movw    r0, :lower16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC2_1+4))
	    movt    r0, :upper16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC2_1+4))
	LPC2_0:
	    add     r1, pc
	LPC2_1:
	    add     r0, pc
	    ldr     r1, [r1]
	    ldr     r0, [r0]
	    blx     _objc_msgSend
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_4-(LPC2_2+4))
	    movs    r2, #10
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_4-(LPC2_2+4))
	LPC2_2:
	    add     r1, pc
	    ldr     r1, [r1]
	    blx     _objc_msgSend
	    pop     {r7, pc}
	
	    .align  2
	    .code   16
	    .thumb_func     "-[ClassA getNumber]"
	"-[ClassA getNumber]":
	    push    {r7, lr}
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_2-(LPC3_0+4))
	    mov     r7, sp
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_2-(LPC3_0+4))
	    movw    r0, :lower16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC3_1+4))
	    movt    r0, :upper16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC3_1+4))
	LPC3_0:
	    add     r1, pc
	LPC3_1:
	    add     r0, pc
	    ldr     r1, [r1]
	    ldr     r0, [r0]
	    blx     _objc_msgSend
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_4-(LPC3_2+4))
	    movs    r2, #10
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_4-(LPC3_2+4))
	LPC3_2:
	    add     r1, pc
	    ldr     r1, [r1]
	    blx     _objc_msgSend
	    pop     {r7, pc}

```

然后是ARC模式下：

``` arm

	.align  2
	    .code   16
	    .thumb_func     "-[ClassA newNumber]"
	"-[ClassA newNumber]":
	    push    {r7, lr}
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_2-(LPC2_0+4))
	    mov     r7, sp
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_2-(LPC2_0+4))
	    movw    r0, :lower16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC2_1+4))
	    movt    r0, :upper16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC2_1+4))
	LPC2_0:
	    add     r1, pc
	LPC2_1:
	    add     r0, pc
	    ldr     r1, [r1]
	    ldr     r0, [r0]
	    blx     _objc_msgSend
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_4-(LPC2_2+4))
	    movs    r2, #10
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_4-(LPC2_2+4))
	LPC2_2:
	    add     r1, pc
	    ldr     r1, [r1]
	    blx     _objc_msgSend
	    pop     {r7, pc}
	
	    .align  2
	    .code   16
	    .thumb_func     "-[ClassA getNumber]"
	"-[ClassA getNumber]":
	    push    {r7, lr}
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_2-(LPC3_0+4))
	    mov     r7, sp
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_2-(LPC3_0+4))
	    movw    r0, :lower16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC3_1+4))
	    movt    r0, :upper16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC3_1+4))
	LPC3_0:
	    add     r1, pc
	LPC3_1:
	    add     r0, pc
	    ldr     r1, [r1]
	    ldr     r0, [r0]
	    blx     _objc_msgSend
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_4-(LPC3_2+4))
	    movs    r2, #10
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_4-(LPC3_2+4))
	LPC3_2:
	    add     r1, pc
	    ldr     r1, [r1]
	    blx     _objc_msgSend
	    blx     _objc_autorelease
	    pop     {r7, pc}

```

查看上述两段代码唯一不同点：ARC模式下getNumber:函数中调用了objc_autorelease。这也是我们所期望的，因为ARC模式能自动觉察到函数名是以关键字new还是关键字copy开头的，并为不属于这两种的情况的Get类函数的返回对象自动添加一次autorelease调用。棒极了！

这里仅仅只展示了关于ARC在两种模式下如何工作的一小部分奥秘，与此同时，我希望这能激励读者能自己去探索ARC的内部实现而不是理所当然的接受现有的知识点。作为一个程序员，理解自己使用的工具的内部实现是很重要的。
