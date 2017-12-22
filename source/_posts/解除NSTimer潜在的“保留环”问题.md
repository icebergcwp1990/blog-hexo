title: 解除NSTimer潜在的“保留环”问题
date: 2017-2-12 22:28:07
tags: 
- Objective-C
categories: 
- 专业
keywords:  NSTimer
decription:  解除NSTimer潜在的“保留环”问题

---

NSTimer是Foundation框架中的一个使用频率很高的类，然而其调用过程中很容易引入潜在的“保留环“问题。可能是因为NSTimer的提供的API足够便利与顺手，以至于这个问题不容易被察觉到。这篇博客旨在阐述这个问题并提供解决方法。

以下的NSTimer提供的三个常用的创建或者初始化的API：

```objc
+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(nullable id)userInfo repeats:(BOOL)yesOrNo;
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(nullable id)userInfo repeats:(BOOL)yesOrNo;

- (instancetype)initWithFireDate:(NSDate *)date interval:(NSTimeInterval)ti target:(id)t selector:(SEL)s userInfo:(nullable id)ui repeats:(BOOL)rep NS_DESIGNATED_INITIALIZER;
```

这三个API有一个共同的点，即都需要提供一个target参数。这个target参数会被创建的NSTimer实例对象强引用一次，直到NSTimer实例对象调用invalidate方法后失效才释放。API文档原文如下：

> target: The object to which to send the message specified by aSelector when the timer fires. The timer maintains a strong reference to target until it (the timer) is invalidated. 

多数情况，我们都会将创建后NSTimer实例对象保存为当前类的实例变量，然后NSTimer的target参数设置为self指针。我写代码的习惯就是这样的。实例代码如下：

```objc
#import <Foundation/Foundation.h>

@interface MyObject : NSObject {
    NSTimer *mTimer;
}
@end

@implementation MyObject

- (id)init {
    if ((self = [super init])) {
      	//此处参数repeats = YES;
        mTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerFiredFun) userInfo:nil repeats:YES];
        [mTimer setFireDate:[NSDate distantPast]];
     
    }
    return self;
}

- (void)dealloc {
    [mTimer invalidate];
    mTimer = nil;
}

- (void)timerFiredFun{
    NSLog(@"%s" , __func__);
}

@end

int main (int argc , const char * argv[]) {
    
    MyObject *myObjcet = [MyObject new];
    //self只是一个空消息，避免编译器发出myObjcet未使用的警告
    [myObjcet self];
  	//NSTimer依赖于RunLoop而存活，手动激活RunLoop
    while (1) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
  
    return 0;
}
```

上述代码就是典型的计时器使用情景之一。如果计时器只是一次执行而非反复触发，那么计时器会在执行后自动失效，也就不会有“保留环”的问题。但是如果是设置反复触发的计时器类型，那么NSTimer对象会强引用MyObject对象，而当前类也一直持有NSTimer对象，因此，如果NSTimer不调用invalidate设置无效，MyObject对象不会背释放，其dealloc函数也一直被调用，然而NSTimer的invalidate恰好是MyObject对象的dealloc函数中调用。这样两个对象都不会释放。

出现“保留环”的根本原因在于NSTimer对象在创建的API隐性地强引用一次target，因此，解除“保留环”的关键在于避开NSTimer对象对self指针的强引用。以下是提供的一种解决方案：

**NSTimer+BlockSupported分类**

```objective-c
#import <Foundation/Foundation.h>

typedef void(^ICETimerScheduleBlock)(void);

@interface NSTimer (BlockSupported)

+ (NSTimer *)ice_scheduledTimerWithTimeInterval:(NSTimeInterval)ti
                                         block:(ICETimerScheduleBlock)block
                                       repeats:(BOOL)yesOrNo;

@end

#import "NSTimer+BlockSupported.h"

@implementation NSTimer (BlockSupported)

+ (NSTimer *)ice_scheduledTimerWithTimeInterval:(NSTimeInterval)ti
                                         block:(ICETimerScheduleBlock)block
                                       repeats:(BOOL)yesOrNo {
    //Timer会对target强引用，但是此处target变成Timer类对象。因为类对象生命周期与应用程序一置的，不受引用计数限制，所以没关系。
    return [NSTimer scheduledTimerWithTimeInterval:ti target:self selector:@selector(ice_timerFiredFun:) userInfo:block repeats:yesOrNo];
    
}

+ (void)ice_timerFiredFun:(NSTimer *)timer {
    ICETimerScheduleBlock block = timer.userInfo;
    if (block) {
        block();
    }
}

@end
```

**使用方式**

```objective-c
__weak typeof(self) weakSelf = self;
mTimer = [NSTimer zd_scheduledTimerWithTimeInterval:1.0f block:^{
    //添加一次局部强引用，确保即使在block执行过程中外部的self被释放了也能顺利完成。局部变量strongSelf的生命周期只限于当前block，不会一直持有self，所以不影响外部self对象的引用计数平衡。
    //如果局部强引用，weakSelf可能会在block执行过程中因为外部self释放而被设置为nil。
    __strong typeof(weakSelf) strongSelf = weakSelf;
    [strongSelf timerFiredFun];
} repeats:YES];
```

上述解决方案使用了NSTimer+BlockSupported分类对NSTimer原生函数进行了二次封装，将调用方需要的执行的函数转移到block中执行，再结合__weak指针解除NSTimer对self的强引用。NSTimer原生API调用照样会对target强引用，但是此时的target变成Timer类对象。因为类对象生命周期与应用程序一置的，不受引用计数限制，所以没关系。

*注：这个解决方案参考了Effective Objective-C 2.0一书中第52条，有兴趣的同学可以自行查阅。*

这种类型的“保留环”问题很隐蔽，很有记录价值，与君共享。

