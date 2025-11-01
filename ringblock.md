---
title: ringblock
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: 7cb92c08
date: 2025-10-03 09:44:52
---
# 环形缓冲块 ringblock

环形块状缓冲区简称为：rbb。与传统的环形缓冲区不同的是，rbb 是一个由很多不定长度的块组成的环形缓冲区，而传统的环形缓冲区是由很多个单字节的 char 组成。rbb 支持 零字节拷贝 。所以 rbb 非常适合用于生产者顺序 put 数据块，消费者顺序 get 数据块的场景，例如：DMA 传输，通信帧的接收与发送等等

ringblk: 是由 多个不同长度 的 block 组成的，ringbuff : 是由单字节的数据组成的。ringblk 每一个 block 有多少个字节可以由用户自己设定。

ringblk 支持零字节拷贝(不需要额外的 memcpy 操作)。所以 rbb 非常适合用于生产者顺序 put 数据块，消费者顺序 get 数据块的场景，例如：DMA 传输，通信帧的接收与发送等等。

## 初始化

1. 初始化块链表和释放链表
2. 对每一个块链表进行初始化,并插入到释放链表中

## PUT & GET 块

- put

```c

block->status = RT_RBB_BLK_PUT;

```

- get

1. 判断块链表为空,则返回NULL
2. 遍历链表,找到具有 `RT_RBB_BLK_PUT`状态的块,设置状态为 `RT_RBB_BLK_GET`,返回块指针

## 块释放

1. 从块链表总移除块,并插入到释放链表中

## rt_rbb_blk_queue_get

```c

//遍历块链表

for (; node; node = tmp, tmp = rt_slist_next(node))

{

    //// 如果下一个 block 为空

    if (!last_block)

    {

        // // 获取 list 节点上的结构体的地址

        last_block = rt_slist_entry(node, struct rt_rbb_blk, list);

        if (last_block->status == RT_RBB_BLK_PUT)

        {

            // 保存第一个 block

            blk_queue->blocks = last_block;

            blk_queue->blk_num = 0;

        }

        else

        {

            // 没有找到可用的 block

            last_block = RT_NULL;

            continue;

        }

    }

    else

    {

        block = rt_slist_entry(node, struct rt_rbb_blk, list);

        /*

            1.当前块没有放置状态

            2.最后一个块和当前块是不连续的

            3.data_total_size将超出范围

        */

        if (block->status != RT_RBB_BLK_PUT ||

                last_block->buf > block->buf ||

                data_total_size + block->size > queue_data_len)

        {

            break;

        }

        /* backup last block */

        last_block = block;

    }

    /* remove current block */

    data_total_size += last_block->size;

    last_block->status = RT_RBB_BLK_GET;

    blk_queue->blk_num++;

}

```

## rt_rbb_blk_alloc

```c

rt_rbb_blk_trt_rbb_blk_alloc(rt_rbb_trbb, rt_size_tblk_size)

{

    new_rbb = find_empty_blk_in_set(rbb); // 找到一个空闲块

    // 判断申请出来的块是不是在 最大范围之内

    if (rt_slist_len(&rbb->blk_list) < rbb->blk_max_num && new_rbb)

    {

        if (rt_slist_len(&rbb->blk_list) > 0) // 检查是不是第一次申请blk

        {   // 获取头节点的结构体起始地址

            head = rt_slist_first_entry(&rbb->blk_list, struct rt_rbb_blk, list);

            // 获取尾节点的结构体起始地址

            tail = rt_slist_tail_entry(&rbb->blk_list, struct rt_rbb_blk, list);

            if (head->buf <= tail->buf) // 头节点数据缓冲区的地址小于尾节点的数据缓存区的地址

            {

        /**

         *                      head                     tail

         * +--------------------------------------+-----------------+------------------+

         * |      empty2     | block1 |   block2  |      block3     |       empty1     |

         * +--------------------------------------+-----------------+------------------+

         *                            rbb->buf

         */

                // 求出空 block 的大小

                empty1 = (rbb->buf + rbb->buf_size) - (tail->buf + tail->size);

                empty2 = head->buf - rbb->buf;

                // 判断新的 block 可以存放的区域

                if (empty1 >= blk_size)

                { // 给 block 结构体赋值

                    rt_slist_append(&rbb->blk_list, &new_rbb->list);

                    new_rbb->status = RT_RBB_BLK_INITED;

                    new_rbb->buf = tail->buf + tail->size;

                    new_rbb->size = blk_size;

                }

                elseif (empty2 >= blk_size)

                {// 给 block 结构体赋值

                    rt_slist_append(&rbb->blk_list, &new_rbb->list);

                    new_rbb->status = RT_RBB_BLK_INITED;

                    new_rbb->buf = rbb->buf;

                    new_rbb->size = blk_size;

                }

                else

                {

                    /* no space */

                    new_rbb = NULL;

                }

            }

            else

            {

        /**

         *        tail                                              head

         * +----------------+-------------------------------------+--------+-----------+

         * |     block3     |                empty1               | block1 |  block2   |

         * +----------------+-------------------------------------+--------+-----------+

         *                            rbb->buf

         */

                // 获取空闲的空间

                empty1 = head->buf - (tail->buf + tail->size);

                // 判断剩余空间是否够本次的分配

                if (empty1 >= blk_size)

                {// 给 block 结构体赋值

                    rt_slist_append(&rbb->blk_list, &new_rbb->list);

                    new_rbb->status = RT_RBB_BLK_INITED;

                    new_rbb->buf = tail->buf + tail->size;

                    new_rbb->size = blk_size;

                }

                else

                {   /* no space */

                    new_rbb = NULL;

                }

            }

        }

        else

        {

            /* the list is empty */

            rt_slist_append(&rbb->blk_list, &new_rbb->list); // 把bew_rbb 链表插入到 rbb

            new_rbb->status = RT_RBB_BLK_INITED; // 修改状态为 已经初始化

            new_rbb->buf = rbb->buf; // 设置缓冲区

            new_rbb->size = blk_size;// 设置块大小

        }

    }

    else

    {

        new_rbb = NULL;

    }

    return new_rbb;

}

```

