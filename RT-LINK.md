---
title: RT-LINK
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: a6152ded
date: 2025-10-03 09:44:51
---
# RT-LINK

## service attach&detach

```c

struct rt_link_service

{

    rt_int32_t timeout_tx;

    void (*send_cb)(struct rt_link_service *service, void *buffer);

    void (*recv_cb)(struct rt_link_service *service, void *data, rt_size_t size);

    void *user_data;


    rt_uint8_t flag;            /* Whether to use the CRC and ACK */

    rt_link_service_e service;

    rt_link_linkstate_e state;  /* channel link state */

    rt_link_err_e err;

};


rt_err_trt_link_service_attach(struct rt_link_service *serv)

{

    //初始化硬件

    rt_link_hw_init();

    //注册服务及其配置

    rt_link_scb->service[serv->service] = serv;

    //如果有其它服务已经存在,帧序号进行替换

    if (rt_slist_next(&rt_link_scb->tx_data_slist))

    {

        struct rt_link_frame *frame = rt_container_of(rt_slist_next(&rt_link_scb->tx_data_slist), struct rt_link_frame, slist);

        seq = frame->head.sequence;

    }

    serv->state = RT_LINK_INIT;

    //发送握手帧

    rt_link_command_frame_send(serv->service, seq, RT_LINK_HANDSHAKE_FRAME, rt_link_scb->rx_record.rx_seq);

    return RT_EOK;

}


rt_err_trt_link_service_detach(struct rt_link_service *serv)

{

    //发送断开帧

    rt_link_command_frame_send(serv->service,

                               rt_link_scb->tx_seq,

                               RT_LINK_DETACH_FRAME,

                               rt_link_scb->rx_record.rx_seq);


    serv->state = RT_LINK_DISCONN;

    rt_link_scb->service[serv->service] = RT_NULL;

    return RT_EOK;

}

```

## frame send

- rt_link_send阻塞方式发送,发送事件通知线程执行数据发送;并且阻塞等待发送完成事件

```c

rt_size_trt_link_send(struct rt_link_service *service, constvoid *data, rt_size_tsize)

{

    //根据数据大小,计算帧数和帧类型

    if (size % RT_LINK_MAX_DATA_LENGTH == 0)

    {

        total = (rt_uint8_t)(size / RT_LINK_MAX_DATA_LENGTH);

    }

    else

    {

        total = (rt_uint8_t)(size / RT_LINK_MAX_DATA_LENGTH + 1);

    }

    do

    {

        /* 将帧附加到列表尾部 */

        rt_slist_append(&rt_link_scb->tx_data_slist, &send_frame->slist);

        index++;

    }while(total > index);


    /* 通知核心线程发送数据包 */

    rt_event_send(&rt_link_scb->event, RT_LINK_SEND_READY_EVENT);


    if (service->timeout_tx != RT_WAITING_NO)

    {

        /* 等待数据包发送结果 */

        rt_err_t ret = rt_event_recv(&rt_link_scb->sendevent, (0x01 << service->service),

                                     RT_EVENT_FLAG_OR | RT_EVENT_FLAG_CLEAR,

                                     service->timeout_tx, &recved);

        if (ret == -RT_ETIMEOUT)

        {

            service->err = RT_LINK_ETIMEOUT;

            send_len = 0;

        }

    }

}

```

```c

staticvoidrt_link_send_ready(void)

{

    rt_uint8_t seq = rt_link_scb->tx_seq;

    if (rt_slist_next(&rt_link_scb->tx_data_slist))

    {

        frame = rt_container_of(rt_slist_next(&rt_link_scb->tx_data_slist), struct rt_link_frame, slist);

    }


    if (rt_link_scb->state != RT_LINK_CONNECT)

    {

        rt_link_scb->state = RT_LINK_DISCONN;

        rt_link_command_frame_send(RT_LINK_SERVICE_RTLINK, seq,

                                   RT_LINK_HANDSHAKE_FRAME, rt_link_scb->rx_record.rx_seq);


        rt_int32_t timeout = 50;

        rt_timer_control(&rt_link_scb->sendtimer, RT_TIMER_CTRL_SET_TIME, &timeout);

        rt_timer_start(&rt_link_scb->sendtimer);

    }

    else

    {

        /* Avoid sending the first data frame multiple times */

        if ((frame != RT_NULL) && (frame->issent == RT_LINK_FRAME_NOSEND))

        {

            if (RT_EOK != rt_link_frame_send(&rt_link_scb->tx_data_slist))

            {

                rt_link_scb->state = RT_LINK_DISCONN;

                rt_link_service_send_finish(RT_LINK_EIO);

            }

        }

    }

}

```

## 线程处理

```c

voidrt_link_thread(void *parameter)

{

    rt_uint32_t recved = 0;

    while (1)

    {

        rt_event_recv(&rt_link_scb->event,

                      RT_LINK_READ_CHECK_EVENT |

                      RT_LINK_SEND_READY_EVENT  |

                      RT_LINK_SEND_TIMEOUT_EVENT |

                      RT_LINK_RECV_TIMEOUT_FRAME_EVENT |

                      RT_LINK_RECV_TIMEOUT_LONG_EVENT,

                      RT_EVENT_FLAG_OR | RT_EVENT_FLAG_CLEAR,

                      RT_WAITING_FOREVER,

                      &recved);


        if (recved & RT_LINK_READ_CHECK_EVENT)

        {

            rt_link_frame_check();

        }


        if (recved & RT_LINK_SEND_READY_EVENT)

        {

            rt_link_send_ready();

        }


        if (recved & RT_LINK_SEND_TIMEOUT_EVENT)

        {

            rt_link_send_timeout();

        }


        if (recved & RT_LINK_RECV_TIMEOUT_FRAME_EVENT)

        {

            rt_link_frame_recv_timeout();

        }


        if (recved & RT_LINK_RECV_TIMEOUT_LONG_EVENT)

        {

            rt_link_long_recv_timeout();

        }

    }

}

```

## RT_LINK_SEND_READY_EVENT 执行发送

```c

staticvoidrt_link_send_ready(void)

{

    struct rt_link_frame *frame = RT_NULL;

    rt_uint8_t seq = rt_link_scb->tx_seq;

    //获取TX帧

    if (rt_slist_next(&rt_link_scb->tx_data_slist))

    {

        frame = rt_container_of(rt_slist_next(&rt_link_scb->tx_data_slist), struct rt_link_frame, slist);

    }

    //连接状态不是连接状态,则发送握手帧

    if (rt_link_scb->state != RT_LINK_CONNECT)

    {

        rt_link_scb->state = RT_LINK_DISCONN;

        rt_link_command_frame_send(RT_LINK_SERVICE_RTLINK, seq,

                                   RT_LINK_HANDSHAKE_FRAME, rt_link_scb->rx_record.rx_seq);


        rt_int32_t timeout = 50;

        rt_timer_control(&rt_link_scb->sendtimer, RT_TIMER_CTRL_SET_TIME, &timeout);

        rt_timer_start(&rt_link_scb->sendtimer);

    }

    else

    {

        /* Avoid sending the first data frame multiple times */

        if ((frame != RT_NULL) && (frame->issent == RT_LINK_FRAME_NOSEND))

        {

            if (RT_EOK != rt_link_frame_send(&rt_link_scb->tx_data_slist))

            {

                //发送失败

                rt_link_scb->state = RT_LINK_DISCONN;

                rt_link_service_send_finish(RT_LINK_EIO);

            }

        }

    }

}


/* performs data transmission */

staticrt_err_trt_link_frame_send(rt_slist_t *slist)

{

    rt_uint8_t is_finish = RT_FALSE;

    struct rt_link_frame *frame = RT_NULL;

    rt_uint8_t send_max = RT_LINK_ACK_MAX;


    //发送链表中帧,一次性发送最多8帧

    do

    {

        /* get frame for send */

        frame = rt_container_of(slist, struct rt_link_frame, slist);

        slist = rt_slist_next(slist);


        if (frame_send(frame) == 0)

        {

            rt_link_scb->service[frame->head.service]->err = RT_LINK_EIO;

            goto __err;

        }

        frame->issent = RT_LINK_FRAME_SENT;

        if ((slist == RT_NULL) || (frame->index + 1 >= frame->total))

        {

            send_max = 0;

            is_finish = RT_TRUE;

        }

        else

        {

            send_max >>= 1;

        }

    }while (send_max);


    if ((is_finish) && (frame->head.ack == 0))

    {

        /* NACK frame send finish, remove after sending */

        rt_link_service_send_finish(RT_LINK_EOK);

        if (slist != RT_NULL)

        {

            LOG_D("Continue sending");

            //剩下的下次发送

            rt_event_send(&rt_link_scb->event, RT_LINK_SEND_READY_EVENT);

        }

    }

    else

    {

        //需要ACK,则启动ACK超时定时器

        rt_int32_t timeout = RT_LINK_SENT_FRAME_TIMEOUT;

        rt_timer_control(&rt_link_scb->sendtimer, RT_TIMER_CTRL_SET_TIME, &timeout);

        rt_timer_start(&rt_link_scb->sendtimer);

    }

    return RT_EOK;

__err:

    return -RT_ERROR;

}

```

## RT_LINK_SEND_TIMEOUT_EVENT 发送超时处理

1. 发送需要ACK,开启发送超时定时器
2. 握手帧发送,开启发送超时定时器
3. 超时回调

```c

staticvoidrt_link_sendtimer_callback(void *parameter)

{

    //超时次数

    rt_uint32_t count = (rt_uint32_t)rt_link_scb->sendtimer.parameter + 1;

    rt_link_scb->sendtimer.parameter = (void *)count;

    rt_event_send(&rt_link_scb->event, RT_LINK_SEND_TIMEOUT_EVENT);

}


staticvoidrt_link_send_timeout(void)

{

    LOG_D("send count(%d)", (rt_uint32_t)rt_link_scb->sendtimer.parameter);

    if ((rt_uint32_t)rt_link_scb->sendtimer.parameter >= 5)

    {

        rt_timer_stop(&rt_link_scb->sendtimer);

        LOG_W("Send timeout, please check the link status!");

        rt_link_scb->sendtimer.parameter = 0x00;

        //多次发送失败,执行接收长时间超时处理

        rt_link_service_send_finish(RT_LINK_ETIMEOUT);

    }

    else

    {

        //尝试重连

        if (rt_slist_next(&rt_link_scb->tx_data_slist))

        {

            struct rt_link_frame *frame = rt_container_of(rt_slist_next(&rt_link_scb->tx_data_slist), struct rt_link_frame, slist);

            frame->issent = RT_LINK_FRAME_NOSEND;

            rt_link_command_frame_send(RT_LINK_SERVICE_RTLINK,

                                       frame->head.sequence,

                                       RT_LINK_HANDSHAKE_FRAME,

                                       rt_link_scb->rx_record.rx_seq);

        }

    }

}

```

## RT_LINK_READ_CHECK_EVENT 接收检测并处理

1. 接收

- 初始化接收的FIFO缓冲区
- 接收后传入FIFO中
- 发送 `RT_LINK_READ_CHECK_EVENT`,由线程执行接收

2. 接收处理

```c

staticvoidrt_link_frame_check(void)

{

    staticstruct rt_link_frame receive_frame = {0};

    staticrt_link_frame_parse_t analysis_status = FIND_FRAME_HEAD;

    staticrt_uint8_t *data = RT_NULL;

    staticrt_uint16_t buff_len = RT_LINK_HEAD_LENGTH;


    struct rt_link_frame *send_frame = RT_NULL;

    rt_tick_t timeout = 0;

    rt_uint32_t temporary_crc = 0;


    rt_uint8_t offset = 0;

    rt_size_t recv_len = rt_link_hw_recv_len(rt_link_scb->rx_buffer);

    while (recv_len > 0)

    {

        switch (analysis_status)

        {

        //查找帧头,不断查找直到找到帧头

        case FIND_FRAME_HEAD:

        {

            break;

        }

        //解析帧头

        case PARSE_FRAME_HEAD:

        {

            if (receive_frame.head.extend)

            {

                buff_len += RT_LINK_EXTEND_LENGTH;

                analysis_status = PARSE_FRAME_EXTEND;

            }

            else

            {

                receive_frame.attribute = RT_LINK_SHORT_DATA_FRAME;

                analysis_status = PARSE_FRAME_SEQ;

            }

        }

        //解析帧扩展

        case PARSE_FRAME_EXTEND:

        {

            if (receive_frame.head.extend)

            {

                //没有接收完整,继续接收

                if (recv_len < buff_len)

                {

                    LOG_D("EXTEND: actual: %d, need: %d.", recv_len, buff_len);

                    /* should set timer, control receive frame timeout, one shot */

                    timeout = 50;

                    rt_timer_control(&rt_link_scb->recvtimer, RT_TIMER_CTRL_SET_TIME, &timeout);

                    rt_timer_start(&rt_link_scb->recvtimer);

                    return;

                }

                rt_timer_stop(&rt_link_scb->recvtimer);

            }

            analysis_status = PARSE_FRAME_SEQ;

        }

        //解析帧序列

        case PARSE_FRAME_SEQ:

        {

            switch (receive_frame.attribute)

            {

            case RT_LINK_CONFIRM_FRAME:

            case RT_LINK_RESEND_FRAME:

            {

                //检查发送和接收次数,不一致忽略

                break;

            }

            case RT_LINK_LONG_DATA_FRAME:

            case RT_LINK_SHORT_DATA_FRAME:

            case RT_LINK_SESSION_END:

            {

                //检查发送和接收次数,不一致忽略

            }

            case RT_LINK_HANDSHAKE_FRAME:

            case RT_LINK_DETACH_FRAME:

                analysis_status = HEADLE_FRAME_DATA;

                break;


            default:

                LOG_D("quick filter error frame.");

                goto __find_head;

            }

            buff_len += receive_frame.data_len;

            if (receive_frame.head.crc)

            {

                buff_len += RT_LINK_CRC_LENGTH;

                analysis_status = CHECK_FRAME_CRC;

            }

            else

            {

                analysis_status = HEADLE_FRAME_DATA;

            }

            /* fill real data point */

            receive_frame.real_data = data;

        }

        //检查CRC

        case CHECK_FRAME_CRC:

        {

            if (receive_frame.head.crc)

            {

            analysis_status = HEADLE_FRAME_DATA;

        }

        //处理数据

        case HEADLE_FRAME_DATA:

        {

            rt_timer_stop(&rt_link_scb->recvtimer);

            rt_link_hw_buffer_point_shift(&rt_link_scb->rx_buffer->read_point, buff_len);

            rt_link_parse_frame(&receive_frame);

            data = RT_NULL;

            buff_len = RT_LINK_HEAD_LENGTH;

            analysis_status = FIND_FRAME_HEAD;

            break;

        }


        default:

__find_head:

            LOG_D("to find head (%d)", analysis_status);

            rt_link_frame_stop_receive(&receive_frame);

            buff_len = RT_LINK_HEAD_LENGTH;

            analysis_status = FIND_FRAME_HEAD;

            break;

        }


        recv_len = rt_link_hw_recv_len(rt_link_scb->rx_buffer);

    }

}

```

## 接收超时与长数据接收超时

1. RT_LINK_RECV_TIMEOUT_FRAME_EVENT

- 接收帧超时，新的接收开始

2. RT_LINK_RECV_TIMEOUT_LONG_EVENT

```c

staticvoidrt_link_long_recv_timeout(void)

{

    if ((rt_uint32_t)rt_link_scb->longframetimer.parameter >= 5)

    {

        LOG_W("long package receive timeout");

        rt_link_scb->longframetimer.parameter = 0x00;

        _stop_recv_long();

        rt_timer_stop(&rt_link_scb->longframetimer);

    }

    else

    {

        rt_uint8_t total = rt_link_scb->rx_record.total;

        for (; total > 0; total--)

        {

            if (((rt_link_scb->rx_record.long_count >> (total - 1)) & 0x01) == 0x00)

            {

                /* resend command */

                rt_link_command_frame_send(RT_LINK_SERVICE_RTLINK,

                                           (rt_link_scb->rx_record.rx_seq + total),

                                           RT_LINK_RESEND_FRAME, RT_NULL);

            }

        }

    }

}

```

## 接收帧类型处理

- RT_LINK_RESEND_FRAME: 重发帧

1. 长数据接收超时处理时,立刻发送 `RT_LINK_RESEND_FRAME`帧要求重发;
2. 接收到 `RT_LINK_RESEND_FRAME`帧,找到对应序号的帧,重新发送;找不到结束会话

```c

    tem_list = rt_slist_first(&rt_link_scb->tx_data_slist);

    while (tem_list != RT_NULL)

    {

        find_frame = rt_container_of(tem_list, struct rt_link_frame, slist);

        if (find_frame->head.sequence == receive_frame->head.sequence)

        {

            LOG_D("resend frame(%d)", find_frame->head.sequence);

            frame_send(find_frame);

            break;

        }

        tem_list = tem_list->next;

    }


    if (tem_list == RT_NULL)

    {

        LOG_D("frame resent failed, can't find(%d).", receive_frame->head.sequence);

        rt_link_command_frame_send(receive_frame->head.service,

                                   receive_frame->head.sequence,

                                   RT_LINK_SESSION_END, RT_NULL);

    }

```

- RT_LINK_HANDSHAKE_FRAME: 握手帧

```c

staticrt_err_trt_link_handshake_handle(struct rt_link_frame *receive_frame)

{

    LOG_D("HANDSHAKE: seq(%d) param(%d)", receive_frame->head.sequence, receive_frame->extend.parameter);

    rt_link_scb->state = RT_LINK_CONNECT;

    /* sync requester tx seq, responder rx seq = requester tx seq */

    rt_link_scb->rx_record.rx_seq = receive_frame->head.sequence;

    /* sync requester rx seq, responder tx seq = requester rx seq */

    rt_link_scb->tx_seq = (rt_uint8_t)receive_frame->extend.parameter;


    if (rt_link_scb->service[receive_frame->head.service] != RT_NULL)

    {

        //发送确认帧

        rt_link_scb->service[receive_frame->head.service]->state = RT_LINK_CONNECT;

        rt_link_command_frame_send(receive_frame->head.service,

                                   receive_frame->head.sequence,

                                   RT_LINK_CONFIRM_FRAME, RT_NULL);

    }

    else

    {

        //发送断开帧

        rt_link_command_frame_send(receive_frame->head.service,

                                   receive_frame->head.sequence,

                                   RT_LINK_DETACH_FRAME, RT_NULL);

    }

    return RT_EOK;

}

```

- RT_LINK_SESSION_END: 结束帧
- 上下文变量复位

```c

staticrt_err_trt_link_session_end_handle(struct rt_link_frame *receive_frame)

{

    rt_link_frame_stop_receive(receive_frame);

    return RT_EOK;

}

```

- RT_LINK_DETACH_FRAME: 断开帧

1. 握手帧连接的是没有注册的服务,发送 `RT_LINK_DETACH_FRAME`断开帧
2. 主动断开,发送 `RT_LINK_DETACH_FRAME`断开帧

```c

staticrt_err_trt_link_detach_handle(struct rt_link_frame *receive_frame)

{

    if (rt_link_scb->service[receive_frame->head.service] != RT_NULL)

    {

        rt_link_scb->service[receive_frame->head.service]->state = RT_LINK_DISCONN;

    }

    return RT_EOK;

}

```

- RT_LINK_SHORT_DATA_FRAME: 短数据帧

1. 发送时,自动判断长度是否分包还是以短数据帧发送
2. 接收后执行copy,执行接收回调

- RT_LINK_LONG_DATA_FRAME:

```c

staticrt_err_trt_link_long_handle(struct rt_link_frame *receive_frame)

{

    if (rt_link_scb->rx_record.long_count == 0)

    {

        /* Receive this long package for the first time:

         * calculates the total number of frames,

         * requests space, and turns on the receive timer */

        _long_handle_first(receive_frame);

    }

    if (rt_link_scb->rx_record.total > 0)

    {

        /* Intermediate frame processing:

         * serial number repeated check,

         * receive completion check, reply to ACK */

        _long_handle_second(receive_frame);

    }

    receive_frame->real_data = RT_NULL;

    return RT_EOK;

}

```

- RT_LINK_CONFIRM_FRAME: ACK帧

```c

staticrt_err_trt_link_confirm_handle(struct rt_link_frame *receive_frame)

{

    staticstruct rt_link_frame *send_frame = RT_NULL;

    rt_slist_t *tem_list = RT_NULL;

    rt_uint16_t seq_offset = 0;

    LOG_D("confirm seq(%d) frame", receive_frame->head.sequence);


    rt_timer_stop(&rt_link_scb->sendtimer);


    if (rt_link_scb->service[receive_frame->head.service] != RT_NULL)

    {

        rt_link_scb->service[receive_frame->head.service]->state = RT_LINK_CONNECT;

    }


    if (rt_link_scb->state != RT_LINK_CONNECT)

    {

        /* The handshake success and resends the data frame */

        rt_link_scb->state = RT_LINK_CONNECT;

        if (rt_slist_first(&rt_link_scb->tx_data_slist))

        {

            rt_event_send(&rt_link_scb->event, RT_LINK_SEND_READY_EVENT);

        }

        return RT_EOK;

    }


    /* Check to see if the frame is send for confirm */

    tem_list = rt_slist_first(&rt_link_scb->tx_data_slist);

    if (tem_list == RT_NULL)

    {

        return -RT_ERROR;

    }

    send_frame = rt_container_of(tem_list, struct rt_link_frame, slist);

    seq_offset = rt_link_check_seq(receive_frame->head.sequence, send_frame->head.sequence);

    if (seq_offset <= send_frame->total)

    {

        rt_link_service_send_finish(RT_LINK_EOK);

        rt_link_scb->state = RT_LINK_CONNECT;


        tem_list = rt_slist_first(&rt_link_scb->tx_data_slist);

        if (tem_list != RT_NULL)

        {

            LOG_D("Continue sending");

            rt_event_send(&rt_link_scb->event, RT_LINK_SEND_READY_EVENT);

        }

    }

    return RT_EOK;

}

```

