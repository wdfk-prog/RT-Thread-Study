---
title: RTC
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: a17babb6
date: 2025-10-03 09:44:51
---
# RTC

## RTC驱动

1.`rt_hw_rtc_register`注册RTC设备

2. 实现RTC设备的操作函数
3. 提供控制命令

```c

        case RT_DEVICE_CTRL_RTC_GET_TIME:

            ret = TRY_DO_RTC_FUNC(rtc_device, get_secs, args);

            break;

        case RT_DEVICE_CTRL_RTC_SET_TIME:

            ret = TRY_DO_RTC_FUNC(rtc_device, set_secs, args);

            break;

        case RT_DEVICE_CTRL_RTC_GET_TIMEVAL:

            ret = TRY_DO_RTC_FUNC(rtc_device, get_timeval, args);

            break;

        case RT_DEVICE_CTRL_RTC_SET_TIMEVAL:

            ret = TRY_DO_RTC_FUNC(rtc_device, set_timeval, args);

            break;

        case RT_DEVICE_CTRL_RTC_GET_ALARM:

            ret = TRY_DO_RTC_FUNC(rtc_device, get_alarm, args);

            break;

        case RT_DEVICE_CTRL_RTC_SET_ALARM:

            ret = TRY_DO_RTC_FUNC(rtc_device, set_alarm, args);

            break;

```

## 软件RTC

1. 使用 `rt_tick_get`获取时间

## alarm模块

alarm 闹钟功能是基于 RTC 设备实现的，根据用户设定的闹钟时间，当时间到时触发 alarm 中断，执行闹钟事件，在硬件上 RTC 提供的 Alarm 是有限的，RT-Thread 将 Alarm 在软件层次上封装成了一个组件，原理上可以实现无限个闹钟，但每个闹钟只有最后一次设定有效

各项操作加锁保护

### 初始化

1. 初始化链表,互斥量,事件
2. 创建alarm线程

```c

    rt_list_init(&container->head);

    rt_mutex_init(&container->mutex, "alarm", RT_IPC_FLAG_FIFO);

    rt_event_init(&container->event, "alarm", RT_IPC_FLAG_FIFO);


```c

    rt_list_init(&container->head);

    rt_mutex_init(&container->mutex, "alarm", RT_IPC_FLAG_FIFO);

    rt_event_init(&container->event, "alarm", RT_IPC_FLAG_FIFO);


```c

struct rt_alarm_container

{

    rt_list_t head;

    struct rt_mutex mutex;

    struct rt_event event;

    struct rt_alarm *current;

};

```

3.`rt_alarmsvc_thread_init`线程中阻塞接收事件,唤醒执行 `alarm_update`

4. 使用 `rt_alarm_update`发生事件

### create

1. 创建alarm对象,并初始化
2. 初始化alarm的链表
3. 注册唤醒方式及时间
4. 插入到container链表

```c

struct rt_alarm_setup

{

    rt_uint32_t flag;                /* alarm flag */

    struct tm wktime;                /* when will the alarm wake up user */

};

```

### start

1.`alarm_setup` 设置唤醒时间

- 获取当前时间,转成格林威治时间

2.`alarm_set` 设置alarm对象

- container没有当前alarm对象,则设置当前alarm对象
- container有当前alarm对象,则根据当前时间与当前alarm对象时间和设置的alarm对象时间执行比较,设置container当前alarm对象.

```c

    sec_now = alarm_mkdaysec(&now);

    sec_old = alarm_mkdaysec(&_container.current->wktime);

    sec_new = alarm_mkdaysec(&alarm->wktime);

    //sec_now ---- sec_new ---- sec_old

    if ((sec_new < sec_old) && (sec_new > sec_now))

    {

        ret = alarm_set(alarm);

    }

    //sec_old ---- sec_now ---- sec_new

    elseif ((sec_new > sec_now) && (sec_old < sec_now))

    {

        ret = alarm_set(alarm);

    }

    //sec_new ---- sec_old ---- sec_now

    elseif ((sec_new < sec_old) && (sec_old < sec_now))

    {

        ret = alarm_set(alarm);

    }

    /* sec_old ---- sec_new ---- sec_now

     * sec_now ---- sec_old ---- sec_new

     * sec_new ---- sec_now ---- sec_old

     */

    else

    {

        ret = RT_EOK;

        goto _exit;

    }

```

### alarm_wakeup

1. 根据模式执行判断,进而唤醒操作

### alarm_update

1. 获取当前时间
2. 检查container链表是否为空

- 不为空,循环遍历链表,执行 `alarm_wakeup`

3. 再次检查链表,计算下一个alarm的时间并设置

## STM32 HAL RTC

### 初始化 UTIL_TIMER_Init

1. 链表初始化

```c

/**

  * @brief Timers list head pointer

  *

  */

staticUTIL_TIMER_Object_t *TimerListHead = NULL;

```

2. 调用 `InitTimer`初始化定时器

### Stop

1. 停止的是当前定时器对象

```c

    if( TimerListHead == TimerObject ) /* Stop the Head */

    {

        TimerListHead->IsPending = 0;

        //链表具体下一个对象

        if( TimerListHead->Next != NULL )

        {

            //链表头指向下一个对象,并设置超时时间

            TimerListHead = TimerListHead->Next;

            TimerSetTimeout( TimerListHead );

        }

        else

        {

            //停止定时器

            UTIL_TimerDriver.StopTimerEvt( );

            TimerListHead = NULL;

        }

    }

```

2. 停止的是非当前定时器对象

- 先找到当前定时器对象
- 从定时器链表中删除当前定时器对象

```c

    while( cur != NULL )

    {

        if( cur == TimerObject )

        {

            if( cur->Next != NULL )

            {

                cur = cur->Next;

                prev->Next = cur;

            }

            else

            {

                cur = NULL;

                prev->Next = cur;

            }

            break;

        }

        else

        {

            prev = cur;

            cur = cur->Next;

        }

    }

```

### Start

1. 定时器链表为空,则设置当前定时器对象为链表头

```c

    if( TimerListHead == NULL )

    {

      UTIL_TimerDriver.SetTimerContext();

      TimerInsertNewHeadTimer( TimerObject ); /* insert a timeout at now+obj->Timestamp */

    }

```

2. 计算唤醒时间并插入定时器链表中

```c

    elapsedTime = UTIL_TimerDriver.GetTimerElapsedTime( );

    TimerObject->Timestamp += elapsedTime;

    //时间小于链表头时间,则插入链表头

    if( TimerObject->Timestamp < TimerListHead->Timestamp )

    {

        TimerInsertNewHeadTimer( TimerObject);

    }

    //插入链表合适的时间节点

    else

    {

        TimerInsertTimer( TimerObject);

    }

```

3. TimerInsertNewHeadTimer

- 设置当前定时器对象为链表头
- 设置超时时间

4. TimerInsertTimer
5. 判断插入定时器与链表中节点的时间大小
6. 找到合适的位置插入
7. 没找到插入尾部

### 中断回调

```c

voidHAL_RTC_AlarmAEventCallback(RTC_HandleTypeDef *hrtc)

{

    UTIL_TIMER_IRQ_Handler();

}

```

1. 计算上一次唤醒时间与当前时间的差值
2. 遍历定时器链表,找到超时的定时器对象

- 超时设置timestamp为0
- 没超时,设置timestamp为超时时间减去差值

3. 执行超时回调,并更新链表

```c

    /* Execute expired timer and update the list */

    while ((TimerListHead != NULL) && ((TimerListHead->Timestamp == 0U) 

    // 防止中断过程中RTC时间增加导致错误未执行

    || (TimerListHead->Timestamp < UTIL_TimerDriver.GetTimerElapsedTime(  ))))

    {

        cur = TimerListHead;

        TimerListHead = TimerListHead->Next;

        cur->IsPending = 0;

        cur->IsRunning = 0;

        cur->Callback(cur->argument);

        if(( cur->Mode == UTIL_TIMER_PERIODIC) && (cur->IsReloadStopped == 0U))

        {

            (void)UTIL_TIMER_Start(cur);

        }

    }

```

4. 启动下一个 TimerListHead（如果它存在并且不是挂起的）

### TIMER_IF_Init

```c

UTIL_TIMER_Status_tTIMER_IF_Init(void)

{

    __HAL_RCC_RTC_ENABLE( );  // 使能RTC时钟

    HAL_RTC_Init( &RtcHandle );  // 初始化RTC

    if(!(g_rcc_csr & 0xf0000000)) {  // 如果备份寄存器的复位标志位未设置

        HAL_RTC_SetDate( &RtcHandle, &date, RTC_FORMAT_BIN );  // 设置RTC日期

        HAL_RTC_SetTime( &RtcHandle, &time, RTC_FORMAT_BIN );  // 设置RTC时间

    }

    HAL_RTCEx_EnableBypassShadow( &RtcHandle );  // 使能直接读取日历寄存器（不通过影子寄存器）

    HAL_NVIC_SetPriority( RTC_Alarm_IRQn, 1, 0 );  // 设置RTC闹钟中断的优先级

    HAL_NVIC_EnableIRQ( RTC_Alarm_IRQn );  // 使能RTC闹钟中断


    // Init alarm.

    HAL_RTC_DeactivateAlarm( &RtcHandle, RTC_ALARM_A );  // 关闭RTC闹钟A


    TIMER_IF_SetTimerContext( );  // 设置定时器上下文

}


```

### TIMER_IF_StartTimer

1. 停止定时器
2. 计算 `RTC_AlarmStructure`
3. 设置闹钟 `HAL_RTC_SetAlarm_IT( &RtcHandle, &RtcAlarm, RTC_FORMAT_BIN );`

### TIMER_IF_StopTimer

```c

  // Disable the Alarm A interrupt

  HAL_RTC_DeactivateAlarm( &RtcHandle, RTC_ALARM_A );


  // Clear RTC Alarm Flag

  __HAL_RTC_ALARM_CLEAR_FLAG( &RtcHandle, RTC_FLAG_ALRAF );

```

### TIMER_IF_SetTimerContext

- 获取日历值并写入 `RtcTimerContext`

### HAL_RTC_AlarmIRQHandler

```c

/**

  * @brief  Handle Alarm interrupt request.

  * @param  hrtc RTC handle

  * @retval None

  */

voidHAL_RTC_AlarmIRQHandler(RTC_HandleTypeDef *hrtc)

{

  uint32_t tmp = READ_REG(RTC->MISR) & READ_REG(hrtc->IsEnabled.RtcFeatures);


  if ((tmp & RTC_MISR_ALRAMF) != 0U)

  {

    /* Clear the AlarmA interrupt pending bit */

    WRITE_REG(RTC->SCR, RTC_SCR_CALRAF);

    HAL_RTC_AlarmAEventCallback(hrtc);

  }


  if ((tmp & RTC_MISR_ALRBMF) != 0U)

  {

    /* Clear the AlarmB interrupt pending bit */

    WRITE_REG(RTC->SCR, RTC_SCR_CALRBF);

    HAL_RTCEx_AlarmBEventCallback(hrtc);

  }


  /* Change RTC state */

  hrtc->State = HAL_RTC_STATE_READY;

}

```

