title: 揭秘dispatch_once的内部实现
date: 2016-08-08 22:25:07
tags:
- GCD
categories:
- 专业
- 翻译
keywords: dispatch_once
decription: 一篇剖析dispatch_once实现原理的译文

---

这是一篇译文，原文[Secrets of dispatch](https://www.mikeash.com/pyblog/friday-qa-2014-06-06-secrets-of-dispatch_once.html)的作者是Mike Ash大神。在拜读这篇文章之后，颇有收获，不得不感叹Mike Ash专业知识的深度与广度。因此，我想试着进行翻译以加深理解。

**以下是原文**

一位名为Paul Kim的读者向我推荐了Micheal Tsai的一篇关于“让dispatch_once执行更快”的博客。虽然dispatch_once源代码中的注释精彩且详实，但是它并没有深入剖析那些让人着迷的细节。因为这是我最喜欢研究的方面之一，所以今天的文章我将进行深入地探究dispatch_once内部逻辑和实现原理。

####API介绍####
dispatch_once函数顾名思义，它只执行一次且唯一的一次。函数接收两个参数，第一个参数是一个predicate，用于跟踪和保证函数的“一次性”；第二个参数是一个block，在函数第一次被调用时执行。调用方式如下所示：

```objc
static dispatch_once_t predicate;
dispatch_once(&predicate , ^{
	//执行一次性的任务
});

```

这个函数很适用于共享状态的“懒初始化”，适用范围包括全局字典、单例实体、缓存或者其他任何需要在第一次执行时进行配置的地方。

在只有单线程的环境中，这种调用方式显得有些繁琐，用一个简单的if语句就能取而代之。然而，我们现在面临的都是多线程的运行环境，且diaspatch_once是线程安全的。这就保证了即使多个线程同时调用dispatch_once函数，函数也只执行一个block，并且所有线程直到block中的任务执行结束且dispatch_once退出之前都会处于阻塞状态。尽管你自己实现一个类似的函数不是很难，但是dispatch_once函数执行速度相当之快，并且实现的难度很大。

####单线程版本####
让我们先看一个这个函数精简后的单线程版本。虽然这个版本没有实用性，但是让我们对这个函数有一个具体的视觉感官。注意到dispatch_once_t只是一个long整型，且初始化为0，根据实现被赋予不同的含义。以下是实现：

```objc
void SimpleOnce(dispatch_once_t *predicate, dispatch_block_t block) {

	if (!*predicate)
	{
		block();
		*predicate = 1;
	}
}
```

实现很简单：如果predicate是0，执行block且更新predicate的值为1。后续的函数调用会发现predicate未非0值便不会重复执行block。如果不是因为在多线程环境是不安全的，这完全就是我们想要的结果。糟糕的是，如果两个线程可能同时访问if语句，会导致block被调用两次。很不幸，这种情况时有发生，因此，让这份代码变成线程安全意味着一次实质性的成功。

####性能####

当谈及dispatch_once的性能时，主要有以下三种不同的情景：

1、第一次调用dispatch_once时，指定一个predicate，并执行block.
2、在第一次调用dispatch_once之后且block未执行完之前，后续调用线程必须等待直到block执行完成。
3、在第一次调用dispatch_once且执行完成之后，后续调用不需要等待而是立即执行。

情景1基本上不影响性能，毕竟只执行一次，只要block执行速度不是太慢。

情景2同样不太影响性能。这个情况可能潜在地发生好几次，但是只有在block未执行完才会发生。大多数情况，这种情况几乎不会发生。如果发生了也可能是仅仅出现一次。甚至在极端测试下：很多线程同时调用dispatch_once并且block执行时间很长，后续处于等待的调用也局限在几千个以内。这些后续调用线程全都必须等待block执行完成，所以即使这些线程在等待过程中耗费了一些不必要的CPU时间也是无关紧要的。

情景3则是性能高低的关键所在。这种性质的调用可能在程序中潜在发生成千上万次。我们想通过dispatch_once来保护那些一次性运算，运算结果被作为调用的返回值。理想情况下，dispatch_once的性能应该可以与直接读取一个提前初始化好的全局变量的性能媲美。换言之，一旦你面临情景3，我们想让下面两个代码块执行的效率是一样的。

代码段1：

```objc
id gObject;
void Compute(void)
{
	gObject = ....;
}

id Fetch(void)
{
	return gObject;
}
```
代码段2：

```objc
id DispatchFetch(void)
{
	static id object;
	static dispatch_once_t predicate;
	dispatch_once(&predicate, ^{
            object = ...;
    });
    return object;
}
```
在被编译器内联处理和优化之后，SimpleOnce函数的执行效率接近DispatchFetch函数。在我电脑上测试，DispatchFetch函数执行时间为0.5纳秒。这无疑是线程安全版本中的黄金标准。

如何自己实现一个的dispatch_once版本，关键在于确保线程安全，以下列出几种方式：

####使用线程锁####

常规的线程安全的做法是在共享数据访问前后添加锁。因为是示例代码，我决定只用一个单一的全局锁变量来做。代码中使用一个静态线程锁变量pthread_mutex_t来保护predicate的线程安全。在实际的项目中，随着函数被多个不同的类调用，伴随着很多不同的predicate变量，这将会是一个糟糕的设计。因为每一个互不关联的predicate变量必须一直等待当前被保护的predicate解锁才能获得执行机会。作为一个快速测试，这里我仅仅只测试一个predicate的情况。这份代码除了加了锁之外与前面的SimpleOnce函数没有区别：

```objc
void LockedOnce(dispatch_once_t *predicate, dispatch_block_t block) {
        static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

        pthread_mutex_lock(&mutex);
        if(!*predicate) {
            block();
            *predicate = 1;
        }
        pthread_mutex_unlock(&mutex);
    }
```
这段代码是线程安全的，但不幸的是执行速度太慢。在我的电脑上测试结果为每次调用需要30纳秒，相较于上述0.5纳秒的版本实在差太远。线程锁已经算很快的了，但不属于纳秒级别的。

####使用自旋锁####

自旋锁是一种试图将额外的开销降到最低的锁。顾名思义，自旋锁在处于需要等待的时候拥有“自旋”的功能，不断地轮询临锁的状态查看是否已经解锁。一般的锁都会配合操作系统休眠正在等待的线程，等解锁之后再唤醒所在的线程。这种锁虽然节省了CPU时间，但是这种协调休眠的机制也是有代价的。自旋锁不会休眠等待线程，因此在处于等待解锁的情况下节省了很多时间，付出的代价则是当多个线程试图获得自旋锁时效率会比较低。

MacOS X提供了[一套便利的自旋锁API](https://developer.apple.com/legacy/library/documentation/Darwin/Reference/ManPages/man3/spinlock.3.html)名为OSSpinLock.使用OSSinLock实现LockedOnce只需要在原有的基础修改几个名称：

```objc
 void SpinlockOnce(dispatch_once_t *predicate, dispatch_block_t block) {
        static OSSpinLock lock = OS_SPINLOCK_INIT;

        OSSpinLockLock(&lock);
        if(!*predicate) {
            block();
            *predicate = 1;
        }
        OSSpinLockUnlock(&lock);
    }
```
这次有了相当大的提升。在我电脑上测试结果为每次调用需要6.5纳秒，远好于pthread_mutex版本的每次调用30纳秒。然而于dispatch_once比起来还是太慢了。

####原子操作####

原子操作是底层CPU级别的操作且即使没有锁也一直都是线程安全。从技术层面来说，它们使用的硬件锁。使用锁会带来额外的开销，直接使用原子操作可以带来性能上的提升。多线程编程没有锁可能会显得很别捏，所以除非你真的需要原子操作，否则这不是明智的选择。我们现在讨论的是一个可能会被频繁使用的系统库，因此也许值得添加原子操作。

原子操作创建锁的过程是“比较并交换”。这是一个类似于下面代码的简单操作：

```objc
BOOL CompareAndSwap(long *ptr, long testValue, long newValue) {
	if(*ptr ==  testValue) {
		*ptr = newValue;
		return YES;
	}
	return NO;
}
```
总而言之，函数CompareAndSwap的功能用来测试内存的一个地址是否存储着一个特定的值，如果是则用新的值替换原有的值，返回结果表示匹配成功与否。因为“比较并交换”是一个CPU级的原子指令，所以即使有多个线程都试着对同一个内存区域进行“比较并交换”的操作都能确保其中只有一个操作能够成功。

LockedOnce的这个版本的实现策略是对predicate赋予三个不同的值。0表示函数还未被调用过；1表示函数block正处于执行状态，后续调用线程则处于等待状态；2表示block执行完成且释放阻塞的等待线程并返回结果。

“比较并交换”原子操作将被用于检测predicate的值是否为0，如果是则自动更新predicate为1。一旦原子操作返回的是YES，意味着当前线程是第一个调用线程，并开始唯一一次地block执行。在block执行完成后更新predicate的值为2作为标识.

如果“比较并交换”原子操作执行失败意味着当前线程不是第一个调用者，然后线程进入一个循环，不断地检测predicate的值是否更新为2，直到predicate更新为2才退出循环。这将导致线程在block执行结束之前一直处于等待状态。

以下是这个版本的函数的具体：

```objc
void AtomicBuiltinsOnce(dispatch_once_t *predicate, dispatch_block_t block) {
	//将predicate指针转换成volatile指针，
	//以告知编译器这个变量的值可能在函数执行过程中被其他线程更改，
	//必须每次从内存地址取值，而非寄存器
	volatile dispatch_once_t *volatilePredicate = predicate;
	
	//调用“比较并交换”原子操作。
	//Gcc编译器和clang编译器均提供了各种以_sync开头的内置函数以实现原子操作。
	//下面的函数对predicate执行了“比较并交换”的原子操作，
	//检测predicate的值是否为0，如果是则更新为1
	if(__sync_bool_compare_and_swap(volatilePredicate, 0, 1)) {
		//执行block
		block();
		//一旦block执行完成，更新predicate的值为2用以告知当前正在等待的调用线程以及未来的调用者block已经执行完成。
		//然而，考虑到CPU的优化机制，我们使用内存屏障以确保volatilePredicate值的读书顺序是正确的。
		//使用内置函数__sync_synchronize在此出设置内存屏障，
		//确保volatilePredicate在block执行完后立即更新为2，且在此之前不可读。
		__sync_synchronize();
		//更新
		*volatilePredicate = 2;
	}else {
		//等待线程循环检测
		while(*volatilePredicate != 2);
		//线程返回之前设置内存屏障，匹配if语句中的内存屏障设置，保证volatilePredicate读取一致性
		__sync_synchronize();
	}
}
```
上述代码满足需求且是线程安全的，但是性能一般。在我电脑上每次调用时间为20纳秒，明显高于自旋锁版本。

####提前预判####

这里有一个显而易见的优化可以添加到原子操作的版本中。因为通常情况下都是predicate的值已经是2，在函数最开始的地方加一个判断语句，可以在大多数情况下加快函数执行速度：

```objc
void EarlyBailoutAtomicBuiltinsOnce(dispatch_once_t *predicate, dispatch_block_t block) {
        if(*predicate == 2) {
            __sync_synchronize();
            return;
        }

        volatile dispatch_once_t *volatilePredicate = predicate;

        if(__sync_bool_compare_and_swap(volatilePredicate, 0, 1)) {
            block();
            __sync_synchronize();
            *volatilePredicate = 2;
        } else {
            while(*volatilePredicate != 2)
                ;
            __sync_synchronize();
        }
    }
```
这个版本的执行效率有相当大的提升，大约是调用一次11.5纳秒。然而，对比与dispatch_once版本还是相去甚远，甚至不如自旋锁版本。

设置内存屏障有额外的开销，这也是为什么这个版本的执行速度比dispatch_once慢的原因所在。至于为什么会比自旋锁版本慢，是因为代码中设置了不同类型的内存屏障。__sync_synchronize函数会产生一个mfence的指令，这个指令是可能是最耗费资源的指令之一，然而OSSpinLock使用的是一个效率更高的指令。我们可以尝试不同的内存屏障以到达更好的效果，但是很明显代码最终的执行速度未达到我们预期结果，因为我打算弃用这种方法。

####非线程安全的提前预判####

这个版本与上面的版本很类似，只不过将内存屏障移除了：

```objc
void UnsafeEarlyBailoutAtomicBuiltinsOnce(dispatch_once_t *predicate, dispatch_block_t block) {
        if(*predicate == 2)
            return;

        volatile dispatch_once_t *volatilePredicate = predicate;

        if(__sync_bool_compare_and_swap(volatilePredicate, 0, 1)) {
            block();
            *volatilePredicate = 2;
        } else {
            while(*volatilePredicate != 2)
                ;
        }
    }
```
不出意外，这个版本的执行速度与SimpleOnce一样都是0.5纳秒。因为*predicate == 2的适用于大多数情况，差不多每次调用都是检测predicate的值并返回。这个版本除了第一次执行block之外，几乎与SimpleOnce函数一样。

正如函数名所示，这是一个非线程安全版本，缺少了内存屏障导致线程不安全。原因何在？

####CPU流水线执行方式####

我们可以将CPU想象成一个简单的机器，我们告诉它做什么，它就做什么。如此反复直到天荒地老。

曾经有一段时间确实如此。老版的CPU的工作方式很简单，一眼一板。不幸的是，这种方式简单，容易且成本低，但是执行效率低。根据摩尔定律，CPU内置的晶体管成指数增长。8086CPU内置了大约29000个晶体管。一个英特尔处理器CPU集成了超过十亿的晶体管。

根据市场需求决定了CPU拥有更好的效率，现在的CPU集成了越来越多的晶体管旨在让电脑运行速度更快。

这里面有很多技巧让CPU执行的更快。其中一种就是流水线。执行单一的CPU指令，分成多个小步骤：

1. 从内存加载指令
2. 指令解码（分析指令解析包含哪些运算操作）
3. 加载输入数据
4. 结合输入执行运算
5. 保存输出数据

在一个早期的CPU，上述流程执行步骤如下所示：

```html
加载指令
解码
加载数据
运算
保存输出
加载下一个指令
解码
加载数据
运算
保存输出
...
```

在一个流水线型的CPU，执行步骤则如下所示：

```html
加载指令  
解码				加载指令		
加载数据			解码				加载指令
运算				加载数据			解码
保存输出			运算				加载数据
					保存输出			运算
										保存输出
```
这种方式执行速度快很多。随着CPU中的晶体管数量越来越多，CPU内部结构也越来越复杂，同步执行的指令也越来越多。								
更有甚者，如果可以让速度更快，指令的执行顺序会被完全打乱。不同于上述简单的例子，真实情况下，指令更为复杂以及变量更多。

代码执行的顺序并不以总是与代码本身的顺序一致的，比如下面的代码：

```objc
x = 1;
y = 2;
```

CPU可能会先写入Y变量的值。有些情况下编译器也会对语法重新排序，即便你屏蔽了编译器的行为，CPU仍然会乱序执行。如果是多核CPU，在其他的CPU看了写入的顺序是乱序的。即使是按代码顺序写入的，其他的CPU也会乱序读取。综合考虑，其它的线程在读取x和y的值时会发现y的值已经改变而x还是原来的值。

在你需要这些值必须按照既定的顺序写入的时候，内存屏障就派上用场了。设置内存屏障以确保上述代码中x的值先被更新：

* x = 1;
* memory_barrier();
* y = 2;

同样地，内存屏障可以确保读的顺序：

* use(x);
* memory_barrier();
* use(y);


然而，因为内存屏障的主要功能导致CPU的执行速度，所以自然而然影响性能。

对于dispatch_once来说，代码必须按照既定的顺序执行，因此必须设置内存屏障。但是，内存屏障会导致代码效率低下，所以为了避免额外的开销，我们想办法避免设置内存屏障。

####CPU的分支预测和推测性执行####

流水线和乱序工作模式适用于一系列线性执行的指令，但是对于添加分支语句则变得麻烦。CPU在分支语句执行完之前不知道下一步该执行什么指令，因此不得不停止运行等待前面的分支语句结束再重新运行。这就是所谓的pipeline stall，在一定程度上影响CPU性能。

为了弥补pipeline stall带了的性能损失，CPU加入了推测性执行。当CPU遇到一个分支语句则会进行分支预测判断哪一个分支可能被执行。现在的CPU配置精密的分支预判硬件，准确率在90%以上。在做出预判之后，CPU开始执行假设的分支中的代码块，而不是等待分支语句的结果。如果分支预判是正确的则继续后续执行。如果预判错误则清空推测执行结果重新执行另外一个分支代码块。

这种情况被用在了dispatch_once的读取端，这也是我们期望执行速度越快越好的地方。dispatch_once中有一个判断predicate的值得分支语句。CPU应该会预判并执行else分支，因为这个大多数情况下会执行的分支，即绕过block执行然后立即返回结果。在推测性执行过程中，CPU可能会从内存中加载那些后续需要但是还未被其他线程初始化的变量。如果分支预判是正确的，CPU会使用未初始化的值进行推测性执行。

####非对称屏障####

内存屏障一般都是需要对称的：在写的一端确保按照正确的顺序写入，在读的一端确保按照正确的顺序读取。然而，我们需要非对称屏障来满足我们的性能需求：我们可以容忍写入端的速度缓慢，但是让读的速度越快越好。

这个技巧用来防范推测性执行导致的问题。当分支预判是错误的，推测性执行的结果会被弃用。如果dispatch_once可以在初始化完成之后强制确定CPU的分支预判，这个问题则可以被避免。

此处有一个间隔时间，即最初的推测性执行到条件语句执行结束之间的间隔时间。间隔具体的时间因CPU而异，但是最多几十个CPU周期的时间。

在英特尔CPU中，dispatch_once使用spuid指令到达上述目的。cpuid指令主要是用于获取CPU的ID和功能等信息，但是也可以强行序列化指令流并需要耗费几百个CPU周期的时间。

在dispatch_once的源代码中，你会发现在读的一端没有使用内存屏障：

```objc
DISPATCH_INLINE DISPATCH_ALWAYS_INLINE DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
void
_dispatch_once(dispatch_once_t *predicate, dispatch_block_t block)
{
    if (DISPATCH_EXPECT(*predicate, ~0l) != ~0l) {
        dispatch_once(predicate, block);
    }
}
#define dispatch_once _dispatch_once
```
这段代码位于头文件中，并内联只调用者的代码块。DISPATCH_EXPECT宏告诉编译器去告知CPU：*predicate = ~0l是更有可能发生的分支。这可以提高分支预判的准确性，继而提升执行效率。基本上，这里只有一个普通的if语句，没有设置任何屏障。调用dispatch_once的执行速度接近0.5纳秒的黄金标准。

在dispatch_once实现文件中可以看到写入端的实现，在block执行后立即执行了下面的宏：

```objc
dispatch_atomic_maximally_synchronizing_barrier();
```
在英特尔的CPU中，这个宏使用了cpuid指令，在其他的CPU框架中也会产生类似的指令。

####结论####		

多线程是最奇怪和复杂的地方，现代的CPU在背后做了很多不为认知的事情。内存屏障允许你告知硬件按照你需要的顺序执行代码，但是相应的需要在性能上做出牺牲。dispatch_once有着独一无二的需求，让CPU不走寻常路：在相关的内存写入完成之前牺牲足够多的等待时间，但是确保每一次读取都是高效安全的且不需要额外的内存屏障。			

