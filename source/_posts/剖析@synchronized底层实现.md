title: 剖析@synchronizd底层实现原理
date: 2017-12-21 17:28:07
tags: 
- Objective-C
categories: 
- 专业
keywords: @synchronizd
decription: 剖析@synchronizd底层实现原理

---

[源代码](https://github.com/opensource-apple/objc4/blob/master/runtime/objc-sync.mm#L295)


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
	    NSString *obj = (NSString *)&__NSConstantStringImpl__var_folders_8l_rsj0hqpj42b9jsw81mc3xv_40000gn_T_block_main_baa732_mi_0;
	    { id _rethrow = 0; id _sync_obj = (id)obj; objc_sync_enter(_sync_obj);
	try {
		struct _SYNC_EXIT { _SYNC_EXIT(id arg) : sync_exit(arg) {}
		~_SYNC_EXIT() {objc_sync_exit(sync_exit);}
		id sync_exit;
		} _sync_exit(_sync_obj);
	
	        NSLog((NSString *)&__NSConstantStringImpl__var_folders_8l_rsj0hqpj42b9jsw81mc3xv_40000gn_T_block_main_baa732_mi_1 , obj);
	    } catch (id e) {_rethrow = e;}
	{ struct _FIN { _FIN(id reth) : rethrow(reth) {}
		~_FIN() { if (rethrow) objc_exception_throw(rethrow); }
		id rethrow;
		} _fin_force_rethow(_rethrow);}
	}
	
	}
```