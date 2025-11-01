---
title: tmpfs
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: ad661a3b
date: 2025-10-03 09:44:52
---
# tmpfs

- 它不能格式化，可以同时创建多个，在创建时可以指定其最大能使用的内存大小。其优点是读写速度很快，但存在掉电丢失的风险。如果一个进程的性能瓶颈是硬盘的读写，那么可以考虑在tmpfs 上进行大文件的读写操作。
- 比如在linux中，有个叫sysfs也是属于ramfs类型得，通过文件得形式来实时反映系统驱动、设备等状态，甚至可以直接对其进行操作。而这些驱动、设备运行状态只有在运行的时候看才有意义.并且以文件的形式来查看，使得交互方式很方便。所以在linux中，有“一切皆文件”的说法。
- 临时文件系统,不存储在硬盘上,存储在内存中;掉电后数据丢失
- 文件结构和DFS相同;用文件方式统一目录和文件对象;
- 文件具有同级链表和子节点链表进行关联文件结构

## 文件系统操作

### mount 挂载

```c

    /* romfs 挂载在 / 下 */

    /* fatfs 挂载在 /mnt 下 */

    /* tmpfs 挂载在 /mnt/tmp 下 */

    if (dfs_mount(RT_NULL, "/mnt/tmp", "tmp", 0, NULL) != 0)

    {

        rt_kprintf("Dir /tmp mount failed!\n");

        return -1;

    }

```

```c

mnt->data = superblock; //挂载点数据为超级块

//构造根目录

superblock->root.name[0] = '/';

superblock->root.sb = superblock;

superblock->root.type = TMPFS_TYPE_DIR;

```

### create_vnode 创建节点

- 用于在目录下创建虚拟节点

```c

staticstruct dfs_vnode *dfs_tmpfs_create_vnode(struct dfs_dentry *dentry, inttype, mode_tmode)

{

        superblock = (struct tmpfs_sb *)dentry->mnt->data;

        superblock->df_size += sizeof(struct tmpfs_file);

        /* open parent directory */

        p_file = dfs_tmpfs_lookup(superblock, parent_path, &size);

        /* create a file entry */

        d_file = (struct tmpfs_file *)rt_calloc(1, sizeof(struct tmpfs_file));

        strncpy(d_file->name, file_name, TMPFS_NAME_MAX);


        rt_list_init(&(d_file->subdirs));

        rt_list_init(&(d_file->sibling));

        d_file->data = NULL;

        d_file->fre_memory = RT_FALSE;


        rt_spin_lock(&superblock->lock);

        //将文件插入到父目录的子目录中

        rt_list_insert_after(&(p_file->subdirs), &(d_file->sibling));

        rt_spin_unlock(&superblock->lock);


        vnode->mnt = dentry->mnt;

        vnode->data = d_file;

        vnode->size = d_file->size;

    }

    return vnode;

}

```

### lookup 查找文件

- 根据路径查找文件
- 创建vnode关联文件

### stat

## 文件操作

### open && close

```c

staticintdfs_tmpfs_open(struct dfs_file *file)

{

    struct tmpfs_file *d_file;


    d_file = (struct tmpfs_file *)file->vnode->data;


    //复写

    if (file->flags & O_TRUNC)

    {

        d_file->size = 0;

        file->vnode->size = d_file->size;

        file->fpos = file->vnode->size;

        if (d_file->data != NULL)

        {

            /* ToDo: fix for rt-smart. */

            rt_free(d_file->data);

            d_file->data = NULL;

        }

    }


    if (file->flags & O_APPEND)

    {

        file->fpos = file->vnode->size;

    }

    else

    {

        file->fpos = 0;

    }


    RT_ASSERT(file->vnode->ref_count > 0);

    if(file->vnode->ref_count == 1)

    {

        rt_mutex_init(&file->vnode->lock, file->dentry->pathname, RT_IPC_FLAG_PRIO);

    }


    return0;

}

```

### read && write

```c

staticssize_t_dfs_tmpfs_write(struct tmpfs_file *d_file, constvoid *buf, size_tcount, off_t *pos)

{

    struct tmpfs_sb *superblock;


    RT_ASSERT(d_file != NULL);


    superblock = d_file->sb;

    RT_ASSERT(superblock != NULL);


    if (count + *pos > d_file->size)

    {

        rt_uint8_t *ptr;

        //重新分配更多的内存

        ptr = rt_realloc(d_file->data, *pos + count);


        rt_spin_lock(&superblock->lock);

        superblock->df_size += (*pos - d_file->size + count);

        rt_spin_unlock(&superblock->lock);

        /* update d_file and file size */

        d_file->data = ptr;

        d_file->size = *pos + count;

        LOG_D("tmpfile ptr:%x, size:%d", ptr, d_file->size);

    }

    //写入数据

    if (count > 0)

        memcpy(d_file->data + *pos, buf, count);


    /* update file current position */

    *pos += count;


    return count;

}


staticssize_tdfs_tmpfs_read(struct dfs_file *file, void *buf, size_tcount, off_t *pos)

{

    ssize_t length;

    struct tmpfs_file *d_file;

    d_file = (struct tmpfs_file *)file->vnode->data;


    rt_mutex_take(&file->vnode->lock, RT_WAITING_FOREVER);

    ssize_t size = (ssize_t)file->vnode->size;

    if ((ssize_t)count < size - *pos)

        length = count;

    else

        length = size - *pos;


    if (length > 0)

        memcpy(buf, &(d_file->data[*pos]), length);


    // 更新文件位置,读取到的位置

    *pos += length;


    rt_mutex_release(&file->vnode->lock);


    return length;

}

```

### lseek

```c

staticoff_tdfs_tmpfs_lseek(struct dfs_file *file, off_toffset, intwherece)

{

    switch (wherece)

    {

    case SEEK_SET:

        break;


    case SEEK_CUR:

        offset += file->fpos;

        break;


    case SEEK_END:

        offset += file->vnode->size;

        break;


    default:

        return -EINVAL;

    }


    if (offset <= (off_t)file->vnode->size)

    {

        return offset;

    }


    return -EIO;

}

```

### getdents 获取目录条目

```c

staticintdfs_tmpfs_getdents(struct dfs_file *file,

                       struct dirent *dirp,

                       uint32_t    count)

{

    //create_vnode中创建的文件

    d_file = (struct tmpfs_file *)file->vnode->data;


    rt_mutex_take(&file->vnode->lock, RT_WAITING_FOREVER);


    end = file->fpos + count;

    index = 0;

    count = 0;

    //获取文件的子目录

    rt_list_for_each(list, &d_file->subdirs)

    {   

        //获取子目录中的兄弟节点进行拷贝

        n_file = rt_list_entry(list, struct tmpfs_file, sibling);

        if (index >= (rt_size_t)file->fpos)

        {

            d = dirp + count;

            if (d_file->type == TMPFS_TYPE_FILE)

            {

                d->d_type = DT_REG;

            }

            if (d_file->type == TMPFS_TYPE_DIR)

            {

                d->d_type = DT_DIR;

            }

            d->d_namlen = RT_NAME_MAX;

            d->d_reclen = (rt_uint16_t)sizeof(struct dirent);

            rt_strncpy(d->d_name, n_file->name, TMPFS_NAME_MAX);


            count += 1;

            file->fpos += 1;

        }

        index += 1;

        if (index >= end)

        {

            break;

        }

    }

    rt_mutex_release(&file->vnode->lock);


    return count * sizeof(struct dirent);

}

```

### truncate 截断文件

```c

staticintdfs_tmpfs_truncate(struct dfs_file *file, off_toffset)

{

    d_file = (struct tmpfs_file *)file->vnode->data;

    superblock = d_file->sb;


    ptr = rt_realloc(d_file->data, offset);

    rt_spin_lock(&superblock->lock);

    superblock->df_size = offset;

    rt_spin_unlock(&superblock->lock);


    /* update d_file and file size */

    d_file->data = ptr;

    d_file->size = offset;

    file->vnode->size = d_file->size;

    return0;

}

```

