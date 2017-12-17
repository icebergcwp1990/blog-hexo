title: Objective-C中布尔类型
date: 2016-10-15 12:16:07
tags: 
- Objective-C
categories: 
- 专业
keywords: 布尔类型
decription: 关于Objective-C中布尔类型的知识总结

---
 
 Objective-C中的BOOL类型在iWatch和64位iOS上的原始类型为bool，而在其它情况下是signed char。
 
用@encode去看看BOOL的类型串：

```objc
@encode(BOOL) // 64位iOS系统："B"
@encode(BOOL) // 32位iOS系统，32/64位OS X："c"
```

众所周知，在C\C++语言中bool类型中的两个常量false为0，true为1，且非0值都被认为true。Objective-C是建立在C++基础的面相对象的语言，因此bool的定义应该也是如此。

下面对两种情况分别讨论：

**typeof BOOL bool**

```objc

BOOL a = 7;

if( a == YES )
	NSLog("This is YES.")
else
	NSLog("This is NO.")

```

输出结果：This is YES。说明变量被赋值为1，而非数字7。

**typeof BOOL signed char**

```objc

BOOL a = 7;

if( a == YES )
	NSLog("This is YES.")
else
	NSLog("This is NO.")

```

输出结果：This is NO。说明变量被赋值为数字7。

综上所述，在Objective-C中进行布尔比较时，不建议直接将布尔变量和YES或者true做比较，即：if( a == YES )。但是可以和NO或者false做比较，即：if( a != NO )，也可以写成if( a )或者if( !a )的形式。