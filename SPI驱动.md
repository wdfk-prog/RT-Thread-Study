---
title: SPI驱动
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: 76997d73
date: 2025-10-03 09:44:51
---
# SPI驱动

## SPI原理

> https://www.circuitbasics.com/basics-of-the-spi-communication-protocol/

> https://learn.sparkfun.com/tutorials/serial-peripheral-interface-spi/all

## SPI设备驱动

### 初始化

1.`rt_spi_bus_register`注册 `SPI BUS`设备,并且初始化互斥量

1.`rt_spi_bus_attach_device_cspin` 调用 `rt_spidev_device_init`注册 `SPI DEV`设备

- 初始化CS引脚

2. 配置SPI设备,互斥量加锁保护

### rt_spi_transfer_message 传输任意消息

1. 互斥量加锁保护
2. 总线设备不是当前设备,则切换设备,并且重新配置SPI总线

> SPI需要明确当前操作的设备是什么,并且需要重新配置SPI总线,因为SPI一次只能操作一个设备,所以设备可以是不同的配置信息;SPI的配置可以有相位和极性,速率等

> I2C总线不需要重新配置,因为I2C总线是共享的;I2C的配置只有时钟速率

3.`xfer`执行每个消息的传输

4. 互斥量解锁

### rt_spi_send_then_send

本函数适合向 SPI 设备中写入一块数据，第一次先发送命令和地址等数据，第二次再发送指定长度的数据。之所以分两次发送而不是合并成一个数据块发送，或调用两次 rt_spi_send()，是因为在大部分的数据写操作中，都需要先发命令和地址，长度一般只有几个字节。如果与后面的数据合并在一起发送，将需要进行内存空间申请和大量的数据搬运。而如果调用两次 rt_spi_send()，那么在发送完命令和地址后，片选会被释放，大部分 SPI 设备都依靠设置片选一次有效为命令的起始，所以片选在发送完命令或地址数据后被释放，则此次操作被丢弃。

### rt_spi_send_then_recv

此函数发送第一条数据 send_buf 时开始片选，此时忽略接收到的数据，然后发送第二条数据，此时主设备会发送数据 0XFF，接收到的数据保存在 recv_buf 里，函数返回时释放片选。

本函数适合从 SPI 从设备中读取一块数据，第一次会先发送一些命令和地址数据，然后再接收指定长度的数据。

### 独占总线

- rt_spi_take_bus 获取总线;在多线程的情况下，同一个 SPI 总线可能会在不同的线程中使用，为了防止 SPI 总线正在传输的数据丢失，从设备在开始传输数据前需要先获取 SPI 总线的使用权，获取成功才能够使用总线传输数据
- rt_spi_release_bus 释放总线;在 SPI 总线传输数据完成后，需要释放 SPI 总线的使用权，以便其他线程使用 SPI 总线
- rt_spi_take 从设备数据传输开始前，需要获取片选
- rt_spi_release 从设备数据传输完成后，需要释放片选

## 模拟SPI

- CPOL极性

先说什么是SCLK时钟的空闲时刻，其就是当SCLK在发送8个bit比特数据之前和之后的状态，

于此对应的，SCLK在发送数据的时候，就是正常的工作的时候，有效active的时刻了。

SPI的CPOL，表示当SCLK空闲idle的时候，其电平的值是低电平0还是高电平1：

CPOL=0，时钟空闲idle时候的电平是低电平，所以当SCLK有效的时候，就是高电平，就是所谓的active-high；

CPOL=1，时钟空闲idle时候的电平是高电平，所以当SCLK有效的时候，就是低电平，就是所谓的active-low；

![img](https://imgconvert.csdnimg.cn/aHR0cHM6Ly9pbWFnZXMwLmNuYmxvZ3MuY29tL2Jsb2cyMDE1LzI2ODE4Mi8yMDE1MDgvMjMxNDE2NTQ5ODg0ODcxLmdpZg)

- CPHA相位

相位，对应着数据采样是在第几个边沿（edge），是第一个边沿还是第二个边沿，0对应着第一个边沿，1对应着第二个边沿。

![img](https://imgconvert.csdnimg.cn/aHR0cHM6Ly9pbWFnZXMwLmNuYmxvZ3MuY29tL2Jsb2cyMDE1LzI2ODE4Mi8yMDE1MDgvMjMxNDE3NDYyMzgyMTk1LmdpZg)

```c

#define RT_SPI_CPHA     (1<<0)                             /* bit[0]:CPHA, clock phase */

#define RT_SPI_CPOL     (1<<1)                             /* bit[1]:CPOL, clock polarity */

```

### 初始化

- 注册到 `rt_spi_bus_register`

```c

rt_err_trt_spi_bit_add_bus(struct rt_spi_bit_obj *obj,

                            constchar            *bus_name,

                            struct rt_spi_bit_ops *ops)

{

    obj->ops = ops;

    obj->config.data_width = 8;

    obj->config.max_hz     = 1 * 1000 * 1000;

    obj->config.mode       = RT_SPI_MASTER | RT_SPI_MSB | RT_SPI_MODE_0;


    returnrt_spi_bus_register(&obj->bus, bus_name, &spi_bit_bus_ops);

}

```

### 配置

1. 初始化引脚

- SPI总线具有SCLK、MOSI、MISO、CS;这里只初始化SCLK、MOSI、MISO;CS由外部设备控制

```c

staticvoidstm32_spi_gpio_init(struct stm32_soft_spi *spi)

{

    struct stm32_soft_spi_config *cfg = (struct stm32_soft_spi_config *)spi->cfg;

    rt_pin_mode(cfg->sck, PIN_MODE_OUTPUT);

    rt_pin_mode(cfg->miso, PIN_MODE_INPUT);

    rt_pin_mode(cfg->mosi, PIN_MODE_OUTPUT);


    rt_pin_write(cfg->miso, PIN_HIGH);

    rt_pin_write(cfg->sck, PIN_HIGH);

    rt_pin_write(cfg->mosi, PIN_HIGH);

}

```

2. 配置SPI

- CPOL=1,SCLK空闲时为高电平;CPOL=0,SCLK空闲时为低电平
- 拷贝设备的配置

```c

    if (configuration->mode & RT_SPI_CPOL)

    {

        SCLK_H(ops);

    }

    else

    {

        SCLK_L(ops);

    }


    if (configuration->max_hz < 200000)

    {

        ops->delay_us = 1;

    }

    else

    {

        ops->delay_us = 0;

    }

```

### 传输

1. 片选使能,拉低电平为使能
2. SCLK翻转由空闲变为激活状态
3. 根据不同线序,发送数据
4. 释放片选,拉高电平为释放

```c

rt_ssize_tspi_bit_xfer(struct rt_spi_device *device, struct rt_spi_message *message)

{

    /* take CS */

    if (message->cs_take && (cs_pin != PIN_NONE))

    {

        rt_pin_write(cs_pin, PIN_LOW);

        spi_delay(ops);


        /* spi phase */

        if (config->mode & RT_SPI_CPHA)

        {

            spi_delay(ops);

            TOG_SCLK(ops);

        }

    }


    if (config->mode & RT_SPI_3WIRE)

    {

        if (config->data_width <= 8)

        {

            spi_xfer_3line_data8(ops,

                                 config,

                                 message->send_buf,

                                 message->recv_buf,

                                 message->length);

        }

        elseif (config->data_width <= 16)

        {

            spi_xfer_3line_data16(ops,

                                  config,

                                  message->send_buf,

                                  message->recv_buf,

                                  message->length);

        }

    }

    else

    {

        if (config->data_width <= 8)

        {

            spi_xfer_4line_data8(ops,

                                 config,

                                 message->send_buf,

                                 message->recv_buf,

                                 message->length);

        }

        elseif (config->data_width <= 16)

        {

            spi_xfer_4line_data16(ops,

                                  config,

                                  message->send_buf,

                                  message->recv_buf,

                                  message->length);

        }

    }


    /* release CS */

    if (message->cs_release && (cs_pin != PIN_NONE))

    {

        spi_delay(ops);

        rt_pin_write(cs_pin, PIN_HIGH);

        LOG_I("spi release cs\n");

    }


    returnmessage->length;

}

```

### 四线传输

1. 设置MOSI的电平,翻转SCLK;因为确认数据是在SCLK的边沿后采集MISO的数据
2. 读取MISO的数据
3. 翻转SCLK

```c

        while (size--)

        {

            rt_uint8_t tx_data = 0xFF;

            rt_uint8_t rx_data = 0xFF;

            rt_uint8_t bit  = 0;


            if (send_buf != RT_NULL)

            {

                tx_data = *send_ptr++;

            }


            for (i = 0; i < 8; i++)

            {

                if (config->mode & RT_SPI_MSB) { bit = tx_data & (0x1 << (7 - i)); }

                else                           { bit = tx_data & (0x1 << i); }


                if (bit) MOSI_H(ops);

                else     MOSI_L(ops);


                spi_delay2(ops);


                TOG_SCLK(ops);


                if (config->mode & RT_SPI_MSB) { rx_data <<= 1; bit = 0x01; }

                else                           { rx_data >>= 1; bit = 0x80; }


                if (GET_MISO(ops)) { rx_data |=  bit; }

                else               { rx_data &= ~bit; }


                spi_delay2(ops);


                if (!(config->mode & RT_SPI_CPHA) || (size != 0) || (i < 7))

                {

                    TOG_SCLK(ops);

                }

            }


            if (recv_buf != RT_NULL)

            {

                *recv_ptr++ = rx_data;

            }

        }

```

### 三线传输

- 三线传输是指MISO和MOSI共用一个引脚;所以需要切换发送与接收

```c

        if ((send_buf != RT_NULL) || (recv_buf == RT_NULL))

        {

            MOSI_OUT(ops);

            send_flg = 1;

        }

        else

        {

            MOSI_IN(ops);

        }


        while (size--)

        {

            rt_uint8_t tx_data = 0xFF;

            rt_uint8_t rx_data = 0xFF;

            rt_uint8_t bit  = 0;


            if (send_buf != RT_NULL)

            {

                tx_data = *send_ptr++;

            }


            if (send_flg)

            {

                for (i = 0; i < 8; i++)

                {

                    if (config->mode & RT_SPI_MSB) { bit = tx_data & (0x1 << (7 - i)); }

                    else                           { bit = tx_data & (0x1 << i); }


                    if (bit) MOSI_H(ops);

                    else     MOSI_L(ops);


                    spi_delay2(ops);


                    TOG_SCLK(ops);


                    spi_delay2(ops);


                    if (!(config->mode & RT_SPI_CPHA) || (size != 0) || (i < 7))

                    {

                        TOG_SCLK(ops);

                    }

                }


                rx_data = tx_data;

            }

            else

            {

                for (i = 0; i < 8; i++)

                {

                    spi_delay2(ops);


                    TOG_SCLK(ops);


                    if (config->mode & RT_SPI_MSB) { rx_data <<= 1; bit = 0x01; }

                    else                           { rx_data >>= 1; bit = 0x80; }


                    if (GET_MOSI(ops)) { rx_data |=  bit; }

                    else               { rx_data &= ~bit; }


                    spi_delay2(ops);


                    if (!(config->mode & RT_SPI_CPHA) || (size != 0) || (i < 7))

                    {

                        TOG_SCLK(ops);

                    }

                }


            }


            if (recv_buf != RT_NULL)

            {

                *recv_ptr++ = rx_data;

            }

        }


        if (!send_flg)

        {

            MOSI_OUT(ops);

        }

```

## 硬件SPI

- 与I2C一致;使用完成量进行通信;

## STM32 HAL SPI
- 对于小 SPI 数据包，使用常规轮询，对于大 SPI 数据包，使用 DMA。
- https://github.com/RT-Thread/rt-thread/pull/7593

在使用SPI DMA传输短数据时，速度反而比直接使用SPI模式慢，主要原因有以下几点：

DMA初始化和配置开销：每次使用DMA传输数据时，需要进行DMA通道的初始化和配置，这些操作会增加额外的时间开销1。
数据传输延迟：对于短数据传输，DMA的启动和停止时间可能会占据较大的比例，导致整体传输时间增加2。
中断处理延迟：DMA传输完成后，通常会触发中断来通知CPU数据传输完成。处理这些中断也会增加额外的延迟2。
SPI和DMA的同步问题：在每次传输一个字节时，SPI和DMA之间的同步可能会导致额外的等待时间1。
总体来说，DMA在处理大量数据传输时优势明显，但在处理短数据时，由于上述原因，反而可能会比直接使用SPI模式慢。如果你的应用场景主要涉及短数据传输，直接使用SPI模式可能会更高效。

总的来说，DMA在处理大量数据传输时优势明显，但在处理短数据时，由于初始化、配置和中断处理等开销，反而可能会比直接使用I2C或UART模式慢。如果你的应用场景主要涉及短数据传输，直接使用I2C或UART模式可能会更高效。

