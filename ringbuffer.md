---
title: ringbuffer
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: ea1e9b9f
date: 2025-10-03 09:44:52
---
# ringbuffer

- buffer_ptr 是指向缓冲区的指针，buffer_size 是缓冲区的大小，read_index 是读索引，write_index 是写索引，而 read_mirror 和 write_mirror 可以理解为一种镜像值，每次向缓冲区写入数据，碰到缓冲区末尾时，切换到另一个镜像的缓冲区头部写入剩余数据。这种镜像操作可用于判断缓冲区内数据是满还是空。

> 等于是把缓冲区回绕了看做为另一个缓冲区,通过镜像值来判断缓冲区的状态,当前读写指针是否进入到另一个缓冲区中;

- 当 write_index == read_index 且 read_mirror == write_mirror 时，缓冲区内数据为空。
- 当 write_index == read_index 且 read_mirror != write_mirror 时，缓冲区内数据已满。
- 若是没有上述镜像值，我们就没有办法区分缓冲区空和缓冲区满这两种情况。
- 注意：RT-Thread 的 ringbuffer 组件并未提供线程阻塞的功能，因此 ringbuffer 本质上是一个全局共享的对象，多线程使用时注意使用互斥锁保护。

## 写入

```c

//无需翻转镜像,空间足够写入

if (rb->buffer_size - rb->write_index > length)

{

    rt_memcpy(&rb->buffer_ptr[rb->write_index], ptr, length);

    rb->write_index += length;

    return length;

}

//尾部空间填满

rt_memcpy(&rb->buffer_ptr[rb->write_index],

            &ptr[0],

            rb->buffer_size - rb->write_index);

//剩余的填入头部

rt_memcpy(&rb->buffer_ptr[0],

            &ptr[rb->buffer_size - rb->write_index],

            length - (rb->buffer_size - rb->write_index));


//需要翻转镜像

rb->write_mirror = ~rb->write_mirror;

rb->write_index = length - (rb->buffer_size - rb->write_index);

```

## 读取

```c

//无需翻转镜像,数据足够读取

if (rb->buffer_size - rb->read_index > length)

{

    rt_memcpy(ptr, &rb->buffer_ptr[rb->read_index], length);

    rb->read_index += length;

    return length;

}

//尾部数据读取

rt_memcpy(&ptr[0],

            &rb->buffer_ptr[rb->read_index],

            rb->buffer_size - rb->read_index);

//剩余数据读取

rt_memcpy(&ptr[rb->buffer_size - rb->read_index],

            &rb->buffer_ptr[0],

            length - (rb->buffer_size - rb->read_index));


//需要翻转镜像

rb->read_mirror = ~rb->read_mirror;

rb->read_index = length - (rb->buffer_size - rb->read_index);

```

## 判断数据长度及状态

```c

rt_size_trt_ringbuffer_data_len(struct rt_ringbuffer *rb)

{

    switch (rt_ringbuffer_status(rb))

    {

    case RT_RINGBUFFER_EMPTY:

        return0;

    case RT_RINGBUFFER_FULL:

        returnrb->buffer_size;

    case RT_RINGBUFFER_HALFFULL:

    default:

    {

        rt_size_t wi = rb->write_index, ri = rb->read_index;


        if (wi > ri)

            return wi - ri;

        else

            returnrb->buffer_size - (ri - wi);

    }

    }

}

```

```c

rt_inline enum rt_ringbuffer_state rt_ringbuffer_status(struct rt_ringbuffer *rb)

{

    if (rb->read_index == rb->write_index)

    {

        if (rb->read_mirror == rb->write_mirror)

            return RT_RINGBUFFER_EMPTY;

        else

            return RT_RINGBUFFER_FULL;

    }

    return RT_RINGBUFFER_HALFFULL;

}

```

