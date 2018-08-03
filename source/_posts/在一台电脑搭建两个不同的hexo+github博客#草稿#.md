title: 在一台电脑搭建两个不同的hexo+github博客
date: 2018-02-03 21:55:07
tags: 
- hexo
- github
categories: 
- 专业
keywords: hexo
decription: 在一台电脑搭建两个不同的hexo+github博客

---

草稿：

大概思路：
1、先完成一台电脑配置两个不同的github账号，参考https://www.jianshu.com/p/3fc93c16ad2d
~/.ssh/config文件下有两个host，分别对应不同的ssh秘钥：
\# default
Host github.com
HostName github.com
User git
IdentityFile ~/.ssh/id_rsa
\# industriousonesoft
Host ios.github.com
HostName github.com
User git
IdentityFile ~/.ssh/id_rsa_ios


2、每个账号分别搭建一个hexo博客
3、在hexo的目录下，在完成hexo安装和初始化后,以及配置主题之后，运行hexo g，如果运行hexo d，会因为权限限制导致发布失败
4、在当前目录下ls -la，进入隐藏目录：.deploy_git中，这个是hexo与github对接的目录，本质上就是git项目文件夹。
5、在.deploy_git目录下，运行
\# 取消全局 用户名/邮箱 配置
git config –global –unset user.name
git config –global –unset user.email
\# 单独设置每个repo 用户名/邮箱
git config user.email “xxxx@xx.com”
git config user.name “xxxx”

重新关联git项目：如果是industriousonesoft上的则使用ios.github.com，如果是default则使用github.com，这一步是关键！！!
git remote rm origin
git remote add origin git@ios.github.com:whatever


坑：_config.yml文件中设置下列属性，否则hexo s可以正常加载，hexo d加载失败：
url: https://industriousonesoft.github.io //github账号
root: /gTunes-Mini-Player //仓库名称