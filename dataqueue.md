---
title: dataqueue
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: 9997c49a
date: 2025-10-03 09:44:51
---
# dataqueue

消息队列：消息队列能够接收来自线程或中断服务例程中不固定长度的消息，并把消息缓存在自己的内存空间中。其他线程也能够从消息队列中读取相应的消息，而当消息队列是空的时候，可以挂起读取线程。当有新的消息到达时，挂起的线程将被唤醒以接收并处理消息。消息队列是一种异步的通信方式。(摘自 RT-Thread文档中心).

数据队列：没有找到官方详细的说明，只是在 RT-Thread API参考手册,有介绍。数据队列能够接收来自线程中不固定长度的数据，数据 不会 缓存在自己的内存空间中，自己的内存空间只有一个指向这包数据的指针。其他线程也能够从数据队列获取数据，当数据队列为空的时候，可以挂起线程。当有新的数据到达时，挂起的线程将被唤醒以接收并处理消息。数据队列是一种异步的通信方式。

消息队列 是用于线程消息传递的，属于线程间同步异步 IPC；消息队列在 recv 数据之后，这组数据就没了。

数据队列 更多的使用在流式数据传递，属于线程间通信 IPC；数据队列可以使用 peak 的方式 舔一下 这组数据不会丢失。自带高、低水位，可以对锯齿速度(压入数据的间隔不一致，时快时慢的)情况进行调节.

```

data queu -> 数据队列

ring buffer -> 环形缓冲区


data queue -> 数据丢到队列中，并不做数据拷贝；

ring buffer -> 数据会拷贝到缓冲区中


data queue -> 自带高、低水位，可以对锯齿速度情况进行调节

ring buffer -> 完全不带出、入数据时，任务的挂起机制

```

```c

#define     RT_DATAQUEUE_EVENT_UNKNOWN   0x00//     未知数据队列事件

 

#define     RT_DATAQUEUE_EVENT_POP   0x01//     数据队列取出事件

 

#define     RT_DATAQUEUE_EVENT_PUSH   0x02//    数据队列写入事件

 

#define     RT_DATAQUEUE_EVENT_LWM   0x03//     数据队列数达到设定阈值事件

 

#define     RT_DATAQUEUE_SIZE(dq)   ((dq)->put_index- (dq)->get_index)//   数据队列使用数量

 

#define     RT_DATAQUEUE_EMPTY(dq)   ((dq)->size-RT_DATAQUEUE_SIZE(dq))//     数据队列空闲数量

```

