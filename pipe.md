---
title: pipe
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: 1f9a630e
date: 2025-10-03 09:44:52
---
# pipe

pipe： 匿名管道。pipe 是一种 IPC 机制，他的作用是用作有血缘进程间完成数据传递，只能从一端写入，从另外一端读出。为了解决 pipe 的弊端，linux 又引入了 mkfifo(实名管道)。

## 创建管道

```c

rt_pipe_t *rt_pipe_create(constchar *name, intbufsz)

{

    //分配管道内存,初始化锁,初始化等待队列,初始化条件变量

    rt_mutex_init(&pipe->lock, name, RT_IPC_FLAG_FIFO);

    rt_wqueue_init(&pipe->reader_queue);

    rt_wqueue_init(&pipe->writer_queue);

    rt_condvar_init(&pipe->waitfor_parter, "piwfp");


    pipe->writer = 0;

    pipe->reader = 0;


    pipe->bufsz = bufsz;

    //注册PIPE设备的操作函数到rt_device中

    dev = &pipe->parent;

    dev->type = RT_Device_Class_Pipe;

    dev->init        = RT_NULL;

    dev->open        = rt_pipe_open;

    dev->read        = rt_pipe_read;

    dev->write       = rt_pipe_write;

    dev->close       = rt_pipe_close;

    dev->control     = rt_pipe_control;


    dev->rx_indicate = RT_NULL;

    dev->tx_complete = RT_NULL;

    //注册PIPE设备

    rt_device_register(&pipe->parent, name, RT_DEVICE_FLAG_RDWR | RT_DEVICE_FLAG_REMOVABLE);


    return pipe;

}

```

## 删除管道

```c

intrt_pipe_delete(constchar *name)

{

    //通过名字查找设备

    device = rt_device_find(name);

    if (device)

    {

        if (device->type == RT_Device_Class_Pipe)

        {

            rt_pipe_t *pipe;


            pipe = (rt_pipe_t *)device;

            //释放锁,释放等待队列,释放条件变量

            rt_condvar_detach(&pipe->waitfor_parter);

            rt_mutex_detach(&pipe->lock);

            //注销设备

            rt_device_unregister(device);


            /* close fifo ringbuffer */

            if (pipe->fifo)

            {

                rt_ringbuffer_destroy(pipe->fifo);

                pipe->fifo = RT_NULL;

            }

            rt_free(pipe);

        }

    }


    return result;

}

```

## 打开管道

```c

rt_mutex_take(&pipe->lock, RT_WAITING_FOREVER);

pipe->fifo = rt_ringbuffer_create(pipe->bufsz);//创建 ringbuff

rt_mutex_release(&pipe->lock);

```

## 关闭管道

```c

rt_mutex_take(&pipe->lock, RT_WAITING_FOREVER);

rt_ringbuffer_destroy(pipe->fifo);//摧毁 ringbuff

rt_mutex_release(&pipe->lock);

```

## 读取管道数据

```c

    rt_mutex_take(&pipe->lock, RT_WAITING_FOREVER);

    //一直从管道中读取数据,直到读取到count个字节

    while (read_bytes < count)

    {

        int len = rt_ringbuffer_get(pipe->fifo, &pbuf[read_bytes], count - read_bytes);

        if (len <= 0)

        {

            break;

        }


        read_bytes += len;

    }

    rt_mutex_release(&pipe->lock);

```

## 写入管道数据

```c

    rt_mutex_take(&pipe->lock, RT_WAITING_FOREVER);

    //一直往管道中写入数据,直到写入count个字节

    while (write_bytes < count)

    {

        int len = rt_ringbuffer_put(pipe->fifo, &pbuf[write_bytes], count - write_bytes);

        if (len <= 0)

        {

            break;

        }


        write_bytes += len;

    }

    rt_mutex_release(&pipe->lock);

```

## 匿名管道

```c

intpipe(intfildes[2])

{

    rt_pipe_t *pipe;

    chardname[8];// 这里应该写 RT_NAME_MAX

    chardev_name[32];

    staticint pipeno = 0;

    //拼接字符串，作为管道的名字

    rt_snprintf(dname, sizeof(dname), "pipe%d", pipeno++);

    pipe = rt_pipe_create(dname, PIPE_BUFSZ);// 创建管道

    if (pipe == RT_NULL)

    {

        return -1;

    }

    // 设置为匿名管道

    pipe->is_named = RT_FALSE; /* unamed pipe */

    //拼接字符串，作为管道的名字

    rt_snprintf(dev_name, sizeof(dev_name), "/dev/%s", dname);

    //只读的方式打开文件

    fildes[0] = open(dev_name, O_RDONLY, 0);

    if (fildes[0] < 0)

    {

        return -1;

    }

    //只写的方式打开文件

    fildes[1] = open(dev_name, O_WRONLY, 0);

    if (fildes[1] < 0)

    {

        close(fildes[0]);

        return -1;

    }

    return0;

}

```

## 实名管道

```c

intmkfifo(constchar *path, mode_tmode)

{

    rt_pipe_t *pipe;

    pipe = rt_pipe_create(path, PIPE_BUFSZ);// 创建管道

    if (pipe == RT_NULL)

    {

        return -1;

    }

    return0;

}

```

