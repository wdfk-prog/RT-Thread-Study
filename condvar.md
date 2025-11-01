---
title: condvar
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: de47c3e5
date: 2025-10-03 09:44:51
---
# condvar

条件变量是一种线程间同步的机制，它可以让一个线程等待另一个线程满足某个条件。条件变量是与互斥量配合使用的，互斥量用于保护共享数据，条件变量用于等待某个条件的发生。

## 初始化

```c

//初始化等待队列

rt_wqueue_init(&cv->event);

rt_atomic_store(&cv->waiters_cnt, 0);

rt_atomic_store(&cv->waiting_mtx, 0);

```

## 等待

```c

intrt_condvar_timedwait(rt_condvar_tcv, rt_mutex_tmtx, intsuspend_flag,

                         rt_tick_ttimeout)

{

    waiting_mtx = rt_atomic_load(&cv->waiting_mtx);

    //如果没有过互斥量

    if (!waiting_mtx)

        //将cv->waiting_mtx的值设置为当前互斥锁mtx的地址

        acq_mtx_succ = rt_atomic_compare_exchange_strong(

            &cv->waiting_mtx, &waiting_mtx, (size_t)mtx);

    else

        acq_mtx_succ = 0;


    rt_spin_unlock(&_local_cv_queue_lock);

    //acq_mtx_succ会被设置为1，意味着没有其他线程正在等待这个条件变量，当前线程可以安全地进入等待状态。

    //如果相等，这意味着当前线程之前已经与这个条件变量关联过，可以继续等待。

    if (acq_mtx_succ == 1 || waiting_mtx == (size_t)mtx)

    {

        //等待线程数加1

        rt_atomic_add(&cv->waiters_cnt, 1);

        //将当前线程加入到等待队列中

        rc = _waitq_inqueue(&cv->event, &node, timeout, RT_KILLABLE);

        //释放互斥锁

        acq_mtx_succ = rt_mutex_release(mtx);

        //执行调度,将当前线程挂起

        rt_schedule();


        //线程切换回来,证明线程唤醒,从等待队列中移除当前线程

        rt_wqueue_remove(&node);

        //等待线程数减1

        if (rt_atomic_add(&cv->waiters_cnt, -1) == 1)//当前线程是最后一个离开等待队列的线程

        {

            waiting_mtx = (size_t)mtx;

            //将cv->waiting_mtx的值设置为0

            acq_mtx_succ = rt_atomic_compare_exchange_strong(&cv->waiting_mtx,

                                                      &waiting_mtx, 0);

        }

        //重新获取互斥锁

        acq_mtx_succ = rt_mutex_take(mtx, RT_WAITING_FOREVER);

    }


    return rc;

}

```

## 唤醒

-`rt_condvar_signal`

```c

/* to avoid spurious wakeups */

if (rt_atomic_load(&cv->waiters_cnt) > 0)

    rt_wqueue_wakeup(&cv->event, 0);


cv->event.flag = 0;

```

-`rt_condvar_broadcast`

```c

/* to avoid spurious wakeups */

if (rt_atomic_load(&cv->waiters_cnt) > 0)

    rt_wqueue_wakeup_all(&cv->event, 0);


cv->event.flag = 0;

```

