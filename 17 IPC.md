# 17 IPC

## 17.1 共用函数

### 17.1.1 _ipc_object_init

- 初始化挂起链表

### 17.1.2 rt_susp_list_enqueue

- RT_IPC_FLAG_FIFO

  - 将线程插入到链表尾部
- RT_IPC_FLAG_PRIO

  - 将线程插入到链表中,按照优先级排序

## 17.2 信号量

- 用于同步,资源计数;一对一场合,一对多使用事件同步

### 17.2.1 获取&&阻塞

1. 信号值>0,信号量减1,返回OK
2. 信号值=0,线程挂起,等待信号量变为非0
3. 若有超时时间,则设置超时时间,否则一直等待
4. 超时时间将启动线程定时器,超时后,线程从挂起链表中移除,插入就绪链表中
5. 不可在中断中阻塞

### 17.2.2 释放&&唤醒

1. 挂起链表中有线程,将第一个线程从挂起链表中出队;线程需要调度
2. 无线程挂起,信号量加1
3. 可以在中断中释放信号量

## 17.3 互斥量

- 使用信号量会导致的另一个潜在问题是线程优先级翻转问题。所谓优先级翻转，即当一个高优先级线程试图通过信号量机制访问共享资源时，如果该信号量已被一低优先级线程持有，而这个低优先级线程在运行过程中可能又被其它一些中等优先级的线程抢占，因此造成高优先级线程被许多具有较低优先级的线程阻塞，实时性难以得到保证。
- 在 RT-Thread 操作系统中，互斥量可以解决优先级翻转问题，实现的是优先级继承协议 (Sha, 1990)。优先级继承是通过在线程 A 尝试获取共享资源而被挂起的期间内，将线程 C 的优先级提升到线程 A 的优先级别，从而解决优先级翻转引起的问题。这样能够防止 C（间接地防止 A）被 B 抢占，如下图所示。优先级继承是指，提高某个占有某种资源的低优先级线程的优先级，使之与所有等待该资源的线程中优先级最高的那个线程的优先级相等，然后执行，而当这个低优先级线程释放该资源时，优先级重新回到初始设定。因此，继承优先级的线程避免了系统资源被任何中间优先级的线程抢占。

> 注：在获得互斥量后，请尽快释放互斥量，并且在持有互斥量的过程中，不得再行更改持有互斥量线程的优先级，否则可能人为引入无界优先级反转的问题。

### 17.3.1 初始化&&剥离

- 剥离

  - 当前互斥量持有线程,

### 17.3.2 获取&&阻塞

0. 不可在中断中阻塞
1. 互斥量持有者是当前线程

- hold++ ,返回OK
- hold计数>=MAX_HOLD,返回错误

2. 没有线程持有互斥量,设置当前线程持有互斥量

- 如果上限优先级被修改,则更新线程优先级
- 将节点插入互斥量阻塞链表中

3. 互斥量持有者不是当前线程

- 将当前线程插入改签链表中
- 将线程中的挂起对象设置为此互斥体;
- 互斥量优先级 > 当前线程优先级 互斥量优先级继承此线程的优先级

> 注意RTT中 数值越小的优先级越高，0 为最高优先级。

- 当互斥量优先级 < 互斥量持有者优先级,则更新互斥量持有者的优先级;优先级继承协议

4. 超时时间设置则启动线程定时器,超时后,线程从挂起链表中移除,插入就绪链表中

5.进行线程调度

### 17.3.3 释放&&唤醒

1. 互斥量只能由所有者释放
2. hold = 0时

- 将互斥量挂起的第一个线程插入就绪链表中

## 17.4 事件

### 17.4.1 事件发送

1. 设置事件采用 OR 操作设置
2. 当前事件挂起线程不为空时,循环链表进行判断

- 满足条件,将线程从挂起链表中移除,插入就绪链表中

3. 可以在中断中发送事件

### 17.4.2 事件接收

0. 不可在中断中接收事件
1. 接收不到事件,线程挂起,等待事件

## 17.5 邮箱

### 17.5.1 邮箱发送

0. 有超时时间,不可在中断中发送
1. 邮箱未满,将消息插入到邮箱中
2. 邮箱满,线程挂起,等待邮箱有空间

- 其中从挂起到恢复时,计算经过的偏差时间,如果超过超时时间,则返回超时

### 17.5.2 紧急发送

1. 将消息插入上一次接收的位置,执行一次调度

### 17.5.3 邮箱接收

1. 邮箱为空

- 线程挂起,等待邮箱有消息
