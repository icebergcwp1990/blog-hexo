title: JavaScript的this关键字
date: 2017-06-07 23:33:07
tags: 
- JavaSctript
categories: 
- 翻译
- 专业
keywords: 
- this
description: JavaScript的this关键字详解

---

这是一篇翻译文章，原文地址*[点击这里](http://davidshariff.com/blog/javascript-this-keyword/#first-article)*。

JavaScript中一个常用的语法特征就是this关键字，同时这也是JavaScript最容易被误解和造成困惑的特征。this关键字的含义是什么且决定其含义的依据是什么？

这篇文章试着解开这个的疑惑并给出一个简单清晰的解释。

对于有其他语言编程经验的人来说应该也使用过this关键字，且多数情况下this指向的是一个通过构造函数创建的新对象。举例来说，假设有一个Boat类，里面包含一个成员方法moveBoat()，我们可以在moveBoat()方法中通过this关键字访问当前的对象实例。

在JavaSctript中，当使用new关键字创建一个新对象后，在构造函数中可以通过this关键字访问当前对象。然而，JavaScript中的this关键字指向的对象是随着函数调用的上下文变化而变化的。如果你不是很了解关于JavaScript执行上下文的知识，我推荐你看看我的另外一篇关于这个话题的[文章](http://davidshariff.com/blog/what-is-the-execution-context-in-javascript/#first-article)。好了，讲得够多了，让我们看几个代码实例：

```JavaScript
// Global scope

foo = 'abc';
alert(foo); //abc

this.foo = 'def';
alert(foo); //def
```

无论何时，只要是在全局上下文而非函数体内使用this关键字，那么this总是指向全局对象的（JavaSctript中的全局对象一般是Windows，NodeJS中是global）。接下来看看在函数中使用this关键字的情景：

```JavaScript
var boat = {
    size: 'normal',
    boatInfo: function() {
        alert(this === boat);
        alert(this.size);
    }
};

boat.boatInfo(); // true, 'normal'

var bigBoat = {
    size: 'big'
};

bigBoat.boatInfo = boat.boatInfo;
bigBoat.boatInfo(); // false, 'big'
```
上述代码中的this关键字指向是如何判断的？上述代码中有一个boat对象，包含了一个size属性和boatInfo方法。在boatInfo方法中有两条输出语句，分别是判断this关键字是否指向boat对象和输出this关键字指向的对象的size属性。因此，当执行代码boat.boatInfo()时，输出结果分别是true和normal。



