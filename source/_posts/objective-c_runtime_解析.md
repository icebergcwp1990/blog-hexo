title: Objective-C Runtime 解析
date: 2015-01-01 22:46:07
tags: 
- Runtime
categories: 
- Objective-C
- 翻译
keywords: Runtime
decription: 关于Objective-C Runtime的译文

---

这是一篇译文，作为一个英语水平处于半吊子的理科男，因此一定存在不尽原意的地方，翻译此文纯属个人喜好，希望能得到大家的指点和反馈，读者如有兴趣的话可以[查看原文](http://cocoasamurai.blogspot.jp/2010/01/understanding-objective-c-runtime.html)。

**以下是正文：**

一般而言，当人们刚接触Cocoa/Objective-C的时候，运行时机制（Objective-C Runtime）是最容易被忽视的特征之一。究其原因在于Objective-C是一门简单的语言，花费几个小时便能入门，此后，新手们通常会将大部分的时间和精力用于研究Cocoa Framework以及如何使用它。然而，每一个人至少应该清楚运行时是如何运转的，而不仅仅停留在编译方式的认知层面，如：[target doMethodWith:var];编译之后变成object_msgSend(target,@selector(doMethodWith:),var1)。了解运行时机制的工作原理可以帮助你进一步理解Objective-C这门语言以及你编写的App的运转流程。我相信各个水平层次的Mac/iPhone开发者都会在研究运行时机制的过程中有所收获。

### Objective-C Runtime库是开源的

Objective-C Runtime库是开源的，你随时可以在[源代码](http://opensource.apple.com)上查阅。事实上，查阅源代码是弄清楚Objective-C原理的首选途径之一，胜过阅读苹果开发文档。下载最新版本的源代码[点击我](http://opensource.apple.com/source/objc4/objc4-680/)。

### 动态 & 静态 语言

Objective-C是基于运行时的语言，意味着它会尽可能地将决定代码执行逻辑的操作从编译&链接阶段延迟到代码被执行的阶段。这将给你带来很大的灵活性，因此如果有必要的话你可以将消息重定向到合适的对象，或者你甚至可以交换两个方法实现，等等。实现上述功能需要运行时具备审查对象可以响应哪些请求和不能响应哪些请求然后准确地派发消息的能力。如果我们将Objective-C这一特性对比C语言。C语言程序运行始于main()函数，基于至上而下的设计执行你的逻辑和调用你实现的函数。C结构体不能通过发送请求到其他的结构体来执行某个函数。很可能你会编写一段C语言代码，如下所示：

``` c
	#include < stdio.h >
	int main(int argc, const char **argv[])
	{
	       printf("Hello World!");
	       return 0;
	}
```
	
上述代码经过编译器编译、优化，然后将优化后的代码转化成汇编语言：

``` arm
	.text
	 .align 4,0x90
	 .globl _main
	_main:
	Leh_func_begin1:
		pushq %rbp
	Llabel1:
	 movq %rsp, %rbp
	Llabel2:
	 subq $16, %rsp
	Llabel3:
	 movq %rsi, %rax
	 movl %edi, %ecx
	 movl %ecx, -8(%rbp)
	 movq %rax, -16(%rbp)
	 xorb %al, %al
	 leaq LC(%rip), %rcx
	 movq %rcx, %rdi
	 call _printf
	 movl $0, -4(%rbp)
	 movl -4(%rbp), %eax
	 addq $16, %rsp
	 popq %rbp
	 ret
	Leh_func_end1:
	 .cstring
	LC:
	 .asciz "Hello World!"
 ```

随后链接相关的库生成一个可执行文件。对比于Objective-C，虽然代码处理过程很相似，但是编译后的代码取决于Objective-C Runtime库。当我们最初学习Objective-C时被告知中括号里面的代码是如何被处理的，如下

``` objc
	[self doSomethingWithVar:var1];
```
	
	
被转变成

``` objc
	objc_msgSend(self,@selector(doSomethingWithVar:),var1);
```
	
除此之外我们并不真的知道运行时机制是如何工作的，也许很久以后会知道。

### 何为Runtime(运行时)

Objective-C Runtime就是一个Runtime库，主要有C语言&汇编语言编写而成，在C语言的基础上加上面向对象的功能之后就成为了Objective-C语言。这意味着运行时机制负责加载类，方法派发，方法传达等操作。本质上而言，运行时机制提供了所有的需要的结构用以支持Objective-C的面向对象编程。

### Objective-C 运行时术语

在进一步深入之前，让我们扫清一些术语的障碍，这样使我们处于同一立场。就MacOS X App & iPhone OS App开发者所关心而言，这里有两种运行时机制: Modern Runtime和Legacy Runtime。Modern Runtime适用于所有64位MacOS应用和所有iPhone应用，Legacy Runtime适用于所有的32位MacOS应用。运行时机制中有两种类型的函数：实例函数（以‘-’符号开头如-(void)doFoo）;类函数（以‘+’开头如+(id)alloc）。两种函数都与C函数很像，包含一组实现某个任务的代码，如下所示

``` objc
	-(NSString *)movieTitle
	{
	    return @"Futurama: Into the Wild Green Yonder";
	}
```

选择器：在Objective-C中，选择器本质上是一个C数据结构体用以标识一个对象将要执行的函数。在运行时机制中的定义如下

``` objc
	typedef struct objc_selector  *SEL; 
```
	
使用方式

``` objc
	SEL aSel = @selector(movieTitle); 
```
	
消息调用：

``` objc
	[target getMovieTitleForObject:obj];
```
	
Objective-C消息就是中括号[]里面的所有东西，包括消息的接受者target，调用的函数getMovieTileForObject以及所有发送的参数obj。消息调用虽然样式上类似于c函数调用但是实现却不同。实际上，当你发送一个消息给一个对象并意味着函数会被执行。对象可能会检测谁是消息的发送者，基于此再决定执行一个不同的函数或者转送消息给其他不同的目标对象。如果你查看运行时机制里的类定义，你将会看到如下所示的内容：

``` objc
	typedef struct objc_class *Class;
	typedef struct objc_object {
	    Class isa;
	} *id; 
```

这里有几个要点。首先是类Class和对象Object都有一个对应的结构体。所有的objc_object结构体都有一个类指针isa，这就是我们所说的“**isa指针**”。运行时机制需要通过检测一个对象的isa指针去查看对象的类别，然后查看该对象是否能响应你当前发送过来的消息。接下来是id指针，id指针默认不属于任何类别只表明指向的是一个Objective-C对象。对于id指针指向的对象，你可以获知对象的类别，查看对象是否能响应某个函数等等，然后当你具体了解了id指针指向的对象之后便可以更好的使用该对象。你同样可以查看LLVM/Clang文档中Blocks的定义：

``` objc
	struct Block_literal_1 {
	    void *isa; // initialized to &_NSConcreteStackBlock or &_NSConcreteGlobalBlock
	    int flags;
	    int reserved; 
	    void (*invoke)(void *, ...);
	    struct Block_descriptor_1 {
	 unsigned long int reserved; // NULL
	     unsigned long int size;  // sizeof(struct Block_literal_1)
	 // optional helper functions
	     void (*copy_helper)(void *dst, void *src);
	     void (*dispose_helper)(void *src); 
	    } *descriptor;
	    // imported variables
	}; 
```

Block结构的设计兼容于运行时机制。因此Block被视为一个Objective-C对象，所有也就可以响应消息如-retain,-release,-copy等等。

IMP:Method Implementations

``` objc
	typedef id (*IMP)(id self,SEL _cmd,...); 
```
	
IMP是一个函数指针，由编译器生成且指向函数的实现内容。如果你目前是一个Objective-C新手则浅尝辄止，但是我们随后会了解运行时机制是如何调用你的函数的。

Objective-C类：类里面是什么？在Objective-C中，类实现基本上类似于：

``` objc
	@interface MyClass : NSObject {
	//vars
	NSInteger counter;
	}
	//methods
	-(void)doFoo;
	@end
```
	
但是类在运行时机制中定义远不如此，如下

``` objc
	#if !__OBJC2__
	    Class super_class                                        OBJC2_UNAVAILABLE;
	    const char *name                                         OBJC2_UNAVAILABLE;
	    long version                                             OBJC2_UNAVAILABLE;
	    long info                                                OBJC2_UNAVAILABLE;
	    long instance_size                                       OBJC2_UNAVAILABLE;
	    struct objc_ivar_list *ivars                             OBJC2_UNAVAILABLE;
	    struct objc_method_list **methodLists                    OBJC2_UNAVAILABLE;
	    struct objc_cache *cache                                 OBJC2_UNAVAILABLE;
	    struct objc_protocol_list *protocols                     OBJC2_UNAVAILABLE;
	#endif 
```

我们可以看到一个类中声明了一个父类的引用，类名，实例变量列表，方法列表，缓存以及协议列表。当响应发送给类或对象的消息时，运行时机制需要用到这些信息。

### 类定义对象同时类本身也是对象？何解？

之前我提到过在Objective-C中类本身也是对象，运行时机制通过引入元类（Meta Class）来处理类对象。当你发送一个类似于[NSObject alloc]消息的时候，实际上是发送一个消息给类对象，此时将类对象视为元类的实例对待，而元类本身也是一个根元类（Root Meta Class）的实例。While if you say subclass from NSObject, your class points to NSObject as it's superclass. However all meta classes point to the root metaclass as their superclass. (原文似乎表达观点有误，暂不翻译)。所有的元类仅有一个类函数列表（不同于类处理实例函数列表，还有变量列表和协议列表等等）。因此，当你发送一个消息给类对象时，如[NSObject alloc]，objc_megSend()实际上是搜索元类的函数列表查看是否有响应的函数，如果存在则在该类对象上执行该函数。

### 为什么继承Apple的原生类？

在你刚开始Cocoa编程时，相关教程都是说创建一个类继承于NSObject然后开始编写自己的代码，简单地继承Apple的原生类会让你获益匪浅。其中一个你甚至意识不到的好处就是让你创建的类运行于运行时机制之上。当我们新建一个实例对象，如下：

``` objc
	MyObject *object = [[MyObject alloc] init];
```
	
最先被执行的消息是+alloc。如果你[查阅这个文档](https://developer.apple.com/library/content/#documentation/cocoa/reference/Foundation/Classes/NSObject_Class/Reference/Reference.html)会发现：“isa这一实例变量被初始化指向一个描述对于类的数据结构体，其他所有的实例变量都被初始化为0”。所以，通过继承Apple原始类不仅仅继承一些不错的属性，而且还能让我们轻易地创建符合于运行时机制要求的对象（包含一个指向类的isa指针）。

### 类缓存机制
当OC的运行时机制机制通过检视一个对象的isa指针指向的类时会发现该对象实现了很多函数。然而，你可能仅仅调用其中的一小部分也就意味没必要每一次查找某个函数时都去搜索一遍类中的函数列表。因此，类创建了缓存，将你每次搜索函数列表后找到的相应函数存入缓存中。所以，当objc_msgSend()在类中搜寻某个函数是首先会遍历缓存列表。这样做的理论依据在于如果你发送过某个消息给一个对象，你很可能回再次发送同样的消息。因此如果我们将该理论考虑在内意味着如果你有一个NSObject的子类MyObject,并运行以下代码：

``` objc

	MyObject *obj = [[MyObject alloc] init];
	
	@implementation MyObject
	-(id)init {
	    if(self = [super init]){
	        [self setVarA:@”blah”];
	    }
	    return self;
	}
	@end
```

接下来发生：

1. [MyObject alloc]最先被执行。因为MyObject类没有实现alloc函数所以在该类自然找不到对应的函数，随后进入父类指针指向的NSObject类。
2. 询问NSObject类是否响应+alloc，发现其实现了alloc函数。+alloc检测到接收类是MyObject然后分配一块响应大小的内存并在其中初始化一个isa指针指向MyObject类。现在，我们获得了一个实例对象，随后运行时机制将NSObject类的+alloc函数指针存入NSObject对象对应的类中的缓存列表中。
3. 截至目前，我们发送了一个类消息，现在我们发送一个实例消息：调用-init函数或者自定义的初始化函数。显然，MyObject的实例对象能响应这个消息，因此-(id)init会被存入缓存列表中。
4. 随后self=[super init]被调用。super作为一个魔法关键字指向父类对象，因此转向NSObjct类中，调用init函数。这样做是为了确保面向对象继承体系（OOP inheritance）正常运转，因为所以的父类都将会正确地初始化它们的变量，然后作为子类对象可以正确地初始化自身的变量和必要时重载父类。

在这个NSObject类的例子中，没有特别的要点出现。但是事实并不总是如此，有时候初始化很重要，如下：

```  objc

	#import < Foundation/Foundation.h>
	 
	@interface MyObject : NSObject
	{
	 NSString *aString;
	}
	 
	@property(retain) NSString *aString;
	 
	@end
	 
	@implementation MyObject
	 
	-(id)init
	{
	 if (self = [super init]) {
	  [self setAString:nil];
	 }
	 return self;
	}
	 
	@synthesize aString;
	 
	@end
	 
	int main (int argc, const char * argv[]) {
	    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	 
	 id obj1 = [NSMutableArray alloc];
	 id obj2 = [[NSMutableArray alloc] init];
	  
	 id obj3 = [NSArray alloc];
	 id obj4 = [[NSArray alloc] initWithObjects:@"Hello",nil];
	  
	 NSLog(@"obj1 class is %@",NSStringFromClass([obj1 class]));
	 NSLog(@"obj2 class is %@",NSStringFromClass([obj2 class]));
	  
	 NSLog(@"obj3 class is %@",NSStringFromClass([obj3 class]));
	 NSLog(@"obj4 class is %@",NSStringFromClass([obj4 class]));
	  
	 id obj5 = [MyObject alloc];
	 id obj6 = [[MyObject alloc] init];
	  
	 NSLog(@"obj5 class is %@",NSStringFromClass([obj5 class]));
	 NSLog(@"obj6 class is %@",NSStringFromClass([obj6 class]));
	  
	 [pool drain];
	    return 0;
	}
	
```

如果你是Cocoa初学者，然后我问你上述代码的打印结果，你的回答可能如下：


``` objc
	NSMutableArray
	NSMutableArray 
	NSArray
	NSArray
	MyObject
	MyObject
```

但是运行结果却是：


``` objc
	obj1 class is __NSPlaceholderArray
	obj2 class is NSCFArray
	obj3 class is __NSPlaceholderArray
	obj4 class is NSCFArray
	obj5 class is MyObject
	obj6 class is MyObject
```

这是因为在Objective-C中，调用+alloc会隐性地返回一个类的实例对象而调用-init会返回另外一个类的实例对象。

### objc_msgSend的工作流程是什么？

objc_msgSend函数实现比较复杂。比如我们写了如下代码...

``` objc
	[self printMessageWithString:@"Hello World!"];
```

上述代码实际上会被编译器转化成：

``` objc
	objc_msgSend(self,@selector(printMessageWithString:),@"Hello World!");
```
随后，objc_msgSend函数根据目标对象的isa指针去查询对应的类（或者任一父类）看是否响应选择器@selector(printMessageWithString:)。假设在类的函数派发列表或者缓存中找到了对应的函数实现，那么执行该函数。如此看来，objc_msgSend函数没有返回值，它开始执行然后找到对应的目标函数并执行，因此目标函数的返回值被视为objc_msgSend函数的返回值。

Bill Bumgarner对于objc_msgSend的研究比我要表达的更为深入（[part 1](http://cocoasamurai.blogspot.jp/2010/01/understanding-objective-c-runtime.html),[part 2](http://www.friday.com/bbum/2009/12/18/objc_msgsend-tour-part-2-setting-the-stage/),[part 3](http://www.friday.com/bbum/2009/12/18/objc_msgsend-tour-part-3-the-fast-path/)）。总结一下他所要表达的以及你在查阅运行时机制源代码时可能发现的内容：

1. 检测屏蔽的函数和死循环，很显然如果代码运行在垃圾回收的环境下，我们可以忽略-retain,-release的调用，诸如此类。
2. 检测空对象。 不同于其他编程语言，在Objective-C中发送一个消息给空对象是完全合法的。[there are some valid reasons you'd want to. Assuming we have a non nil target we go on... ]
3. 然后在一个类中查找函数指针，首先是搜索缓存列表，如果找到了对应的函数指针就跳转对其实现代码段，即执行函数。
4. 如果在缓存列表中没有找到对应的函数指针，便搜索类中的函数派发列表。如果找到了对应的函数指针即跳转到其实现代码段。
5. 如果在缓存列表和函数列表都没有找到对应的函数，随即跳转到消息转发机制，意味着代码会被编译成c语言代码。所以一个函数如下所示：

``` objc
	-(int)doComputeWithNum:(int)aNum 
```

将会被编译成：

``` objc
	int aClass_doComputeWithNum(aClass *self,SEL _cmd,int aNum)  
```

此时，运行时机制通过这些函数的指针来调用这些转化后的函数，现在你已经不能直接调用这些函数，但是Cocoa库提供了一个方法来获得这些函数的函数指针。。。

``` objc
	//declare C function pointer
	int (computeNum *)(id,SEL,int);
	 
	//methodForSelector is COCOA & not ObjC Runtime
	//gets the same function pointer objc_msgSend gets
	computeNum = (int (*)(id,SEL,int))[target methodForSelector:@selector(doComputeWithNum:)];
	 
	//execute the C function pointer returned by the runtime
	computeNum(obj,@selector(doComputeWithNum:),aNum); 
	
```

这样，你可以知道访问这些函数并在运行时中直接调用，甚至利用这种方法来绕开运行时的动态调用来确保一个指定的函数被执行。运行时机制同样可以调用你的函数，只不过是通过objc_msgSend()。

### Objective-C消息传送

在Objective-C中，发送一个消息给一个不会做出响应的对象是合法的，甚至可能是有意这样设计的。苹果在其开发文档中给出的原因之一是为了模拟Objective-C不支持的多继承，或者你只是想抽象化你的设计，隐藏能处理这些消息的实例对象或类。这是运行时机制必要的功能之一。
消息传送工作流程：
1. 运行时机制搜寻了对象的类和它所有父类中的缓存列表和函数列表，但是并没有找到指定的方法。
2. 随后运行时机制将会调用你类中的 +(BOOL)resolveInstanceMethod:(SEL)aSEL方法给你一次机会为指定的函数提供函数实现，并告诉运行时机制你已经实现了这个方法。如果运行时机制再次搜索这个函数就能找到对应的函数实现。你可以如下所示，实现这个功能：

定义一个函数

``` objc
	void fooMethod(id obj, SEL _cmd)
	{
	 NSLog(@"Doing Foo");
	}
```
如下所示，使用class_addMethod()来实现

``` objc
	+(BOOL)resolveInstanceMethod:(SEL)aSEL
	{
	    if(aSEL == @selector(doFoo:)){
	        class_addMethod([self class],aSEL,(IMP)fooMethod,"v@:");
	        return YES;
	    }
	    return [super resolveInstanceMethod];
	}
```

class_addMethod()最后一个参数“v@:”表示函数fooMethod的返回值和参数，你可以在运行时机制指南中类型编码[Type Encodings](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html)了解你可以具体的规则。
3. 运行时机制随后会调用- (id)forwardingTargetForSelector:(SEL)aSelector函数，给你一次机会将运行时指向另外一个能响应目标函数的对象。这样做比触发消耗更大的函数：-(void)forwardInvocation:(NSInvocation *)anInvocation更划算。你的具体实现可能如下所示：

``` objc 
	- (id)forwardingTargetForSelector:(SEL)aSelector
	{
	    if(aSelector == @selector(mysteriousMethod:)){
	        return alternateObject;
	    }
	    return [super forwardingTargetForSelector:aSelector];
	}
```
很显然你不想返回self指针，否则可能导致死循环。

4. 此时，运行时机制尝试最后一次去获取消息的预期目标，并调用- (void)forwardInvocation:(NSInvocation *)anInvocation。如果你未曾了解NSInvocation[点击查看](https://developer.apple.com/reference/foundation/nsinvocation),这是Objective-C消息中很重要的构成部分。一旦你持有一个NSInvocation对象，你基本上可以更改消息的任何内容，包括目标对象，选择器和函数参数。你可能操作如下：

``` objc
	-(void)forwardInvocation:(NSInvocation *)invocation
	{
	    SEL invSEL = invocation.selector;
	 
	    if([altObject respondsToSelector:invSEL]) {
	        [invocation invokeWithTarget:altObject];
	    } else {
	        [self doesNotRecognizeSelector:invSEL];
	    }
	}
```

如果类是继承自NSObjct，- (void)forwardInvocation:(NSInvocation *)anInvocation函数的默认实现是调用-doesNotRecognizeSelector函数，如果你还想做点什么来响应这次消息转送，重载这个函数将是最后一次机会。

### 实例变量的无碎片化（Modern Runtime）

目前我们所了解到关于Modern Runtime的概念之一是实例变量无碎片化（Non Fragile ivars）。编译器在编译类的时候确定了实例变量的布局，决定了某个实例变量的访问位置。这属于底层细节，关乎于获得一个对象的指针，查找某个实例变量相对于对象起始位置的偏移，根据实例变量的类型读取相应数量的字节。因此，实例变量的布局可能如下所示，左侧的数字表示实例变量的字节偏移量

![](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/translation/runtime-f-1.png)

如上所示，NSObject对象的实例变量布局以及继承NSObject后添加了自己的变量之后的布局。这样的布局在苹果发布更新之前都能正常运行，但是苹果发布了Mac OS X 10.6之后，布局就会变成如下所示：

![](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/translation/runtime-f-2.png)

因为与父类的实例变量重叠，自定义的对象的实例变量被抹掉。防止这样的情况发生唯一的可能是苹果能保持更新之前的布局。但是如果苹果这样做的话，那么苹果的框架将不可能得到改进，因为这些框架的实例变量布局已经写死了。处于实例变量碎片化的情况下只能通过重新编译所有继承于苹果类的类来保证兼容新的框架。那么实例变量无碎片化的情况下会是如何处理？

![](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/translation/runtime-f-3.png)

实例变量无碎片化的前提下，编译器创建同实例变量碎片化情况下一样的实例变量布局。但是当运行时检测到一个重叠的父类时会调整自定义变量的偏移量，因此子类中自定义的变量得以保留。

### Objective-C 关联对象

最近Mac OS X 10.6 Snow Leopard推出了一个新特性，称之为关联引用。不同于其他一些语言，Objective-C不支持动态添加实例变量到某个对象的类中。所以在此之前你不得不耗尽脑力去构建一个特定的基础架构，营造一个可以给某个对象动态添加变量的假象。现在在Mac OS X 10.6中，运行时已经支持这一功能。如果想添加一个变量到任一个已经存在的苹果原生类中，比如NSView，我们可以做如下操作：

``` objc

	#import < Cocoa/Cocoa.h> //Cocoa
	#include < objc/runtime.h> //objc runtime api’s
	 
	@interface NSView (CustomAdditions)
	@property(retain) NSImage *customImage;
	@end
	 
	@implementation NSView (CustomAdditions)
	 
	static char img_key; //has a unique address (identifier)
	 
	-(NSImage *)customImage
	{
	    return objc_getAssociatedObject(self,&img_key);
	}
	 
	-(void)setCustomImage:(NSImage *)image
	{
	    objc_setAssociatedObject(self,&img_key,image,
	                             OBJC_ASSOCIATION_RETAIN);
	}
	@end

```
在runtime.h头文件中可以看到存储关联对象方式的可选项，作为objc_setAssociatedObject()函数的参数传入。

```objc

	/* Associated Object support. */
	 
	/* objc_setAssociatedObject() options */
	enum {
	    OBJC_ASSOCIATION_ASSIGN = 0,
	    OBJC_ASSOCIATION_RETAIN_NONATOMIC = 1,
	    OBJC_ASSOCIATION_COPY_NONATOMIC = 3,
	    OBJC_ASSOCIATION_RETAIN = 01401,
	    OBJC_ASSOCIATION_COPY = 01403
	}; 
	
```
这些可选值与@property语法的可选值相匹配。

### 混合虚函数表派发（Hybrid vTable Dispatch）

如果你查阅现代版运行时的源代码，你会看到以下内容（[位于objc-runtime-new.m](http://opensource.apple.com/source/objc4/objc4-437/runtime/objc-runtime-new.m)）:

``` objc 

	/***********************************************************************
	* vtable dispatch
	* 
	* Every class gets a vtable pointer. The vtable is an array of IMPs.
	* The selectors represented in the vtable are the same for all classes
	*   (i.e. no class has a bigger or smaller vtable).
	* Each vtable index has an associated trampoline which dispatches to 
	*   the IMP at that index for the receiver class's vtable (after 
	*   checking for NULL). Dispatch fixup uses these trampolines instead 
	*   of objc_msgSend.
	* Fragility: The vtable size and list of selectors is chosen at launch 
	*   time. No compiler-generated code depends on any particular vtable 
	*   configuration, or even the use of vtable dispatch at all.
	* Memory size: If a class's vtable is identical to its superclass's 
	*   (i.e. the class overrides none of the vtable selectors), then 
	*   the class points directly to its superclass's vtable. This means 
	*   selectors to be included in the vtable should be chosen so they are 
	*   (1) frequently called, but (2) not too frequently overridden. In 
	*   particular, -dealloc is a bad choice.
	* Forwarding: If a class doesn't implement some vtable selector, that 
	*   selector's IMP is set to objc_msgSend in that class's vtable.
	* +initialize: Each class keeps the default vtable (which always 
	*   redirects to objc_msgSend) until its +initialize is completed.
	*   Otherwise, the first message to a class could be a vtable dispatch, 
	*   and the vtable trampoline doesn't include +initialize checking.
	* Changes: Categories, addMethod, and setImplementation all force vtable 
	*   reconstruction for the class and all of its subclasses, if the 
	*   vtable selectors are affected.
	**********************************************************************/
	
```
上述内容阐述的要点就是运行时会尽量存储调用最频繁的函数以达到提高软件运行速度的目的，因为通过虚函数表查找比调用objc_msgSend函数使用的指令更少。虚函数表中的16个函数调用次数远多于其他所有函数。实际上，进一步深入研究代码你会发现垃圾回收机制和无垃圾回收机制下虚函数表中默认的函数：

```objc
	static const char * const defaultVtable[] = {
	    "allocWithZone:", 
	    "alloc", 
	    "class", 
	    "self", 
	    "isKindOfClass:", 
	    "respondsToSelector:", 
	    "isFlipped", 
	    "length", 
	    "objectForKey:", 
	    "count", 
	    "objectAtIndex:", 
	    "isEqualToString:", 
	    "isEqual:", 
	    "retain", 
	    "release", 
	    "autorelease", 
	};
	static const char * const defaultVtableGC[] = {
	    "allocWithZone:", 
	    "alloc", 
	    "class", 
	    "self", 
	    "isKindOfClass:", 
	    "respondsToSelector:", 
	    "isFlipped", 
	    "length", 
	    "objectForKey:", 
	    "count", 
	    "objectAtIndex:", 
	    "isEqualToString:", 
	    "isEqual:", 
	    "hash", 
	    "addObject:", 
	    "countByEnumeratingWithState:objects:count:", 
	};
```
那么你如何知道是否调用了这些函数？调试模式下，你将会在栈中看到以下函数中的某一个被调用，出于调试的目的，所有的这些方法都可以视为通过objc_msgSend函数调用的。

1. objc_msgSend_fixup：是当运行时正在派发一个位于虚函数表的函数时触发，即用于派发虚函数表中的函数。
2. objc_msgSend_fixedup：是当调用一个本应存在于虚函数表的函数但是现在已经不存在的函数时触发（个人觉得应该是调用在objc_msgSend_fixup函数之后，并且由前者触发的）。
3. objc_msgSend_vtable[0-15]：调试模式下，也许会看到某个函数调用类似于objc_msgSend_vtable5意味着正在调用虚函数表中对应序号的某个函数。

运行时可以决定是否派发这些函数，所以不要指望以下这种情况存在：objc_msgSend_vtable10在运行时的一次循环中对应的函数是-length,意味着后面任一次循环中也是同样情况。

### 结论

我希望你能喜欢这些内容，这篇文章基本上覆盖了我在[Des Moines Cocoaheads ](http://cocoaheads.org/us/DesMoinesIowa/index.html)上谈及的内容。Objective-C运行时是一个了不起的杰作，它为我们的Cocoa/Objective-C应用提供了一个强大的平台，让很多我们正在受用的功能都成为可能。如果你还没有查阅关于如何使用Objective-C运行时的Apple开发文档，我希望你马上行动，谢谢。附上：[运行时开发文档](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Introduction/Introduction.html)，[运行时介绍文档](https://developer.apple.com/reference/objectivec/1657527-objective_c_runtime)



