---
title: PM电源管理
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: 386931f6
date: 2025-10-03 09:44:51
---
# PM电源管理

## 初始化

drv_pm_hw_init -> rt_system_pm_init

```c

    /* initialize timer mask */

    timer_mask = 1UL << PM_SLEEP_MODE_DEEP;


    /* when system power on, set default sleep modes */

    pm->modes[pm->sleep_mode] = 1;

    pm->module_status[PM_POWER_ID].req_status = 1;

    pm->run_mode   = RT_PM_DEFAULT_RUN_MODE;

```

## pm设备注册

```c

/**

 * Register a device with PM feature

 *

 * @paramdevice the device with PM feature

 * @paramops the PM ops for device

 */

voidrt_pm_device_register(struct rt_device *device, conststruct rt_device_pm_ops *ops)

{

    device_pm = (struct rt_device_pm *)RT_KERNEL_REALLOC(_pm.device_pm,

                (_pm.device_pm_number + 1) * sizeof(struct rt_device_pm));

    if (device_pm != RT_NULL)

    {

        _pm.device_pm = device_pm;

        _pm.device_pm[_pm.device_pm_number].device = device;

        _pm.device_pm[_pm.device_pm_number].ops    = ops;

        _pm.device_pm_number += 1;

    }

}


/**

 * Unregister device from PM manager.

 *

 * @paramdevice the device with PM feature

 */

voidrt_pm_device_unregister(struct rt_device *device)

{

    if (_pm.device_pm[index].device == device)

    {

        /* remove current entry */

        for (; index < _pm.device_pm_number - 1; index ++)

        {

            _pm.device_pm[index] = _pm.device_pm[index + 1];

        }


        _pm.device_pm[_pm.device_pm_number - 1].device = RT_NULL;

        _pm.device_pm[_pm.device_pm_number - 1].ops = RT_NULL;


        _pm.device_pm_number -= 1;

        /* break out and not touch memory */

        break;

    }

}

```

## 频率调整

1. rt_pm_run_enter

```c

rt_err_trt_pm_run_enter(rt_uint8_tmode)

{

    //切换的模式比当前模式小,则执行立刻切换

    if (mode < pm->run_mode)

    {

        /* change system runing mode */

        if(pm->ops != RT_NULL && pm->ops->run != RT_NULL)

        {

            pm->ops->run(pm, mode);

        }

        // pm设备进行频率调整

        _pm_device_frequency_change(mode);

    }

    else

    {

        pm->flags |= RT_PM_FREQUENCY_PENDING;

    }

    pm->run_mode = mode;

}

```

## 调度

1. 由空闲线程中执行 `rt_system_power_manager`

```c

voidrt_system_power_manager(void)

{

    if (_pm_init_flag == 0)

        return;


    /* CPU frequency scaling according to the runing mode settings */

    _pm_frequency_scaling(&_pm);


    /* Low Power Mode Processing */

    _pm_change_sleep_mode(&_pm);

}

```

### 睡眠调度

1.`_pm_select_sleep_mode` 获取sleep模式,选择请求的最高级别的模式

使用 `rt_pm_request`和 `rt_pm_release`进行请求和释放

对mode进行加减操作

```c

if (pm->modes[mode] < 255)

    pm->modes[mode] ++;


if (pm->modes[mode] > 0)

    pm->modes[mode] --;

```

2.`_pm_device_check_idle` 检查设备是否在忙

使用 `rt_pm_module_request`和 `rt_pm_module_release`进行请求和释放

对mode进行加减操作,并设置请求状态

```c

pm->module_status[module_id].req_status = 0x01;

if (pm->modes[mode] < 255)

    pm->modes[mode] ++;


if (pm->modes[mode] > 0)

    pm->modes[mode] --;

if (pm->modes[mode] == 0)

    pm->module_status[module_id].req_status = 0x00;

```

`rt_pm_module_delay_sleep` 延迟睡眠

```c

    pm->module_status[module_id].busy_flag = RT_TRUE;

    pm->module_status[module_id].timeout = timeout;

    pm->module_status[module_id].start_time = rt_tick_get();

```

3. 判断idle空闲 可修改模式为idle模式

```c

    /* module busy request check */

    if (_pm_device_check_idle() == RT_FALSE)

    {

        sleep_mode = PM_BUSY_SLEEP_MODE;

        if (sleep_mode < pm->sleep_mode)

        {

            pm->sleep_mode = sleep_mode; /* judge the highest sleep mode */

        }

    }

```

4. 进退睡眠模式执行通知函数 `rt_pm_notify_set`注册通知函数

执行pm 设备 `suspend`和 `resume`

5. 计算tick补偿

```c

/* Tickless*/

if (pm->timer_mask & (0x01 << pm->sleep_mode))

{

    timeout_tick = pm_timer_next_timeout_tick(pm->sleep_mode);

    timeout_tick = timeout_tick - rt_tick_get();


    // 根据需要唤醒时间,计算下一个睡眠模式

    pm->sleep_mode = pm_get_sleep_threshold_mode(pm->sleep_mode, timeout_tick);


    if (pm->timer_mask & (0x01 << pm->sleep_mode))

    {

        //开启下一个睡眠模式的定时器

        if (timeout_tick == RT_TICK_MAX)

        {

            pm_lptimer_start(pm, RT_TICK_MAX);

        }

        else

        {

            pm_lptimer_start(pm, timeout_tick);

        }

    }

}

```

6. SLEEP后等待触发唤醒
7. 获取定时器经过时间,停止定时器;

设置系统滴答时间补偿,并执行调度器时间片检查与定时器检查

