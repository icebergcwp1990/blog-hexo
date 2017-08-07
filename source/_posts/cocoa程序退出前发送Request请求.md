title: Cocoa程序退出前发送HttpRequest请求
date: 2017-05-05 17:06:07
tags: 
- cocoa
categories: 
- cocoa
keywords: HttpRequest
decription: Cocoa程序退出前发送HttpRequest请求

---

最近在视频投送项目中遇到一个奇葩问题，花费了一整天时间才得以解决。这个问题比较隐晦，值得记录一下。

根据功能需要，需要在cocoa程序退出前，发送一个关闭设备的指令，本质上就是post一个Http请求，用于中止当前出于投送状态的设备。

具体代码如下：

在回调函数- (void)applicationWillTerminate:中调用停止投送API

```objc

	- (void)applicationWillTerminate:(NSNotification *)aNotification {
    	// Insert code here to tear down your application
    	
    	[[CastHelper sharedInstance] stopCast];
    
	}

````

将stop指令集成到URL里面，加入投送队列castOperationQueue中，然后通过HttpRequest发送出去。

```objc

		- (void)stopCast
		{
			dispatch_async(castOperationQueue, ^{
        
	       		 for (ZDCastDevice * device in self.connectedDeviceInfo.allValues )
	        	{
	            	//发送stop请求
					[self sendRequestURL:@"192.168.1.1/xxx/stop" HTTPMethod:@"POST" completionHandler:completionHandler];
	            
	        	}
        
    		});
			
		
		}

		//异步请求
		- (void)sendRequestURL:(NSURL *)url HTTPMethod:(NSString *)httpMethod
	{
	    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	    [request setURL:url];
	    [request setHTTPMethod:httpMethod];
	    [request setValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
	    [request setHTTPBody:nil];
	 
	    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
	        
	        //Error
	        if (error)
	        {
	            
	            
	        }else
	        {
	            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
	         
	            //successed
	            if ( statusCode == 200)
	            {
	                
	            //failed
	            }else
	            {
	                
	            }
	            
	        }
	  
	    }] resume];
	 
}

```

在程序正常运行期间，使用上述代码能够正常的执行stop指令，并接受相应的响应。但是，如果在applicationWillTerminate这一函数中调用，通过断点调试发现Request并未成功发送出去，程序就退出了。

一开始以为是异步发送请求的原因，于是使用dispatch_semaphore_t信号量进行同步，执行结果一样，未解锁之前程序就退出了。代码如下：

```objc

		//异步请求
		- (void)sendRequestURL:(NSURL *)url HTTPMethod:(NSString *)httpMethod
	{
	    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	    [request setURL:url];
	    [request setHTTPMethod:httpMethod];
	    [request setValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
	    [request setHTTPBody:nil];
	    
	    //创建信号量
	    dispatch_semaphore_t semp = dispatch_semaphore_create(0);
	    
	    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
	        
	        //Error
	        if (error)
	        {
	            
	            
	        }else
	        {
	            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
	         
	            //successed
	            if ( statusCode == 200)
	            {
	                
	            //failed
	            }else
	            {
	                
	            }
	            
	        }
	        
	        dispatch_semaphore_signal(semp);
	        
	    }] resume];
	    
	    //等待接受到请求响应才执行后续代码
	    dispatch_semaphore_wait(semp, DISPATCH_TIME_FOREVER);
   
}

```

同步请求方式的方式也试过，结果同样达不到预期效果。代码如下：

```objc

	NSURLResponse* response = nil;
	    NSError * error = nil;
	    
	    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	    
	    if (error) {
	        
	        HTTPLogInfo(@"%s:%d - Error: %@" , __func__ , __LINE__ , [error localizedDescription]);
	        
	    }else
	    {
	        HTTPLogInfo(@"%s:%d - response: %@" , __func__ , __LINE__ , [response description]);
	    }
    
```

思来想去，觉得可能是程序退出去前，只有主线程有效，其他线程均被释放了。于是，把调用stop指令的代码放入主线程队列：

```objc

	- (void)stopCast
	{
		//加入主线程队列
		dispatch_async(dispatch_get_main_queue(), ^{
       
       		 for (ZDCastDevice * device in self.connectedDeviceInfo.allValues )
        	{
            	//发送stop请求
				[self sendRequestURL:@"192.168.1.1/xxx/stop" HTTPMethod:@"POST" completionHandler:completionHandler];
            
        	}
       
   		});
		
	
	}

```

执行结果还是同之前一样。最后，仔细回想了一下RunLoop的执行过程，很可能是RunLoop在执行了applicationWillTerminate函数所在的任务之后就直接退出了，也就不会执行主线程队列后续的任务了。

于是，直接把调用stop指令的函数放在与applicationWillTerminate同一个任务中，代码如下：

```objc

	- (void)stopCast
	{
		//发送stop请求
		[self sendRequestURL:@"192.168.1.1/xxx/stop" HTTPMethod:@"POST" completionHandler:completionHandler];
		
	
	}

```

果然不出所料，Request执行成功，并获得相应的Response。

#### 小结 #####

上述言论都是基于我的猜测，我暂时没有去验证。这个问题比较隐晦，有点违背习惯性的思维。改天抽空结合Apple源代码进行分析验证，此处留坑。
