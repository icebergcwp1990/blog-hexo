title: 两个特殊函数+load & +initialize
date: 2015-04-01 23:50:07
tags: 
- Category
categories: 
- Objective-C
keywords: Category
decription: 分析两个特殊函数+load和+initialize

---

记得还在上一家公司任职的时候，在研发部的探讨会会上就“+load的加载过程”这一议题有过激烈的讨论，大家各执一词，争得面红耳赤。最终是部门老大专门做了一期讲解，才平息了这场争执。但是那时候的讲解并未涉及到源代码分析，而是基于测试代码做的分析，故我并没有完全理解。

在苹果开发文档中提及到：+load是在类或者分类被添加到runtime的时候被调用，而+initialize则是在类的用实例方法或者类方法第一次被调用之前调用。

上面的说明只是说明了这两个函数调用时机，但是并没有涉及父类、子类和分类之间的调用顺序和相互影响，于是试着结合[apple公司的开源代码](https://opensource.apple.com/tarballs/objc4/)objc4-532.2试着分析这两个函数的加载过程，以加深理解。

#### +load ####

首先在objc-os.mm文件中找到函数\_objc\_load\_image\_objc\_load\_image：

```objc

OBJC_EXPORT void _objc_load_image(HMODULE image, header_info *hinfo)
{
    prepare_load_methods(hinfo);
    call_load_methods();
}
 
```
根据参数判断，这个函数应该是在加载镜像文件的时候由系统直接调用，且里面就两行代码，分别是对+load函数的预处理与加载

接着在objc-runtime-new.mm文件找查看prepare_load_methods的函数实现：

```objc

void prepare_load_methods(header_info *hi)
{
    size_t count, i;

    rwlock_assert_writing(&runtimeLock);
	//获取头文件中所有的类
    classref_t *classlist = 
        _getObjc2NonlazyClassList(hi, &count);
    //先处理类中的+load方法
    for (i = 0; i < count; i++) {
    //处理类与父类中的+load函数    schedule_class_load(remapClass(classlist[i]));
    }
	 //再处理分类中的+load方法
    category_t **categorylist = _getObjc2NonlazyCategoryList(hi, &count);
    for (i = 0; i < count; i++) {
    	 //初始化分类
        category_t *cat = categorylist[i];
        class_t *cls = remapClass(cat->cls);
        if (!cls) continue;  // category for ignored weak-linked class
        realizeClass(cls);
        assert(isRealized(cls->isa));
        //将可加载的（存在+load函数）分类归类
        add_category_to_loadable_list((Category)cat);
    }
}

static void schedule_class_load(class_t *cls)
{
    if (!cls) return;
    assert(isRealized(cls));  // _read_images should realize
    if (cls->data()->flags & RW_LOADED) return;

    // Ensure superclass-first ordering
    //递归调用，优先处理父类
    schedule_class_load(getSuperclass(cls));

    //也就意味着父类中的+load方法先被加入列表
    add_class_to_loadable_list((Class)cls);
    changeInfo(cls, RW_LOADED, 0); 
}

```
由上述函数可以推断出：父类的+load方法先于子类被加入待处理列表，分类与类中的+load方法是区分对待的。

接着，在objc-loadmethod.mm文件中查看call_class_loads函数：

```objc

void call_load_methods(void)
{
    static BOOL loading = NO;
    BOOL more_categories;

    recursive_mutex_assert_locked(&loadMethodLock);

    // Re-entrant calls do nothing; the outermost call will finish the job.
    if (loading) return;
    loading = YES;

    void *pool = objc_autoreleasePoolPush();

    do {
        // 1. Repeatedly call class +loads until there aren't any more
        
        //先调用类中的+load方法
        while (loadable_classes_used > 0) {
        	//先入先出处理+load函数列表
            call_class_loads();
        }
			
        // 2. Call category +loads ONCE
        //再调用分类中的+load函数
        more_categories = call_category_loads();

        // 3. Run more +loads if there are classes OR more untried categories
    } while (loadable_classes_used > 0  ||  more_categories);

    objc_autoreleasePoolPop(pool);

    loading = NO;
}


static void call_class_loads(void)
{
    int i;
    
    // Detach current loadable list.
    struct loadable_class *classes = loadable_classes;
    int used = loadable_classes_used;
    loadable_classes = NULL;
    loadable_classes_allocated = 0;
    loadable_classes_used = 0;
    
    // Call all +loads for the detached list.
    //先入先出的遍历顺序，调用父类函数先于子类
    for (i = 0; i < used; i++) {
        Class cls = classes[i].cls;
        //获得+load的函数指针
        load_method_t load_method = (load_method_t)classes[i].method;
        if (!cls) continue; 

        if (PrintLoading) {
            _objc_inform("LOAD: +[%s load]\n", _class_getName(cls));
        }
        
   		  //注意：是通过函数指针直接调用，而非使用objc_msgSend，因此不会走runtime调用过程。
        (*load_method)(cls, SEL_load);
    }
    
    // Destroy the detached list.
    if (classes) _free_internal(classes);
}

static BOOL call_category_loads(void)
{
	....
	
    // Call all +loads for the detached list.
    for (i = 0; i < used; i++) {
        Category cat = cats[i].cat;
        load_method_t load_method = (load_method_t)cats[i].method;
        Class cls;
        if (!cat) continue;

        cls = _category_getClass(cat);
        if (cls  &&  _class_isLoadable(cls)) {
            if (PrintLoading) {
                _objc_inform("LOAD: +[%s(%s) load]\n", 
                             _class_getName(cls), 
                             _category_getName(cat));
            }
            
            //直接通过函数指针进行调用，而非通过objc_msgSend调用
            (*load_method)(cls, SEL_load);
            cats[i].cat = NULL;
        }
    }
    
    .....

    return new_categories_added;
}

```

在上述函数中，先调用了类的+load函数列表，再处理分类中的+load函数，且都是直接通过函数指针调用。又因为父类的+load函数先于子类加入列表，因此+load函数的调用顺序是：父类->子类->分类

在上一篇博客[Objective-C Category 深入浅出系列之实现原理](http://icebergcwp.com/2015/03/25/Objective-C%20Category%20%E6%B7%B1%E5%85%A5%E6%B5%85%E5%87%BA%E7%B3%BB%E5%88%97%E4%B9%8B%E5%AE%9E%E7%8E%B0%E5%8E%9F%E7%90%86/)中结合源代码分析了Category的实现原理。其中有一个重要的知识点就是分类Category中函数会覆盖主类中同名的函数。然而这种情况发生的前提是函数必须是通过runtime机制（使用objc_msgSend发送消息）调用，因为这样才会通过遍历类的方法列表去获得方法对应的实现。

#### +initialize ####

既然+initialize函数是在类的实例方法或者类方法第一次被调用之前触发，而类的实例方法或者类方法正常的调用方式是通过objc_msgSend函数。那么+initialize很有可能是在objc_msgSend函数中进行判断和触发，于是，在objc-msg-x86_64.s文件找到了objc_msgSend的汇编实现：

```asm
/********************************************************************
 *
 * id objc_msgSend(id self, SEL	_cmd,...);
 *
 ********************************************************************/
	
	.data
	.align 3
	.private_extern __objc_tagged_isa_table
__objc_tagged_isa_table:
	.fill 16, 8, 0

	ENTRY	_objc_msgSend
	DW_START _objc_msgSend

	NilTest	NORMAL

	GetIsaFast NORMAL		// r11 = self->isa
	CacheLookup NORMAL, _objc_msgSend  // r11=method, eq set (nonstret fwd)
	jmp	*method_imp(%r11)	// goto *imp

	NilTestSupport	NORMAL

	GetIsaSupport	NORMAL

// cache miss: go search the method lists
LCacheMiss:
	DW_MISS _objc_msgSend
	GetIsa	NORMAL			// r11 = self->isa
	MethodTableLookup %a1, %a2, _objc_msgSend	// r11 = IMP
	cmp	%r11, %r11		// set eq (nonstret) for forwarding
	jmp	*%r11			// goto *imp

	DW_END 		_objc_msgSend, 1, 1
	END_ENTRY	_objc_msgSend

#if __OBJC2__
	ENTRY _objc_msgSend_fixup
	DW_START _objc_msgSend_fixup

	NilTest	NORMAL

	SaveRegisters _objc_msgSend_fixup
	
	// Dereference obj/isa/cache to crash before _objc_fixupMessageRef
	movq	8(%a2), %a6		// selector
	GetIsa	NORMAL			// r11 = isa = *receiver
	movq	cache(%r11), %a5	// cache = *isa
	movq	mask(%a5), %a4		// *cache

	// a1 = receiver
	// a2 = address of message ref
	movq	%a2, %a3
	xorl	%a2d, %a2d
	// __objc_fixupMessageRef(receiver, 0, ref)
	call	__objc_fixupMessageRef
	movq	%rax, %r11

	RestoreRegisters _objc_msgSend_fixup

	// imp is in r11
	// Load _cmd from the message_ref
	movq	8(%a2), %a2
	cmp	%r11, %r11		// set nonstret (eq) for forwarding
	jmp 	*%r11

	NilTestSupport	NORMAL
	
	DW_END 		_objc_msgSend_fixup, 0, 1
	END_ENTRY 	_objc_msgSend_fixup


	STATIC_ENTRY _objc_msgSend_fixedup
	// Load _cmd from the message_ref
	movq	8(%a2), %a2
	jmp	_objc_msgSend
	END_ENTRY _objc_msgSend_fixedup
#endif

```

汇编基本就是大一水平，很有限。初略发现在调用指令_objc_msgSend之前，先调用了_objc_fixupMessageRef函数。

接着在objc-runtime-new.mm文件中找到_objc_fixupMessageRef函数：

```objc

OBJC_EXTERN IMP 
_objc_fixupMessageRef(id obj, struct objc_super2 *supr, message_ref_t *msg)
{
    IMP imp;
    class_t *isa;
    
	.....

    msg->sel = sel_registerName((const char *)msg->sel);

    if (ignoreSelector(msg->sel)) {
        // ignored selector - bypass dispatcher
        msg->imp = (IMP)&vtable_ignored;
        imp = (IMP)&_objc_ignored_method;
    }
#if SUPPORT_VTABLE
    else if (msg->imp == (IMP)&objc_msgSend_fixup  &&  
        (vtableIndex = vtable_getIndex(msg->sel)) >= 0) 
    {
        // vtable dispatch
        msg->imp = vtableTrampolines[vtableIndex];
        imp = isa->vtable[vtableIndex];
    }
#endif
    else {
        // ordinary dispatch
        //常规的消息派发，遍历类的函数列表
        imp = lookUpMethod((Class)isa, msg->sel, YES/*initialize*/, YES/*cache*/, obj);
        
        ......
    }

    return imp;
}

```

在上述函数中调用了lookUpMethod函数，其中调用了prepareForMethodLookup函数：

```objc

IMP prepareForMethodLookup(Class cls, SEL sel, BOOL init, id obj)
{
    rwlock_assert_unlocked(&runtimeLock);

    if (!isRealized(newcls(cls))) {
        rwlock_write(&runtimeLock);
        realizeClass(newcls(cls));
        rwlock_unlock_write(&runtimeLock);
    }

	//调用_class_initialize对类进行初始化
    if (init  &&  !_class_isInitialized(cls)) {
        _class_initialize (_class_getNonMetaClass(cls, obj));
        // If sel == initialize, _class_initialize will send +initialize and 
        // then the messenger will send +initialize again after this 
        // procedure finishes. Of course, if this is not being called 
        // from the messenger then it won't happen. 2778172
    }

    return NULL;
}

```

在objc-initialize.mm函数中，找到_class_initialize函数：

```objc

void _class_initialize(Class cls)
{
    assert(!_class_isMetaClass(cls));

    Class supercls;
    BOOL reallyInitialize = NO;

    // Make sure super is done initializing BEFORE beginning to initialize cls.
    // See note about deadlock above.
    //递归，保证父类先于子类初始化
    supercls = _class_getSuperclass(cls);
    if (supercls  &&  !_class_isInitialized(supercls)) {
        _class_initialize(supercls);
    }
    
	.....
	
	
    if (reallyInitialize) {
        // We successfully set the CLS_INITIALIZING bit. Initialize the class.
        
        // Record that we're initializing this class so we can message it.
        _setThisThreadIsInitializingClass(cls);
        
        // Send the +initialize message.
        // Note that +initialize is sent to the superclass (again) if 
        // this class doesn't implement +initialize. 2157218
        if (PrintInitializing) {
            _objc_inform("INITIALIZE: calling +[%s initialize]",
                         _class_getName(cls));
        }
	
		//通过objc_msgSend调用+initialize函数
        ((void(*)(Class, SEL))objc_msgSend)(cls, SEL_initialize);

        if (PrintInitializing) {
            _objc_inform("INITIALIZE: finished +[%s initialize]",
                         _class_getName(cls));
        }        
        
        // Done initializing. 
        // If the superclass is also done initializing, then update 
        //   the info bits and notify waiting threads.
        // If not, update them later. (This can happen if this +initialize 
        //   was itself triggered from inside a superclass +initialize.)
        
        .....
        
        return;
    }
    
    ......
}

```

通过上述函数可知两点：一是父类的+initialize函数先于子类调用，二是+initialize不同于+load函数的采用函数指针调用，而是通过objc_msgSend函数调用，如果分类实现了+initialize函数，那么类（包括子类和父类）的+initialize函数就会被覆盖。

因此，+initialize的调用顺序是父类->子类，且分类的实现覆盖类的实现，因此分类中的+initialize可能会被多次调用。

#### 小结 ####

至此，对于+load和+initialize的调用规则和方式有了进一步的认识。在日后的编程过程中也可以根据二者的特点，更好的使用它们的功能。
