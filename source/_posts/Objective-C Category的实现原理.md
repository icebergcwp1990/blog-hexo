title: Objective-C Category的实现原理
date: 2015-03-25 10:48:07
tags: 
- Category
categories: 
- Objective-C
keywords: Category
decription: 关于揭秘Objective-C Category内部实现原理的探索

---


Objective-C Category（分类）之于我而言有种神秘感，虽然自己已经在实际开发过程中已经多次使用它，且感受到了它带来的便利与高效。但是我却仅仅是停留在对它的基本使用层面，除此之外一无所知。我能感觉它的强大，心中也一直有种对它内部实现一探究竟的冲动，奈何迟迟没有行动。时间愈久，这种情绪愈发浓烈，今天终究是按耐不住了...

### 知其然
 
对于苹果应用开发者来说，开发者想要快速地了解或是回顾某个知识点，[Apple开发者文档](https://developer.apple.com/library/content/documentation/General/Conceptual/DevPedia-CocoaCore/Category.html#//apple_ref/doc/uid/TP40008195-CH5-SW1)往往是不二首选。
  
文档上如是说：你可以使用Category为一个已经存在的类添加额外的方法，比如Cocoa库中的类，即便是这个类的源代码是不可见的-不能子类化。使用Category给类添加的方法能被其子类继承，且在Runtime下其与类原有的方法是无差别的。

分类的使用场景：

  * 在不改变某个类源文件和不使用继承的前提下，为该类添加先的方法
  * 声明类的私有方法
  * 将一个类的实现拆分为多个独立的源文件
  
很明显，Category其实就是设计模式之一的装饰者模式的具体实现。
 
 *注意，Category是一个类的拓展，为不是一个新类。*

借助Apple开发者文档了解到Category的“知其然”，然后就是基于[Apple Opensource](https://opensource.apple.com/tarballs/objc4/)来解决“知其所以然”的问题？
  
### 知其然所以然

 此处使用的源码版本是objc4-532.2。与本文相关的代码都在源文件objc-runtime-new.mm中，接下来就结合关键的代码与注释进行分析。
 
 Catrgory的定义
 
 ```objc
 
	 typedef struct category_t {
	    const char *name;
	    classref_t cls;
	    struct method_list_t *instanceMethods;
	    struct method_list_t *classMethods;
	    struct protocol_list_t *protocols;
	    struct property_list_t *instanceProperties;
	} category_t;
 
 ```
 
 通过Category的定义可以看出，Category与Class的结构很相似。不过Category没有isa指针，结合OC中对类的定义，说明Category不是一个类，只能作为一个类的拓展存在。

 关键Method-1: _read_images()
 
 ``` objc
 
	 void _read_images(header_info **hList, uint32_t hCount)
	{
	    ...
	    
	#define EACH_HEADER \
	hIndex = 0;         \
	crashlog_header_name(NULL) && hIndex < hCount && (hi = hList[hIndex]) && crashlog_header_name(hi); \
	hIndex++
	   
	    ...
	    
	    // Discover categories.
	    //遍历工程中所有的头文件
	    for (EACH_HEADER) {
	        //Category列表
	        category_t **catlist =
	        _getObjc2CategoryList(hi, &count);
	        //遍历Category列表
	        for (i = 0; i < count; i++) {
	            category_t *cat = catlist[i];
	            //Category拓展的类的指针
	            class_t *cls = remapClass(cat->cls);
	            
	            if (!cls) {
	                // Category's target class is missing (probably weak-linked).
	                // Disavow any knowledge of this category.
	                catlist[i] = NULL;
	                if (PrintConnecting) {
	                    _objc_inform("CLASS: IGNORING category \?\?\?(%s) %p with "
	                                 "missing weak-linked target class",
	                                 cat->name, cat);
	                }
	                continue;
	            }
	            
	            // Process this category.
	            // First, register the category with its target class.
	            // Then, rebuild the class's method lists (etc) if
	            // the class is realized.
	            
	            BOOL classExists = NO;
	            //将分类中的实例方法添加在类的实例方法列表
	            if (cat->instanceMethods ||  cat->protocols
	                ||  cat->instanceProperties)
	            {
	                addUnattachedCategoryForClass(cat, cls, hi);
	                if (isRealized(cls)) {
	                    remethodizeClass(cls);
	                    classExists = YES;
	                }
	                if (PrintConnecting) {
	                    _objc_inform("CLASS: found category -%s(%s) %s",
	                                 getName(cls), cat->name,
	                                 classExists ? "on existing class" : "");
	                }
	            }
	            
	            //将分类中的类方法添加到类的类方法列表中
	            if (cat->classMethods  ||  cat->protocols
	                /* ||  cat->classProperties */)
	            {
	                //关键函数块
	                
	                //添加Category到目标类
	                addUnattachedCategoryForClass(cat, cls->isa, hi);
	                
	                //重构目标类的方法列表
	                if (isRealized(cls->isa)) {
	                	//关键函数！
	                    remethodizeClass(cls->isa);
	                }
	                if (PrintConnecting) {
	                    _objc_inform("CLASS: found category +%s(%s)",
	                                 getName(cls), cat->name);
	                }
	            }
	        }
	    }
	    
	    // Category discovery MUST BE LAST to avoid potential races
	    // when other threads call the new category code before
	    // this thread finishes its fixups.
	    
	    // +load handled by prepare_load_methods()
	 
	#undef EACH_HEADER
	}
 
 ```
 
 _read_images()是赋值读取镜像文件的函数，函数末尾就是处理Category的代码块。其中将工程中所有的Category分别与其目标类建立关联，然后调用了remethodizeClass()对目标类的进行重构。
 
 关键Method-2: remethodizeClass()
 
 ```objc
 
	 static void remethodizeClass(class_t *cls)
	{
	    category_list *cats;
	    BOOL isMeta;
	    
	    rwlock_assert_writing(&runtimeLock);
	    
	    //识别目标类是否为元类
	    isMeta = isMetaClass(cls);
	    
	    // Re-methodizing: check for more categories
	    //重构目标类的方法列表
	    if ((cats = unattachedCategoriesForClass(cls))) {
	        chained_property_list *newproperties;
	        const protocol_list_t **newprotos;
	        
	        if (PrintConnecting) {
	            _objc_inform("CLASS: attaching categories to class '%s' %s",
	                         getName(cls), isMeta ? "(meta)" : "");
	        }
	        
	        // Update methods, properties, protocols
	        
	        BOOL vtableAffected = NO;
	        
	        //添加Category中的方法到目标类
	        //关键函数！
	        attachCategoryMethods(cls, cats, &vtableAffected);
	        
	        //将Category中的属性插入属性链表的头部，只有匿名Category才能额外添加属性
	        newproperties = buildPropertyList(NULL, cats, isMeta);
	        if (newproperties) {
	            newproperties->next = cls->data()->properties;
	            cls->data()->properties = newproperties;
	        }
	        
	        //将Category中的协议加入目标类
	        //查看buildProtocolList函数得知，新的协议的加入目标类原有协议的尾部
	        newprotos = buildProtocolList(cats, NULL, cls->data()->protocols);
	        if (cls->data()->protocols  &&  cls->data()->protocols != newprotos) {
	            _free_internal(cls->data()->protocols);
	        }
	        cls->data()->protocols = newprotos;
	        
	        _free_internal(cats);
	        
	        // Update method caches and vtables
	        flushCaches(cls);
	        if (vtableAffected) flushVtables(cls);
	    }
	}
 
 ```
 
 remethodizeClass()函数的功能比较简单，进一步细化了对Category中的方法列表、协议列表和属性列表的处理。其中，属性列表的处理则是直接插入原属性链表头部，协议列表则是附加到原协议列表的尾部。接下来，重点分析处理Category方法列表的attachCategoryMethods函数。

关键Method-3: attachCategoryMethods()

```objc

	static void attachCategoryMethods(class_t *cls, category_list *cats,
	                      BOOL *inoutVtablesAffected)
	{
	    if (!cats) return;
	    if (PrintReplacedMethods) printReplacements(cls, cats);
	    
	    BOOL isMeta = isMetaClass(cls);
	    
	    //为每个Category分配函数列表
	    method_list_t **mlists = (method_list_t **)
	    _malloc_internal(cats->count * sizeof(*mlists));
	    
	    // Count backwards through cats to get newest categories first
	    int mcount = 0;
	    int i = cats->count;
	    BOOL fromBundle = NO;
	    //汇总所有Category的拓展方法
	    while (i--) {
	        method_list_t *mlist = cat_method_list(cats->list[i].cat, isMeta);
	        if (mlist) {
	            mlists[mcount++] = mlist;
	            fromBundle |= cats->list[i].fromBundle;
	        }
	    }
	    
	    //关键函数!
	    //将Category中的拓展方法加入到目标类
	    attachMethodLists(cls, mlists, mcount, NO, fromBundle, inoutVtablesAffected);
	    
	    _free_internal(mlists);
	    
	}

```

attachCategoryMethods()函数的功能也比较简单，对与目标类的Category中所有方法进行汇总，然后调用attachMethodLists函数进行处理。

关键Method-4: attachMethodLists()

```objc

	static void attachMethodLists(class_t *cls, method_list_t **addedLists, int addedCount,
	                  BOOL baseMethods, BOOL methodsFromBundle,
	                  BOOL *inoutVtablesAffected)
	{
	    rwlock_assert_writing(&runtimeLock);
	    
	    ...
	    
	    // Method list array is NULL-terminated.
	    // Some elements of lists are NULL; we must filter them out.
	    
	    //方法列表以NULL作为结束符，因此需要过滤掉目标类中的NULL函数
	    method_list_t *oldBuf[2];
	    method_list_t **oldLists;
	    int oldCount = 0;
	    if (cls->data()->flags & RW_METHOD_ARRAY) {
	        oldLists = cls->data()->method_lists;
	    } else {
	        oldBuf[0] = cls->data()->method_list;
	        oldBuf[1] = NULL;
	        oldLists = oldBuf;
	    }
	    if (oldLists) {
	        while (oldLists[oldCount]) oldCount++;
	    }
	    
	    int newCount = oldCount;
	    //同上，过滤掉Category方法列表中的NULL函数
	    for (int i = 0; i < addedCount; i++) {
	        if (addedLists[i]) newCount++;  // only non-NULL entries get added
	    }
	    
	    //创建新的方法列表
	    method_list_t *newBuf[2];
	    method_list_t **newLists;
	    if (newCount > 1) {
	        newLists = (method_list_t **)
	        _malloc_internal((1 + newCount) * sizeof(*newLists));
	    } else {
	        newLists = newBuf;
	    }
	    
	    // Add method lists to array.
	    // Reallocate un-fixed method lists.
	    // The new methods are PREPENDED to the method list array.
	    
	    newCount = 0;
	    int i;
	    
	    //先将Category加入到新的方法列表
	    for (i = 0; i < addedCount; i++) {
	        method_list_t *mlist = addedLists[i];
	        if (!mlist) continue;
	        
	        // Fixup selectors if necessary
	        if (!isMethodListFixedUp(mlist)) {
	            mlist = fixupMethodList(mlist, methodsFromBundle, true/*sort*/);
	        }
	        
	        ...
	        
	        // Fill method list array
	        newLists[newCount++] = mlist;
	    }
	    
	    // Copy old methods to the method list array、
	    //再将目标类原方法加入新的方法列表
	    for (i = 0; i < oldCount; i++) {
	        newLists[newCount++] = oldLists[i];
	    }
	    if (oldLists  &&  oldLists != oldBuf) free(oldLists);
	    
	    // NULL-terminate
	    newLists[newCount] = NULL;
	    
	    //更新目标类的方法列表
	    if (newCount > 1) {
	        assert(newLists != newBuf);
	        cls->data()->method_lists = newLists;
	        changeInfo(cls, RW_METHOD_ARRAY, 0);
	    } else {
	        assert(newLists == newBuf);
	        cls->data()->method_list = newLists[0];
	        assert(!(cls->data()->flags & RW_METHOD_ARRAY));
	    }
	}

```

attachMethodLists才是最关键的函数。函数中为目标类分配了一个新的函数列表，先加入Category中的方法，再加入目标类原有方法。这也就是为什么如果Category中的函数与目标类中的函数重名，那么目标类的函数会被覆盖的原因，因为Runtime在遍历方法列表时会先发现Category中的函数。另外，这也是为什么即便不导入category的头文件也可以通过-performSelector：方式调用category中的方法的原因。

### 小结

这篇博客基于源代码对Category与目标类的组合过程进行了分析，明白了Category中的方法、协议和属性的处理流程。因此，我们可以更加高效和准确地使用Category，甚至利用其中存在的“漏洞”实现一些小魔法。
