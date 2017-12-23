title: 剖析@synchronizd底层实现原理
date: 2017-06-11 22:28:07
tags: 
- Objective-C
categories: 
- 专业
keywords:  synchronizd
decription:  剖析@synchronizd底层实现原理

---

@synchronizd是Objective-C中的一个语法糖，用于给某个对象加锁，因为使用起来简单方便，所以使用频率很高。然而，滥用@synchronizd很容易导致代码效率低下。本篇博客旨在结合@synchronizd底层实现源码并剖析其实现原理，这样可以更好的让我们在适合的情景使用@synchronizd。

@synchronizd本质上是一个编译器标识符，在Objective-C层面看不其任何信息。因此可以通过clang -rewrite-objc指令来获得@synchronizd的C++实现代码。示例代码如下：

```objc
int main(int argc, const char * argv[]) {
    NSString *obj = @"Iceberg";
    @synchronized(obj) {
        NSLog(@"Hello,world! => %@" , obj);
    }
}
```
```C++
int main(int argc, const char * argv[]) {
    
    NSString *obj = (NSString *)&__NSConstantStringImpl__var_folders_8l_rsj0hqpj42b9jsw81mc3xv_40000gn_T_block_main_54f70c_mi_0;
    
    {
        id _rethrow = 0;
        id _sync_obj = (id)obj;
        objc_sync_enter(_sync_obj);
        try {
	            struct _SYNC_EXIT {
	                _SYNC_EXIT(id arg) : sync_exit(arg) {}
	                ~_SYNC_EXIT() {
	                    objc_sync_exit(sync_exit);
	                }
	                id sync_exit;
	            } _sync_exit(_sync_obj);

                NSLog((NSString *)&__NSConstantStringImpl__var_folders_8l_rsj0hqpj42b9jsw81mc3xv_40000gn_T_block_main_54f70c_mi_1 , obj);
                
            } catch (id e) {
                _rethrow = e;
            }
        
        {
            struct _FIN {
                _FIN(id reth) : rethrow(reth) {}
                ~_FIN() {
                    if (rethrow)
                        objc_exception_throw(rethrow);
                }
                id rethrow;
            } _fin_force_rethow(_rethrow);
        }
    }

}
```
通过分析C++代码可以看到@sychronized的实现主要依赖于两个函数：objc_sync_enter和objc_sync_exit。此外还有try{}catch{}语句用于捕捉@sychronized{}语法块中代码执行过程中出现的异常。

我们发现objc\_sync\_enter函数是在try语句之前调用，参数为需要加锁的对象。因为C++中没有try{}catch{}finally{}语句，所以不能在finally{}调用objc\_sync\_exit函数。因此objc\_sync\_exit是在\_SYNC\_EXIT结构体中的析构函数中调用，参数同样是当前加锁的对象。这个设计很巧妙，原因在_SYNC_EXIT结构体类型的\_sync\_exit是一个局部变量，生命周期为try{}语句块，其中包含了@sychronized{}代码需要执行的代码，在代码完成后，\_sync\_exit局部变量出栈释放，随即调用其析构函数，进而调用objc\_sync\_exit函数。即使try{}语句块中的代码执行过程中出现异常，跳转到catch{}语句，局部变量\_sync\_exit同样会被释放，完美的模拟了finally的功能。

接下来，在[苹果公开的源代码文件objc-sync.mm](https://github.com/opensource-apple/objc4/blob/master/runtime/objc-sync.mm)中找到objc_sync_enter和objc_sync_exit这两个函数的实现，一窥其中的奥秘。

```C++
typedef struct SyncData {
    struct SyncData* nextData;
    DisguisedPtr<objc_object> object; //当前加锁的对象
    int32_t threadCount;  //使用对object加锁的线程个数
    recursive_mutex_t mutex; //递归互斥锁
} SyncData;

typedef struct {
    SyncData *data;
    unsigned int lockCount;  //表示当前线程对object对象加锁次数
} SyncCacheItem;

typedef struct SyncCache {
    unsigned int allocated;
    unsigned int used;
    SyncCacheItem list[0];
} SyncCache;

/*
  Fast cache: two fixed pthread keys store a single SyncCacheItem. 
  This avoids malloc of the SyncCache for threads that only synchronize 
  a single object at a time.
  SYNC_DATA_DIRECT_KEY  == SyncCacheItem.data
  SYNC_COUNT_DIRECT_KEY == SyncCacheItem.lockCount
 */

struct SyncList {
    SyncData *data;
    spinlock_t lock;

    SyncList() : data(nil) { }
};

// Use multiple parallel lists to decrease contention among unrelated objects.
#define LOCK_FOR_OBJ(obj) sDataLists[obj].lock
#define LIST_FOR_OBJ(obj) sDataLists[obj].data
static StripedMap<SyncList> sDataLists;
```
上述代码是一些相关的数据结构，下面分别进行介绍：

SyncData结构体中有四个成员变量，其中object指针变量指向当前加锁对象，threadCount表示对object加锁的线程个数，mutex是一个递归互斥锁，意味着可以对object进行多次加锁，其具体作用后面会提到。

SyncCacheItem结构体中有两个成员变量，其中data是SyncData结构体类型的指针，lockCount表示当前线程对当前结构体对象加锁次数，其实就是对加锁对象object的加锁次数。我们可以看到SyncCacheItem与SyncData是一对一关系，SyncCacheItem只是对SyncData进行了再次封装以便于缓存，具体使用见后文。

SyncCache结构体中有三个成员变量，其中维护了一个SyncCacheItem类型的数组，allocated和used则分别表示当前分配的SyncCacheItem数组中的总个数和已经使用的个数。这个结构体与线程是一对一的关系，用于存储当前线程已加锁对象对应的SyncCacheItem结构体，因为一个线程可以对同一个对象多次加锁，所以通过引入缓存SyncCache可以提高效率，具体使用见后文。

SyncList结构体中有两个成员变量和一个构造函数，其中data是SyncData结构体类型的指针，lock是一个自旋锁。

sDataLists是一个全局StripedMap哈希列表，其中value为SyncList对象，key为加锁对象object指针进行hash后的值。StripedMap是一个C++模板类，其实现代码如下所示：

```C++
template<typename T>
class StripedMap {

    enum { CacheLineSize = 64 };

#if TARGET_OS_EMBEDDED
    enum { StripeCount = 8 };
#else
    enum { StripeCount = 64 };
#endif

    struct PaddedT {
        T value alignas(CacheLineSize);
    };

    PaddedT array[StripeCount];

    static unsigned int indexForPointer(const void *p) {
        uintptr_t addr = reinterpret_cast<uintptr_t>(p);
        return ((addr >> 4) ^ (addr >> 9)) % StripeCount;
    }

 public:
    T& operator[] (const void *p) { 
        return array[indexForPointer(p)].value; 
    }
    const T& operator[] (const void *p) const { 
        return const_cast<StripedMap<T>>(this)[p]; 
    }

#if DEBUG
    StripedMap() {
        // Verify alignment expectations.
        uintptr_t base = (uintptr_t)&array[0].value;
        uintptr_t delta = (uintptr_t)&array[1].value - base;
        assert(delta % CacheLineSize == 0);
        assert(base % CacheLineSize == 0);
    }
#endif
};
```
上述代码中，由于自己对C++模板类不熟悉，所以只能看个大概。其中有两个值得注意的地方，其中StripeCount表示哈希数组的长度，如果是嵌入式系统值为8，否则值为64，也就意味着哈希数组最大长度为64；另外indexForPointer函数是用于计数哈希下标的函数，算法不难，但是很巧妙，值得学习。

下面开始分析相关的函数实现，首先找到@sychronized直接调用的两个函数：objc_sync_enter和objc_sync_exit，代码如下：

```C++
// Begin synchronizing on 'obj'. 
// Allocates recursive mutex associated with 'obj' if needed.
// Returns OBJC_SYNC_SUCCESS once lock is acquired.  
int objc_sync_enter(id obj)
{
    int result = OBJC_SYNC_SUCCESS;

    if (obj) {
        SyncData* data = id2data(obj, ACQUIRE);
        assert(data);
        data->mutex.lock();
    } else {
        // @synchronized(nil) does nothing
        if (DebugNilSync) {
            _objc_inform("NIL SYNC DEBUG: @synchronized(nil); set a breakpoint on objc_sync_nil to debug");
        }
        objc_sync_nil();
    }

    return result;
}

// End synchronizing on 'obj'. 
// Returns OBJC_SYNC_SUCCESS or OBJC_SYNC_NOT_OWNING_THREAD_ERROR
int objc_sync_exit(id obj)
{
    int result = OBJC_SYNC_SUCCESS;
    
    if (obj) {
        SyncData* data = id2data(obj, RELEASE); 
        if (!data) {
            result = OBJC_SYNC_NOT_OWNING_THREAD_ERROR;
        } else {
            bool okay = data->mutex.tryUnlock();
            if (!okay) {
                result = OBJC_SYNC_NOT_OWNING_THREAD_ERROR;
            }
        }
    } else {
        // @synchronized(nil) does nothing
    }
	

    return result;
}
```
不难发现，上述代码都调用了id2data函数来获取一个与obj对应的SyncData对象，然后使用该对象中的递归互斥锁分别进行加锁与解锁。至此@sychronized的大致实现过程已经很清晰了，本质上是为一个对象分配一把递归互斥锁，可以也是为什么可以反复使用@sychronized对同一个对象进行加锁的原因。那么@sychronized是如果管理这把互斥锁，以及是如何处理多个线程对同一个对象进行多次加锁的情况？很明显，一切奥秘都藏在id2data函数中，其代码如下所示：

* 注：为了描述方便，下面将id2data函数的形参object描述为同步对象obejct。

```C++
static SyncData* id2data(id object, enum usage why)
{
	//从全局哈希表sDataLists中获取object对应的SyncList对象
	//lockp指针指向SyncList对象中自旋锁
	//listp二级指针是指向SyncData对象指针的指针，这里为什么要用二级指针不是很明白？
    spinlock_t *lockp = &LOCK_FOR_OBJ(object);
    SyncData **listp = &LIST_FOR_OBJ(object);
    SyncData* result = NULL;

	//对于同一个线程来说，有两种缓存方式：
	//第一种：快速缓存（fastCache），适用于一个线程一次只对一个对象加锁的情况，用宏SUPPORT_DIRECT_THREAD_KEYS来标识
	//这种情况意味着同一时间内，线程缓存中只有一个SyncCacheItem对象，键值SYNC_DATA_DIRECT_KEY和SYNC_COUNT_DIRECT_KEY分别对应SyncCacheItem结构体中的SyncData对象和lockCount.
#if SUPPORT_DIRECT_THREAD_KEYS
    // Check per-thread single-entry fast cache for matching object
    //用于标识当前线程的是否已使用fastCache
    bool fastCacheOccupied = NO;
    //直接调用tls_get_direct函数获取SyncData对象
    SyncData *data = (SyncData *)tls_get_direct(SYNC_DATA_DIRECT_KEY);
    if (data) {
    	 //标识fastCache已被使用
        fastCacheOccupied = YES;
		 //比较fastCache中的SyncData对象中的object与当前同步对象object是否为同一个对象
        if (data->object == object) {
            // Found a match in fast cache.
   			  //fastCache中的对象恰好是当前同步对象object，则后续处理直接使用fastCache中SyncData对象
            uintptr_t lockCount;

            result = data;
            //获取当前线程对应当前SyncData对象已经加锁的次数
            lockCount = (uintptr_t)tls_get_direct(SYNC_COUNT_DIRECT_KEY);
            //无效的SyncData对象
            if (result->threadCount <= 0  ||  lockCount <= 0) {
                _objc_fatal("id2data fastcache is buggy");
            }
			  //判断当前操作的加锁还是解锁
            switch(why) {
            //加锁
            case ACQUIRE: {
                //加锁一次
                lockCount++;
                //更新已加锁次数
                tls_set_direct(SYNC_COUNT_DIRECT_KEY, (void*)lockCount);
                break;
            }
            //解锁
            case RELEASE:
                //解锁一次
                lockCount--;
                //更新已加锁次数
                tls_set_direct(SYNC_COUNT_DIRECT_KEY, (void*)lockCount);
                //已加锁次数为0，表示当前线程对当前同步对象object达到锁平衡，因此不需要再持有当前同步对象。
                if (lockCount == 0) {
                    // remove from fast cache
                    //将对应的SyncData对象从线程缓存中移除
                    tls_set_direct(SYNC_DATA_DIRECT_KEY, NULL);
                    // atomic because may collide with concurrent ACQUIRE
                    //此函数为原子操作函数，用于对32位的threadCount整形变量执行减一操作，且确保线程安全。因为可能存在同一时间多个线程对一个threadCount进行加减操作，避免出现多线程竞争。不同于lockCount，threadCount是多个线程共享的一个变量，用于记录对一个对象加锁的线程个数，threadCount对应的SyncData对象除了线程缓存中持有之外，还存在于全局哈希表sDataLists中，sDataLists哈希表是多个线程共享的数据结构，因此存在多线程访问的可能。而lockCount则与线程一一对应且存储在线程的缓存区中，不存在多线性读写问题，因此不需要加锁。
                    OSAtomicDecrement32Barrier(&result->threadCount);
                }
                break;
            case CHECK:
                // do nothing
                break;
            }

            return result;
        }
    }
#endif

    // Check per-thread cache of already-owned locks for matching object
    //这是第二章缓存方式：使用SyncCache结构体来维护一个SyncCacheItem数组，这样一个线程就可以处理对多个同步对象。值得注意的是SyncCache与线程也是一对一的关系。
    //获取当前线程缓存区中的SyncCache对象
    SyncCache *cache = fetch_cache(NO);
    if (cache) {
        unsigned int i;
        //遍历SyncCache对象中的SyncCacheItem数组，匹配当前同步对象object
        for (i = 0; i < cache->used; i++) {
            SyncCacheItem *item = &cache->list[i];
            if (item->data->object != object) continue;

            // Found a match.
            //当前同步对象object已存在的SyncCache中
            //获取对应的SyncData对象
            result = item->data;
            //无效的SyncData对象
            if (result->threadCount <= 0  ||  item->lockCount <= 0) {
                _objc_fatal("id2data cache is buggy");
            }
            //后续操作同fastCache一样，参考fastCache的注释
            switch(why) {
            case ACQUIRE:
                item->lockCount++;
                break;
            case RELEASE:
                item->lockCount--;
                if (item->lockCount == 0) {
                    // remove from per-thread cache
                    cache->list[i] = cache->list[--cache->used];
                    // atomic because may collide with concurrent ACQUIRE
                    OSAtomicDecrement32Barrier(&result->threadCount);
                }
                break;
            case CHECK:
                // do nothing
                break;
            }
			  
            return result;
        }
    }

    // Thread cache didn't find anything.
    // Walk in-use list looking for matching object
    // Spinlock prevents multiple threads from creating multiple 
    // locks for the same new object.
    // We could keep the nodes in some hash table if we find that there are
    // more than 20 or so distinct locks active, but we don't do that now.
    
    //如果当前线程中的缓存中没有找到当前同步对象对应的SyncData对象，则在全局哈希表中查找
    //因为全局哈希表是多个线程共享的数据结构，因此需要进行加锁处理
    lockp->lock();

    {
        SyncData* p;
        SyncData* firstUnused = NULL;
        //遍历当前同步对象obejct在全局哈希表中的SyncData链表。这里之所以使用链表，是因为哈希表的hash算法不能确保hash的唯一性，存在多个对象对应一个hash值的情况。
        for (p = *listp; p != NULL; p = p->nextData) {
        	  //哈希表中存在对应的SyncData对象
            if ( p->object == object ) {
                result = p;
                // atomic because may collide with concurrent RELEASE
                //此函数为原子操作函数，确保线程安全，用于对32位的threadCount整形变量执行加一操作，表示占用当前同步对象的线程数加1。
                OSAtomicIncrement32Barrier(&result->threadCount);
                goto done;
            }
            //用于标记一个空闲的SyncData对象
            if ( (firstUnused == NULL) && (p->threadCount == 0) )
                firstUnused = p;
        }
    
        // no SyncData currently associated with object
        //由于此时同步对象object没有对应的SyncData对象，因此RELEASE与CHECK都属于无效操作
        if ( (why == RELEASE) || (why == CHECK) )
            goto done;
    
        // an unused one was found, use it
        //如果没有找到匹配的SyncData对象且存在空闲的SyncData对象，则直接使用，不需要创建新的SyncData，以提高效率。
        if ( firstUnused != NULL ) {
            result = firstUnused;
            //关联当前同步对象
            result->object = (objc_object *)object;
            //重置占用线程为1
            result->threadCount = 1;
            goto done;
        }
    }

    // malloc a new SyncData and add to list.
    // XXX calling malloc with a global lock held is bad practice,
    // might be worth releasing the lock, mallocing, and searching again.
    // But since we never free these guys we won't be stuck in malloc very often.
    
    //到这一步说明需要新建一个SyncData对象
    result = (SyncData*)calloc(sizeof(SyncData), 1);
    result->object = (objc_object *)object;
    result->threadCount = 1;
    //创建递归互斥锁
    new (&result->mutex) recursive_mutex_t();
    //以“入栈”的方式加入当前同步对象object对应的SyncData链表
    result->nextData = *listp;
    *listp = result;
    
 done:
 	 //对全局哈希表的操作结束，解锁
    lockp->unlock();
    if (result) {
        // Only new ACQUIRE should get here.
        // All RELEASE and CHECK and recursive ACQUIRE are 
        // handled by the per-thread caches above.
        //只有ACQUIRE才需要新建SyncData对象
        if (why == RELEASE) {
            // Probably some thread is incorrectly exiting 
            // while the object is held by another thread.
            return nil;
        }
        if (why != ACQUIRE) _objc_fatal("id2data is buggy");
        if (result->object != object) _objc_fatal("id2data is buggy");

		 //fastCache缓存模式
#if SUPPORT_DIRECT_THREAD_KEYS
        if (!fastCacheOccupied) {
            // Save in fast thread cache
            //直接缓存新建的SyncData对象
            tls_set_direct(SYNC_DATA_DIRECT_KEY, result);
            //设置加锁次数为1
            tls_set_direct(SYNC_COUNT_DIRECT_KEY, (void*)1);
        } else 
#endif
		 //SyncCache缓存模式，则直接加入SyncCacheItem数组中
        {
            // Save in thread cache
            if (!cache) cache = fetch_cache(YES);
            cache->list[cache->used].data = result;
            cache->list[cache->used].lockCount = 1;
            cache->used++;
        }
    }

    return result;
}
```
通过上述代码的注释，id2data函数的功能已经大致清晰。id2data函数主要是用于管理同步对象object与线程之间的关联。不论是ACQUIRE、RELEASE还是CHECK操作，都会先从当前线程的缓存中去获取对应的SyncData对象。如果当前线程的缓存区中不存在，那么再从全局的哈希数组中查找，查看其它线程是否已经占用过当前同步对象object。如果还是没有，那么就新建一个与之对应的SyncData对象，分别加入全局哈希表和当前线程缓存中。

至此，@synchronized的实现原理已经剖析结束，其有一个最大的特点是：不论是多个线性同一时间内对一个对象进行多次同步还是一个线程对同一个对象同步多次，一个对象只分配一把递归互斥锁。也就意味着对同一个对象而言，当执行某一次同步操作时，其他线程或同一线程的其他同步操作都会被阻塞，不言而喻，这种加锁方式的效率是很低的。

下面代码展示了@synchronized经典的使用案例之一：

```objc
- (void)setInstanceMemberObjecObject1:(id)value {
	@synchronized(self) {
		self.instanceMember1 = value;
	}
}

- (void)setInstanceMemberObjecObject2:(id)value {
	@synchronized(self) {
		self.instanceMember2 = value;
	}
}

- (void)setInstanceMemberObjecObject3:(id)value {
	@synchronized(self) {
		self.instanceMember3 = value;
	}
}
```
上述代码，调用其中一个设置函数时，另外两个成员变量的设置函数在同一时间被调用都会被阻塞。这里@synchronized同步的代码很简单，所以不会效率差别不大。如果是同步的代码需要执行较长的时间，且被多个线程并发调用，那么效率变得很低。如果不清楚@synchronized的实现原理，可能很难排查出来导致效率低下的问题所在。我建议使用GCD取代@synchronized实现同步功能，GCD不仅是线程安全，且其由底层实现，效率会好很多。我们发生@synchronized的底层实现有捕获异常的功能，因此适合在需要确保发生错误时代码不会死锁，而是抛出异常时使用。

