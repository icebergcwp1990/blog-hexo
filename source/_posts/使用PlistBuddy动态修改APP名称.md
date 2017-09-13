title: 使用PlistBuddy命令动态修改APP名称
date: 2016-10-15 12:16:07
tags: 
- PlistBuddy
categories: 
- Shell
keywords: PlistBuddy
decription: 使用PlistBuddy动态修改APP名称

---

当一个工程里面包含多个target且每个target都有本地化的名称，一般做法是为每个target配备一个InfoList.strings文件。随着target数量和支持的语种增多，InfoList.strings文件数量也增加，更改和管理target名称也会变得复杂。

我们可以在工程里面只保留一个InfoList.strings文件用于显示当前编译的target本地化名称，并且将所有target的本地化名称用一个plist文件统一管理，然后使用shell脚本和PlistBuddy命令在编译阶段动态修改target名称。以下是具体实现：

假设工程中有4个target，本地化需求为英语（en）和西班牙语言（es）。

1、在Xcode中创建一个名为ProductName.plist文件，并保存至工程根目录。注意：这个文件不需要和任何target关联。

```xml
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
	<dict>
		<key>ProductId_1</key>
		<dict>
			<key>en</key>
			<string>ProductId_1_EnglistName</string>
			<key>es</key>
			<string>ProductId_1_SpanishName</string>
		</dict>
		<key>ProductId_2</key>
		<dict>
			<key>en</key>
			<string>ProductId_2_EnglistName</string>
			<key>es</key>
			<string>ProductId_2_SpanishName</string>
		</dict>
		<key>ProductId_3</key>
		<dict>
			<key>en</key>
			<string>ProductId_3_EnglistName</string>
			<key>es</key>
			<string>ProductId_3_SpanishName</string>
		</dict>
		<key>ProductId_4</key>
		<dict>
			<key>en</key>
			<string>ProductId_4_EnglistName</string>
			<key>es</key>
			<string>ProductId_4_SpanishName</string>
		</dict>
	</dict>
	</plist>
```

2、Info.plist中有个叫CFBundleDisplayName的key决定APP的名称，创建一个InfoList.string文件并关联所有的target。在InfoList.string文件修改CFBundleDisplayName即可更改APP名称,格式如下所示：

CFBundleDisplayName="xxxxxxxxxx";

3、在project的“Build Settings”中新建一个“Use_Defined Setting”命名为MY_PRODUCTID，然后为每一个target设置对应的ID。此处分别为四个target命名为：ProductId_1、ProductId_2、ProductId_3、ProductId_4。

4、在工程的“build Phases”界面中新建一个脚本块，脚本内容如下：

```sh

	#PRODUCT_NAEMS_FILE_PATH的路径
	PRODUCT_NAEMS_FILE_PATH="${SRCROOT}/PRODUCT_NAEMS_FILE_PATH"
	
	#获取对应ProductId的plist
	/usr/libexec/PlistBuddy -c "print ${MY_PRODUCTID}" -x "${PRODUCT_NAEMS_FILE_PATH}" > "/var/tmp/${MY_PRODUCTID}.plist"
	
	#获取ProductId.plist对应的本地化名称
	EN_NAME=$(/usr/libexec/PlistBuddy -c "print en" "/var/tmp/${MY_PRODUCTID}.plist" )
	ES_NAME=$(/usr/libexec/PlistBuddy -c "print es" "/var/tmp/${MY_PRODUCTID}.plist" )
	
	#设置InfoPlist.strings对应的本地化文件中的CFBundleDisplayName字段值
	echo "CFBundleDisplayName=\"${EN_NAME}\";" > "${SRCROOT}/en.lproj/InfoPlist.strings"
	
	echo "CFBundleDisplayName=\"${ES_NAME}\";" > "${SRCROOT}/es.lproj/InfoPlist.strings"

```
5、编译target，即可在InfoPlist.strings看到对应的本地化名称。



