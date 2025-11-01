---
title: romfs
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: 9cd11733
date: 2025-10-03 09:44:52
---
# romfs

RomFS 是在嵌入式设备上常用的一种文件系统，具备体积小，可靠性高，读取速度快等优点，常用来作为系统初始文件系统。但也具有其局限性，RomFS 是一种只读文件系统。

不同的数据存储方式对文件系统占用空间，读写效率，查找速度等主要性能影响极大。RomFS 使用顺序存储方式，所有数据都是顺序存放的。因此 RomFS 中的数据一旦确定就无法修改，这是 RomFS 是一种只读文件系统的原因。也由于这种顺序存放策略，RomFS 中每个文件的数据都能连续存放，读取过程中只需要一次寻址操作，就可以读入整块数据，因此 RomFS 中读取数据效率很高。

> https://www.rt-thread.org/document/site/#/rt-thread-version/rt-thread-standard/tutorial/qemu-network/filesystems/filesystems?id=%e4%bd%bf%e7%94%a8-romfs

## 文件系统操作

### mount 挂载

```c

dfs_mount(RT_NULL, "/", "rom", 0, &(romfs_root));

```

### lookup 查找文件

```c

struct romfs_dirent *__dfs_romfs_lookup(struct romfs_dirent *root_dirent, constchar *path, rt_size_t *size)

{

    rt_size_t index, found;

    constchar *subpath, *subpath_end;

    struct romfs_dirent *dirent;

    rt_size_t dirent_size;


    /* goto root directy entries */

    dirent = (struct romfs_dirent *)root_dirent->data;

    dirent_size = root_dirent->size;


    /* get the end position of this subpath */

    while (dirent != NULL)

    {

        found = 0;


        /* search in folder */

        for (index = 0; index < dirent_size; index ++)

        {

            if (check_dirent(&dirent[index]) != 0)

                returnNULL;

            if (rt_strlen(dirent[index].name) == (subpath_end - subpath) &&

                    rt_strncmp(dirent[index].name, subpath, (subpath_end - subpath)) == 0)

            {

                dirent_size = dirent[index].size;

                if (dirent[index].type == ROMFS_DIRENT_DIR)

                {

                    /* enter directory */

                    dirent = (struct romfs_dirent *)dirent[index].data;

                    found = 1;

                    break;

                }

                else

                {

                    /* return file dirent */

                    return &dirent[index];

                }

            }

        }

    }


    /* not found */

    returnNULL;

}


staticstruct dfs_vnode *dfs_romfs_lookup (struct dfs_dentry *dentry)

{

    rt_size_t size;

    struct dfs_vnode *vnode = RT_NULL;

    struct romfs_dirent *root_dirent = RT_NULL, *dirent = RT_NULL;

    //mount时挂载的数据

    root_dirent = (struct romfs_dirent *)dentry->mnt->data;

    if (check_dirent(root_dirent) == 0)

    {

        /* create a vnode */

        vnode = dfs_vnode_create();

        if (vnode)

        {

            dirent = __dfs_romfs_lookup(root_dirent, dentry->pathname, &size);

            if (dirent)

            {

                vnode->nlink = 1;

                vnode->size = dirent->size;

                if (dirent->type == ROMFS_DIRENT_DIR)

                {

                    vnode->mode = romfs_modemap[ROMFS_DIRENT_DIR] | (S_IRUSR | S_IXUSR | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);

                    vnode->type = FT_DIRECTORY;

                }

                elseif (dirent->type == ROMFS_DIRENT_FILE)

                {

                    vnode->mode = romfs_modemap[ROMFS_DIRENT_FILE] | (S_IRUSR | S_IXUSR | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);

                    vnode->type = FT_REGULAR;

                }

                //挂载vnode数据

                vnode->data = dirent;

                vnode->mnt = dentry->mnt;

            }

            else

            {

                dfs_vnode_destroy(vnode);

                vnode = RT_NULL;

            }

        }

    }


    return vnode;

}

```

## 文件操作

