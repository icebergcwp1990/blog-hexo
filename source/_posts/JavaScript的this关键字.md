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

随后我们创建了另外一个对象bigBoat，里面同样有一个值为big的size属性。然而，bigBoat对象没有boatInfo方法，因此通过语句bigBoat.boatInfo = boat.boatInfo拷贝一个boatInfo方法。现在，当我们执行语句bigBoat.boatInfo()时，输出的结果分别是false和big。为什么会输出false? boatInfo方法中的this指向的对象是如何发生变化的？

首先你得明白任何函数中的this关键字指向的值都不是定值，它根据你每次调用函数前的上下文来决定，这个上下文就是函数被调用时所作的生命周期。更为重要的是函数具体的调用语句。

当一个函数被调用时，如果函数是被某个对象调用时，那么函数中this关键字指向的是调用该函数的对象，否则指向的全局对象。下面举例说明：

```JavaScript
function bar() {
    alert(this);
}
// global - because the method bar() belongs to the global object when invoked
//this指向全局对象
bar(); 

var foo = {
    baz: function() {
        alert(this);
    }
}
// foo - because the method baz() belongs to the object foo when invoked
//this指向foo对象
foo.baz(); 
```
如果事情有这么简单，那么上述代码显然解决了我们的疑惑。但是还有更为复杂的情况，看似同一个的函数，调用的语句不同也会导致this关键字的指向不同。如下所示：

```JavaScript
var foo = {
    baz: function() {
        alert(this);
    }
}
// foo - because baz belongs to the foo object when invoked
//this指向foo对象
foo.baz(); 

var anotherBaz = foo.baz;
// global - because the method anotherBaz() belongs to the global object when invoked, NOT foo
//this指向全局对象，即使anotherBaz是由foo.baz赋值而来，但是this的指向最终还是由调用的方式决定。
anotherBaz(); 

```
通过上述代码我们看到由于调用语句的不同，baz方法中的this关键字指向的对象也不一样。现在我们来看看this关键字处于内嵌时的指向是如何的：

```JavaScript
var anum = 0;

var foo = {
    anum: 10,
    baz: {
        anum: 20,
        bar: function() {
            console.log(this.anum);
        }
    }
}
// 20 - because left side of () is bar, which belongs to baz object when invoked
//输出的值是20，因为bar方法是通过baz对象调用的
foo.baz.bar(); 

var hello = foo.baz.bar;
// 0 - because left side of () is hello, which belongs to global object when invoked
//输出的是0，因为hello函数没有显示的调用对象，缺省调用对象为全局对象global
hello();
```
另外一个被常问到的问题是：如何判断事件监听函数中的this关键字指向？答案是处于事件监听函数中的this关键字通常指向触发该事件的DOM元素。下面举例说明：

```JavaScript
<div id="test">I am an element with id #test</div>

function doAlert() { 
    alert(this.innerHTML); 
} 
//指向全局对象，但是因为全局对象没有相应的属性，因此输出undefined
doAlert(); // undefined 

var myElem = document.getElementById('test'); 
myElem.onclick = doAlert; 

alert(myElem.onclick === doAlert); // true 
//this指向myElem对象
myElem.onclick(); // I am an element

```

上述代码中，第一次调用doAlert函数，输出的是undefined，因此此时this指向的是全局对象global。当我们将doAlert函数设置为myElem元素对象的click消息监听函数时，意味着每次触发click消息时，doAlert等价于被myElem对象直接调用，因此this关键字指向的就是myElem对象。

最后，我想提醒大家的是this关键字的指向是可以通过call()和apply()函数手动修改的，这将导致我们上面讨论的内容都不再适用。另外一点是，在某个对象的构造函数中的this关键字默认是指向当前新建的对象，因为构造函数是使用new关键字调用的，系统会将构造函数中的this关键字指向即将创建的对象。

**总结**

希望今天的博客能够清除你对this关键字的疑惑，并且以后都能正确地判断this关键字的指向。现在我们知道了this关键字的指向的动态变化的且具体的值取决于this所在函数的调用方式。






