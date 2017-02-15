title: 揭开ARC的神秘面纱系列-第3话
date: 2015-02-25 23:45:07
tags: 
- ARC
categories: 
- Objective-C
- 翻译
keywords: ARC
decription: 关于揭秘ARC内部实现的译文

---

[原文地址](http://www.galloway.me.uk/2012/02/a-look-under-arcs-hood-episode-3/)

“揭开ARC的神秘面纱系列”的这篇续集全都是关于@autoreleasepool这一新指令的。[LLVM提及到](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#autoreleasepool)autorelease pools（自动释放池）的语义已经在LLVM3.0版本中发生变化，尤其是，我觉得探究ARC模式更新之后是如何实现的会很有意思。

因此，思考一下下面的函数：

``` objc

	void foo() {
	    @autoreleasepool {
	        NSNumber *number = [NSNumber numberWithInt:0];
	        NSLog(@"number = %p", number);
	    }
	}

```
显然，这完全是不和谐的代码段，但是它能让我看到发生什么。在非ARC模式下，我们可能会假设：number将会在numberWithInt:函数中被分配内存，并返回的是一个自动释放的对象。因此当自动释放池随后被销毁时，number对象将会被释放。所以让我们看看是否如上所述（一如往常，使用的是ARMv7指令集）：

``` arm

	.globl  _foo
	    .align  2
	    .code   16
	    .thumb_func     _foo
	_foo:
	    push    {r4, r7, lr}
	    add     r7, sp, #4
	    blx     _objc_autoreleasePoolPush
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_-(LPC0_0+4))
	    movs    r2, #0
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_-(LPC0_0+4))
	    mov     r4, r0
	    movw    r0, :lower16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC0_1+4))
	LPC0_0:
	    add     r1, pc
	    movt    r0, :upper16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC0_1+4))
	LPC0_1:
	    add     r0, pc
	    ldr     r1, [r1]
	    ldr     r0, [r0]
	    blx     _objc_msgSend
	    mov     r1, r0
	    movw    r0, :lower16:(L__unnamed_cfstring_-(LPC0_2+4))
	    movt    r0, :upper16:(L__unnamed_cfstring_-(LPC0_2+4))
	LPC0_2:
	    add     r0, pc
	    blx     _NSLog
	    mov     r0, r4
	    blx     _objc_autoreleasePoolPop
	    pop     {r4, r7, pc}

```

不错，答案是肯定的。正是这样的。我们可以看到函数先将自动释放池入栈，然后调用numberWithInt:函数，然后将自动释放池出栈。正如我们所预料的。现在我们看看完全相同的代码在ARC模式编译出来是怎么样的：

``` arm

	.globl  _foo
	    .align  2
	    .code   16
	    .thumb_func     _foo
	_foo:
	    push    {r4, r5, r7, lr}
	    add     r7, sp, #8
	    blx     _objc_autoreleasePoolPush
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_-(LPC0_0+4))
	    movs    r2, #0
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_-(LPC0_0+4))
	    mov     r4, r0
	    movw    r0, :lower16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC0_1+4))
	LPC0_0:
	    add     r1, pc
	    movt    r0, :upper16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC0_1+4))
	LPC0_1:
	    add     r0, pc
	    ldr     r1, [r1]
	    ldr     r0, [r0]
	    blx     _objc_msgSend
	    @ InlineAsm Start
	    mov     r7, r7          @ marker for objc_retainAutoreleaseReturnValue
	    @ InlineAsm End
	    blx     _objc_retainAutoreleasedReturnValue
	    mov     r5, r0
	    movw    r0, :lower16:(L__unnamed_cfstring_-(LPC0_2+4))
	    movt    r0, :upper16:(L__unnamed_cfstring_-(LPC0_2+4))
	    mov     r1, r5
	LPC0_2:
	    add     r0, pc
	    blx     _NSLog
	    mov     r0, r5
	    blx     _objc_release
	    mov     r0, r4
	    blx     _objc_autoreleasePoolPop
	    pop     {r4, r5, r7, pc}

```

留意上述代码中objc_retainAutoreleasedReturnValue函数和objc_release的调用。ARC已经为我们做了决定，完全不必担心自动释放池，因为ARC可以直接不然自动释放池生效，通过调用objc_retainAutoreleasedReturnValue函数对number对象进行retain一次，然后在后面在调用objc_release函数释放它。这意味着自动释放池的逻辑不一定执行，让人满意的结果。

注意到自动释放池一直需要入栈和出栈，是因为ARC无法知晓numberWithInt函数和NSLog函数中会发生什么，不知道在函数中是否有对象会被加入释放池。如果说ARC知道这两个函数不会自动释放任何东西则实际上可以移除自动释放池的入栈和出栈操作。也许这种逻辑在ARC未来的版本中出现，尽管我不是很确定那时候ARC的语义会如何实现。

现在让我思考另外一个例子，在这个例子中我们想要在自动释放池的作用域之外使用number对象。这应该告诉我们为什么ARC是一个神奇的工具。思考下面的代码：

``` objc

	void bar() {
	    NSNumber *number;
	    @autoreleasepool {
	        number = [NSNumber numberWithInt:0];
	        NSLog(@"number = %p", number);
	    }
	    NSLog(@"number = %p", number);
	}

```

你可能会认为上述这段看似很和谐的代码会出问题。问题在于number对象将在自动释放池中创建，在自动释放池初衷时被释放，但是却在释放之后继续使用。噢！让我们通过在非ARC模式下编译上述代码来看看我们的猜想是否是正确的：

``` arm

	.globl  _bar
	    .align  2
	    .code   16
	    .thumb_func     _bar
	_bar:
	    push    {r4, r5, r6, r7, lr}
	    add     r7, sp, #12
	    blx     _objc_autoreleasePoolPush
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_-(LPC1_0+4))
	    movs    r2, #0
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_-(LPC1_0+4))
	    mov     r4, r0
	    movw    r0, :lower16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC1_1+4))
	LPC1_0:
	    add     r1, pc
	    movt    r0, :upper16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC1_1+4))
	LPC1_1:
	    add     r0, pc
	    ldr     r1, [r1]
	    ldr     r0, [r0]
	    blx     _objc_msgSend
	    movw    r6, :lower16:(L__unnamed_cfstring_-(LPC1_2+4))
	    movt    r6, :upper16:(L__unnamed_cfstring_-(LPC1_2+4))
	LPC1_2:
	    add     r6, pc
	    mov     r5, r0
	    mov     r1, r5
	    mov     r0, r6
	    blx     _NSLog
	    mov     r0, r4
	    blx     _objc_autoreleasePoolPop
	    mov     r0, r6
	    mov     r1, r5
	    blx     _NSLog
	    pop     {r4, r5, r6, r7, pc}

```

很明显，正如我们所期望的那样没有调用retain,release或者autorelease，因为我们没有显式调用这些函数以及使用ARC。编译的结果也正如我们之前推理的那样。接下来让我们在ARC的帮助下会是什么样：

``` arm 

	.globl  _bar
	    .align  2
	    .code   16
	    .thumb_func     _bar
	_bar:
	    push    {r4, r5, r6, r7, lr}
	    add     r7, sp, #12
	    blx     _objc_autoreleasePoolPush
	    movw    r1, :lower16:(L_OBJC_SELECTOR_REFERENCES_-(LPC1_0+4))
	    movs    r2, #0
	    movt    r1, :upper16:(L_OBJC_SELECTOR_REFERENCES_-(LPC1_0+4))
	    mov     r4, r0
	    movw    r0, :lower16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC1_1+4))
	LPC1_0:
	    add     r1, pc
	    movt    r0, :upper16:(L_OBJC_CLASSLIST_REFERENCES_$_-(LPC1_1+4))
	LPC1_1:
	    add     r0, pc
	    ldr     r1, [r1]
	    ldr     r0, [r0]
	    blx     _objc_msgSend
	    @ InlineAsm Start
	    mov     r7, r7          @ marker for objc_retainAutoreleaseReturnValue
	    @ InlineAsm End
	    blx     _objc_retainAutoreleasedReturnValue
	    movw    r6, :lower16:(L__unnamed_cfstring_-(LPC1_2+4))
	    movt    r6, :upper16:(L__unnamed_cfstring_-(LPC1_2+4))
	LPC1_2:
	    add     r6, pc
	    mov     r5, r0
	    mov     r1, r5
	    mov     r0, r6
	    blx     _NSLog
	    mov     r0, r4
	    blx     _objc_autoreleasePoolPop
	    mov     r0, r6
	    mov     r1, r5
	    blx     _NSLog
	    mov     r0, r5
	    blx     _objc_release
	    pop     {r4, r5, r6, r7, pc}

```

此处应该有掌声！ARC识别出我们在自动释放池作用域之外使用了number对象，因此它如上一段代码一样对numberWithInt:函数的返回值进行了retain，但是这一次它将release操作放在了bar函数末尾而不是自动释放池出栈的时候。这一举措避免在一些代码中出现崩溃，我们可能会认为这些代码是正确的，但实际上却潜在着内存管理的bug。

