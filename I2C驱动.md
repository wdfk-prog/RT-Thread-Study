---
title: I2C驱动
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: 79c94d14
date: 2025-10-03 09:44:51
---
# I2C驱动

> https://www.i2c-bus.org/i2c-primer/termination-versus-capacitance/

## 硬件电路

![image-20240613172342801](readme.assets/image-20240613172342801.png)

I2C 总线使用 SDA 和 SCL 传输数据和时钟。首先要意识到：SDA 和 SCL 是*开漏*（在 TTL 世界中也称为*开集*），也就是说 I2C 主设备和从设备只能将这些线路驱动为低电平或保持开路。如果没有 I2C 设备将其拉低，*终端电阻Rp 会将线路拉高至 Vcc。这允许同时操作多个 I2C 主设备（如果它们具有**多主设备*功能）或*拉伸*（从设备可以通过按住 SCL 来减慢通信速度）等功能。

终端电阻 Rp 与线路电容 Cp 一起影响 SDA 和 SCL 上信号的时间行为。虽然 I2C 设备使用开漏驱动器或 FET 拉低线路（通常可以驱动至少约 10mA 或更多），但上拉电阻 Rp 负责将信号恢复到高电平。Rp 通常在 1 kΩ 至 10 kΩ 之间，导致典型的上拉电流约为 1 mA 或更小。这就是 I2C 信号具有锯齿状外观的原因。事实上，每个“齿”在上升沿显示线路的充电特性，在下降沿显示放电特性。

![img](https://www.i2c-bus.org/static/i2c/i2c-signals-10k-300pf_02.gif)

SDA（上）和 SCL（下）的 Rp = 10 kΩ 和 Cp = 300 pF。SCL 时钟以 100 kHz（标称值）运行。

## I2C设备驱动

### I2C设备注册

1. 调用 `rt_i2c_bus_device_device_init`,将I2C设备注册到rt_device中

```c

struct rt_i2c_bus_device_ops

{

    rt_ssize_t (*master_xfer)(struct rt_i2c_bus_device *bus,

                             struct rt_i2c_msg msgs[],

                             rt_uint32_t num);

    rt_ssize_t (*slave_xfer)(struct rt_i2c_bus_device *bus,

                            struct rt_i2c_msg msgs[],

                            rt_uint32_t num);

    rt_err_t (*i2c_bus_control)(struct rt_i2c_bus_device *bus,

                                int cmd,

                                void *args);

};


struct rt_i2c_bus_device

{

    struct rt_device parent;

    conststruct rt_i2c_bus_device_ops *ops;

    rt_uint16_t  flags;

    struct rt_mutex lock;

    rt_uint32_t  timeout;

    rt_uint32_t  retries;

    void *priv;

};

rt_err_trt_i2c_bus_device_device_init(struct rt_i2c_bus_device *bus,

                                       constchar               *name)

{

    //注册bus设备

    device->user_data = bus;

    //挂钩读写控制函数

    device->init    = RT_NULL;

    device->open    = RT_NULL;

    device->close   = RT_NULL;

    device->read    = i2c_bus_device_read;

    device->write   = i2c_bus_device_write;

    device->control = i2c_bus_device_control;

}

```

### I2C总线设备驱动

### 初始化

- 总线初始化互斥量

```c

rt_err_trt_i2c_bus_device_register(struct rt_i2c_bus_device *bus,

                                    constchar               *bus_name)

{

    //初始化锁

    rt_mutex_init(&bus->lock, "i2c_bus_lock", RT_IPC_FLAG_PRIO);

    //默认超时时间按照一个切换时间

    if (bus->timeout == 0) bus->timeout = RT_TICK_PER_SECOND;

    //注册I2C设备,挂钩读写控制函数

    res = rt_i2c_bus_device_device_init(bus, bus_name);

    return res;

}

```

### transfer

- 加锁形成临界区,调用 `master_xfer`函数,完成I2C数据传输

```c

    err = rt_mutex_take(&bus->lock, RT_WAITING_FOREVER);

    if (err != RT_EOK)

    {

        return (rt_ssize_t)err;

    }

    ret = bus->ops->master_xfer(bus, msgs, num);

    err = rt_mutex_release(&bus->lock);

```

- rt_i2c_master_recv

```c

    msg.flags  = flags | RT_I2C_RD;

    ret = rt_i2c_transfer(bus, &msg, 1);

```

- rt_i2c_master_send

```c

    msg.flags = flags;

    ret = rt_i2c_transfer(bus, &msg, 1);

```

## 软件I2C

- TIMING_DELAY 默认 10us, 即10kHz
- TIMING_TIMEOUT 默认 10 tick

### 初始化

1. 初始化I2C 引脚,设置为开漏输出,默认高电平

```c

    rt_pin_mode(cfg->scl_pin, PIN_MODE_OUTPUT_OD);

    rt_pin_mode(cfg->sda_pin, PIN_MODE_OUTPUT_OD);

    rt_pin_write(cfg->scl_pin, PIN_HIGH);

    rt_pin_write(cfg->sda_pin, PIN_HIGH);

```

- 原因:

```

SDA 和 SCL 是开漏，也就是说 I2C 主设备和从设备只能将这些线路驱动为低电平或保持开路。如果没有 I2C 设备将其拉低，终端电阻Rp 会将线路拉高至 Vcc。


终端电阻 Rp 与线路电容 Cp 一起影响 SDA 和 SCL 上信号的时间行为。虽然 I2C 设备使用开漏驱动器或 FET 拉低线路（通常可以驱动至少约 10mA 或更多），但上拉电阻 Rp 负责将信号恢复到高电平。Rp 通常在 1 kΩ 至 10 kΩ 之间，导致典型的上拉电流约为 1 mA 或更小。这就是 I2C 信号具有锯齿状外观的原因。事实上，每个“齿”在上升沿显示线路的充电特性，在下降沿显示放电特性。

```

2. 调用 `rt_i2c_bus_device_register`注册设I2C总线设备,初始化总线互斥量

- 将软件I2C操作函数挂钩到总线设备中

```c

struct rt_i2c_bit_ops

{

    void *data;            /* private data for lowlevel routines */

    void (*set_sda)(void *data, rt_int32_t state);

    void (*set_scl)(void *data, rt_int32_t state);

    rt_int32_t (*get_sda)(void *data);

    rt_int32_t (*get_scl)(void *data);


    void (*udelay)(rt_uint32_t us);


    rt_uint32_t delay_us;  /* scl and sda line delay */

    rt_uint32_t timeout;   /* in tick */


    void (*pin_init)(void);

    rt_bool_t i2c_pin_init_flag;

};


intrt_soft_i2c_init(void)

{

    obj->ops = soft_i2c_ops;

    obj->ops.data = cfg;

    //i2c_bug.priv用于rt_i2c_bit_ops

    obj->i2c_bus.priv = &obj->ops;

}

```

3.`i2c_bus_unlock`解锁I2C

- 死锁

总线表现:SCL为高，SDA一直为低

原因:

```

正常情况下，I2C总线协议能够保证总线正常的读写操作。

但是，当I2C主设备异常复位时(看门狗动作，板上电源异常导致复位芯片动作，手动按钮复位等等)有可能导致I2C总线死锁产生。下面详细说明一下总线死锁产生的原因。在I2C主设备进行读写操作的过程中.主设备在开始信号后控制SCL产生8个时钟脉冲，然后拉低SCL信号为低电平，在这个时候，从设备输出应答信号，将SDA信号拉为低电平。

    如果这个时候主设备异常复位，SCL就会被释放为高电平。此时，如果从设备没有复位，就会继续I2C的应答，将SDA一直拉为低电平，直到SCL变为低电平，才会结束应答信号。

    而对于I2C主设备来说.复位后检测SCL和SDA信号，如果发现SDA信号为低电平，则会认为I2C总线被占用，会一直等待SCL和SDA信号变为高电平。

    这样，I2C主设备等待从设备释放SDA信号，而同时I2C从设备又在等待主设备将SCL信号拉低以释放应答信号，两者相互等待，I2C总线进入一种死锁状态。

    同样，当I2C进行读操作，I2C从设备应答后输出数据，如果在这个时刻I2C主设备异常复位而此时I2C从设备输出的数据位正好为0，也会导致I2C总线进入死锁状态。


这样主从进入一个相互等待的死锁过程。

```

解决方式:

```

死锁解决方法

    在I2C主设备中增加I2C总线恢复程序。每次I2C主设备复位后，如果检测到SDA数据线被拉低，则控制I2C中的SCL时钟线产生9个时钟脉冲(针对8位数据的情况)，这样I2C从设备就可以完成被挂起的读操作，从死锁状态中恢复过来。

    这种方法有很大的局限性，因为大部分主设备的I2C模块由内置的硬件电路来实现，软件并不能够直接控制SCL信号模拟产生需要时钟脉冲。

```

```c

/**

* if i2c is locked, this function will unlock it

*

* @parami2c config class.

*

* @return RT_EOK indicates successful unlock.

*/

staticrt_err_ti2c_bus_unlock(conststruct soft_i2c_config *cfg)

{

    rt_ubase_t i = 0;

    //复位后发现SDA为低电平,则产生9个时钟脉冲

    if(PIN_LOW == rt_pin_read(cfg->sda_pin))

    {

        while(i++ < 9)

        {

            rt_pin_write(cfg->scl_pin, PIN_HIGH);

            rt_hw_us_delay(cfg->timing_delay);

            rt_pin_write(cfg->scl_pin, PIN_LOW);

            rt_hw_us_delay(cfg->timing_delay);

        }

    }

    //还是低电平死锁状态,则返回错误

    if(PIN_LOW == rt_pin_read(cfg->sda_pin))

    {

        return -RT_ERROR;

    }


    return RT_EOK;

}

```

### 读写 i2c_bit_xfer

```c

#define RT_I2C_WR              0x0000        /* 写标志，不可以和读标志进行“|”操作 */

#define RT_I2C_RD              (1u<<0)     /* 读标志，不可以和写标志进行“|”操作 */

#define RT_I2C_ADDR_10BIT      (1u<<2)     /* 10 位地址模式 */

#define RT_I2C_NO_START        (1u<<4)     /* 无开始条件 */

#define RT_I2C_IGNORE_NACK     (1u<<5)     /* 忽视 NACK */

#define RT_I2C_NO_READ_ACK     (1u<<6)     /* 读的时候不发送 ACK */

#define RT_I2C_NO_STOP         (1u<<7)     /* 不发送结束位 */


staticrt_ssize_ti2c_bit_xfer(struct rt_i2c_bus_device *bus,

                              struct rt_i2c_msg         msgs[],

                              rt_uint32_t               num)

{

    for (i = 0; i < num; i++)

    {

        msg = &msgs[i];

        ignore_nack = msg->flags & RT_I2C_IGNORE_NACK;

        //发送开始条件

        if (!(msg->flags & RT_I2C_NO_START))

        {

            if (i)

            {

                //发送重复开始条件

                i2c_restart(ops);

            }

            else

            {

                LOG_D("send start condition");

                i2c_start(ops);

            }

            //发送地址

            ret = i2c_bit_send_address(bus, msg);

            if ((ret != RT_EOK) && !ignore_nack)

            {

                LOG_D("receive NACK from device addr 0x%02x msg %d",

                        msgs[i].addr, i);

                goto out;

            }

        }

        //读取数据

        if (msg->flags & RT_I2C_RD)

        {

            ret = i2c_recv_bytes(bus, msg);

            if (ret >= 1)

            {

                LOG_D("read %d byte%s", ret, ret == 1 ? "" : "s");

            }

            if (ret < msg->len)

            {

                if (ret >= 0)

                    ret = -RT_EIO;

                goto out;

            }

        }

        //发送数据

        else

        {

            ret = i2c_send_bytes(bus, msg);

            if (ret >= 1)

            {

                LOG_D("write %d byte%s", ret, ret == 1 ? "" : "s");

            }

            if (ret < msg->len)

            {

                if (ret >= 0)

                    ret = -RT_ERROR;

                goto out;

            }

        }

    }

    ret = i;


out:

    if (!(msg->flags & RT_I2C_NO_STOP))

    {

        LOG_D("send stop condition");

        //发送停止条件

        i2c_stop(ops);

    }


    return ret;

}

```

### i2c_start

```c

staticvoidi2c_start(struct rt_i2c_bit_ops *ops)

{

    //开始前,I2C总线应该为空闲状态,即SDA和SCL都为高电平

#ifdef RT_I2C_BITOPS_DEBUG

    if (ops->get_scl &&!GET_SCL(ops))

    {

        LOG_E("I2C bus error, SCL line low");

    }

    if (ops->get_sda &&!GET_SDA(ops))

    {

        LOG_E("I2C bus error, SDA line low");

    }

#endif

    //SCL 线是高电平时，SDA 线从高电平向低电平切换表示起始条件

    SDA_L(ops);

    i2c_delay(ops);

    SCL_L(ops);

}

```

### i2c_restart

```c

staticvoidi2c_restart(struct rt_i2c_bit_ops *ops)

{

    SDA_H(ops);

    SCL_H(ops);

    i2c_delay(ops);

    SDA_L(ops);

    i2c_delay(ops);

    SCL_L(ops);

}

```

### i2c_stop

```c

staticvoidi2c_stop(struct rt_i2c_bit_ops *ops)

{

    //当SCL 是高电平时，SDA 线由低电平向高电平切换表示停止条件。

    SDA_L(ops);

    i2c_delay(ops);

    SCL_H(ops);

    i2c_delay(ops);

    SDA_H(ops);

    i2c_delay2(ops);

}

```

### i2c_writeb

![img](https://pic2.zhimg.com/80/v2-632929cc1016b4fd90e056d2523b3bf5_720w.webp)

- 从高位到低位发送数据,发送一个字节数据,等待ACK
- 每个bit由SDA发送,低电平表示0,高电平表示1;每次发送一个bit,等待SCL高电平,发送下一个bit

```c

    for (i = 7; i >= 0; i--)

    {

        SCL_L(ops);

        bit = (data >> i) & 1;

        SET_SDA(ops, bit);

        i2c_delay(ops);

        if (SCL_H(ops) < 0)

        {

            LOG_D("i2c_writeb: 0x%02x, "

                    "wait scl pin high timeout at bit %d",

                    data, i);


            return -RT_ETIMEOUT;

        }

    }

    SCL_L(ops);

    i2c_delay(ops);


    returni2c_waitack(ops);

```

### i2c_waitack

- 等待ACK;在SCL高电平时,读取SDA电平,ACK为低电平,NACK为高电平

```c

rt_inline rt_bool_ti2c_waitack(struct rt_i2c_bit_ops *ops)

{

    rt_bool_t ack;


    SDA_H(ops);

    i2c_delay(ops);


    if (SCL_H(ops) < 0)

    {

        LOG_W("wait ack timeout");


        return -RT_ETIMEOUT;

    }


    ack = !GET_SDA(ops);    /* ACK : SDA pin is pulled low */

    LOG_D("%s", ack ? "ACK" : "NACK");


    SCL_L(ops);


    return ack;

}

```

### i2c_readb

- 从高位到低位接收数据,接收一个字节数据
- 必须在SCL高电平期间读取SDA电平

```c

staticrt_int32_ti2c_readb(struct rt_i2c_bus_device *bus)

{

    rt_uint8_t i;

    rt_uint8_t data = 0;

    struct rt_i2c_bit_ops *ops = (struct rt_i2c_bit_ops *)bus->priv;


    SDA_H(ops);

    i2c_delay(ops);

    for (i = 0; i < 8; i++)

    {

        data <<= 1;


        if (SCL_H(ops) < 0)

        {

            LOG_D("i2c_readb: wait scl pin high "

                    "timeout at bit %d", 7 - i);


            return -RT_ETIMEOUT;

        }


        if (GET_SDA(ops))

            data |= 1;

        SCL_L(ops);

        i2c_delay2(ops);

    }


    return data;

}

```

### i2c_bit_send_address

```c

    /* 7-bit addr */

    addr1 = msg->addr << 1;

    if (flags & RT_I2C_RD)

        addr1 |= 1;


    for (i = 0; i <= retries; i++)

    {

        ret = i2c_writeb(bus, addr);

        if (ret == 1 || i == retries)

            break;

        LOG_D("send stop condition");

        i2c_stop(ops);

        i2c_delay2(ops);

        LOG_D("send start condition");

        i2c_start(ops);

    }

```

### i2c_recv_bytes

```c


while (count > 0)

{

    val = i2c_readb(bus);

    if (val >= 0)

    {

        *ptr = val;

        bytes ++;

    }

    else

    {

        break;

    }


    ptr ++;

    count --;


    LOG_D("recieve bytes: 0x%02x, %s",

            val, (flags & RT_I2C_NO_READ_ACK) ?

            "(No ACK/NACK)" : (count ? "ACK" : "NACK"));


    if (!(flags & RT_I2C_NO_READ_ACK))

    {

        val = i2c_send_ack_or_nack(bus, count);

        if (val < 0)

            return val;

    }

}

```

### i2c_send_ack_or_nack

- 在SCL高电平时,发送ACK或NACK

```c

staticrt_err_ti2c_send_ack_or_nack(struct rt_i2c_bus_device *bus, intack)

{

    struct rt_i2c_bit_ops *ops = (struct rt_i2c_bit_ops *)bus->priv;


    if (ack)

        SET_SDA(ops, 0);

    i2c_delay(ops);

    if (SCL_H(ops) < 0)

    {

        LOG_E("ACK or NACK timeout.");


        return -RT_ETIMEOUT;

    }

    SCL_L(ops);


    return RT_EOK;

}

```

## STM32 HAL I2C

1.`HAL_I2C_Mem_Write` : 发送设备地址,也发送寄存器地址,再发送数据

2.`HAL_I2C_Master_Transmit`: 发送设备地址,再发送数据

3.`HAL_I2C_Master_Seq_Transmit_IT`: 通信的序列(Seq)传输函数

### 阻塞方式

- HAL_I2C_Master_Transmit

1. 等待 `I2C_FLAG_BUSY`不被设置,超时时间25ms

> ISR->BUSY 此标志表示在总线上正在进行通信。当检测到启动条件时，它由硬件设置。当检测到STOP条件或PE=0时，硬件清除。

2. 根据发送长度执行不同的发送方式

->255 ,使用 `I2C_RELOAD_MODE`

- <=255,使用 `I2C_AUTOEND_MODE`

3. 调用 `I2C_TransferConfig` ,执行 `I2C_GENERATE_START_WRITE`写入
4. 等待 `TXIS`标志设置,才能写入数据

> 发送传输状态:当I2C_TXDR寄存器为空，要传输的数据必须写入I2C_TXDR寄存器时，该位由硬件设置。当下一个要发送的数据被写入I2C_TXDR寄存器时，它将被清除。

5. 如果是>255数据,需要多次写入,等待 `I2C_FLAG_TCR`标志设置,再次执行发送
6. 结束后等待 `STOPF`标志设置,发送停止条件

- HAL_I2C_Master_Receive

### 非阻塞 中断方式

- HAL_I2C_Master_Transmit_IT

1. 设置ISR回调函数 `I2C_Master_ISR_IT`
2. 发送设备地址
3. 使能 `使能 ERR、TC、STOP、NACK、TXI 中断`
4. 中断服务函数 `HAL_I2C_EV_IRQHandler` -> `I2C_Master_ISR_IT`

由中断中判断还未发送完数据,继续发送;

发送完成后调用 `I2C_ITMasterSeqCplt`

5. 触发回调 `HAL_I2C_MasterTxCpltCallback`

### 非阻塞 DMA

### SEQ传输函数

> https://blog.csdn.net/NeoZng/article/details/128496694

## 硬件I2C驱动

1. IT方式和DMA启用完成量进行通信;且TX和RX使用同一个的完成量

原因:对于主机来说,对于需要接收的数据,也需要先发送命令在执行接收;所以使用同一个完成量,并不会存在冲突;对于主机收发来说,非阻塞方式并无意义,所以使用完成量来进行通信

