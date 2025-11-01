---
title: DFS
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: dc9314c3
date: 2025-10-03 09:44:51
---
# DFS 虚拟文件系统

https://www.rt-thread.org/document/site/#/rt-thread-version/rt-thread-standard/programming-manual/filesystem/filesystem

```

FatFS 是专为小型嵌入式设备开发的一个兼容微软 FAT 格式的文件系统，采用 ANSI C 编写，具有良好的硬件无关性以及可移植性，是 RT-Thread 中最常用的文件系统类型。


传统型的 RomFS 文件系统是一种简单的、紧凑的、只读的文件系统，不支持动态擦写保存，按顺序存放数据，因而支持应用程序以 XIP(execute In Place，片内运行) 方式运行，在系统运行时, 节省 RAM 空间。


Jffs2 文件系统是一种日志闪存文件系统。主要用于 NOR 型闪存，基于 MTD 驱动层，特点是：可读写的、支持数据压缩的、基于哈希表的日志型文件系统，并提供了崩溃 / 掉电安全保护，提供写平衡支持等。


DevFS 即设备文件系统，在 RT-Thread 操作系统中开启该功能后，可以将系统中的设备在 /dev 文件夹下虚拟成文件，使得设备可以按照文件的操作方式使用 read、write 等接口进行操作。


NFS 网络文件系统（Network File System）是一项在不同机器、不同操作系统之间通过网络共享文件的技术。在操作系统的开发调试阶段，可以利用该技术在主机上建立基于 NFS 的根文件系统，挂载到嵌入式设备上，可以很方便地修改根文件系统的内容。


UFFS 是 Ultra-low-cost Flash File System（超低功耗的闪存文件系统）的简称。它是国人开发的、专为嵌入式设备等小内存环境中使用 Nand Flash 的开源文件系统。与嵌入式中常使用的 Yaffs 文件系统相比具有资源占用少、启动速度快、免费等优势。

```

## 初始化

1.`dfs_init` 初始化

-`fslock` 互斥锁(文件系统锁) `fdlock` 互斥锁(文件锁);

- 执行 `dfs_dentry_init`

初始化 `hash_head.head`链表

## 注册与卸载

1.`dfs_register` 注册文件系统

- 一般在初始化时调用,由各文件系统自行注册调用

```c

struct dfs_filesystem_type

{

    conststruct dfs_filesystem_ops *fs_ops;

    struct dfs_filesystem_type *next;

};


staticstruct dfs_filesystem_type *file_systems = NULL;


staticstruct dfs_filesystem_type **_find_filesystem(constchar *name)

{

    struct dfs_filesystem_type **type;

    //寻找链表中是否存在相同的文件系统

    for (type = &file_systems; *type; type = &(*type)->next)

    {

        if (strcmp((*type)->fs_ops->name, name) == 0)

            break;

    }

    //返回文件系统指针

    return type;

}


intdfs_register(struct dfs_filesystem_type *fs)

{

    int ret = 0;

    //寻找是否已经注册

    struct dfs_filesystem_type **type = _find_filesystem(fs->fs_ops->name);


    LOG_D("register %s file system.", fs->fs_ops->name);


    if (*type)

    {

        //已经注册,返回错误

        ret = -EBUSY;

    }

    else

    {

        //如果没有注册,则注册

        *type = fs;

    }


    return ret;

}

```

## 格式化(创建指定类型的文件系统)

- mkfs

```c

intdfs_mkfs(constchar *fs_name, constchar *device_name)

{

    rt_device_t dev_id = NULL;

    struct dfs_filesystem_type *type;

    int ret = -RT_ERROR;


    type = *_find_filesystem(fs_name);

    if (!type)

    {

        rt_kprintf("no file system: %s found!\n", fs_name);

        return ret;

    }

    else

    {

        if (type->fs_ops->flags & FS_NEED_DEVICE)

        {

            /* check device name, and it should not be NULL */

            if (device_name != NULL)

                dev_id = rt_device_find(device_name);


            if (dev_id == NULL)

            {

                rt_set_errno(-ENODEV);

                rt_kprintf("Device (%s) was not found", device_name);

                return ret;

            }

        }

        else

        {

            dev_id = RT_NULL;

        }

    }


    if (type->fs_ops->mkfs)

    {

        ret = type->fs_ops->mkfs(dev_id, type->fs_ops->name);

#ifdef RT_USING_PAGECACHE

        if (ret == RT_EOK)

        {

            struct dfs_mnt *mnt = RT_NULL;


            mnt = dfs_mnt_dev_lookup(dev_id);

            if (mnt)

            {

                dfs_pcache_unmount(mnt);

            }

        }

#endif

    }


    return ret;

}

```

## 挂载(挂载指定设备到指定目录)

挂载是指将一个存储设备挂接到一个已存在的路径上。我们要访问存储设备中的文件，必须将文件所在的分区挂载到一个已存在的路径上，然后通过这个路径来访问存储设备

```c

/*

 *    parent(mount path)

 *    mnt_parent <- - - - - - -  +

 *         |                     |

 *         |- mnt_child <- - - - - -+ (1 refcount)

 *                 |             |

 *                 |- parent - - + (1 refcount)

 */

intdfs_mount(constchar *device_name,

              constchar *path,

              constchar *filesystemtype,

              unsignedlongrwflag,

              constvoid *data)

{


    struct dfs_filesystem_type *type = *_find_filesystem(filesystemtype);


    if (type)

    {

        //对于路径进行规范化,内部使用malloc,需要注意释放

        fullpath = dfs_normalize_path(RT_NULL, path);

        if (fullpath)

        {

            /* open specific device */

            if (device_name) dev_id = rt_device_find(device_name);

            //不需要设备支持的文件系统 或者 设备存在

            if (!(type->fs_ops->flags & FS_NEED_DEVICE) ||

                ((type->fs_ops->flags & FS_NEED_DEVICE) && dev_id))

            {

                mnt_parent = dfs_mnt_lookup(fullpath);

                if ((!mnt_parent && (strcmp(fullpath, "/") == 0 || strcmp(fullpath, "/dev") == 0))

                    || (mnt_parent && strcmp(fullpath, "/") == 0 && strcmp(mnt_parent->fullpath, fullpath) != 0))

                {

                    /* it's the root file system */

                    /* the mount point dentry is the same as root dentry. */

                    mnt_parent = dfs_mnt_create(fullpath); /* mnt->ref_count should be 1. */

                    if (mnt_parent)

                    {

                        mnt_parent->fs_ops = type->fs_ops;

                        mnt_parent->dev_id = dev_id;

                        if (mnt_parent->fs_ops->mount)

                        {

                            ret = mnt_parent->fs_ops->mount(mnt_parent, rwflag, data);

                            if (ret == RT_EOK)

                            {

                                mnt_child = mnt_parent;

                                mnt_child->flags |= MNT_IS_MOUNTED;

                                dfs_mnt_insert(RT_NULL, mnt_child);

                                dfs_mnt_unref(mnt_parent);

                                /*

                                * About root mnt:

                                * There are two ref_count:

                                * 1. the gobal root reference.

                                * 1. the mnt->parent reference.

                                */

                            }

                            else

                            {

                                dfs_mnt_destroy(mnt_parent);

                                mnt_parent = RT_NULL;

                                rt_set_errno(EPERM);

                            }

                        }

                        else

                        {

                            dfs_mnt_destroy(mnt_parent);

                            mnt_parent = RT_NULL;

                            rt_set_errno(EIO);

                        }

                    }

                }

            }

        }

    }

}

```

## mnt挂载点

```c

/*

 * mnt tree structure

 *

 * mnt_root <----------------------------------------+

 *   | (child)                +----------+           |

 *   v          (sibling)     v          |           |

 *   mnt_child0     ->    mnt_child1     |           |

 *                            | (child)  |           |

 *                            v         / (parent)   | (root)

 *                            mnt_child10         ---/

 *

 */

```

### mnt创建

```c

struct dfs_mnt *dfs_mnt_create(constchar *path)

{

    struct dfs_mnt *mnt = rt_calloc(1, sizeof(struct dfs_mnt));


    mnt->fullpath = rt_strdup(path);        //alloc路径

    rt_list_init(&mnt->sibling);            //初始化兄弟节点

    rt_list_init(&mnt->child);              //初始化子节点

    mnt->flags |= MNT_IS_ALLOCED;           //设置标志,已分配

    rt_atomic_store(&(mnt->ref_count), 1);  //引用计数


    return mnt;

}

```

### mnt销毁

```c

intdfs_mnt_destroy(struct dfs_mnt* mnt)

{

    if (mnt->flags & MNT_IS_MOUNTED)

    {

        if (mnt->flags & MNT_IS_ADDLIST)

        {

            dfs_mnt_remove(mnt);

        }

    }


    dfs_mnt_unref(mnt);

}


/* remove mnt from mnt_tree */

intdfs_mnt_remove(struct dfs_mnt* mnt)

{

    //没有子节点,执行删除兄弟节点

    if (rt_list_isempty(&mnt->child))

    {

        rt_list_remove(&mnt->sibling);

        if (mnt->parent)

        {

            /* parent unref parent */

            rt_atomic_sub(&(mnt->parent->ref_count), 1);

        }


        ret = RT_EOK;

    }

    else

    {

        //有子节点,返回错误

        LOG_W("remove a mnt point:%s with child.", mnt->fullpath);

    }


    return ret;

}


intdfs_mnt_unref(struct dfs_mnt* mnt)

{

    if (mnt)

    {

        rt_atomic_sub(&(mnt->ref_count), 1);


        if (rt_atomic_load(&(mnt->ref_count)) == 0)

        {

            dfs_lock();


            if (mnt->flags & MNT_IS_UMOUNT)

            {

                mnt->fs_ops->umount(mnt);

            }


            /* free full path */

            rt_free(mnt->fullpath);

            mnt->fullpath = RT_NULL;

            rt_free(mnt);


            dfs_unlock();

        }

        else

        {

            DLOG(note, "mnt", "mnt(%s),ref_count=%d", mnt->fs_ops->name, rt_atomic_load(&(mnt->ref_count)));

        }

    }

}

```

### mnt查找

```c

/**

 * this function will return the file system mounted on specified path.

 *

 * @parampath the specified path string.

 *

 * @return the found file system or NULL if no file system mounted on

 * specified path

 */

struct dfs_mnt *dfs_mnt_lookup(constchar *fullpath)

{

    struct dfs_mnt *mnt = _root_mnt;

    struct dfs_mnt *iter = RT_NULL;


    if (mnt)

    {

        int mnt_len = rt_strlen(mnt->fullpath);


        dfs_lock();

        if ((strncmp(mnt->fullpath, fullpath, mnt_len) == 0) && //路径匹配

            (mnt_len == 1 || (fullpath[mnt_len] == '\0') || (fullpath[mnt_len] == '/'))) //根路径或者具有子目录或者路径结束

        {

            //挂载点存在子节点

            while (!rt_list_isempty(&mnt->child))

            {

                //遍历寻找匹配的子节点

                rt_list_for_each_entry(iter, &mnt->child, sibling)

                {

                    mnt_len = rt_strlen(iter->fullpath);

                    if ((strncmp(iter->fullpath, fullpath, mnt_len) == 0) &&

                        ((fullpath[mnt_len] == '\0') || (fullpath[mnt_len] == '/')))

                    {

                        mnt = iter;

                        break;

                    }

                }


                if (mnt != iter) break;

            }

        }

        else

        {

            mnt = RT_NULL;

        }

        dfs_unlock();


        if (mnt)

        {

            LOG_D("mnt_lookup: %s path @ mount point %p", fullpath, mnt);

            DLOG(note, "mnt", "found mnt(%s)", mnt->fs_ops->name);

        }

    }


    return mnt;

}

```

### mnt插入

```c

intdfs_mnt_insert(struct dfs_mnt* mnt, struct dfs_mnt* child)

{

    if (child)

    {

        if (mnt == RT_NULL)

        {

            /* insert into root */

            mnt = dfs_mnt_lookup(child->fullpath);

            if (mnt == RT_NULL //找不到该路径

            || (strcmp(child->fullpath, "/") == 0)) //插入为根路径

            {

                /* it's root mnt */

                mnt = child;

                mnt->flags |= MNT_IS_LOCKED;


                /* ref to gobal root */

                if (_root_mnt)

                {

                    child = _root_mnt;

                    rt_atomic_sub(&(_root_mnt->parent->ref_count), 1);

                    rt_atomic_sub(&(_root_mnt->ref_count), 1);


                    _root_mnt = dfs_mnt_ref(mnt);

                    mnt->parent = dfs_mnt_ref(mnt);

                    mnt->flags |= MNT_IS_ADDLIST;


                    mkdir("/dev", 0777);

                }

                else

                {

                    //根路径不存在,直接赋值当前mnt挂载点为根路径

                    _root_mnt = dfs_mnt_ref(mnt);//引用次数+1

                }

            }

        }


        if (mnt)

        {

            child->flags |= MNT_IS_ADDLIST;

            if (child != mnt)

            {

                /* not the root, insert into the child list */

                rt_list_insert_before(&mnt->child, &child->sibling);

                /* child ref self */

                dfs_mnt_ref(child);

            }

            /* parent ref parent */

            child->parent = dfs_mnt_ref(mnt);

        }

    }


    return0;

}

```

### mnt搜索

```c

staticstruct dfs_mnt* _dfs_mnt_foreach(struct dfs_mnt *mnt, struct dfs_mnt* (*func)(struct dfs_mnt *mnt, void *parameter), void *parameter)

{

    struct dfs_mnt *iter, *ret = NULL;


    if (mnt)

    {

        //执行注册的函数

        ret = func(mnt, parameter);

        if (ret == RT_NULL)

        {

            //具有子节点

            if (!rt_list_isempty(&mnt->child))

            {

                //遍历子节点的兄弟节点,都执行一次注册的函数

                rt_list_for_each_entry(iter, &mnt->child, sibling)

                {

                    ret = _dfs_mnt_foreach(iter, func, parameter);

                    if (ret != RT_NULL)

                    {

                        break;

                    }

                }

            }

        }

    }

    else

    {

        ret = RT_NULL;

    }


    return ret;

}

```

## posix接口

- 权限:

```c

//用户权限 R:读取 W:写入 X:执行

#define S_IRWXU              00700

#define S_IRUSR              00400

#define S_IWUSR              00200

#define S_IXUSR              00100

//XG:eXecute Group

//组权限

#define S_IRWXG              00070

#define S_IRGRP              00040

#define S_IWGRP              00020

#define S_IXGRP              00010

//其他用户权限

#define S_IRWXO              00007

#define S_IROTH              00004

#define S_IWOTH              00002

#define S_IXOTH              00001

```

### mkdir 创建目录

```c

/**

 * this function is a POSIX compliant version, which will make a directory

 *

 * @parampath the directory path to be made.

 * @parammode

 *

 * @return 0 on successful, others on failed.

 */

intmkdir(constchar *path, mode_tmode)

{

    int result;

    struct stat stat;

    struct dfs_file file;


    if (path == NULL)

    {

        rt_set_errno(-EBADF);

        return -1;

    }

    //dfs_file_lstat == 0,证明该目录已经存在

    if (path && dfs_file_lstat(path, &stat) == 0)

    {

        rt_set_errno(-EEXIST);

        return -1;

    }


    dfs_file_init(&file);


    result = dfs_file_open(&file, path, O_DIRECTORY | O_CREAT, mode);

    if (result >= 0)

    {

        dfs_file_close(&file);

        result = 0;

    }

    else

    {

        rt_set_errno(result);

        result = -1;

    }


    dfs_file_deinit(&file);


    return result;

}

```

### open && openat && close

- open:根据路径打开文件
- openat:根据相对路径打开文件

```c

/**

 * this function is a POSIX compliant version, which will open a file and

 * return a file descriptor according specified flags.

 *

 * @paramfile the path name of file.

 * @paramflags the file open flags.

 *

 * @return the non-negative integer on successful open, others for failed.

 */

intopen(constchar *file, intflags, ...)

{

    fd = fd_new();

    if (fd >= 0)

    {

        df = fd_get(fd);

    }

    else

    {

        rt_set_errno(-RT_ERROR);

        return RT_NULL;

    }


    result = dfs_file_open(df, file, flags, mode);

    if (result < 0)

    {

        fd_release(fd);

        rt_set_errno(result);

        return -1;

    }


    return fd;

}

```

### utimensat 修改文件时间

```c

intutimensat(int__fd, constchar *__path, conststruct timespec __times[2], int__flags)

{

    int ret;

    struct stat buffer;

    struct dfs_file *d;

    char *fullpath;

    struct dfs_attr attr;

    time_t current_time;

    char *link_fn = (char *)rt_malloc(DFS_PATH_MAX);

    int err;


    if (__path == NULL)

    {

        return -EFAULT;

    }

    //1. 获取文件路径

    if (__path[0] == '/' || __fd == AT_FDCWD)

    {

        if (stat(__path, &buffer) < 0)

        {

            return -ENOENT;

        }

        else

        {

            fullpath = (char*)__path;

        }

    }

    else

    {

        if (__fd != AT_FDCWD)

        {

            d = fd_get(__fd);

            if (!d || !d->vnode)

            {

                return -EBADF;

            }


            fullpath = dfs_dentry_full_path(d->dentry);

            if (!fullpath)

            {

                rt_set_errno(-ENOMEM);

                return -1;

            }

        }

    }


    //2. update time

    attr.ia_valid = ATTR_ATIME_SET | ATTR_MTIME_SET;

    time(&current_time);

    if (UTIME_NOW == __times[0].tv_nsec)

    {

        attr.ia_atime.tv_sec = current_time;

    }

    elseif (UTIME_OMIT != __times[0].tv_nsec)

    {

        attr.ia_atime.tv_sec = __times[0].tv_sec;

    }

    else

    {

        attr.ia_valid &= ~ATTR_ATIME_SET;

    }


    if (UTIME_NOW == __times[1].tv_nsec)

    {

        attr.ia_mtime.tv_sec = current_time;

    }

    elseif (UTIME_OMIT == __times[1].tv_nsec)

    {

        attr.ia_mtime.tv_sec = __times[1].tv_sec;

    }

    else

    {

        attr.ia_valid &= ~ATTR_MTIME_SET;

    }

    // 3. 获取文件属性

    if (dfs_file_lstat(fullpath, &buffer) == 0)

    {

        if (S_ISLNK(buffer.st_mode) && (__flags != AT_SYMLINK_NOFOLLOW))

        {

            if (link_fn)

            {

                err = dfs_file_readlink(fullpath, link_fn, DFS_PATH_MAX);

                if (err < 0)

                {

                    rt_free(link_fn);

                    return -ENOENT;

                }

                else

                {

                    fullpath = link_fn;

                    if (dfs_file_stat(fullpath, &buffer) != 0)

                    {

                        rt_free(link_fn);

                        return -ENOENT;

                    }

                }

            }


        }

    }

    // 4. 设置文件属性

    attr.st_mode = buffer.st_mode;

    ret = dfs_file_setattr(fullpath, &attr);

    rt_free(link_fn);


    return ret;

}

```

### read && write

```c

dfs_file_read

dfs_file_write

```

### lseek

### rmdir

```c

        dir = opendir(pathname);


        while (1)

        {

            dirent = readdir(dir);

            if (dirent == RT_NULL)

                break;

            if (rt_strcmp(".", dirent->d_name) != 0 &&

                rt_strcmp("..", dirent->d_name) != 0)

            {

                break;

            }

        }


        closedir(dir);

```

### opendir

```c

DIR *opendir(constchar *name)

{

    fd = fd_new();

    file = fd_get(fd);

    result = dfs_file_open(file, name, O_RDONLY | O_DIRECTORY, 0);//通过文件的方式创建目录

    /* open successfully */

    t = (DIR *) rt_malloc(sizeof(DIR));

    rt_memset(t, 0, sizeof(DIR));

    t->fd = fd;

}

```

### ## 文件操作

### stat(文件状态查询)

```c

//https://en.wikibooks.org/wiki/C_Programming/POSIX_Reference/sys/stat.h

struct stat

{

    dev_t st_dev;              // 文件的设备编号

    uint16_t  st_ino;          // 节点

    uint16_t  st_mode;         // 文件的类型和存取的权限

    uint16_t  st_nlink;        // 连接到该文件的硬连接数目，刚建立的文件值为1

    uint16_t  st_uid;          // 用户ID

    uint16_t  st_gid;          // 组ID

    struct rt_device *st_rdev; // 设备类型，若此文件为设备文件，则为其设备编号

    uint32_t  st_size;         // 文件字节数（如果文件是常规文件或者目录）

    time_t    st_atime;        // 文件最后一次被访问或者被执行的时间

    long      st_spare1;       // 未使用

    time_t    st_mtime;        // 文件内容最后一次被修改的时间

    long      st_spare2;       // 未使用

    time_t    st_ctime;        // 文件状态最后一次改变的时间

    long      st_spare3;       // 未使用

    uint32_t  st_blksize;      // 块大小（文件系统的I/O 缓冲区大小）

    uint32_t  st_blocks;       // 块数

    long      st_spare4[2];    // 未使用

};

```

-`dfs_file_stat` : 查询文件状态,使用 `DFS_REALPATH_EXCEPT_NONE`获取文件路径

```c

dfs_file_realpath(&mnt, fullpath, DFS_REALPATH_EXCEPT_NONE);

```

-`dfs_file_lstat` : 查询文件状态,使用 `DFS_REALPATH_EXCEPT_LAST`获取文件目录的路径

```c

dfs_file_realpath(&mnt, fullpath, DFS_REALPATH_EXCEPT_LAST);

```

### init && deinit

```c

voiddfs_file_init(struct dfs_file *file)

{

    if (file)

    {

        rt_memset(file, 0x00, sizeof(struct dfs_file));

        file->magic = DFS_FD_MAGIC;

        rt_mutex_init(&file->pos_lock, "fpos", RT_IPC_FLAG_PRIO);

        rt_atomic_store(&(file->ref_count), 1);

    }

}


voiddfs_file_deinit(struct dfs_file *file)

{

    if (file)

    {

        rt_mutex_detach(&file->pos_lock);

    }

}

```

### open && close

```c

/**

 * this function will open a file which specified by path with specified oflags.

 *

 * @paramfd the file descriptor pointer to return the corresponding result.

 * @parampath the specified file path.

 * @paramoflags the oflags for open operator.

 *

 * @return 0 on successful, -1 on failed.

 */

intdfs_file_open(struct dfs_file *file, constchar *path, intoflags, mode_tmode)

{

    //1. 找到路径的挂载点,并获取文件目录

    dentry = dfs_dentry_lookup(mnt, fullpath, oflags);

    if (dentry && dentry->vnode->type == FT_SYMLINK)    //链接文件,类似与快捷方式

    {

        /* it's a symbol link but not follow */

        if (oflags & O_NOFOLLOW)

        {

            /* no follow symbol link */

            dfs_dentry_unref(dentry);

            dentry = RT_NULL;

        }

        else

        {

            struct dfs_dentry *target_dentry = RT_NULL;

            char *path = dfs_file_realpath(&mnt, fullpath, DFS_REALPATH_ONLY_LAST);

            if (path)

            {

                target_dentry = dfs_dentry_lookup(mnt, path, oflags);

                rt_free(path);

            }

            dfs_dentry_unref(dentry);

            dentry = target_dentry;

        }

    }

    //2. 创建文件/目录

    if (oflags & O_CREAT)

    {

        dfs_file_lock();

        dentry = dfs_dentry_create(mnt, fullpath);

        if (dentry)

        {

            vnode = mnt->fs_ops->create_vnode(dentry, oflags & O_DIRECTORY ? FT_DIRECTORY:FT_REGULAR, mode);


            if (vnode)

            {

                /* set vnode */

                dentry->vnode = vnode;  /* the refcount of created vnode is 1. no need to reference */

                dfs_dentry_insert(dentry);

            }

            else

            {

                DLOG(msg, mnt->fs_ops->name, "dfs_file", DLOG_MSG_RET, "create failed.");

                dfs_dentry_unref(dentry);

                dentry = RT_NULL;

            }

        }

        dfs_file_unlock();

    }

    //3. 将文件放在目录下

    if (dentry)

    {

        rt_bool_t permission = RT_TRUE;

        //文件的目录

        file->dentry = dentry;

        file->vnode = dentry->vnode;

        file->fops  = dentry->mnt->fs_ops->default_fops;

        file->flags = oflags;


        dfs_file_lock();

        ret = file->fops->open(file);

        dfs_file_unlock();

    }

}

```

```c

intdfs_file_close(struct dfs_file *file)

{

    int ret = -RT_ERROR;


    if (file)

    {

        if (dfs_file_lock() == RT_EOK)

        {

            rt_atomic_t ref_count = rt_atomic_load(&(file->ref_count));

            //引用计数为1进入关闭流程

            if (ref_count == 1 && file->fops && file->fops->close)

            {

                ret = file->fops->close(file);


                if (ret == 0) /* close file sucessfully */

                {

                    dfs_file_unref(file);

                }

            }

            else

            {

                //还有引用, 减少引用

                dfs_file_unref(file);

                ret = 0;

            }

            dfs_file_unlock();

        }

    }


    return ret;

}

```

### read && write

- write不允许指定位置写入,只能顺序写入;pwrite允许指定位置写入
- write和read都会对文件的位置进行加锁,防止多线程操作文件时出现问题
- 实际使用过程中,如果具有多线程操作文件的需求,可以使用 `pwrite`和 `pread`进行操作

```c

ssize_tdfs_file_read(struct dfs_file *file, void *buf, size_tlen)

{

    /* fpos lock */

    off_t pos = dfs_file_get_fpos(file);

    ret = file->fops->read(file, buf, len, &pos);

    /* fpos unlock */

    dfs_file_set_fpos(file, pos);

}


ssize_tdfs_file_write(struct dfs_file *file, constvoid *buf, size_tlen)

{

    /* fpos lock */

    pos = dfs_file_get_fpos(file);

    {

        ret = file->fops->write(file, buf, len, &pos);

    }


    if (file->flags & O_SYNC)

    {

        file->fops->flush(file);

    }

    dfs_file_set_fpos(file, pos);

}

```

### lseek

## 目录操作

- 目录结构体中挂载链表,挂载 `vnode`节点参数

-`vnode`节点对 `File types`进行统一抽象

```c

/* File types */

#define FT_REGULAR      0   /* regular file */

#define FT_SOCKET       1   /* socket file  */

#define FT_DIRECTORY    2   /* directory    */

#define FT_USER         3   /* user defined */

#define FT_DEVICE       4   /* device */

#define FT_SYMLINK      5   /* symbol link */

#define FT_NONLOCK      6   /* non lock */


struct dfs_vnode

{

    uint16_t type;               /* Type (regular or socket) */


    char *path;                  /* Name (below mount point) */

    char *fullpath;              /* Full path is hash key */

    int ref_count;               /* Descriptor reference count */

    rt_list_t list;              /* The node of vnode hash table */


    struct dfs_filesystem *fs;

    conststruct dfs_file_ops *fops;

    uint32_t flags;              /* self flags, is dir etc.. */


    size_t   size;               /* Size in bytes */

    void *data;                  /* Specific file system data */

};


struct dfs_dentry

{

    rt_list_t hashlist;


    uint32_t flags;


#define DENTRY_IS_MOUNTED   0x1 /* dentry is mounted */

#define DENTRY_IS_ALLOCED   0x2 /* dentry is allocated */

#define DENTRY_IS_ADDHASH   0x4 /* dentry was added into hash table */

#define DENTRY_IS_OPENED    0x8 /* dentry was opened. */

    char *pathname;             /* the pathname under mounted file sytem */


    struct dfs_vnode *vnode;    /* the vnode of this dentry */

    struct dfs_mnt *mnt;        /* which mounted file system does this dentry belong to */


    rt_atomic_t ref_count;    /* the reference count */

};

```

### 哈希表

- 对路径进行hash,并根据挂载点进行hash并取模 `DFS_DENTRY_HASH_NR`以分配到不同的哈希链表

```c

staticuint32_t_dentry_hash(struct dfs_mnt *mnt, constchar *path)

{

    uint32_t val = 0;


    if (path)

    {

        while (*path)

        {

            val = ((val << 5) + val) + *path++;

        }

    }

    return (val ^ (unsignedlong) mnt) & (DFS_DENTRY_HASH_NR - 1);

}

```

### create 创建目录

```c

staticstruct dfs_dentry *_dentry_create(struct dfs_mnt *mnt, char *path, rt_bool_tis_rela_path)

{

    struct dfs_dentry *dentry = RT_NULL;


    if (mnt == RT_NULL || path == RT_NULL)

    {

        return dentry;

    }


    dentry = (struct dfs_dentry *)rt_calloc(1, sizeof(struct dfs_dentry));

    if (dentry)

    {

        char *dentry_path = path;

        if (!is_rela_path)

        {

            int mntpoint_len = strlen(mnt->fullpath);


            if (rt_strncmp(mnt->fullpath, dentry_path, mntpoint_len) == 0)

            {

                dentry_path += mntpoint_len;

            }

        }

        //根据是否相对路径,获取路径

        dentry->pathname = strlen(dentry_path) ? rt_strdup(dentry_path) : rt_strdup(path);

        dentry->mnt = dfs_mnt_ref(mnt);


        rt_atomic_store(&(dentry->ref_count), 1);

        dentry->flags |= DENTRY_IS_ALLOCED;


        LOG_I("create a dentry:%p for %s", dentry, fullpath);

    }


    return dentry;

}

```

### insert 插入目录

```c

voiddfs_dentry_insert(struct dfs_dentry *dentry)

{

    dfs_file_lock();

    rt_list_insert_after(&hash_head.head[_dentry_hash(dentry->mnt, dentry->pathname)], &dentry->hashlist);

    dentry->flags |= DENTRY_IS_ADDHASH;

    dfs_file_unlock();

}

```

### unref 文件取消引用

```c

staticvoiddfs_file_unref(struct dfs_file *file)

{

    rt_err_t ret = RT_EOK;


    ret = dfs_file_lock();

    if (ret == RT_EOK)

    {

        if (rt_atomic_load(&(file->ref_count)) == 1)

        {

            // 文件具有目录,则取消引用

            if (file->dentry)

            {

                dfs_dentry_unref(file->dentry);

                file->dentry = RT_NULL;

            }

            elseif (file->vnode)

            {

                if (file->vnode->ref_count > 1)         //引用计数大于1,则减少引用

                {

                    rt_atomic_sub(&(file->vnode->ref_count), 1);

                }

                elseif (file->vnode->ref_count == 1)   //引用计数为1,则释放vnode

                {

                    rt_free(file->vnode);

                    file->vnode = RT_NULL;

                }

            }

        }


        dfs_file_unlock();

    }

}

```

### vnode 虚拟节点

将vnode节点挂载到dentry节点上

```

    dentry = dfs_dentry_create(mnt, fullpath);

    if (dentry)

    {

        DLOG(msg, "dfs_file", mnt->fs_ops->name, DLOG_MSG, "fs_ops->create_vnode");


        if (dfs_is_mounted(mnt) == 0)

        {

            vnode = mnt->fs_ops->create_vnode(dentry, oflags & O_DIRECTORY ? FT_DIRECTORY:FT_REGULAR, mode);

        }


        if (vnode)

        {

            /* set vnode */

            dentry->vnode = vnode;  /* the refcount of created vnode is 1. no need to reference */

            dfs_dentry_insert(dentry);

        }

    }

```

### lookup 查找目录

```c

/*

 * lookup a dentry, return this dentry and increase refcount if exist, otherwise return NULL

 */

struct dfs_dentry *dfs_dentry_lookup(struct dfs_mnt *mnt, constchar *path, uint32_tflags)

{

    struct dfs_dentry *dentry;

    struct dfs_vnode *vnode = RT_NULL;

    int mntpoint_len = strlen(mnt->fullpath);


    dfs_file_lock();

    //查找哈希表对应的dentry

    dentry = _dentry_hash_lookup(mnt, path);

    if (!dentry)

    {

        if (mnt->fs_ops->lookup)

        {

            /* not in hash table, create it */

            dentry = dfs_dentry_create_rela(mnt, (char*)path);

            if (dentry)

            {

                if (dfs_is_mounted(mnt) == 0)

                {

                    vnode = mnt->fs_ops->lookup(dentry);

                }


                if (vnode)

                {

                    dentry->vnode = vnode; /* the refcount of created vnode is 1. no need to reference */

                    dfs_file_lock();

                    rt_list_insert_after(&hash_head.head[_dentry_hash(mnt, path)], &dentry->hashlist);

                    dentry->flags |= DENTRY_IS_ADDHASH;

                    dfs_file_unlock();

                }

            }

        }

    }

    else

    {

        DLOG(note, "dentry", "found dentry");

    }

    dfs_file_unlock();

    return dentry;

}

```

## 文件描述符 FD

### NEW 新建文件描述符

```c

staticint_fdt_slot_expand(struct dfs_fdtable *fdt, intfd)

{

    nr = ((fd + 4) & ~3);//4字节对齐,以便更好的管理


    fds = (struct dfs_file **)rt_realloc(fdt->fds, nr * sizeof(struct dfs_file *));

    if (!fds)

    {

        return -1;

    }


    /* clean the new allocated fds */

    for (index = fdt->maxfd; index < nr; index++)

    {

        fds[index] = NULL;

    }

    fdt->fds = fds;

    fdt->maxfd = nr;


    return fd;

}


staticint_fdt_slot_alloc(struct dfs_fdtable *fdt, intstartfd)

{

    int idx;


    // 在已有的fd中查找空闲的fd

    for (idx = startfd; idx < (int)fdt->maxfd; idx++)

    {

        if (fdt->fds[idx] == RT_NULL)

        {

            return idx;

        }

    }


    idx = fdt->maxfd;

    if (idx < startfd)

    {

        idx = startfd;

    }


    if (_fdt_slot_expand(fdt, idx) < 0)

    {

        return -1;

    }


    return idx;

}


/**

 * @ingroup Fd

 * This function will allocate a file descriptor.

 *

 * @return -1 on failed or the allocated file descriptor.

 */

intfdt_fd_new(struct dfs_fdtable *fdt)

{

    int idx = -1;


    /* lock filesystem */

    if (dfs_file_lock() != RT_EOK)

    {

        return -RT_ENOSYS;

    }


    /* find an empty fd entry */

    idx = _fdt_fd_alloc(fdt, (fdt == &_fdtab) ? DFS_STDIO_OFFSET : 0);//DFS_STDIO_OFFSET = 3,通常跳过 stdin/stdout/stderr

    /* can't find an empty fd entry */

    if (idx < 0)

    {

        LOG_E("DFS fd new is failed! Could not found an empty fd entry.");

    }

    elseif (!fdt->fds[idx])    //找到空闲fd,则分配一个新的fd

    {

        struct dfs_file *file;


        file = (struct dfs_file *)rt_calloc(1, sizeof(struct dfs_file));


        if (file)

        {

            file->magic = DFS_FD_MAGIC;

            file->ref_count = 1;

            rt_mutex_init(&file->pos_lock, "fpos", RT_IPC_FLAG_PRIO);

            fdt->fds[idx] = file;


            LOG_D("allocate a new fd @ %d", idx);

        }

        else

        {

            fdt->fds[idx] = RT_NULL;

            idx = -1;

        }

    }

    else

    {

        LOG_E("DFS not found an empty fds entry.");

        idx = -1;

    }


    dfs_file_unlock();


    return idx;

}


intfd_new(void)

{

    struct dfs_fdtable *fdt;


    fdt = &_fdtab;


    returnfdt_fd_new(fdt);

}

```

### GET 获取文件描述符提供的文件对象

- 从分配的fd空间,根据FD的索引找到数组对应的文件对象
- 文件在newfd的时候已经calloc分配了空间

### RELEASE 释放文件描述符

```c

voidfdt_fd_release(struct dfs_fdtable *fdt, intfd)

{

    if (fd < fdt->maxfd)

    {

        struct dfs_file *file;


        file = fdt_get_file(fdt, fd);


        if (file && file->ref_count == 1)

        {

            rt_mutex_detach(&file->pos_lock);


            if (file->mmap_context)

            {

                rt_free(file->mmap_context);

            }


            rt_free(file);

        }

        else

        {

            rt_atomic_sub(&(file->ref_count), 1);

        }


        fdt->fds[fd] = RT_NULL;

    }

}

```

### stat 获取文件状态

```c

/**

 * this function is a POSIX compliant version, which will get file information.

 *

 * @paramfile the file name

 * @parambuf the data buffer to save stat description.

 *

 * @return 0 on successful, -1 on failed.

 */

intstat(constchar *file, struct stat *buf)

{

    result = dfs_file_stat(file, buf);

    return result;

}

```

