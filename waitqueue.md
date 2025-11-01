---
title: waitqueue
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: 59c8d408
date: 2025-10-03 09:44:52
---
# waitqueue

## 初始化

```c

rt_inline voidrt_wqueue_init(rt_wqueue_t *queue)

{

    RT_ASSERT(queue != RT_NULL);

    queue->flag = RT_WQ_FLAG_CLEAN;                // 将队列设置为可插入状态

    rt_list_init(&(queue->waiting_list));        // 初始化链表节点

}

```

## 加入队列

线程加入队列有两种方式：

- 阻塞式加入：这种方式类似于信号量的用法，当参数condition为 0 时，线程会被阻塞，并将含有线程信息的等待节点加入到等待队列中。

```c

intrt_wqueue_wait(rt_wqueue_t *queue, intcondition, intmsec)

```

```c

staticint_rt_wqueue_wait(rt_wqueue_t *queue, intcondition, intmsec, intsuspend_flag)

{

    // 初始化等待节点

    __wait.polling_thread = rt_thread_self();

    __wait.key = 0;

    __wait.wakeup = __wqueue_default_wake;    // 使用默认线程唤醒回调函数，该函数只执行return 0

    __wait.wqueue = queue;

    rt_list_init(&__wait.list);


    /* reset thread error */

    tid->error = RT_EOK;

    // 当该队列执行了唤醒函数，但是唤醒的线程还没得到调用时，不插入新节点

    if (queue->flag == RT_WQ_FLAG_WAKEUP)

    {

        /* already wakeup */

        goto __exit_wakeup;

    }

    // 将线程挂起

    ret = rt_thread_suspend_with_flag(tid, suspend_flag);

    if (ret != RT_EOK)

    {

        rt_spin_unlock_irqrestore(&(queue->spinlock), level);

        /* suspend failed */

        return -RT_EINTR;

    }

    // 将节点插入到队列的末尾

    rt_list_insert_before(&(queue->waiting_list), &(__wait.list));

    /* start timer */

    if (tick != RT_WAITING_FOREVER)

    {

        rt_timer_control(tmr,

                         RT_TIMER_CTRL_SET_TIME,

                         &tick);

        rt_timer_start(tmr);

    }

    rt_schedule();                                          // 开启调度

    // 当函数执行到这里，那就意味着线程被唤醒并运行了。

  

__exit_wakeup:

    // 恢复队列的可插入状态，并将节点从队列中删除

    queue->flag = RT_WQ_FLAG_CLEAN;

    rt_wqueue_remove(&__wait);

    returntid->error > 0 ? -tid->error : tid->error;

}

```

- 非阻塞式加入：这种方式是等待队列的一个特性，它允许将等待节点添加到等待队列中，而不会阻塞线程。但需要注意的是，这种方式需要我们自己创建并初始化等待节点。

对于该函数我们只需要注意一个点：这意味着节点插入的方式是前插，即新节点会插入到队列的尾部，因此等待队列会按照先进先出的顺序进行唤醒。

```c

voidrt_wqueue_add(rt_wqueue_t *queue, struct rt_wqueue_node *node)

{

    ......

    node->wqueue = queue;                                            // 记录加入的队列头指针

    rt_list_insert_before(&(queue->waiting_list), &(node->list));    // 插入到队尾

    ......

}


// 使用自定义的函数作为唤醒线程的回调函数

// **注意**：使用自定义唤醒函数时，函数的正常返回值必须得是0，否则无法正常唤醒线程。

#define DEFINE_WAIT_FUNC(name, function)                \

    struct rt_wqueue_node name = {                      \

        rt_current_thread,                              \    更改为：rt_thread_self(),

        RT_LIST_OBJECT_INIT(((name).list)),             \  

        function,                                       \    在functiong前添加NULL,

        0                                               \

    }

// 使用默认唤醒回调函数

#define DEFINE_WAIT(name) DEFINE_WAIT_FUNC(name, __wqueue_default_wake)

```

## 唤醒队列

整个过程都比较清晰，唯一需要注意的是，当调用rt_thread_resume时会检查线程是否已挂起，若未挂起，则函数直接退出，因此，当线程没有挂起时该唤醒函数是无效的。

```c

voidrt_wqueue_wakeup(rt_wqueue_t *queue, void *key)

{

    // 获取链表节点

    queue_list = &(queue->waiting_list);

    // 切换队列工作状态

    queue->flag = RT_WQ_FLAG_WAKEUP;

    // 检查队列中是否存在等待节点

    if (!(rt_list_isempty(queue_list)))

    {

        // 找到队列中第一个可用的节点唤醒

        for (node = queue_list->next; node != queue_list; node = node->next)

        {

            // 通过结构体成员获取该结构体变量的地址

            entry = rt_list_entry(node, struct rt_wqueue_node, list);

            // 只有当wakeup返回0时才能唤醒线程 -- 在自己编写唤醒函数时要注意

            if (entry->wakeup(entry, key) == 0)

            {

                rt_thread_resume(entry->polling_thread); // 唤醒线程

                need_schedule = 1;

                rt_list_remove(&(entry->list));            // 将等待节点从队列中移除

                break;

            }

        }

    }

    // 调度

    if (need_schedule)

        rt_schedule();

}

```

## 非阻塞式加入编写一个示例

示例创建了四个线程，三个生产数据的线程p1, p2, p3和一个消费数据的线程c。将线程c分别加入到p1, p2, p3管理的等待队列中，然后主动挂起，当p1，p2，p3任意一个线程准备好了数据就将线程c唤醒消费数据。

运行结果：

p1，p2，p3线程都不规律的生产数据，每次生产数据之后线程c都会马上消费。有可能出现同时多个线程同时生产好数据，并同时唤醒c线程的情况，这个时候线程c就会一次性消费多个数据，但是这种情况确实非常难出现。

## 等待队列的作用

等待队列在两个地方出现了：

在驱动poll函数中将线程加入到等待队列

文件状态变化，将线程唤醒

我们发现等待队列在其中的作用就像是预约，将线程自己加入到所有文件的等待队列中就像线程预约了所有文件一样，线程好像在跟文件说：“有什么变动你就通知我”。想象一下，每个文件就像是一家理发店，我们有一个理发店电话簿（文件状态数组）。然后，我们逐个给每家理发店打电话预约（遍历并加入等待队列），如果其中有一家理发店有空位了（文件状态改变），店主就会打电话通知你过去剪头发（唤醒），如果我们不喜欢给我们理发的托尼老师（文件状态不满足目标），那我们就继续等待（继续挂起）。当然如果理发店一直没有通知，或者一直没有等待我们想要的托尼老师，而我们又有事情要忙，那么就可以取消预约，忙自己的事情去（超时退出）

