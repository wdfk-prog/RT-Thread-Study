---
title: RTT系统初始化
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: c1f21244
date: 2025-10-03 09:44:51
---
# RTT系统初始化

## `rtthread_startup`

1. 中断禁用
2. 板级初始化

## rt_hw_board_init

1. I/D cache初始化
2. 时钟初始化
3. 外设时钟初始化
4. 堆初始化 `rt_system_heap_init`
5. 组件初始化 `rt_components_board_init`,初始化板级驱动

## INIT_EXPORT

```c

/*

 * Components Initialization will initialize some driver and components as following

 * order:

 * rti_start         --> 0

 * BOARD_EXPORT      --> 1

 * rti_board_end     --> 1.end

 *

 * DEVICE_EXPORT     --> 2

 * COMPONENT_EXPORT  --> 3

 * FS_EXPORT         --> 4

 * ENV_EXPORT        --> 5

 * APP_EXPORT        --> 6

 *

 * rti_end           --> 6.end

 *

 * These automatically initialization, the driver or component initial function must

 * be defined with:

 * INIT_BOARD_EXPORT(fn);

 * INIT_DEVICE_EXPORT(fn);

 * ...

 * INIT_APP_EXPORT(fn);

 * etc.

 */

```

1. 根据编译后 `Image Symbol Table`中顺序执行

```c

    __rt_init_rti_start                      0x900621a4   Data           4  components.o(.rti_fn.0)

    __rt_init_rti_board_start                0x900621a8   Data           4  components.o(.rti_fn.0.end)

    __rt_init_vtor_config                    0x900621ac   Data           4  board.o(.rti_fn.1)

    __rt_init_mpu_init                       0x900621b0   Data           4  drv_mpu.o(.rti_fn.1)

    __rt_init_rt_hw_spi_init                 0x900621b4   Data           4  drv_spi.o(.rti_fn.1)

    __rt_init_SDRAM_Init                     0x900621b8   Data           4  drv_sdram.o(.rti_fn.1)

    __rt_init_rt_wdt_init                    0x900621bc   Data           4  drv_wdt.o(.rti_fn.1)

    __rt_init_rt_usbd_class_list_init        0x900621c0   Data           4  usbdevice.o(.rti_fn.1)

    __rt_init_ulog_init                      0x900621c4   Data           4  ulog.o(.rti_fn.1)

    __rt_init_rti_board_end                  0x900621c8   Data           4  components.o(.rti_fn.1.end)

    __rt_init_rt_mmcsd_core_init             0x900621cc   Data           4  mmcsd_core.o(.rti_fn.2)

    __rt_init_dfs_init                       0x900621d0   Data           4  dfs.o(.rti_fn.2)

    __rt_init_rt_usbd_msc_class_register     0x900621d4   Data           4  mstorage.o(.rti_fn.2)

    __rt_init_ulog_console_backend_init      0x900621d8   Data           4  console_be.o(.rti_fn.2)

    __rt_init_ulog_async_init                0x900621dc   Data           4  ulog.o(.rti_fn.2)

    __rt_init_ulog_console_backend_filter_init 0x900621e0   Data           4  ulog_file_be.o(.rti_fn.3)

    __rt_init_adc_init                       0x900621e4   Data           4  user_adc.o(.rti_fn.3)

    __rt_init_rt_cm_backtrace_init           0x900621e8   Data           4  cmb_port.o(.rti_fn.3)

    __rt_init_stm_usbd_register              0x900621ec   Data           4  drv_usbd.o(.rti_fn.3)

    __rt_init_rt_hw_sdio_init                0x900621f0   Data           4  drv_sdmmc.o(.rti_fn.3)

    __rt_init_rt_hw_rtc_init                 0x900621f4   Data           4  drv_rtc.o(.rti_fn.3)

    __rt_init_set_finsh_irq                  0x900621f8   Data           4  board.o(.rti_fn.4)

    __rt_init_rtc_update_init                0x900621fc   Data           4  board.o(.rti_fn.4)

    __rt_init_elm_init                       0x90062200   Data           4  dfs_elm.o(.rti_fn.4)

    __rt_init_dfs_romfs_init                 0x90062204   Data           4  dfs_romfs.o(.rti_fn.4)

    __rt_init_dfs_lfs_init                   0x90062208   Data           4  dfs_lfs.o(.rti_fn.4)

    __rt_init_syswatch_init                  0x9006220c   Data           4  syswatch.o(.rti_fn.4)

    __rt_init_utest_init                     0x90062210   Data           4  utest.o(.rti_fn.4)

    __rt_init_rt_flash_init                  0x90062214   Data           4  spi_flash_init.o(.rti_fn.5)

    __rt_init_mfbd_init                      0x90062218   Data           4  bsp_key.o(.rti_fn.6)

    __rt_init_User_Led_Init                  0x9006221c   Data           4  user_led.o(.rti_fn.6)

    __rt_init_pvd_init                       0x90062220   Data           4  board.o(.rti_fn.6)

    __rt_init_uart1_init                     0x90062224   Data           4  user_uart1.o(.rti_fn.6)

    __rt_init_cpu_usage_init                 0x90062228   Data           4  cpu_usage.o(.rti_fn.6)

    __rt_init_finsh_system_init              0x9006222c   Data           4  shell.o(.rti_fn.6)

    __rt_init_rti_end                        0x90062230   Data           4  components.o(.rti_fn.6.end)

```

## rt_system_timer_init

