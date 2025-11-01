---
title: map文件分析
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: 427ac97f
date: 2025-10-03 09:44:52
---
# map文件分析

```assembly

Image$$ER_IROM1$$Base                    0x90000000   Number         0  anon$$obj.o ABSOLUTE

__Vectors                                0x90000000   Data           4  startup_stm32h750xx.o(RESET)

__Vectors_End                            0x90000298   Data           0  startup_stm32h750xx.o(RESET)

__main                                   0x90000299   Thumb Code     0  entry.o(.ARM.Collect$$$$00000000)

_main_stk                                0x90000299   Thumb Code     0  entry2.o(.ARM.Collect$$$$00000001)

_main_scatterload                        0x9000029d   Thumb Code     0  entry5.o(.ARM.Collect$$$$00000004)

__main_after_scatterload                 0x900002a1   Thumb Code     0  entry5.o(.ARM.Collect$$$$00000004)

_main_clock                              0x900002a1   Thumb Code     0  entry7b.o(.ARM.Collect$$$$00000008)

_main_cpp_init                           0x900002a1   Thumb Code     0  entry8b.o(.ARM.Collect$$$$0000000A)

_main_init                               0x900002a1   Thumb Code     0  entry9a.o(.ARM.Collect$$$$0000000B)

__rt_final_cpp                           0x900002a9   Thumb Code     0  entry10a.o(.ARM.Collect$$$$0000000D)

__rt_final_exit                          0x900002a9   Thumb Code     0  entry11a.o(.ARM.Collect$$$$0000000F)

rt_hw_interrupt_disable                  0x900002ad   Thumb Code     8  context_rvds.o(.text)

rt_hw_interrupt_enable                   0x900002b5   Thumb Code     6  context_rvds.o(.text)

rt_hw_context_switch                     0x900002bb   Thumb Code    32  context_rvds.o(.text)

rt_hw_context_switch_interrupt           0x900002bb   Thumb Code     0  context_rvds.o(.text)

PendSV_Handler                           0x900002db   Thumb Code   108  context_rvds.o(.text)

rt_hw_context_switch_to                  0x90000347   Thumb Code    76  context_rvds.o(.text)

rt_hw_interrupt_thread_switch            0x90000393   Thumb Code     2  context_rvds.o(.text)

HardFault_Handler                        0x90000395   Thumb Code    56  context_rvds.o(.text)

MemManage_Handler                        0x90000395   Thumb Code     0  context_rvds.o(.text)

rt_memcpy                                0x900003e9   Thumb Code     0  rt_memcpy_rvds.o(.text)

Reset_Handler                            0x9000060d   Thumb Code     8  startup_stm32h750xx.o(.text)

```

1. Reset_Handler 根据链接脚本设置 `ENTRY(Reset_Handler)`;应为RAM首地址位置;实际并不是

原因:

- 在汇编启动文件中,首先设置了向量表,再设置复位函数

```assembly

; Vector Table Mapped to Address 0 at Reset

    AREA    RESET, DATA, READONLY

    EXPORT  __Vectors

    EXPORT  __Vectors_End

    EXPORT  __Vectors_Size


__Vectors       DCD     __initial_sp                      ; Top of Stack

    DCD     Reset_Handler                     ; Reset Handler

```

-`Reset_Handler `编写中调用 `SystemInit`与 `__main`

```assembly

Reset_Handler    PROC

        EXPORT  Reset_Handler                    [WEAK]

    IMPORT  SystemInit

    IMPORT  __main


        LDR     R0, =SystemInit

        BLX     R0

        LDR     R0, =__main

        BX      R0

        ENDP

```

-`__main`中执行rtt初始化:https://www.rt-thread.org/document/api/group___system_init.html#details

