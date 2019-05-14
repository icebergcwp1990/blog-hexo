title: 在一台电脑搭建多个不同的hexo+github博客
date: 2018-02-03 21:55:07
tags: 
- hexo
- github
categories: 
- 专业
keywords: hexo
decription: 在一台电脑搭建多个不同的hexo+github博客

---

hexo+github是目前比较受欢迎的搭建个人博客的组合，hexo最终的发布依赖于github的。因此解决在同一台电脑搭建多个不同的hexo+github博客的根本在于：解决如何在一台电脑上绑定多个github账号。

本地电脑对github服务器访问是基于ssh的，一般情况下git命令会默认在~/.ssh/config文件中写入对github远程host的映射与配置，类似于：

```shell
# default
Host default.github.com //本地使用的host名，可以自定义
HostName github.com //远程的host名，必须是目标服务的域名
User git  //本地ssh登录使用的用户名，登录github服务器只能是git
IdentityFile ~/.ssh/id_rsa  //ssh访问使用的秘钥
```

这个文件所表达的意思是：将本地host名：github.com映射到远程的host名：github.com，并且使用路径：~/.ssh/id_rsa下的秘钥进行ssh访问。

在此之前，我们需要将与私钥~/.ssh/id\_rsa成对出现的公钥~/.ssh/id\_rsa.pub配置到自己的github账号中。具体步骤很简单，参考github官方文档：[adding-a-new-ssh-key-to-your-github-account](https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/)。

在配置好github账号中的公钥之后，可通过以下命令检测是否配置成功：

```shell
$ ssh -T git@default.github.com   #ssh -T 用户名@本地host名
Hi “你绑定的github账号名”! You've successfully authenticated, but GitHub does not provide shell access.
```

在理解远程登录github背后的原理之后，在一台电脑上绑定多个github账户的思路也变得清晰，即将多个本地host映射到同一个github的host上。

又因为每一个新的映射需要一对新的密钥对（公钥和私钥）用于ssh访问，在配置新的host映射之前需要先创建一对新的密钥。具体步骤如下：

- 打开终端，并输入如下命令ssh-keygen：

	```shell
	$ ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
	```
	其中-t表示密钥类型为rsa，-b指定密钥的长度，-C为密钥添加的注释，这个注释你可以输入任何内容，很多网站和软件用这个注释作为密钥的名字。

- 密钥创建完成后会提示你指定密钥存储路径：

	```shell
	Enter a file in which to save the key (/Users/you/.ssh/id_rsa): [Press enter]
	```
	这一步需要注意的是，如果是直接回车则默认存储在~/.ssh/id\_rsa中。因为我们已经有一对名id\_rsa的密钥。我们需要将新创建的秘钥存储在新的文件中以作区分。比如存储在文件~/.ssh/test\_id\_rsa中。

- 接下来为秘钥提供访问密码，如果直接回车表示空密码。如果输入了密码，这个密码在后续在hexo中绑定github时使用到。

	```ssh
	Enter passphrase (empty for no passphrase): [Type a passphrase]
	Enter same passphrase again: [Type passphrase again]
	```

创建完密钥之后，在文件~/.ssh/config中加入新的host映射：

```shell
# default
Host default.github.com //本地使用的host名，可以自定义
HostName github.com //远程的host名，必须是目标服务的域名
User git  //本地ssh登录使用的用户名，登录github服务器只能是git
IdentityFile ~/.ssh/id_rsa  //ssh访问使用的秘钥

# test
Host test.github.com 
HostName github.com 
User git  
IdentityFile ~/.ssh/test_id_rsa  //使用新创建的私钥
```

将新的映射对应的公钥配置到新的github账号中后，就可以使用以下命令检测是否绑定成功：

```shell
$ ssh -T git@test.github.com   #ssh -T 用户名@本地host名
Hi test! You've successfully authenticated, but GitHub does not provide shell access.
```

现在，我们解决了一台电脑绑定多个账户的问题。接下来弄清楚hexo对github依赖的实现方式，便可实现在一台电脑搭建多个hexo博客。

*此处省略了hexo博客搭建的过程，网上有很多教程，可自行查阅*

在完成hexo的安装和初始化后，通过终端进入在对应的目录下，并执行命令ls -la

```shell
cd ./Hexo所在的根目录 && ls -la
```
找到名为.deploy\_git的目录，这是一个隐藏目录，用于存储与同步hexo生成好的博客文件到github账号中。本质上这是一个github的本地仓库，类似于用git init命令创建的本地仓库一样。因此对git的配置都需要在这个目录下完成。以下是配置过程：

- 进入.deploy\_git目录中，执行如下命令：

	```shell
	\# 取消全局 git用户名/git注册邮箱
	git config –global –unset user.name
	git config –global –unset user.email
	\# 单独设置每个repo git用户名/git注册邮箱
	git config user.email “xxxx@xx.com”
	git config user.name “xxxx”
	```
- 重新关联git项目，比如讲hexo部署到本地host:test对应的github账号上：

```shell
git remote rm origin
git remote add origin git@test.github.com:GitHub账户名/hexo对应的仓库名
```
至此，我们实现了在一台电脑上搭建多个hexo博客的想法。








