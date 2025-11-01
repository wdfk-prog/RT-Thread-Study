---
title: CAN驱动
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: afef3039
date: 2025-10-03 09:44:51
---
# CAN驱动

## CAN驱动框架

### CAN初始化

-`rt_hw_can_register`注册CAN设备,并初始化互斥量

-`rt_timer_init`初始化CAN定时器,注册定时器回调函数 `cantimeout`

### 初始化&&配置

1. RT_CAN_CMD_SET_PRIV

```c

if (can->config.privmode)

            {

                for (i = 0;  i < can->config.sndboxnumber; i++)

                {

                    level = rt_hw_interrupt_disable();

                    if(rt_list_isempty(&tx_fifo->buffer[i].list))

                    {

                        rt_sem_release(&(tx_fifo->sem));

                    }

                    else

                    {

                        rt_list_remove(&tx_fifo->buffer[i].list);

                    }

                    rt_hw_interrupt_enable(level);

                }


            }

            else

            {

                for (i = 0;  i < can->config.sndboxnumber; i++)

                {

                    level = rt_hw_interrupt_disable();

                    if (tx_fifo->buffer[i].result == RT_CAN_SND_RESULT_OK)

                    {

                        rt_list_insert_before(&tx_fifo->freelist, &tx_fifo->buffer[i].list);

                    }

                    rt_hw_interrupt_enable(level);

                }

            }

        }

```

2. RT_CAN_CMD_SET_FILTER

```c

    //设置过滤器 激活

    if (pfilter->actived)

    {

        while (count)

        {

            //过滤器的bank组号在最大值内

            if (pitem->hdr_bank >= can->config.maxhdr || pitem->hdr_bank < 0)

            {

                count--;

                pitem++;

                continue;

            }


            level = rt_hw_interrupt_disable();

            //过滤器未连接,则连接;初始化链表

            if (!can->hdr[pitem->hdr_bank].connected)

            {

                rt_hw_interrupt_enable(level);

                rt_memcpy(&can->hdr[pitem->hdr_bank].filter, pitem,

                            sizeof(struct rt_can_filter_item));

                level = rt_hw_interrupt_disable();

                can->hdr[pitem->hdr_bank].connected = 1;

                can->hdr[pitem->hdr_bank].msgs = 0;

                rt_list_init(&can->hdr[pitem->hdr_bank].list);

            }

            rt_hw_interrupt_enable(level);


            count--;

            pitem++;

        }

    }

    else

    {

        //设置过滤器 未激活

        while (count)

        {

            if (pitem->hdr_bank >= can->config.maxhdr || pitem->hdr_bank < 0)

            {

                count--;

                pitem++;

                continue;

            }

            level = rt_hw_interrupt_disable();

            //移除这个过滤器

            if (can->hdr[pitem->hdr_bank].connected)

            {

                can->hdr[pitem->hdr_bank].connected = 0;

                can->hdr[pitem->hdr_bank].msgs = 0;

                if (!rt_list_isempty(&can->hdr[pitem->hdr_bank].list))

                {

                    rt_list_remove(can->hdr[pitem->hdr_bank].list.next);

                }

                rt_hw_interrupt_enable(level);

                rt_memset(&can->hdr[pitem->hdr_bank].filter, 0,

                            sizeof(struct rt_can_filter_item));

            }

            else

            {

                rt_hw_interrupt_enable(level);

            }

            count--;

            pitem++;

        }

    }

```

### open

1. RX

- 采用malloc初始化fifo缓冲区

```c

struct rt_can_rx_fifo

{

    /* software fifo */

    struct rt_can_msg_list *buffer;

    rt_uint32_t freenumbers;

    struct rt_list_node freelist;

    struct rt_list_node uselist;

};

```

- 将每个rt_fifo消息插入free链表中;
- 初始化每个rt_fifo消息的硬件过滤链表
- 配置RX中断

2. TX

- 采用malloc初始化fifo缓冲区

```c

struct rt_can_tx_fifo

{

    struct rt_can_sndbxinx_list *buffer;

    struct rt_semaphore sem;

    struct rt_list_node freelist;

};

```

- 将每个rt_fifo消息插入free链表中;并初始化完成量
- 初始化信号量

3. 硬件过滤表初始化

- malloc初始化硬件过滤表
- 初始化HDR链表

4. 开启can定时器

### close

1. 关闭CAN定时器
2. free hdr分配

### write

1. _can_int_tx

- 互斥量加锁
- 从free链表中取出一个rt_fifo消息并从链表中移除;确保这个消息是安全的发送
- 执行发送操作
- 发送失败,则重新插入free链表
- 发送成功,再次检测是否被插入发送链表,如果是则移除;然后重新插入free链表
- 互斥量解锁
- 计算发送包数和失败包数

```c

    while (msgs)

    {

        rt_base_t level;

        rt_uint32_t no;

        rt_uint32_t result;

        struct rt_can_sndbxinx_list *tx_tosnd = RT_NULL;

        //互斥上锁

        rt_mutex_take(&(tx_fifo->mutex), RT_WAITING_FOREVER);

        level = rt_hw_interrupt_disable();

        tx_tosnd = rt_list_entry(tx_fifo->freelist.next, struct rt_can_sndbxinx_list, list);

        RT_ASSERT(tx_tosnd != RT_NULL);

        //从free链表移除当前发送消息

        rt_list_remove(&tx_tosnd->list);

        rt_hw_interrupt_enable(level);

        //计算发送的消息数

        no = ((rt_ubase_t)tx_tosnd - (rt_ubase_t)tx_fifo->buffer) / sizeof(struct rt_can_sndbxinx_list);

        tx_tosnd->result = RT_CAN_SND_RESULT_WAIT;

        //初始化完成量

        rt_completion_init(&tx_tosnd->completion);

        //发送消息

        if (can->ops->sendmsg(can, data, no) != RT_EOK)

        {

            /* send failed. */

            level = rt_hw_interrupt_disable();

            //发送失败,将消息插入free链表

            rt_list_insert_before(&tx_fifo->freelist, &tx_tosnd->list);

            rt_hw_interrupt_enable(level);

            //互斥解锁

            rt_mutex_release(&(tx_fifo->mutex));

            goto err_ret;

        }


        can->status.sndchange = 1;

        //等待发送完成

        rt_completion_wait(&(tx_tosnd->completion), RT_WAITING_FOREVER);


        level = rt_hw_interrupt_disable();

        result = tx_tosnd->result;

        //再次检查,如果又被加入发送链表,则已经发送过就直接移除

        if (!rt_list_isempty(&tx_tosnd->list))

        {

            rt_list_remove(&tx_tosnd->list);

        }

        //发送完成,将消息插入free链表

        rt_list_insert_before(&tx_fifo->freelist, &tx_tosnd->list);

        rt_hw_interrupt_enable(level);

        rt_mutex_release(&(tx_fifo->mutex));


        if (result == RT_CAN_SND_RESULT_OK)

        {

            level = rt_hw_interrupt_disable();

            //发送包数++

            can->status.sndpkg++;

            rt_hw_interrupt_enable(level);


            data ++;

            msgs -= sizeof(struct rt_can_msg);

            if (!msgs) break;

        }

        else

        {

err_ret:

            level = rt_hw_interrupt_disable();

            //发送失败包数++

            can->status.dropedsndpkg++;

            rt_hw_interrupt_enable(level);

            break;

        }

    }

```

2. _can_int_tx_priv

- 不知道,没用过

### read

1. 判断硬件过滤表不为空

- 取出消息,移除消息出消息链表

2. 判断硬件过滤表为空

- userlist链表不为空,则取出消息,移除消息出消息链表
- 没数据则退出

3. 判断listmsg有取到消息,拷贝消息到用户空间

- 将该消息插入free链表

4.msgs--;msgs为0,则退出

0. 接收中断

-`RT_CAN_EVENT_RXOF_IND`

1. 错误接收数据++

-`RT_CAN_EVENT_RX_IND`

1. 接收数据++
2. 从freelist链表中取出一个消息放入,并移除链表,移除hdr链表
3. 否则从uselist链表中取出一个消息放入,并移除链表,移除hdr链表
4. 拷贝消息到用户空间,插入到uselist链表
5. hdr 有对应的index,这插入hdr链表
6. 执行对应的hdr回调或者用户回调

## STM32 CAN 硬件

