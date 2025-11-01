---
title: fal
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: 8bf91915
date: 2025-10-03 09:44:51
---
# fal flash抽象层

-`FAL_FLASH_DEV_TABLE`设备表挂载不同flash设备

-`FAL_PART_TABLE`分区表对同一个flash挂载不同分区

-`blocks` 对不同颗粒度的flash进行分块

## 初始化

- 执行 `fal_init`

-`FAL_FLASH_DEV_TABLE`注册flash设备

1. fal_flash_init

- 遍历注册表信息,执行flash初始化,与block分割

2. fal_partition_init

- 使用ROM保存分区表,每次查询并挂钩 `FAL_PART_TABLE`分区表
- 使用FLASH保存分区表,仅需读取
- 加载分区表,读取分区信息
- 检查flash设备是否都存在

## 注册设备

- 注册块设备, 或字符串设备,或MTD nor设备

```c

struct rt_mtd_nor_device

{

    struct rt_device parent;


    rt_uint32_t block_size;         /* The Block size in the flash */

    rt_uint32_t block_start;        /* The start of available block*/

    rt_uint32_t block_end;          /* The end of available block */


    /* operations interface */

    conststruct rt_mtd_nor_driver_ops* ops;

};


struct rt_mtd_nor_driver_ops

{

    rt_err_t (*read_id) (struct rt_mtd_nor_device* device);


    rt_ssize_t (*read)    (struct rt_mtd_nor_device* device, rt_off_t offset, rt_uint8_t* data, rt_size_t length);

    rt_ssize_t (*write)   (struct rt_mtd_nor_device* device, rt_off_t offset, constrt_uint8_t* data, rt_size_t length);


    rt_err_t (*erase_block)(struct rt_mtd_nor_device* device, rt_off_t offset, rt_size_t length);

};


struct fal_char_device

{

    struct rt_device                parent;

    conststruct fal_partition     *fal_part;

};


struct fal_blk_device

{

    struct rt_device                parent;

    struct rt_device_blk_geometry   geometry;

    conststruct fal_partition     *fal_part;

};

```

## 读写

- 调用注册的接口

