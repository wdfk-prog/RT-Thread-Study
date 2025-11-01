---
title: ULOG
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: 3b4ed3d1
date: 2025-10-03 09:44:51
---
# ULOG

1. 标准输出
2. 过滤功能
3. 异步输出
4. 颜色功能
5. 后端支持

## 标准输出

### 初始化

```c

intulog_init(void)

{

    rt_mutex_init(&ulog.output_locker, "ulog", RT_IPC_FLAG_PRIO);

    ulog.output_lock_enabled = RT_TRUE;

    return0;

}

```

### ulog_output

1. 根据当前是否在中断中,判断使用的缓冲区
2. 上锁(线程环境互斥量,中断环境关闭中断,未初始化互斥量时使用 `ulog_voutput_recursion`)

3.`ulog_voutput_recursion`递归输出

```c

    /* If there is a recursion, we use a simple way */

    if ((ulog_voutput_recursion == RT_TRUE) && (hex_buf == RT_NULL))

    {

        rt_kprintf(format, args);

        if (newline == RT_TRUE)

        {

            rt_kprintf(ULOG_NEWLINE_SIGN);

        }

        output_unlock();

        return;

    }

```

4. ulog_formater 执行格式化
5. do_output 输出

### ulog_formater

1.`ulog_head_formater` 格式化插入头部信息

- 颜色, 时间, 报警级别, 标签, 线程名称

2.`ulog_tail_formater` 格式化插入尾部信息

### do_output

1. 线程环境,使用后端输出方式
2. 中断环境,仅使用控制台输出方式

我们不能确保所有后端都支持 ISR 上下文输出。因此仅当上下文为 ISR 时才使用 rt_kprintf

## 后端支持

```c

struct ulog_backend

{

    charname[RT_NAME_MAX];

    rt_bool_t support_color;

    rt_uint32_t out_level;

    void (*init)  (struct ulog_backend *backend);

    void (*output)(struct ulog_backend *backend, rt_uint32_t level, constchar *tag, rt_bool_t is_raw, constchar *log, rt_size_t len);

    void (*flush) (struct ulog_backend *backend);

    void (*deinit)(struct ulog_backend *backend);

    /* The filter will be call before output. It will return TRUE when the filter condition is math. */

    rt_bool_t (*filter)(struct ulog_backend *backend, rt_uint32_t level, constchar *tag, rt_bool_t is_raw, constchar *log, rt_size_t len);

    rt_slist_t list;

};

```

1. 初始化后端链表

```c

rt_slist_init(&ulog.backend_list);

```

2 注册后端,将注册后端节点插入到ULOG链表中

```c

rt_slist_append(&ulog.backend_list, &backend->list);

```

3. 卸载后端,将注册后端节点从ULOG链表中移除
4. ulog_output_to_all_backend

```c

staticvoidulog_output_to_all_backend(rt_uint32_tlevel, constchar *tag, rt_bool_tis_raw, constchar *log, rt_size_tlen)

{

    /* if there is no backend */

    if (!rt_slist_first(&ulog.backend_list))

    {

        rt_kputs(log);

        return;

    }


    /* output for all backends */

    for (node = rt_slist_first(&ulog.backend_list); node; node = rt_slist_next(node))

    {

        backend = rt_slist_entry(node, struct ulog_backend, list);

        if (backend->out_level < level)

        {

            continue;

        }

        if (backend->filter && backend->filter(backend, level, tag, is_raw, log, len) == RT_FALSE)

        {

            /* backend's filter is not match, so skip output */

            continue;

        }

        if (backend->support_color || is_raw)

        {

            backend->output(backend, level, tag, is_raw, log, len);

        }

        else

        {

            /* recalculate the log start address and log size when backend not supported color */

            rt_size_t color_info_len = 0, output_len = len;

            constchar *output_log = log;


            if (color_output_info[level] != RT_NULL)

                color_info_len = rt_strlen(color_output_info[level]);


            if (color_info_len)

            {

                rt_size_t color_hdr_len = rt_strlen(CSI_START) + color_info_len;


                output_log += color_hdr_len;

                output_len -= (color_hdr_len + (sizeof(CSI_END) - 1));

            }

            backend->output(backend, level, tag, is_raw, output_log, output_len);

        }

    }

}

```

## 过滤功能

```c

struct

{

    /* all tag's level filter */

    rt_slist_t tag_lvl_list;

    /* global filter level, tag and keyword */

    rt_uint32_t level;

    chartag[ULOG_FILTER_TAG_MAX_LEN + 1];

    charkeyword[ULOG_FILTER_KW_MAX_LEN + 1];

} filter;

```

1. 初始化链表
2. ulog_tag_lvl_filter_set

## 异步输出

```c

    rt_bool_t async_enabled;

    rt_rbb_t async_rbb;

    /* ringbuffer for log_raw function only */

    struct rt_ringbuffer *async_rb;

    rt_thread_t async_th;

    struct rt_semaphore async_notice;

```

1. 初始化

- 创建ringblock块缓冲区,创建信号量

```c

    /* async output ring block buffer */

    ulog.async_rbb = rt_rbb_create(RT_ALIGN(ULOG_ASYNC_OUTPUT_BUF_SIZE, RT_ALIGN_SIZE), ULOG_ASYNC_OUTPUT_STORE_LINES);

    rt_sem_init(&ulog.async_notice, "ulog", 0, RT_IPC_FLAG_FIFO);

```

- 创建线程

2. 日志输入

- RAW日志,创建ringbuffer

```c

/* log_buf_size contain the tail \0, which will lead discard follow char, so only put log_buf_size -1  */

rt_ringbuffer_put(ulog.async_rb, (constrt_uint8_t *)log_buf, (rt_uint16_t)log_buf_size - 1);

/* send a notice */

rt_sem_release(&ulog.async_notice);

```

- 非RAW日志,创建ringblock块缓冲区

```c

struct ulog_frame

{

    /* magic word is 0x10 ('lo') */

    rt_uint32_t magic:8;

    rt_uint32_t is_raw:1;

    rt_uint32_t log_len:23;

    rt_uint32_t level;

    constchar *log;

    constchar *tag;

};


/* allocate log frame */

log_blk = rt_rbb_blk_alloc(ulog.async_rbb, RT_ALIGN(sizeof(struct ulog_frame) + log_buf_size, RT_ALIGN_SIZE));

if (log_blk)

{

    /* package the log frame */

    log_frame = (ulog_frame_t) log_blk->buf;

    log_frame->magic = ULOG_FRAME_MAGIC;

    log_frame->is_raw = is_raw;

    log_frame->level = level;

    log_frame->log_len = log_len;

    log_frame->tag = tag;

    log_frame->log = (constchar *)log_blk->buf + sizeof(struct ulog_frame);

    /* copy log data */

    rt_strncpy((char *)(log_blk->buf + sizeof(struct ulog_frame)), log_buf, log_buf_size);

    /* put the block */

    rt_rbb_blk_put(log_blk);

    /* send a notice */

    rt_sem_release(&ulog.async_notice);

}

```

3. 异步输出线程

```c

rt_err_tulog_async_waiting_log(rt_int32_ttime)

{

    //释放所有等待的信号量

    rt_sem_control(&ulog.async_notice, RT_IPC_CMD_RESET, RT_NULL);

    returnrt_sem_take(&ulog.async_notice, time);

}



voidulog_async_output(void)

{

    rt_rbb_blk_t log_blk;

    ulog_frame_t log_frame;


    //获取日志块

    while ((log_blk = rt_rbb_blk_get(ulog.async_rbb)) != RT_NULL)

    {

        log_frame = (ulog_frame_t) log_blk->buf;

        //判断是否是日志帧

        if (log_frame->magic == ULOG_FRAME_MAGIC)

        {

            /* output to all backends */

            ulog_output_to_all_backend(log_frame->level, log_frame->tag, log_frame->is_raw, log_frame->log,

                    log_frame->log_len);

        }

        /* free the block */

        rt_rbb_blk_free(ulog.async_rbb, log_blk);

    }

    /* output the log_raw format log */

    if (ulog.async_rb)

    {

        rt_size_t log_len = rt_ringbuffer_data_len(ulog.async_rb);

        char *log = rt_malloc(log_len + 1);

        if (log)

        {

            rt_size_t len = rt_ringbuffer_get(ulog.async_rb, (rt_uint8_t *)log, (rt_uint16_t)log_len);

            log[log_len] = '\0';

            ulog_output_to_all_backend(LOG_LVL_DBG, "", RT_TRUE, log, len);

            rt_free(log);

        }

    }

}


staticvoidasync_output_thread_entry(void *param)

{

    ulog_async_output();


    while (1)

    {

        //阻塞等待日志输入

        ulog_async_waiting_log(RT_WAITING_FOREVER);

        while (1)

        {

            //获取日志

            ulog_async_output();

            //输出过程中有新日志输入,则继续输出

            if (ulog_async_waiting_log(RT_TICK_PER_SECOND * 2) == RT_EOK)

            {

                continue;

            }

            else

            {

                ulog_flush();

                break;

            }

        }

    }

}

```

## 文件后端

1. ulog_file_backend_output_with_buf

- 拷贝到缓冲区中,缓冲区未满保留;
- 直到缓冲区满了执行flush操作

```c

    while (len)

    {

        /* free space length */

        free_len = buf_ptr_end - be->buf_ptr_now;

        /* copy the log to the mem buffer */

        if (len > free_len)

        {

            copy_len = free_len;

        }

        else

        {

            copy_len = len;

        }

        rt_memcpy(be->buf_ptr_now, log, copy_len);

        /* update data pos */

        be->buf_ptr_now += copy_len;

        len -= copy_len;

        log += copy_len;


        RT_ASSERT(be->buf_ptr_now <= buf_ptr_end);

        /* check the log buffer remain size */

        if (buf_ptr_end == be->buf_ptr_now)

        {

            ulog_file_backend_flush_with_buf(backend);

            if (buf_ptr_end == be->buf_ptr_now)

            {

                /* There is no space, indicating that the data cannot be refreshed

                   to the back end of the file Discard data and exit directly */

                break;

            }

        }

    }

```

2. ulog_file_backend_flush_with_buf

```c

staticvoidulog_file_backend_flush_with_buf(struct ulog_backend *backend)

{

    struct ulog_file_be *be = (struct ulog_file_be *) backend;

    rt_size_t file_size = 0, write_size = 0;


    if (be->enable == RT_FALSE || be->buf_ptr_now == be->file_buf)

    {

        return;

    }

    if (be->cur_log_file_fd < 0)

    {

        /* check log file directory  */

        if (access(be->cur_log_dir_path, F_OK) < 0)

        {

            mkdir(be->cur_log_dir_path, 0);

        }

        /* open file */

        rt_snprintf(be->cur_log_file_path, ULOG_FILE_PATH_LEN, "%s/%s.log", be->cur_log_dir_path, be->parent.name);

        be->cur_log_file_fd = open(be->cur_log_file_path, O_CREAT | O_RDWR | O_APPEND);

        if (be->cur_log_file_fd < 0)

        {

            rt_kprintf("ulog file(%s) open failed.", be->cur_log_file_path);

            return;

        }

    }


    file_size = lseek(be->cur_log_file_fd, 0, SEEK_END);

    //文件大小大于最大值,则执行文件切换

    if (file_size >= (be->file_max_size - be->buf_size * 2))

    {

        if (!ulog_file_rotate(be))

        {

            return;

        }

    }


    write_size = (rt_size_t)(be->buf_ptr_now - be->file_buf);

    /* write to the file */

    if (write(be->cur_log_file_fd, be->file_buf, write_size) != write_size)

    {

        return;

    }

    /* flush file cache */

    fsync(be->cur_log_file_fd);


    /* point be->buf_ptr_now at the head of be->file_buf[be->buf_size] */

    be->buf_ptr_now = be->file_buf;

}

```

3. ulog_file_rotate

