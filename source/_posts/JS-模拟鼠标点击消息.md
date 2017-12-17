title: 原生JS代码模拟鼠标点击消息
date: 2017-02-23 01:58:07
tags:
- JS
categories:
- 专业
keywords: Click Event
decription: 原生JS代码模拟鼠标点击消息

---

近两天都忙于更新之前做的一个关于国外某知名音乐网站项目，因为自己一直做iOS开发并没有系统的学习过JS，所以属于半吊子水平。

由于该音乐网站对网页进行了全新的改版，导致之前注入的JS代码全部失效，且原网站中使用的第三方JQuery库也被去掉了。意味着只能使用原生JS重写注入代码。

期间遇到了一个“棘手”的问题：使用原生JS代码模拟鼠标点击消息来改变音量，不同于普通的鼠标点击的是消息里面需要附带鼠标坐标。在各种尝试之后，耗费了大半天时间才得以解决，个人觉得有点价值，记录下解决思路以供参考。

以下是解决思路流程：

ps：以下调试和代码均在Chrome浏览器的控制台执行。

#### 分析DOM元素结构 ####

页面样式

![页面样式](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/originality/js-simulate-mouse-click-1.png)

DOM结构

![DOM结构](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/originality/js-simulate-mouse-click-2.png)

由上图可知，DIV元素VolumeSlider作为父元素，其下有四个子元素，分,包括显示音量的slider和控制音量的handle元素。

对音量相关的DOM结构有一个大致了解，便于后面消息派发时选择触发的目标元素。如果说网站将响应鼠标消息的js绑定在父元素，那么选择任意一个子元素或者父元素本身作为触发对象都可以，因为消息会自动传递，最终会作用于父元素VolumeSlider。但是如果响应鼠标消息的js是绑定在四个子元素中的其中一个，则需要一一尝试。这个例子中只有4个子元素，所以很快就能有结果，但是如果需要测试的元素很多，那就效率太低下了。文章后面会介绍一种方法，快速定位响应鼠标消息的元素。

#### 模拟鼠标点击消息 #####

该音乐网站改版之前，因为支持jQuery，借助于jQuery库提供的API很方便获取元素坐标和模拟鼠标点击消息。而新的版本只能用原生js编写相关代码。

第一步：获取元素的坐标位置

```js

	//递归获取元素的纵坐标
	function getTop(e){
	    var offset=e.offsetTop;
	    ／／累加父元素的坐标值
	    if(e.offsetParent!=null) 
	    	／／递归
	    	offset+=getTop(e.offsetParent);
	    return offset;
	}
	//递归获取元素的横坐标
	function getLeft(e){
	    var offset=e.offsetLeft;
	    ／／累加父元素的坐标值
	    if(e.offsetParent!=null) 
	    	／／递归
	    	offset+=getLeft(e.offsetParent);
	    return offset; 
	}

```

第二步：模拟鼠标消息

原生js的Event对象有很多属性，但是创建Event的时并不是每一个属性都需要赋值。在网上找到了一篇博客[Simulating Mouse Events in JavaScript](http://marcgrabanski.com/simulating-mouse-click-events-in-javascript/)讲的比较详细。以下是我使用的示例代码：

``` JS

	／／offset是通过音量值转换过来的：音量level（0-1）* targetElement的长度
	var clientX = getLeft(targetElement) + offset;
	            
	var clientY = getTop(targetElement);
	            
	var event = new MouseEvent('click', {
									'view': window,
									'bubbles': true,
									'cancelable': true,
									'clientX':clientX,
									'clientY':clientY
	                                       });
	            
	targetElement.dispatchEvent(event);

```

第三步：获取响应鼠标消息的元素

如果是普通的鼠标消息，比如点击按钮消息或者不带坐标值的消息，一般很容易触发成功。但是如果是带来坐标位置的鼠标消息则很可能触发成功之后但是达不到预期效果。在这个问题上我困惑了蛮久，明明代码执行之后，返回触发消息成功，但是音量值并没有改变。

我在想有没有办法将真实的鼠标点击消息内容输出到终端，这样通过对比真实的鼠标消息就能找到模拟的鼠标消息的差异所在。

于是，在控制台输入了以下代码：

```js

	//全局变量
	var windowClickEvent = null

	window.onclick = function(ev){
		var oEvent = ev||event;
		／／获取当前鼠标消息对象
		windowClickEvent = oEvent;
	}

```

上述代码能获得当前鼠标消息对象。使用鼠标点击音量条，在控制台获得如下结果：

![DOM结构](https://raw.githubusercontent.com/icebergcwp1990/MarkDownPhotos/master/cocoa/originality/js-simulate-mouse-click-3.png)

对比真实的鼠标消息，确定模拟的鼠标消息中的坐标值是吻合的。但是二者的target元素不同，这也正是原因所在。修改了target元素之后，代码执行结果达到了预期的结果。通过这个方法可以快速定位响应鼠标消息的目标元素。

#### 小结 ####

在刚开始要使用原生js模拟鼠标消息的时候，感觉一片茫然。在网上查了很多资料，没有找到满足需求的代码。最后只能硬着头皮自己写，期间各种不确定性都需要一一测试，折腾了大半天，好在最终达到预期的结果。与此同时，对模拟鼠标消息也有了新的体会，至少以后能够比较轻松的完成类似的功能。

