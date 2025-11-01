---
title: fatfs
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: fa99c9bd
date: 2025-10-03 09:44:51
---
# fatfs

- 因此应用程序应尽可能以大块的形式写入数据。理想的写入块大小和对齐方式是扇区大小，簇大小最好。当然，应用程序和存储设备之间的所有层都必须考虑多扇区写入，但大多数开源存储卡驱动程序都缺乏这一点。不要将多扇区写入请求拆分为单扇区写入事务，否则写入吞吐量会变差。
- 努力实现扇区对齐的读/写访问可以消除缓冲数据传输，从而提高读/写性能。除此之外，在 tiny 配置下，缓存的 FAT 数据不会被文件数据传输刷新，因此它可以以较小的内存占用实现与非 tiny 配置相同的性能。
- 如果由于意外故障（例如突然断电、错误移除介质和不可恢复的磁盘错误）而中断对 FAT 卷的写入操作，则卷上的 FAT 结构可能会被破坏。为了最大限度地降低数据丢失的风险，可以通过最小化以写入模式打开文件的时间或使用f_sync函数来最小化临界区
- FatFs 模块不支持对文件的重复打开的读写冲突控制。仅当对文件的每种打开方式都是读取模式时才允许重复打开。始终禁止对文件进行一次或多次写入模式的重复打开，并且打开的文件不得重命名或删除。违反这些规则可能会导致数据冲突。

## 文件系统操作

### mkfs 格式化

```c


/* results:

 *  -1, no space to install fatfs driver

 *  >= 0, there is an space to install fatfs driver

 */

staticintget_disk(rt_device_tid)

{

    int index;


    for (index = 0; index < FF_VOLUMES; index ++)

    {

        if (disk[index] == id)

            return index;

    }


    return -1;

}


intdfs_elm_mkfs(rt_device_tdev_id, constchar *fs_name)

{

    charlogic_nbr[3] = {'0',':', 0};

    MKFS_PARM opt = 

    {

        .fmt = FM_ANY|FM_SFD,

        .n_fat = 0,

        .align = 0,

        .n_root = 0,

        .au_size = 0,

    };


    flag = FSM_STATUS_INIT;

    index = get_disk(dev_id);   //当前是否已经分配驱动

    if (index == -1)

    {

        /* not found the device id */

        index = get_disk(RT_NULL);  //使用第一个进行分配驱动

        fat = (FATFS *)rt_malloc(sizeof(FATFS));

        disk[index] = dev_id;

        /* try to open device */

        rt_device_open(dev_id, RT_DEVICE_OFLAG_RDWR);

        /*  只需在ff.c中填充FatFs[vol]，否则mkfs将失败!

         *  考虑这种情况:您只umount elm fat，然后释放FatFs[index]中的空间，现在在磁盘上执行mkfs，您将得到一个失败。

         *  因此我们在这里需要f_mount，只需在elm FatFS中填充FatFS[index]以使mkfs工作。

         */

        logic_nbr[0] = '0' + index;

        f_mount(fat, logic_nbr, (BYTE)index);

    }

    else

    {

        logic_nbr[0] = '0' + index;

    }


    //临时挂载的驱动需要卸掉

    /* check flag status, we need clear the temp driver stored in disk[] */

    if (flag == FSM_STATUS_USE_TEMP_DRIVER)

    {

        rt_free(fat);

        f_mount(RT_NULL, logic_nbr, (BYTE)index);

        disk[index] = RT_NULL;

        /* close device */

        rt_device_close(dev_id);

    }

}

```

### dfs_elm_mount 挂载

```c

staticintdfs_elm_mount(struct dfs_mnt *mnt, unsignedlongrwflag, constvoid *data)

{

    /* mount fatfs, always 0 logic driver */

    result = f_mount(fat, (const TCHAR *)logic_nbr, 1);

    if (result == FR_OK)

    {

        chardrive[8];

        DIR *dir;


        rt_snprintf(drive, sizeof(drive), "%d:/", index);

        dir = (DIR *)rt_malloc(sizeof(DIR));


        /* open the root directory to test whether the fatfs is valid */

        result = f_opendir(dir, drive);


        /* mount succeed! */

        mnt->data = fat;

        rt_free(dir);

        return RT_EOK;

    }

}

```

### ## 文件操作

## disk驱动

### disk_initialize

### disk_ioctl

| Command          | Description                                                  |

| ---------------- | ------------------------------------------------------------ |

| CTRL_SYNC        | 确保设备已经完成挂起的写进程。如果磁盘I/O层或存储设备具有回写cache，则cache中的脏数据必须立即提交到介质中。如果对介质的每次写操作都在 `disk_write`函数中完成，则此命令无需执行任何操作。 |

| GET_SECTOR_COUNT | 将驱动器上可用扇区数（允许的最大 LBA + 1）检索到 `buff`指向的 `LBA_t`变量中。此命令由 `f_mkfs`和 `f_fdisk函数用于确定要创建的卷/分区的大小。当``FF_USE_MKFS == 1`时需要它。 |

| GET_SECTOR_SIZE  | 将扇区大小（通用读/写的最小数据单元）检索到 `buff`指向的 `WORD`变量中。有效扇区大小为 512、1024、2048 和 4096。仅当 `FF_MAX_SS > FF_MIN_SS`时才需要此命令。当 `FF_MAX_SS == FF_MIN_SS`时，此命令将永远不会使用，读/写功能必须在 `FF_MAX_SS`字节/扇区中工作。 |

| GET_BLOCK_SIZE   | 将闪存介质的*扇区单位擦除块大小检索到* `buff`指向的 `DWORD`变量中。允许值为 1 到 32768 的 2 次方。如果值未知或非闪存介质，则返回 1。此命令仅由 `f_mkfs`函数使用，它会尝试将数据区域对齐到建议的块边界上。当``FF_USE_MKFS == 1`(启用mkfs函数)时需要它。 |

| CTRL_TRIM        | 通知磁盘 I/O 层或存储设备不再需要扇区块上的数据，可以将其擦除。扇区块在 `buff`指向的 `LBA_t`数组 `{<Start LBA>, <End LBA>}`中指定。这是与 ATA 设备的 Trim 相同的命令。如果不支持此功能或不是闪存设备，则此命令无用。FatFs 不会检查结果代码，即使扇区块未被正确擦除，文件功能也不会受到影响。在删除群集链和 f_mkfs 函数中调用此命令 `。当``FF_USE_TRIM == 1`时需要它 |

### get_fattime

- 当前本地时间应以位字段的形式返回，这些位字段打包成DWORD值

## fatfs module

### 杂项

#### IsTerminator 是否终止

```c

#define IsTerminator(c) ((UINT)(c) < (FF_USE_LFN ?' ':'!'))


//根据是否启用长文件名,判断是否为终止符; 启用长文件名时,终止符为' '; 否则为'!'

//根据ASIIC码; ' ' = 32; '!' = 33 小于"!"的都是终止符,认为不为字符串

```

#### get_ldnumber 获取逻辑驱动器号

| 路径名      | FF_FS_RPATH == 0        | FF_FS_RPATH >= 1             |

| ----------- | ----------------------- | ---------------------------- |

| 文件.txt    | 驱动器 0 根目录中的文件 | 当前驱动器的当前目录中的文件 |

| /文件.txt   | 驱动器 0 根目录中的文件 | 当前驱动器根目录中的文件     |

|             | 驱动器 0 的根目录       | 当前驱动器的当前目录         |

| /           | 驱动器 0 的根目录       | 当前驱动器的根目录           |

| 2：         | 驱动器 2 的根目录       | 驱动器 2 的当前目录          |

| 2：/        | 驱动器 2 的根目录       | 驱动器 2 的根目录            |

| 2：文件.txt | 驱动器 2 根目录中的文件 | 驱动器 2 当前目录中的文件    |

| ../文件.txt | 名称无效                | 父目录中的文件               |

| 。          | 名称无效                | 本目录                       |

| ..          | 名称无效                | 当前目录的父目录 (*)         |

| 目录1/..    | 名称无效                | 当前目录                     |

| /..         | 名称无效                | 根目录（位于最顶层）         |

```c

staticintget_ldnumber (   /* Returns logical drive number (-1:invalid drive number or null pointer) */

    const TCHAR** path      /* Pointer to pointer to the path name */

)

{

    tt = tp = *path;

    if (!tp) return vol;    /* Invalid path name? */

    do {                    /* Find a colon in the path */

        tc = *tt++;

    } while (!IsTerminator(tc) && tc != ':');

    //例:可用路径为"2:/" 或 "2:"

    if (tc == ':') {    /* DOS/Windows style volume ID? */

        i = FF_VOLUMES;

        if (IsDigit(*tp) && tp + 2 == tt) { /* Is there a numeric volume ID + colon? */

            i = (int)*tp - '0'; /* Get the LD number */

        }

    }

```

#### Move/Flush disk access window fs缓冲区移动/刷新

```c

/*-----------------------------------------------------------------------*/

/* Move/Flush disk access window in the filesystem object                */

/*-----------------------------------------------------------------------*/

static FRESULT sync_window (    /* Returns FR_OK or FR_DISK_ERR */

    FATFS* fs           /* Filesystem object */

)

{

    FRESULT res = FR_OK;



    if (fs->wflag) {    /* Is the disk access window dirty? */

        if (disk_write(fs->pdrv, fs->win, fs->winsect, 1) == RES_OK) {  /* Write it back into the volume */

            fs->wflag = 0;  /* Clear window dirty flag */

            if (fs->winsect - fs->fatbase < fs->fsize) {    /* Is it in the 1st FAT? */

                if (fs->n_fats == 2) disk_write(fs->pdrv, fs->win, fs->winsect + fs->fsize, 1); /* Reflect it to 2nd FAT if needed */

            }

        } else {

            res = FR_DISK_ERR;

        }

    }

    return res;

}


static FRESULT move_window (    /* Returns FR_OK or FR_DISK_ERR */

    FATFS* fs,      /* Filesystem object */

    LBA_t sect      /* Sector LBA to make appearance in the fs->win[] */

)

{

    FRESULT res = FR_OK;

    if (sect != fs->winsect) {  /* Window offset changed? */

        res = sync_window(fs);      /* Flush the window */

        if (res == FR_OK) {         /* Fill sector window with new data */

            if (disk_read(fs->pdrv, fs->win, sect, 1) != RES_OK) {

                sect = (LBA_t)0 - 1;    /* Invalidate window if read data is not valid */

                res = FR_DISK_ERR;

            }

            fs->winsect = sect;

        }

    }

    return res;

}

```

#### check_fs

/* Check what the sector is */

static UINT check_fs (  /* 0:FAT/FAT32 VBR, 1:exFAT VBR, 2:Not FAT and valid BS, 3:Not FAT and invalid BS, 4:Disk error */

    FATFS* fs,          /* Filesystem object */

    LBA_t sect          /* Sector to load and check if it is an FAT-VBR or not */

)

{

}

### mkfs

```c

FRESULT f_mkfs (

    const TCHAR* path,      /* Logical drive number */

    const MKFS_PARM* opt,   /* Format options */

    void* work,             /* Pointer to working buffer (null: use len bytes of heap memory) */

    UINT len                /* Size of working buffer [byte] */

)

{

    //根据路径获取逻辑驱动器号,挂钩对应的驱动器与分区

    /* Check mounted drive and clear work area */

    vol = get_ldnumber(&path);                  /* Get target logical drive */

    if (vol < 0) return FR_INVALID_DRIVE;

    if (FatFs[vol]) FatFs[vol]->fs_type = 0;    /* Clear the fs object if mounted */

    pdrv = LD2PD(vol);      /* Hosting physical drive */

    ipart = LD2PT(vol);     /* Hosting partition (0:create as new, 1..:existing partition) */


    // 调用外部接口函数执行底层驱动初始化

    /* Initialize the hosting physical drive */

    ds = disk_initialize(pdrv);


    /* Get physical drive parameters (sz_drv, sz_blk and ss) */

    if (!opt) opt = &defopt;    /* Use default parameter if it is not given */

    sz_blk = opt->align;


    /* Options for FAT sub-type and FAT parameters */

    fsopt = opt->fmt & (FM_ANY | FM_SFD);

    // 指定 FAT/FAT32 卷上的 FAT 副本数。此成员的有效值为 1 或 2。默认值 (0) 和任何无效值均返回 1。如果 FAT 类型为 exFAT，则此成员无效。

    n_fat = (opt->n_fat >= 1 && opt->n_fat <= 2) ? opt->n_fat : 1;  //FAT表数量

    //指定 FAT 卷上的根目录条目数。此成员的有效值最大为 32768，并与扇区大小 / 32 对齐。默认值 (0) 和任何无效值均给出 512。如果 FAT 类型为 FAT32 或 exFAT，则此成员无效。

    n_root = (opt->n_root >= 1 && opt->n_root <= 32768 && (opt->n_root % (ss / SZDIRE)) == 0) ? opt->n_root : 512;

    //以字节为单位指定分配单元 (簇) 的大小。有效值为扇区大小和 128 * 扇区大小（对于 FAT/FAT32 卷）之间的 2 的幂，对于 exFAT 卷则最高为 16 MB。如果给出零（默认值）或任何无效值，则该函数将使用取决于卷大小的默认分配单元大小。

    sz_au = (opt->au_size <= 0x1000000 && (opt->au_size & (opt->au_size - 1)) == 0) ? opt->au_size : 0;

    sz_au /= ss;    /* Byte --> Sector */


    if (FF_MULTI_PARTITION && ipart != 0) { /* Is the volume associated with any specific partition? */

        /* Get partition location from the existing partition table */

        if (disk_read(pdrv, buf, 0, 1) != RES_OK) LEAVE_MKFS(FR_DISK_ERR);  /* Load MBR */

        if (ld_word(buf + BS_55AA) != 0xAA55) LEAVE_MKFS(FR_MKFS_ABORTED);  /* Check if MBR is valid */


        {   /* Get the partition location from MBR partition table */

            pte = buf + (MBR_Table + (ipart - 1) * SZ_PTE);

            if (ipart > 4 || pte[PTE_System] == 0) LEAVE_MKFS(FR_MKFS_ABORTED); /* No partition? */

            b_vol = ld_dword(pte + PTE_StLba);      /* Get volume start sector */

            sz_vol = ld_dword(pte + PTE_SizLba);    /* Get volume size */

        }

    } else {

        {   /* Partitioning is in MBR */

            #define N_SEC_TRACK 63          /* Sectors per track for determination of drive CHS */

            //前0~63 为引导扇区

            if (sz_vol > N_SEC_TRACK) {

                b_vol = N_SEC_TRACK; 

                sz_vol -= b_vol;    /* Estimated partition offset and size */

            }

        }

    }


    if (sz_vol < 128) LEAVE_MKFS(FR_MKFS_ABORTED);  /* Check if volume size is >=128s */


    {   /* Create an FAT/FAT32 volume */

        do {

            pau = sz_au;

            /* Pre-determine number of clusters and FAT sub-type */

            if (fsty == FS_FAT32) { /* FAT32 volume */

                if (pau == 0) { /* AU auto-selection */

                    n = (DWORD)sz_vol / 0x20000;    /* Volume size in unit of 128KS */

                    for (i = 0, pau = 1; cst32[i] && cst32[i] <= n; i++, pau <<= 1) ;   /* Get from table */

                }

                n_clst = (DWORD)sz_vol / pau;   /* Number of clusters */

                sz_fat = (n_clst * 4 + 8 + ss - 1) / ss;    /* FAT size [sector] */

                sz_rsv = 32;    /* Number of reserved sectors */

                sz_dir = 0;     /* No static directory */

                if (n_clst <= MAX_FAT16 || n_clst > MAX_FAT32) LEAVE_MKFS(FR_MKFS_ABORTED);

            } else {                /* FAT volume */

                if (pau == 0) { /* au auto-selection */

                    n = (DWORD)sz_vol / 0x1000; /* Volume size in unit of 4KS */

                    for (i = 0, pau = 1; cst[i] && cst[i] <= n; i++, pau <<= 1) ;   /* Get from table */

                }

                n_clst = (DWORD)sz_vol / pau;

                // 每个簇的信息由一个12位或16位的条目来表示。对于FAT12，每个簇占用1.5个字节（即12位），因此计算FAT大小的公式变得稍微复杂一些。

                if (n_clst > MAX_FAT12) {

                    n = n_clst * 2 + 4;     /* FAT size [byte] */

                } else {

                    fsty = FS_FAT12;

                    n = (n_clst * 3 + 1) / 2 + 3;   /* FAT size [byte] */

                }

                sz_fat = (n + ss - 1) / ss;     /* FAT size [sector] */

                sz_rsv = 1;                     /* Number of reserved sectors */

                sz_dir = (DWORD)n_root * SZDIRE / ss;   /* Root dir size [sector] */

            }

            b_fat = b_vol + sz_rsv;                     /* FAT base */

            b_data = b_fat + sz_fat * n_fat + sz_dir;   /* Data base */

            /* Ok, it is the valid cluster configuration */

            break;

        } while (1);

    }


    /* Update partition information */

    if (FF_MULTI_PARTITION && ipart != 0) { /* Volume is in the existing partition */

        if (!FF_LBA64 || !(fsopt & 0x80)) { /* Is the partition in MBR? */

            /* Update system ID in the partition table */

            if (disk_read(pdrv, buf, 0, 1) != RES_OK) LEAVE_MKFS(FR_DISK_ERR);  /* Read the MBR */

            buf[MBR_Table + (ipart - 1) * SZ_PTE + PTE_System] = sys;           /* Set system ID */

            if (disk_write(pdrv, buf, 0, 1) != RES_OK) LEAVE_MKFS(FR_DISK_ERR); /* Write it back to the MBR */

        }

    } else {                                /* Volume as a new single partition */

        if (!(fsopt & FM_SFD)) {            /* Create partition table if not in SFD format */

            lba[0] = sz_vol; lba[1] = 0;

            res = create_partition(pdrv, lba, sys, buf);

            if (res != FR_OK) LEAVE_MKFS(res);

        }

    }

}


/* Create partitions on the physical drive in format of MBR or GPT */


static FRESULT create_partition (

    BYTE drv,           /* Physical drive number */

    constLBA_tplst[], /* Partition list */

    BYTE sys,           /* System ID for each partition (for only MBR) */

    BYTE *buf           /* Working buffer for a sector */

)

{


}

```

### f_mount

```c

/*-----------------------------------------------------------------------*/

/* Mount/Unmount a Logical Drive                                         */

/*-----------------------------------------------------------------------*/


FRESULT f_mount (

    FATFS* fs,          /* Pointer to the filesystem object to be registered (NULL:unmount)*/

    const TCHAR* path,  /* Logical drive number to be mounted/unmounted */

    BYTE opt            /* Mount option: 0=Do not mount (delayed mount), 1=Mount immediately */

)

{

    if (opt == 0) return FR_OK; /* Do not mount now, it will be mounted in subsequent file functions */


    res = mount_volume(&path, &fs, 0);  /* Force mounted the volume */

}


/*-----------------------------------------------------------------------*/

/* Determine logical drive number and mount the volume if needed         */

/*-----------------------------------------------------------------------*/

// 读取扇区信息,更新fs对象信息

static FRESULT mount_volume (   /* FR_OK(0): successful, !=0: an error occurred */

    const TCHAR** path,         /* Pointer to pointer to the path name (drive number) */

    FATFS** rfs,                /* Pointer to pointer to the found filesystem object */

    BYTE mode                   /* Desiered access mode to check write protection */

)

{

    mode &= (BYTE)~FA_READ;             /* Desired access mode, write access or not */

    if (fs->fs_type != 0) {             /* If the volume has been mounted */

        stat = disk_status(fs->pdrv);

        if (!(stat & STA_NOINIT)) {     /* and the physical drive is kept initialized */

            if (!FF_FS_READONLY && mode && (stat & STA_PROTECT)) {  /* Check write protection if needed */

                return FR_WRITE_PROTECTED;

            }

            return FR_OK;               /* The filesystem object is already valid */

        }

    }


    /* The filesystem object is not valid. */

    /* Following code attempts to mount the volume. (find an FAT volume, analyze the BPB and initialize the filesystem object) */


    fs->fs_type = 0;                    /* Invalidate the filesystem object */

    stat = disk_initialize(fs->pdrv);   /* Initialize the volume hosting physical drive */

    if (stat & STA_NOINIT) {            /* Check if the initialization succeeded */

        return FR_NOT_READY;            /* Failed to initialize due to no medium or hard error */

    }

    /* Find an FAT volume on the hosting drive */

    fmt = find_volume(fs, LD2PT(vol));

}


/*-----------------------------------------------------------------------*/

/* Load a sector and check if it is an FAT VBR                           */

/*-----------------------------------------------------------------------*/


/* Check what the sector is */


static UINT check_fs (  /* 0:FAT/FAT32 VBR, 1:exFAT VBR, 2:Not FAT and valid BS, 3:Not FAT and invalid BS, 4:Disk error */

    FATFS* fs,          /* Filesystem object */

    LBA_t sect          /* Sector to load and check if it is an FAT-VBR or not */

)

{

    //读取指定扇区信息

    //检查是否为FAT/FAT32 VBR

}


/* Find an FAT volume */

/* (It supports only generic partitioning rules, MBR, GPT and SFD) */


static UINT find_volume (   /* Returns BS status found in the hosting drive */

    FATFS* fs,      /* Filesystem object */

    UINT part       /* Partition to fined = 0:find as SFD and partitions, >0:forced partition number */

)

{

    fmt = check_fs(fs, 0);              /* Load sector 0 and check if it is an FAT VBR as SFD format */

}

```

### f_opendir

```c

/*-----------------------------------------------------------------------*/

/* Create a Directory Object                                             */

/*-----------------------------------------------------------------------*/


FRESULT f_opendir (

    DIR* dp,            /* Pointer to directory object to create */

    const TCHAR* path   /* Pointer to the directory path */

)

{

    /* Get logical drive */

    res = mount_volume(&path, &fs, 0);

    if (res == FR_OK) {

        dp->obj.fs = fs;    //挂钩目录的文件系统

    }

}

```

### f_write

- 写入时,将整块的扇区数据写入物理媒介中;
- 非整块数据存入缓存中,等待下一次写入时存满整个扇区再写入物理媒介中;
- 除非是进行修改之前存储数据,才会立刻写入
- 如果启用TINTY模式,则写入后立刻更新文件信息;否则等到关闭文件时更新文件信息或者主动调用f_sync函数

```c

/*-----------------------------------------------------------------------*/

/* Write File                                                            */

/*-----------------------------------------------------------------------*/


FRESULT f_write (

    FIL* fp,            /* Open file to be written */

    constvoid* buff,   /* Data to be written */

    UINT btw,           /* Number of bytes to write */

    UINT* bw            /* Number of bytes written */

)

{

}

```

### f_read

- 成块数据直接读取
- 非成块数据,先读取整块数据,再从缓存中读取拼接

```c


```

### f_sync

- 立刻更新文件信息

```c


```

### f_close

- 调用f_sync函数,立刻更新文件信息

```c


```

### f_open

- 打开文件
- 并且更新文件信息

