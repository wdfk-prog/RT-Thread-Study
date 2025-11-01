---
title: completion
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: 38d6377e
date: 2025-10-03 09:44:51
---
# completion

- completion 可以称之为完成量，是一种轻量级的线程间（IPC）同步机制
- 完成量和信号量对比

信号量是一种非常灵活的同步方式，可以运用在多种场合中。形成锁、同步、资源计数等关系，也能方便的用于线程与线程、中断与线程间的同步中。

完成量，是一种更加轻型的线程间同步的一种实现，可以理解为轻量级的二值信号，可以用于线程和线程间同步，也可以用于线程和中断之间的同步。

完成量不支持在某个线程中调用 rt_completion_wait，还未唤醒退出时，在另一个线程中调用该函数。

注意：当完成量应用于线程和中断之间的同步时，中断函数中只能调用 rt_completion_done 接口，而不能调用 rt_completion_wait 接口，因为 wait 接口是阻塞型接口，不可以在中断函数中调用

```c

/**

 * Completion - A tiny & rapid IPC primitive for resource-constrained scenarios

 *

 * It's an IPC using one CPU word with the encoding:

 *

 * BIT      | MAX-1 ----------------- 1 |       0        |

 * CONTENT  |   suspended_thread & ~1   | completed flag |

 */


struct rt_completion

{

    /* suspended thread, and completed flag */

    rt_atomic_t susp_thread_n_flag;

};

```

## 初始化

- thread在等待时传入,初始化时不需要传入

```c

completion->susp_thread_n_flag = RT_COMPLETION_NEW_STAT(RT_NULL, RT_UNCOMPLETED);

```

## 完成

1. 当前已经是完成状态,直接返回
2. 获取线程

-`RT_COMPLETION_THREAD(comp)` 这个宏的作用就是获取 `susp_thread_n_flag` 中的线程指针。它通过对 `susp_thread_n_flag 和 ~1` 进行位与操作（&），清除了最低位的标志位，剩下的就是线程指针。

```c

#define RT_COMPLETION_THREAD(comp) ((rt_thread_t)((comp)->susp_thread_n_flag&~1))


suspend_thread = RT_COMPLETION_THREAD(completion);

```

3. 唤醒线程
4. 设置完成状态 `RT_COMPLETED`

## 等待

1. 获取当前线程,需要阻塞时传入到flag中
2. 获取当前完成量的状态,不为 `RT_COMPLETED`则进行挂起

