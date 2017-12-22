title: 剖析@synchronizd底层实现原理
date: 2017-12-21 17:28:07
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
    我们发现objc_sync_enter函数是在try语句之前调用，参数为需要加锁的对象，而objc_sync_exit则是在_SYNC_EXIT结构体中的析构函数中调用，参数同样是当前加锁的对象。因为C++中没有try{}catch{}finally{}语句，所以不能在finally{}调用objc_sync_exit函数。

[源代码](https://github.com/opensource-apple/objc4/blob/master/runtime/objc-sync.mm)


