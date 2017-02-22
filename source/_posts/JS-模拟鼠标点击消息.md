title: 原生JS代码模拟鼠标点击消息
date: 2015-01-05 10:10:07
tags:
- JS
categories:
- JS
keywords: Click Event
decription: 原生JS代码模拟鼠标点击消息

---

近两天都忙于更新之前做的一个关于国外某知名音乐网站项目，因为自己一直做iOS开发并没有系统的学习过JS，所以属于半吊子水平。

由于该音乐网站对网页进行了全新的改版，导致之前注入的JS代码全部失效，且原网站中使用的第三方JQuery库也被去掉了。意味着只能使用原生JS重写注入代码。

期间遇到了一个“棘手”的问题：使用原生JS代码模拟鼠标点击消息来改变音量，不同于普通的鼠标点击的是消息里面需要附带鼠标坐标。在各种尝试之后，耗费了大半天时间才得以解决，个人觉得有点价值，记录下解决思路以供参考。

以下是解决思路流程：

#### 分析DOM元素结构 ####

页面样式

![页面样式](www.baidu.com)·

DOM结构

![DOM结构](www.baidu.com)

由上图可知，DIV元素VolumeSlider作为父元素，其下有四个子元素，分别是：

var windowClickEvent = null

window.onclick = function(ev){
var oEvent = ev||event;
windowClickEvent = oEvent;
}

[Simulating Mouse Events in JavaScript](http://marcgrabanski.com/simulating-mouse-click-events-in-javascript/)

``` JS

	//获取元素的纵坐标
	function getTop(e){
	    var offset=e.offsetTop;
	    if(e.offsetParent!=null) offset+=getTop(e.offsetParent);
	    return offset;
	}
	//获取元素的横坐标
	function getLeft(e){
	    var offset=e.offsetLeft;
	    if(e.offsetParent!=null) offset+=getLeft(e.offsetParent);
	    return offset; 
	}

	var volumeSlider = document.querySelector('[data-qa=volume_slider]');
	            
	            var volumeWidth = parseInt(getComputedStyle(volumeSlider , null).getPropertyValue('width'));
	
	            var volumeTrack = document.querySelector('button.VolumeSlider__ClickTracker');
	        
	            var clientX = getLeft(volumeTrack) + volumeWidth * data["amount"]/100;
	            
	            var clientY = getTop(volumeTrack);
	            
	            var event = new MouseEvent('click', {
	                                       'view': window,
	                                       'bubbles': true,
	                                       'cancelable': true,
	                                       'clientX':clientX,
	                                       'clientY':clientY
	                                       });
	            
	            volumeTrack.dispatchEvent(event);

```
