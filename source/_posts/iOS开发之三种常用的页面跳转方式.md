title: iOS开发之storyboard中三种常用的页面跳转方式
date: 2018-07-12 15:04:07
tags: 
- iOS
categories: 
- 专业
- iOS

---

页面跳转属于iOS开发中很常用的一个功能，然而即便是这个看似简单的功能也可以根据不同需求有三个实现方式。下面一一介绍。

#### 方式一：建立Button与目标VC之间Segue ####

这种方式可直接在storyboard上完成，右击源VC上的一个按钮会出现一个接菜单，选择菜单中的“Triggred Segues”下的“action”，然后与目标VC建立一条指定跳转类型（比如Present Modally）的segue。

特点：操作简单，在storyboard上即可完成，不需要额外的手写代码。

#### 方式二：建立源VC与目标VC之间Segue ####

这种方式是在两个VC之间建立一条segue，然后在代码中根据Identify来获取对应的segue对象，调用performSegue函数来触发跳转。

特点：可以将跳转操作的触发与任意的控件绑定，需要添加额外的手写代码来完成绑定功能。

#### 方式一：基于既有的Segue重复显示同一个目标VC ####

这种方式其实是建立在第二种方式之上的，不同的地方在于这种方式会retain目标VC，这样确保在除第一次跳转之后不会再创建新的VC。因为前面两中方式都会在每次跳转时创建一个新的VC。

特点：可以重复使用和显示目标VC的数据。

[GitHub Demo](https://github.com/icebergcwp1990/PageJumpDemo)