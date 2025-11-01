---
title: littlefs
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: a5eec7a4
date: 2025-10-03 09:44:52
---
# littlefs

```c

// Users can override lfs_util.h with their own configuration by defining

// LFS_CONFIG as a header file to include (-DLFS_CONFIG=lfs_config.h).

//

// If LFS_CONFIG is used, none of the default utils will be emitted and must be

// provided by the config file. To start, I would suggest copying lfs_util.h

// and modifying as needed.

#ifdef LFS_CONFIG

#define LFS_STRINGIZE(x) LFS_STRINGIZE2(x)

#define LFS_STRINGIZE2(x) #x

#include LFS_STRINGIZE(LFS_CONFIG)

```

## 机制

- 断电恢复能力:独立的原子性
- 磨损均衡
- 有限的RAM/ROM

1. 日志记录提供独立的原子性，但运行时性能较差。而表现良好的COW数据结构将原子性问题向上推了
2. littlefs 由小型的两个块日志构建而成，这些日志为文件系统上任何位置的元数据提供原子更新。在超级块级别，littlefs 是一个可以按需清除的 CObW 块树

### 元数据对

1. 元数据对是 littlefs 的支柱。这些是小的两个块日志，允许在文件系统中的任何位置进行原子更新。
2. 为了确定哪个元数据块是最新的，我们存储了一个修订计数，我们使用序列算术进行比较（对于避免整数溢出问题非常方便）。方便的是，这个修订计数还让我们大致了解了块上发生了多少次擦除。
3. 原子性（一种功率损耗弹性）需要两部分：冗余和错误检测。错误检测可以通过校验和提供，在 littlefs 的情况下，我们使用 32 位 CRC。另一方面，保持冗余需要多个阶段。
4. 如果我们的块没有满，并且程序大小足够小，可以让我们附加更多条目，我们可以简单地将条目附加到日志中。因为我们不会覆盖原始条目（请记住，重写 flash 需要擦除），所以如果我们在追加过程中断电，我们仍然保留原始条目。
5. 将多个条目分组到一个共享单个校验和的提交中。这使我们可以更新多个不相关的元数据片段，只要它们位于同一元数据对上即可。

### 垃圾回收,压缩

1. 如果我们的块充满了条目，我们需要以某种方式删除过时的条目，以便为新条目腾出空间。这个过程叫做垃圾回收，但是因为 littlefs 有多个垃圾回收器，所以我们也把这个特定情况称为压缩
2. littlefs 的垃圾收集器相对简单。我们希望避免 RAM 消耗，因此我们使用一种暴力解决方案，对于每个条目，我们检查是否编写了较新的条目。如果条目是最新的，我们将其附加到新块中。这就是拥有两个块变得重要的地方，如果我们失去权力，我们仍然拥有原始块中的所有东西。
3. 用完了数据内容;将原始元数据对拆分为两个元数据对，每个元数据对包含一半的条目，通过尾指针连接。我们没有增加日志的大小并处理与较大日志相关的可伸缩性问题，而是形成了一个小有界日志的链接列表。这是一种权衡，因为这种方法确实使用了更多的存储空间，但有利于提高可伸缩性。
4. 为了避免这种指数级增长，我们不是等待元数据对满，而是在超过 50% 的容量时拆分元数据对。我们懒惰地这样做，等到我们需要压缩时再检查是否符合 50% 的限制。这将垃圾回收的开销限制为运行时成本的 2 倍，从而为我们提供了 O（1） 的摊销运行时复杂度。

### CTZ跳过列表

1. CTZ 跳过列表为我们提供了一个 COW 数据结构，该结构在 O（n） 中易于遍历，可以在 O（1） 中追加，并且可以在 O（n log n） 中读取。所有这些操作都在有限的 RAM 量中工作，并且每个块只需要两个字的存储开销。结合元数据对，CTZ 跳过列表可提供强大的弹性和紧凑的数据存储。

### 块分配器

1. 通常，块分配涉及存储在文件系统上的某种空闲列表或位图，这些空闲列表或位图会使用空闲块进行更新。然而，由于具有电力弹性，保持这些结构的一致性变得困难。更新这些结构的任何错误都可能导致无法恢复的丢失块，这无济于事。
2. littlefs 中的块分配器是磁盘大小的位图和暴力遍历之间的折衷方案。我们跟踪的不是存储大小的位图，而是一个名为 lookahead 缓冲区的小型固定大小的位图。在区块分配期间，我们从 lookahead 缓冲区中获取区块。如果 lookahead 缓冲区为空，我们将扫描文件系统以查找更多空闲块，从而填充我们的 lookahead 缓冲区。在每次扫描中，我们都使用一个递增的偏移量，在分配块时围绕存储圈。

### 检测和恢复坏块

1. 在 littlefs 中，在写入时检测坏块相当简单。所有写入都必须由 RAM 中的某种形式的数据源，因此在我们写入块后，我们可以立即读回数据并验证它是否被正确写入。如果我们发现磁盘上的数据与RAM中的副本不匹配，则发生了写入错误，并且很可能有一个坏块。
2. 检测到坏块，我们就需要从中恢复。在写入错误的情况下，我们在RAM中有损坏数据的副本，因此我们需要做的就是逐出坏块，分配一个新的，希望是好的块，并重复以前失败的写入。
3. 另一方面，读取错误要复杂得多。我们没有在RAM中徘徊的数据副本，因此我们需要一种方法来重建原始数据，即使它已被损坏。其中一种机制是纠错码 （ECC）。ECC 是校验和概念的扩展。如果校验和（如 CRC）可以检测到数据中发生了错误，则 ECC 可以检测并实际纠正一定数量的错误。但是，ECC 可以检测到的错误数量是有限制的：汉明绑定。当错误数量接近汉明边界时，我们可能仍然能够检测到错误，但无法再修复数据。如果我们达到这一点，则块是不可恢复的。littlefs 本身不提供 ECC。ECC 的块性质和相对较大的占用空间不适用于文件系统的动态大小数据，在没有 RAM 的情况下纠正错误很复杂，而 ECC 更适合块设备的几何形状。事实上，一些 NOR 闪存芯片具有用于 ECC 的额外存储，许多 NAND 芯片甚至可以在芯片本身上计算 ECC。

### 磨损均衡

> https://en.wikipedia.org/wiki/Wear_leveling#Static_wear_leveling

1. 作为对代码大小和复杂性的权衡，littlefs（目前）仅提供动态磨损均衡。这是一个尽力而为的解决方案。磨损不是完全分布的，但它分布在自由块之间，大大延长了设备的使用寿命。
2. 磨损的均匀分布由块分配器决定，该分配器在两部分中创建均匀分布。简单的部分是当设备通电时，在这种情况下，我们线性分配块，围绕设备旋转。更难的部分是当设备断电时该怎么办。我们不能在存储开始时重新启动分配器，因为这会导致磨损。取而代之的是，每次挂载文件系统时，我们都会以随机偏移量的形式启动分配器。只要这种随机偏移量是均匀的，组合分配模式也是均匀分布。最初，这种磨损均衡方法看起来会对与电源无关的随机数生成器产生困难的依赖性，该随机数生成器必须在每次启动时返回不同的随机数。然而，文件系统处于一个相对独特的情况，因为它位于大量的熵之上，这些熵在功率损失期间持续存在。

### 文件

1. 首先，我们可以在单个元数据对中存储多个文件，而不是为每个文件提供自己的元数据对。一种方法是直接将目录与元数据对（或元数据对的链接列表）关联。这使得多个文件可以轻松地共享目录的元数据对以进行日志记录，并减少集体存储开销。
2. 对于非常小的文件，我们尝试使用 CTZ 跳过列表来压缩存储适得其反。元数据对的存储成本是 ~4 倍，因此，如果我们的文件小于块大小的 1/4，那么在元数据对之外存储文件实际上没有任何好处。在这种情况下，我们可以将文件直接存储在目录的元数据对中。我们称之为内联文件，它允许目录非常有效地存储许多小文件。我们之前的 4 字节文件现在在磁盘上只占用理论上的 16 个字节。

### 目录

1. 就其本身而言，每个目录都是元数据对的链接列表。这使我们可以在每个目录中存储无限数量的文件，并且我们无需担心无界日志的运行时复杂性。我们可以在元数据对中存储其他目录指针，这为我们提供了一个目录树，就像您在其他文件系统上找到的一样。
2. 不幸的是，不坚持纯粹的 COW 操作会产生一些问题。现在，每当我们想要操作目录树时，都需要更新多个指针。如果你熟悉设计原子数据结构，这应该会引发一堆危险信号。
3. 为了解决这个问题，我们的线程链接列表有一点回旋余地。它不仅包含在我们的文件系统中找到的元数据对，还允许包含由于断电而没有父级的元数据对。这些称为孤立元数据对。
4. 于存在孤立函数的可能性，我们可以构建具有功率损失弹性的操作，该操作维护一个文件系统树，该树与链接列表线程化，以便进行遍历。
5. 查找孤儿和半孤儿需要花费大量资金，需要对每个元数据对与每个目录条目进行 O（n²） 比较。但权衡是一个具有功率弹性的文件系统，它只使用有限数量的 RAM。幸运的是，我们只需要在启动后的第一次分配中检查孤立项，只读的 littlefs 可以完全忽略线程化的链接列表。

### 文件移动

1. 解决移动问题需要创建一种新的机制，用于在多个元数据对之间共享知识。在 littlefs 中，这导致了一种称为“全局状态”的机制的引入。
2. 全局状态是可以从任何元数据对更新的一小组状态。将全局状态与元数据对在一次提交中更新多个条目的能力相结合，为我们提供了一个强大的工具，用于制作复杂的原子操作。
3. 全局状态以一组增量的形式存在，这些增量分布在文件系统中的元数据对中。通过将文件系统中的所有增量组合在一起，可以从这些增量中构建实际的全局状态。
4. 为了更新元数据对的全局状态，我们采用我们已知的全局状态，并将其与我们的更改和元数据对中的任何现有增量进行异化。将此新增量提交到元数据对会提交对文件系统全局状态的更改。
5. 为了提高效率，我们始终在RAM中保留全局状态的副本。我们只需要遍历我们的元数据对，并在挂载文件系统时构建全局状态。
6. 全局状态的成本非常高。我们在 RAM 中保留一个副本，在无限数量的元数据对中保留一个增量。即使我们将全局状态重置为其初始值，我们也无法轻松清理磁盘上的增量。出于这个原因，我们必须保持全局状态的大小有限且非常小，这一点非常重要。但是，即使有严格的预算，全球状态也非常有价值。

### gdiff

1. GDIFF 跟踪当前 ID 与元数据日志历史记录中 ID 之间的相对差异。

```c

// 考虑一下如果我们创建文件 a、b、c，然后删除 a，会发生什么：

/*

id        0 1 2

---------------

create a id=0  .

               |

create b id=1  | .

               | |

create d id=2  | | .

               | | |

delete a id=0  ' / /

                / /

create c id=1  | .\

               | | \

create a id=0  .\ \ \

               | | | |

delete a id=0  ' / / /

                / / /

               b c d


getslice(id=0) => file b

getslice(id=1) => file c

getslice(id=2) => file d

*/

//如果我们想在 b 上查找一些标签，我们将从 id=0 开始。请记住，我们会向后查找。当我们看到 “delete a” 时，我们需要增加 giff，以便 gtag+gdiff 显示当前 b 的 id（现在 id=1）。

//最终，当我们到达“create b”时，我们可以报告我们找到的标签，但我们需要报告当前的 id，而不是我们过去找到的那个。通过在单独的变量中跟踪 gdiff，我们可以跟踪过去的 id 应该是什么，同时也可以知道当前的 id 应该是什么。

```

2. 关键是元数据块是一个日志，它只追加，我们不能修改任何已经写入的数据。因此，如果我们已经写了文件 b 是 id=0，但我们想在 id=0 处插入一个文件 a 以保持排序顺序，我们需要假设文件 b 是 id=1。这就是此扫描/gdiff 的作用。

- 也是所有元数据访问都需要扫描日志的原因之一，我们需要查看自写入元数据以来 id 是否发生了变化。但是我们首先需要扫描日志以找到元数据，所以这并不是一个太大的惩罚。

3. 请注意：实际的 ID 仅从单个元数据块（有时在代码中称为 mdir）计算得出。文件夹实际上是这些元数据块的链接列表，每个块都是独立的。这样可以使对元数据的操作与块大小保持界限。
4. 因此，要访问文件，您需要知道文件的 mdir 及其在 mdir 中的 id。由于不相关的文件系统操作，这可能会发生变化。
5. lfs_mdir与目录的单个元数据块相关，而lfs_dir - 与整个目录相关

- 当 mdir 空间不足并且无法再追加提交时，它将被压缩。这涉及分配一个新的 mdir ，并从原始 mdir 复制标签。此时，我们可以删除任何已删除、待处理或已提交的删除，并回收空间。
- 为了防止压缩性能失控，我们认为如果压缩没有将 mdir 减小到块大小的 1/2，则压缩将失败。虽然我猜另一个观点是所有 mdir 都使用 1/2 一个块，并且可以通过附加额外的提交来过度分配。
- 如果压缩失败，我们将尝试拆分 mdir。在本例中，我们分配 2 个 mdir，并将大约 1/2 的当前标签复制到每个 mdir 中。在这里，一个目录可以扩展到多个 mdir 中。
- 请注意，由于 mdir 最多可以包含 1 个标签块，因此拆分总是会导致 mdir 大约 1/2 满。所以分裂不能失败。
- 在尝试提交删除标签的 mdir 拆分期间，我们可能会用完块。这种罕见但可能的情况会导致文件系统无法恢复。有趣的是，这个问题在写入时复制的文件系统中很常见。为了解决这个问题，所有主要的 CoW 文件系统都为特定于文件系统的书签、ZFS、btrfs 等预留了一些空间。littlefs 目前不这样做，所以目前有可能填满文件系统并使其无法恢复。有一些计划来改善这一点，对“非紧急”提交的完全截止值为 ~88%

### 示例

```c

// variables used by the filesystem

lfs_t lfs;

lfs_file_t file;


// configuration of the filesystem is provided by this struct

conststruct lfs_config cfg = {

    // block device operations

    .read  = user_provided_block_device_read,

    .prog  = user_provided_block_device_prog,

    .erase = user_provided_block_device_erase,

    .sync  = user_provided_block_device_sync,


    // block device configuration

    .read_size = 16,

    .prog_size = 16,

    .block_size = 4096,

    .block_count = 128,

    .cache_size = 16,

    .lookahead_size = 16,

    .block_cycles = 500,

};


    // mount the filesystem

    int err = lfs_mount(&lfs, &cfg);


    // reformat if we can't mount the filesystem

    // this should only happen on the first boot

    if (err) {

        lfs_format(&lfs, &cfg);

        lfs_mount(&lfs, &cfg);

    }

```

## 文件系统操作

### mount

```c

staticvoid_lfs_load_config(struct lfs_config* lfs_cfg, struct rt_mtd_nor_device* mtd_nor)

{

    uint64_t mtd_size;


    lfs_cfg->context = (void*)mtd_nor;


    lfs_cfg->read_size = LFS_READ_SIZE;

    lfs_cfg->prog_size = LFS_PROG_SIZE;


    lfs_cfg->block_size = mtd_nor->block_size;

    if (lfs_cfg->block_size < LFS_BLOCK_SIZE)

    {

        lfs_cfg->block_size = LFS_BLOCK_SIZE;

    }


    lfs_cfg->cache_size = LFS_CACHE_SIZE;

    lfs_cfg->block_cycles = LFS_BLOCK_CYCLES;


    mtd_size = mtd_nor->block_end - mtd_nor->block_start;

    mtd_size *= mtd_nor->block_size;

    lfs_cfg->block_count = mtd_size / lfs_cfg->block_size;


    lfs_cfg->lookahead_size = 32 * ((lfs_cfg->block_count + 31) / 32);

    if (lfs_cfg->lookahead_size > LFS_LOOKAHEAD_MAX)

    {

        lfs_cfg->lookahead_size = LFS_LOOKAHEAD_MAX;

    }

#ifdef LFS_THREADSAFE

    lfs_cfg->lock = _lfs_lock;

    lfs_cfg->unlock = _lfs_unlock;

#endif

    lfs_cfg->read = _lfs_flash_read;

    lfs_cfg->prog = _lfs_flash_prog;

    lfs_cfg->erase = _lfs_flash_erase;

    lfs_cfg->sync = _lfs_flash_sync;

}


staticint_dfs_lfs_mount(struct dfs_filesystem* dfs, unsignedlongrwflag, constvoid* data)

{

    _lfs_load_config(&dfs_lfs->cfg, (struct rt_mtd_nor_device*)dfs->dev_id);

    /* mount lfs*/

    result = lfs_mount(&dfs_lfs->lfs, &dfs_lfs->cfg);

    /* mount succeed! */

    dfs->data = (void*)dfs_lfs;

    _lfs_mount_tbl[index] = dfs_lfs;

    return RT_EOK;

}

```

### mkfs

1. lfs_format

## 文件操作

## module

### other

#### tag

```c

/*

[----            32             ----]

[1|--  11   --|--  10  --|--  10  --]

 ^.     ^     .     ^          ^- length

 |.     |     .     '------------ id

 |.     '-----.------------------ type (type3)

 '.-----------.------------------ valid bit

  [-3-|-- 8 --]

    ^     ^- chunk

    '------- type (type1)

*/

#define LFS_MKTAG(type, id, size) \

    (((lfs_tag_t)(type) <<20) | ((lfs_tag_t)(id) <<10) | (lfs_tag_t)(size))


// tag最高位为1表示无效

staticinlineboollfs_tag_isvalid(lfs_tag_ttag) {

    return !(tag & 0x80000000);

}


// 判断tag是不是为0x3ff;    特殊值 0x3ff 表示此标签已被删除

staticinlineboollfs_tag_isdelete(lfs_tag_ttag) {

    return ((int32_t)(tag << 22) >> 22) == -1;

}

```

#### lfs_bd_read

- rcache: read cache
- pcache: program cache

1. 当rcache没有数据时,从存储器中读取数据到rcache中,继续循环
2. 当rcache有数据时,从rcache中读取数据到buffer中,判断读取大小是否满足要求,不满足则继续循环
3. 当pcache有数据时,从pcache中读取数据
4. 当直接读取阈值大于size时,绕过缓存,直接从存储器中读取数据到buffer中

```c

/*

bd_read:block device read

pcache：这是一个指向预读取缓存的指针。预读取缓存用于存储预先读取的数据，以便在需要时快速访问。如果当前块已经在预读取缓存中，那么就可以直接从缓存中获取数据，而不需要再次从存储器中读取。

rcache：这是一个指向读取缓存的指针。读取缓存用于存储最近读取的数据。如果当前块已经在读取缓存中，那么就可以直接从缓存中获取数据，而不需要再次从存储器中读取。

hint：这是一个阈值，用于指示读取的大小。这个值用于优化读取，以便在读取大量数据时，可以绕过缓存。

*/

staticintlfs_bd_read(lfs_t *lfs,

        constlfs_cache_t *pcache, lfs_cache_t *rcache, 

        lfs_size_thint,

        lfs_block_tblock, lfs_off_toff,

        void *buffer, lfs_size_tsize) {

    uint8_t *data = buffer;

    if (off+size > lfs->cfg->block_size

            || (lfs->block_count && block >= lfs->block_count)) {

        return LFS_ERR_CORRUPT;

    }


    while (size > 0) {

        lfs_size_t diff = size;


        if (pcache && block == pcache->block &&

                off < pcache->off + pcache->size) {

            if (off >= pcache->off) {

                // is already in pcache?

                diff = lfs_min(diff, pcache->size - (off-pcache->off));

                memcpy(data, &pcache->buffer[off-pcache->off], diff);


                data += diff;

                off += diff;

                size -= diff;

                continue;

            }


            // pcache takes priority

            diff = lfs_min(diff, pcache->off-off);

        }


        if (block == rcache->block &&

                off < rcache->off + rcache->size) {

            if (off >= rcache->off) {

                // is already in rcache?

                diff = lfs_min(diff, rcache->size - (off-rcache->off));

                //将rcache中的数据拷贝到buffer中

                memcpy(data, &rcache->buffer[off-rcache->off], diff);

                //将buffer指针向后移动diff个字节,以便下次拷贝数据

                data += diff;

                off += diff;

                size -= diff;

                continue;

            }


            // rcache takes priority

            diff = lfs_min(diff, rcache->off-off);

        }


        if (size >= hint && off % lfs->cfg->read_size == 0 &&

                size >= lfs->cfg->read_size) {

            // bypass cache?

            diff = lfs_aligndown(diff, lfs->cfg->read_size);

            int err = lfs->cfg->read(lfs->cfg, block, off, data, diff);

            if (err) {

                return err;

            }


            data += diff;

            off += diff;

            size -= diff;

            continue;

        }


        // load to cache, first condition can no longer fail

        LFS_ASSERT(!lfs->block_count || block < lfs->block_count);

        rcache->block = block;

        //如果off < read_size，那么这个值是0。如果off >= read_size，那么这个值是off向下对齐到read_size的最接近的倍数。

        rcache->off = lfs_aligndown(off, lfs->cfg->read_size);

        rcache->size = lfs_min(

                lfs_min(

                    //lfs_alignup(off+hint, lfs->cfg->read_size): 这部分是将偏移量（off）和预测值（hint）的和向上对齐到读取大小（read_size）。这意味着，如果 off+hint 不是 read_size 的整数倍，那么它会被增加到最接近的 read_size 的整数倍。

                    lfs_alignup(off+hint, lfs->cfg->read_size),

                    lfs->cfg->block_size)

                - rcache->off,  //这部分是从上一步得到的值中减去偏移量（off）。这意味着，我们只关心从 off 开始的数据。

                lfs->cfg->cache_size);

        int err = lfs->cfg->read(lfs->cfg, rcache->block,

                rcache->off, rcache->buffer, rcache->size);

        LFS_ASSERT(err <= 0);

        if (err) {

            return err;

        }

    }


    return0;

}

```

#### lfs_bd_cmp

1. 读取数据,比较数据
2. 比较 `buffer`和读取从 `block`偏移 `off`的数据是否相等,长度为 `size`

```c

staticintlfs_bd_cmp(lfs_t *lfs,

        constlfs_cache_t *pcache, lfs_cache_t *rcache, lfs_size_thint,

        lfs_block_tblock, lfs_off_toff,

        constvoid *buffer, lfs_size_tsize) {

        }

```

#### lfs_dir_find_match

```c

staticintlfs_dir_find_match(

    void *data, //struct lfs_dir_find_match *name = data; 将name->name与buffer进行比较

    lfs_tag_ttag, //根据标签大小读取数据

    constvoid *buffer);

```

#### lfs_gstate_hasmovehere

// 参考:https://github.com/littlefs-project/littlefs/issues/920;

// 指明 `如果 gtag 和 lfs->gdisk.tag 的 id 都可以为 0，那么从 gtag （id == 0） 中减去 gdiff （id == 1） 时，我们似乎可以得到一个下溢。`

```c

    // synthetic move

    if (lfs_gstate_hasmovehere(&lfs->gdisk, dir->pair)) {

        if (lfs_tag_id(lfs->gdisk.tag) == lfs_tag_id(besttag)) {

            besttag |= 0x80000000;

        } elseif (besttag != -1 &&

                lfs_tag_id(lfs->gdisk.tag) < lfs_tag_id(besttag)) {

            besttag -= LFS_MKTAG(0, 1, 0);

        }

    }


    // synthetic moves

    if (lfs_gstate_hasmovehere(&lfs->gdisk, dir->pair) &&

            lfs_tag_id(gmask) != 0) {

        if (lfs_tag_id(lfs->gdisk.tag) == lfs_tag_id(gtag)) {

            return LFS_ERR_NOENT;

        } elseif (lfs_tag_id(lfs->gdisk.tag) < lfs_tag_id(gtag)) {

            gdiff -= LFS_MKTAG(0, 1, 0);

        }

    }

```

- 检查元数据对是否包含正在移动的条目，如果是，则将其视为已删除。
- 只有当 gtag 的 id 大于或等于 lfs->gdisk.tag 的 id 时才会调用它

#### fetchmatch

1. 读取指定块 `pair`的元数据对的修订计数,比较两个块的修订计数,找出修订计数最大的块;对dir->pair进行重新赋值,将版本更高的块赋值给dir->pair[0]
2. 从第一个元数据开始扫描,要是读取不到有效信息,则换另一个元数据继续扫描
3. 扫描时while读取一个block的所有标签,直到超出范围或者没有有效tag
4. 扫描要是读到一个CRC标签,然后校验CRC标签,如果校验通过,则将CRC标签的数据更新到dir中

```c

dir->off = off + lfs_tag_dsize(tag);

dir->etag = ptag;

dir->count = tempcount;

dir->tail[0] = temptail[0];

dir->tail[1] = temptail[1];

```

4. 扫描时要是读到FCRC标签
5. 每次扫描会把 `fmask`和 `ftag`进行匹配;匹配成功传入 `data`执行 `cb`函数;返回是否匹配;会遍历一个块的数据看看是否有更加匹配的标签
6. 扫描结束后,判断这个元数据是否被擦过,进而执行标记 `dir->erased = 1;`

```

我们的闪存模型需要两个步骤：

1. 非常大的擦除操作 （block_size）。

2. 小得多的 prog 操作 （prog_size）。


元数据日志通过增量写入大型擦除块内的较小 prog 块来使用此模型。但是，仅仅因为我们有一个有效的日志，它只使用擦除块的一部分，并不意味着块的其余部分一定会被擦除。

主要问题是提交失败。如果我们尝试提交日志，但中途失去电源，由于提交中的校验和，我们将回退到之前的有效状态。但这会留下日志的其余部分部分写入。尝试附加新的提交可能会导致数据损坏/保留问题。

因此，在lfs_dir_fetch期间，littlefs 需要证明日志的其余部分已被擦除，然后才能使用它。这就是 FCRC 标签的用武之地，继续写入日志是否安全存储在 dir->egone 中。

```

7. synthetic move 检查元数据对是否包含正在移动的条目，如果是，则将其视为已删除。
8. 返回tag值代表有匹配的标签

```c

/*

fmask: 过滤器掩码，用于过滤标签

ftag: 标签，用于与标签进行比较

*/

staticlfs_stag_tlfs_dir_fetchmatch(lfs_t *lfs,

        lfs_mdir_t *dir, constlfs_block_tpair[2],

        lfs_tag_tfmask, lfs_tag_tftag, uint16_t *id,

        int (*cb)(void *data, lfs_tag_t tag, constvoid *buffer), void *data) {



    //读取指定块的元数据对的修订计数,比较两个块的修订计数,找出修订计数最大的块

    uint32_trevs[2] = {0, 0};

    int r = 0;

    for (int i = 0; i < 2; i++) {

        int err = lfs_bd_read(lfs,

                NULL, &lfs->rcache, sizeof(revs[i]),

                pair[i], 0, &revs[i], sizeof(revs[i]));

        revs[i] = lfs_fromle32(revs[i]);

        if (err && err != LFS_ERR_CORRUPT) {

            return err;

        }

        //比较修订计数，找出更大的修订计数

        if (err != LFS_ERR_CORRUPT &&

                lfs_scmp(revs[i], revs[(i+1)%2]) > 0) {

            r = i;

        }

    }

    // 现在扫描标签以获取实际目录并找到可能的匹配,要是扫描完找不到匹配的标签,则返回错误

    for (int i = 0; i < 2; i++) {

        //CRC（32 位） - 检测因断电或其他写入问题而导致的损坏。使用多项式为 0x04c11db7 的 CRC-32，初始化为 0xffffffff。

        uint32_t crc = lfs_crc(0xffffffff, &dir->rev, sizeof(dir->rev));


        while (true) {  //循环读取标签 当读取的标签不合法时或者读取的标签超出范围时，退出循环

            // extract next tag

            lfs_tag_t tag;

            off += lfs_tag_dsize(ptag);

            int err = lfs_bd_read(lfs,

                    NULL, &lfs->rcache, lfs->cfg->block_size,

                    dir->pair[0], off, &tag, sizeof(tag));

            crc = lfs_crc(crc, &tag, sizeof(tag));

            //元数据块支持前向迭代和后向迭代。为了在不重复每个标签的空间的情况下执行此操作，相邻条目将其标签异运算在一起，从 0xffffffff 开始。

            tag = lfs_frombe32(tag) ^ ptag;

            //CRC 标签标记了提交的结束，并为元数据块的任何提交提供校验和。

            if (lfs_tag_type2(tag) == LFS_TYPE_CCRC) {

                // check the crc attr

                uint32_t dcrc;

                err = lfs_bd_read(lfs,

                        NULL, &lfs->rcache, lfs->cfg->block_size,

                        dir->pair[0], off+sizeof(tag), &dcrc, sizeof(dcrc));

                if (err) {

                    if (err == LFS_ERR_CORRUPT) {

                        break;

                    }

                    return err;

                }

                dcrc = lfs_fromle32(dcrc);


                if (crc != dcrc) {

                    break;

                }


                // reset the next bit if we need to

                ptag ^= (lfs_tag_t)(lfs_tag_chunk(tag) & 1U) << 31;


                // toss our crc into the filesystem seed for

                // pseudorandom numbers, note we use another crc here

                // as a collection function because it is sufficiently

                // random and convenient

                lfs->seed = lfs_crc(lfs->seed, &crc, sizeof(crc));


                // update with what's found so far

                besttag = tempbesttag;

                dir->off = off + lfs_tag_dsize(tag);

                dir->etag = ptag;

                dir->count = tempcount;

                dir->tail[0] = temptail[0];

                dir->tail[1] = temptail[1];

                dir->split = tempsplit;


                // reset crc, hasfcrc

                crc = 0xffffffff;

                continue;

            }


            //对条目进行校验

            err = lfs_bd_crc(lfs,

                    NULL, &lfs->rcache, lfs->cfg->block_size,

                    dir->pair[0], off+sizeof(tag),

                    lfs_tag_dsize(tag)-sizeof(tag), &crc);

            if (err) {

                if (err == LFS_ERR_CORRUPT) {

                    break;

                }

                return err;

            }


            // directory modification tags?

            if (lfs_tag_type1(tag) == LFS_TYPE_NAME) {

                // increase count of files if necessary

                /*

                关键是LFS_TYPE_CREATE是可选的。如果标记的 id 恰好超出了 mdir 的当前大小，则 mdir 会隐式扩展。 这样做的目的是简化 mdir 压缩。

                MDIR 压缩 （lfs_dir_compact） 按照它们在日志中找到的顺序写出标签，这是任意的。使用 CREATE/DELETE 标签对此进行建模会很困难，因为您需要知道已经写出哪些 id，这需要无限内存。

                */

                if (lfs_tag_id(tag) >= tempcount) {

                    tempcount = lfs_tag_id(tag) + 1;

                }

            } 


            // next commit not yet programmed?

            if (!lfs_tag_isvalid(tag)) {

                // we only might be erased if the last tag was a crc

                maybeerased = (lfs_tag_type2(ptag) == LFS_TYPE_CCRC);

                break;

            // out of range?

            } elseif (off + lfs_tag_dsize(tag) > lfs->cfg->block_size) {

                break;

            }


            //fmask 掩码进行过滤, ftag与tag进行比较

            if ((fmask & tag) == (fmask & ftag)) {

                int res = cb(data, tag, &(struct lfs_diskoff){

                        dir->pair[0], off+sizeof(tag)});

                if (res == LFS_CMP_EQ) {

                    // found a match

                    tempbesttag = tag;

                } elseif ((LFS_MKTAG(0x7ff, 0x3ff, 0) & tag) ==

                        (LFS_MKTAG(0x7ff, 0x3ff, 0) & tempbesttag)) {

                    // found an identical tag, but contents didn't match

                    // this must mean that our besttag has been overwritten

                    tempbesttag = -1;

                } elseif (res == LFS_CMP_GT &&

                        lfs_tag_id(tag) <= lfs_tag_id(tempbesttag)) {

                    // found a greater match, keep track to keep things sorted

                    tempbesttag = tag | 0x80000000;

                }

            }

        }


        // 没有有效提交记录,换另一个块执行操作

        if (dir->off == 0) {

            // try the other block?

            lfs_pair_swap(dir->pair);

            dir->rev = revs[(r+1)%2];

            continue;

        }


        //检查是否被擦除

        dir->erased = false;

        if (maybeerased && dir->off % lfs->cfg->prog_size == 0) {

        #ifdef LFS_MULTIVERSION

            // note versions < lfs2.1 did not have fcrc tags, if

            // we're < lfs2.1 treat missing fcrc as erased data

            //

            // we don't strictly need to do this, but otherwise writing

            // to lfs2.0 disks becomes very inefficient

            if (lfs_fs_disk_version(lfs) <0x00020001) {

                dir->erased = true;


            } else

        #endif

            if (hasfcrc) {

                //在 lfs2.1 中添加的可选 FCRC 标签包含了在下次提交中被擦除时一定数量的字节的校验和。这使我们能够确保我们只对擦除的字节进行编程，即使之前的提交由于断电而失败。

                //如果缺少 FCRC 或校验和不匹配，我们必须假设尝试提交但由于断电而失败。

                // check for an fcrc matching the next prog's erased state, if

                // this failed most likely a previous prog was interrupted, we

                // need a new erase

                uint32_t fcrc_ = 0xffffffff;

                //计算的crc

                int err = lfs_bd_crc(lfs,

                        NULL, &lfs->rcache, lfs->cfg->block_size,

                        dir->pair[0], dir->off, fcrc.size, &fcrc_);

                if (err && err != LFS_ERR_CORRUPT) {

                    return err;

                }


                // found beginning of erased part?

                // 指示是否擦除 MDIR 的其余部分。

                dir->erased = (fcrc_ == fcrc.crc);//比较计算与存储的crc

            }

        }


        // synthetic move

        // 检查元数据对是否包含正在移动的条目，如果是，则将其视为已删除。

        if (lfs_gstate_hasmovehere(&lfs->gdisk, dir->pair)) {

            if (lfs_tag_id(lfs->gdisk.tag) == lfs_tag_id(besttag)) {

                besttag |= 0x80000000;

            } elseif (besttag != -1 &&

                    lfs_tag_id(lfs->gdisk.tag) < lfs_tag_id(besttag)) {

                besttag -= LFS_MKTAG(0, 1, 0);

            }

        }


        // found tag? or found best id?

        // 如果我们找不到 ids >= 请求的标签,将默认 id 映射到一个合理的值(0x3ff)

        // 此处用于将所有位设置为 1，lfs_tag_id（-1） => 0x3ff因为所有位都已设置，如果未找到其他 id，则为 lfs_min（0x3ff， dir->count） => dir->count。

        if (id) {

            *id = lfs_min(lfs_tag_id(besttag), dir->count);

        }

    }

    //如果扫描两个块都找不到任何信息，则返回错误

    LFS_ERROR("Corrupted dir pair at {0x%"PRIx32", 0x%"PRIx32"}",

            dir->pair[0], dir->pair[1]);

    return LFS_ERR_CORRUPT;

}

```

#### lfs_dir_get && lfs_dir_getslice

1. 找到了一个匹配的标签，我们就读取与之关联的数据，并将其存储在gbuffer中。如果标签标记为已删除，或者我们没有找到匹配的标签，那么我们就返回一个错误。

```c

/// Metadata pair and directory operations ///

staticlfs_stag_tlfs_dir_getslice(lfs_t *lfs, constlfs_mdir_t *dir,

        lfs_tag_tgmask, lfs_tag_tgtag,

        lfs_off_tgoff, void *gbuffer, lfs_size_tgsize) {

    lfs_off_t off = dir->off;

    lfs_tag_t ntag = dir->etag;

    lfs_stag_t gdiff = 0;


    // synthetic moves


    // iterate over dir block backwards (for faster lookups)

    while (off >= sizeof(lfs_tag_t) + lfs_tag_dsize(ntag)) {

        off -= lfs_tag_dsize(ntag);

        lfs_tag_t tag = ntag;

        int err = lfs_bd_read(lfs,

                NULL, &lfs->rcache, sizeof(ntag),

                dir->pair[0], off, &ntag, sizeof(ntag));


        ntag = (lfs_frombe32(ntag) ^ tag) & 0x7fffffff;


        if (lfs_tag_id(gmask) != 0 && lfs_tag_type1(tag) == LFS_TYPE_SPLICE && lfs_tag_id(tag) <= lfs_tag_id(gtag - gdiff)) {

            if (tag == (LFS_MKTAG(LFS_TYPE_CREATE, 0, 0) | (LFS_MKTAG(0, 0x3ff, 0) & (gtag - gdiff)))) {

                // found where we were created

                return LFS_ERR_NOENT;

            }


            // move around splices

            gdiff += LFS_MKTAG(0, lfs_tag_splice(tag), 0);

        }


        if ((gmask & tag) == (gmask & (gtag - gdiff))) {

            if (lfs_tag_isdelete(tag)) {

                return LFS_ERR_NOENT;

            }


            lfs_size_t diff = lfs_min(lfs_tag_size(tag), gsize);

            err = lfs_bd_read(lfs,

                    NULL, &lfs->rcache, diff,

                    dir->pair[0], off+sizeof(tag)+goff, gbuffer, diff);

            if (err) {

                return err;

            }


            memset((uint8_t*)gbuffer + diff, 0, gsize - diff);


            return tag + gdiff;

        }

    }


    return LFS_ERR_NOENT;

}

```

#### lfs_fs_prepsuperblock

```c

/*

为了跟踪在lfs_mount期间发现的任何过时的次要版本，我们

可以从我们的gstate中保留的部分中切出一点。这些都是

目前用于计数器中跟踪孤儿的数量

In-device gstate tag:


  [--       32      --]

  [1|- 11 -| 10 |1| 9 ]

   ^----^-----^--^--^-- 1-bit has orphans

        '-----|--|--|-- 11-bit move type

              '--|--|-- 10-bit move id

                 '--|-- 1-bit needs superblock

                    '-- 9-bit orphan count

*/

staticvoidlfs_fs_prepsuperblock(lfs_t *lfs, boolneedssuperblock) {

    lfs->gstate.tag = (lfs->gstate.tag & ~LFS_MKTAG(0, 0, 0x200))

            | (uint32_t)needssuperblock << 9;

}

```

#### lfs_dir_getgstate

1. 读取dir数据中是否具有 `MOVESTATE`标签,获取数据,将 `gstate`的数据更新到 `lfs`中

#### lfs_fs_traverse_

```c

intlfs_fs_traverse_(lfs_t *lfs,

        int (*cb)(void *data, lfs_block_t block), void *data,

        boolincludeorphans) {

    // iterate over metadata pairs

    lfs_mdir_t dir = {.tail = {0, 1}};

    while (!lfs_pair_isnull(dir.tail)) {

        //使用布伦特算法检测尾部是否有环


        for (int i = 0; i < 2; i++) {

            int err = cb(data, dir.tail[i]);

            if (err) {

                return err;

            }

        }


        // 遍历目录中的 ids

        int err = lfs_dir_fetch(lfs, &dir, dir.tail);

        if (err) {

            return err;

        }


        for (uint16_t id = 0; id < dir.count; id++) {

            struct lfs_ctz ctz;

            // 获取CTZ指针


            if (lfs_tag_type3(tag) == LFS_TYPE_CTZSTRUCT) {

                err = lfs_ctz_traverse(lfs, NULL, &lfs->rcache,

                        ctz.head, ctz.size, cb, data);

                if (err) {

                    return err;

                }

            } elseif (includeorphans &&

                    lfs_tag_type3(tag) == LFS_TYPE_DIRSTRUCT) {

                //孤立节点执行操作

                for (int i = 0; i < 2; i++) {

                    err = cb(data, (&ctz.head)[i]);

                    if (err) {

                        return err;

                    }

                }

            }

        }

    }

```

#### lfs_alloc

1. 从 `lookahead`缓冲区中查找空闲块
2. 如果 `lookahead`缓冲区中没有空闲块,则扫描文件系统以查找下一个 `lookahead`窗口中的未使用块
3. 如果 `lookahead`缓冲区中有空闲块,则返回空闲块;并且寻找下一个空闲块
4. littlefs 中的块分配器是磁盘大小的位图和暴力遍历之间的折衷方案。我们跟踪的不是存储大小的位图，而是一个名为 lookahead 缓冲区的小型固定大小的位图。在区块分配期间，我们从 lookahead 缓冲区中获取区块。如果 lookahead 缓冲区为空，我们将扫描文件系统以查找更多空闲块，从而填充我们的 lookahead 缓冲区。在每次扫描中，我们都使用一个递增的偏移量，在分配块时围绕存储圈。
5. 这种前瞻方法的运行时复杂度为 O（n²），用于完全扫描存储;但是，位图非常紧凑，实际上通常只需要一到两次通道即可找到空闲块。此外，可以通过调整块大小或 lookahead 缓冲区的大小来优化分配器的性能，以写入粒度或 RAM 来交换分配器性能。

```c

staticintlfs_alloc(lfs_t *lfs, lfs_block_t *block) {

    while (true) {

        // scan our lookahead buffer for free blocks

        while (lfs->lookahead.next < lfs->lookahead.size) {

            if (!(lfs->lookahead.buffer[lfs->lookahead.next / 8]    //是获取位图中对应的字节

                    & (1U << (lfs->lookahead.next % 8)))) {         // 创建一个只有特定位置为1的掩码

                // found a free block

                *block = (lfs->lookahead.start + lfs->lookahead.next)

                        % lfs->block_count;


                // eagerly find next free block to maximize how many blocks

                // lfs_alloc_ckpoint makes available for scanning

                while (true) {

                    lfs->lookahead.next += 1;

                    lfs->lookahead.ckpoint -= 1;


                    if (lfs->lookahead.next >= lfs->lookahead.size

                            || !(lfs->lookahead.buffer[lfs->lookahead.next / 8]

                                & (1U << (lfs->lookahead.next % 8)))) {

                        return0;

                    }

                }

            }


            lfs->lookahead.next += 1;

            lfs->lookahead.ckpoint -= 1;

        }


        // In order to keep our block allocator from spinning forever when our

        // filesystem is full, we mark points where there are no in-flight

        // allocations with a checkpoint before starting a set of allocations.

        //

        // If we've looked at all blocks since the last checkpoint, we report

        // the filesystem as out of storage.

        //

        if (lfs->lookahead.ckpoint <= 0) {

            LFS_ERROR("No more free space 0x%"PRIx32,

                    (lfs->lookahead.start + lfs->lookahead.next)

                        % lfs->block_count);

            return LFS_ERR_NOSPC;

        }


        // No blocks in our lookahead buffer, we need to scan the filesystem for

        // unused blocks in the next lookahead window.

        int err = lfs_alloc_scan(lfs);

        if(err) {

            return err;

        }

    }

}


// 对位图进行填充

staticintlfs_alloc_lookahead(void *p, lfs_block_tblock) {

    lfs_t *lfs = (lfs_t*)p;

    lfs_block_t off = ((block - lfs->lookahead.start)

            + lfs->block_count) % lfs->block_count;


    if (off < lfs->lookahead.size) {

        lfs->lookahead.buffer[off / 8] |= 1U << (off % 8);

    }


    return0;

}


staticintlfs_alloc_scan(lfs_t *lfs) {

    // move lookahead buffer to the first unused block

    //

    // note we limit the lookahead buffer to at most the amount of blocks

    // checkpointed, this prevents the math in lfs_alloc from underflowing

    lfs->lookahead.start = (lfs->lookahead.start + lfs->lookahead.next) 

            % lfs->block_count;

    lfs->lookahead.next = 0;

    lfs->lookahead.size = lfs_min(

            8*lfs->cfg->lookahead_size,

            lfs->lookahead.ckpoint);


    // find mask of free blocks from tree

    memset(lfs->lookahead.buffer, 0, lfs->cfg->lookahead_size);

    int err = lfs_fs_traverse_(lfs, lfs_alloc_lookahead, lfs, true);

    if (err) {

        lfs_alloc_drop(lfs);

        return err;

    }


    return0;

}

```

#### lfs_bd_flush

- 执行 `prog`写入,根据 `validate`的值,决定是否需要校验写入的数据

#### lfs_bd_prog

- 通过pcache缓存写入数据

1. 搬运数据至 `pcache`缓存

2.`pcache`缓存大小等于 `cache_size`时,将 `pcache`缓存通过 `flush`写入 `block`块

3. 重新设置 `pcache`缓存

#### int lfs_file_relocate(lfs_t *lfs, lfs_file_t *file)

- 重新对 `file`进行定位,并且重新分配 `block`块

1. 通过 `lfs_alloc`重新分配 `block`块
2. 通过 `lfs_bd_erase`擦除 `block`块
3. 通过 `lfs_bd_read`或 `lfs_dir_getread`读取 `file`块的数据
4. 通过 `lfs_bd_prog`写入 `block`块的数据

#### lfs_file_outline

- 将文件从目录中移出

1. 重新分配该文件所在的块
2. 将文件 `flag`取消在目录中的标记

#### lfs_file_flush

1. 在单个元数据对中存储多个文件，而不是为每个文件提供自己的元数据对。一种方法是直接将目录与元数据对（或元数据对的链接列表）关联。这使得多个文件可以轻松地共享目录的元数据对以进行日志记录，并减少集体存储开销。
2. 第二个改进是注意到，对于非常小的文件，我们尝试使用 CTZ 跳过列表来压缩存储适得其反。元数据对的存储成本是 ~4 倍，因此，如果我们的文件小于块大小的 1/4，那么在元数据对之外存储文件实际上没有任何好处。
3. 在这种情况下，我们可以将文件直接存储在目录的元数据对中。我们称之为内联文件，它允许目录非常有效地存储许多小文件。我们之前的 4 字节文件现在在磁盘上只占用理论上的 16 个字节。
4. 一旦文件超过块大小的 1/4，我们就会切换到 CTZ 跳过列表。这意味着我们的文件使用的存储开销永远不会超过 4 倍，并且随着文件大小的增长而减少。
5. 如果 `file->pos < file->ctz.size`, 通过 `lfs_file_flushedread(lfs, &orig, &data, 1);`寻找 `ctz`,在通过 `lfs_file_flushedwrite(lfs, file, &data, 1)`写入
6. 否则直接进行 `lfs_bd_flush(lfs, &file->cache, &lfs->rcache, true);`

3.`lfs_bd_flush`失败为 `LFS_ERR_CORRUPT`,则进行 `lfs_file_relocate`再次尝试写入

#### lfs_dir_orphaningcommit

```c

staticintlfs_dir_orphaningcommit(lfs_t *lfs, lfs_mdir_t *dir,

        conststruct lfs_mattr *attrs, intattrcount) {

    // check for any inline files that aren't RAM backed and

    // forcefully evict them, needed for filesystem consistency

    for (lfs_file_t *f = (lfs_file_t*)lfs->mlist; f; f = f->next) {

        if (dir != &f->m                            //目录不是文件的当前目录

        && lfs_pair_cmp(f->m.pair, dir->pair) == 0  //文件目录和当前目录的元数据对相同

        && f->type == LFS_TYPE_REG && (f->flags & LFS_F_INLINE) //文件是正常文件并且是内联文件

        && f->ctz.size > lfs->cfg->cache_size) {    //文件的大小超过缓存大小

            int err = lfs_file_outline(lfs, f);

            if (err) {

                return err;

            }


            err = lfs_file_flush(lfs, f);

            if (err) {

                return err;

            }

        }

    }


}

```

### lfs_init

- 2*4 不理解 ??? 2*4是块元数据的大小，这些元数据在块的开始和结束处有两个副本

```c

// common filesystem initialization

staticintlfs_init(lfs_t *lfs, conststruct lfs_config *cfg)

{

    // check that the block size is large enough to fit all ctz pointers

    // Littlefs 使用 32 位的字宽，因此只有当指针小于 104 个字节时，我们的块才能溢出指针。

    LFS_ASSERT(lfs->cfg->block_size >= 128);

    // this is the exact calculation for all ctz pointers, if this fails

    // and the simpler assert above does not, math must be broken

    // lfs->cfg->block_size-2*4：这是计算每个块的有效大小，其中2*4是块元数据的大小，这些元数据在块的开始和结束处有两个副本

    // 0xffffffff / (lfs->cfg->block_size-2*4)：这是计算在给定的块大小下，一个块可以容纳的最大文件大小。

    //lfs_npw2(0xffffffff / (lfs->cfg->block_size-2*4))：lfs_npw2函数计算最接近给定数值的2的幂次方。这是因为在许多文件系统中，文件大小通常是2的幂次方。

    LFS_ASSERT(4*lfs_npw2(0xffffffff / (lfs->cfg->block_size-2*4)) <= lfs->cfg->block_size);

    // 元数据不能压缩到 block_size/2 以下，并且元数据不能超过 block_size

    //block_size/2是划分元数据块的阈值，因此合并后所有元数据块都应该放入block_size/2。使用该值作为lfs_fs_gc的下限，意味着如果尝试合并，总是可以保证有进展。

    LFS_ASSERT(lfs->cfg->compact_thresh == 0

            || lfs->cfg->compact_thresh >= lfs->cfg->block_size/2);

    LFS_ASSERT(lfs->cfg->compact_thresh == (lfs_size_t)-1

            || lfs->cfg->compact_thresh <= lfs->cfg->block_size);

    // setup default state

    lfs->root[0] = LFS_BLOCK_NULL;

    lfs->root[1] = LFS_BLOCK_NULL;

    lfs->mlist = NULL;

    lfs->seed = 0;

    lfs->gdisk = (lfs_gstate_t){0};

    lfs->gstate = (lfs_gstate_t){0};

    lfs->gdelta = (lfs_gstate_t){0};

}

```

### mount

1. 初始化lfs加载的驱动配置
2. 扫描目录块,找到超级块,并且名称是"littlefs"的目录的tag
3. 获取超级块的版本与配置信息,进行检查与赋值
4. 更新 `lfs`的 `gstate`,`gdisk`,`lookahead.start`

```c

staticintlfs_mount_(lfs_t *lfs, conststruct lfs_config *cfg) {

    int err = lfs_init(lfs, cfg);

    if (err) {

        return err;

    }


    // scan directory blocks for superblock and any global updates

    lfs_mdir_t dir = {.tail = {0, 1}};

    lfs_block_ttortoise[2] = {LFS_BLOCK_NULL, LFS_BLOCK_NULL};

    lfs_size_t tortoise_i = 1;

    lfs_size_t tortoise_period = 1;

    while (!lfs_pair_isnull(dir.tail)) {

        // 使用布伦特算法检测 尾部数据是否存在循环

        if (lfs_pair_issync(dir.tail, tortoise)) {

            LFS_WARN("Cycle detected in tail list");

            err = LFS_ERR_CORRUPT;

            goto cleanup;

        }

        if (tortoise_i == tortoise_period) {

            tortoise[0] = dir.tail[0];

            tortoise[1] = dir.tail[1];

            tortoise_i = 0;

            tortoise_period *= 2;

        }

        tortoise_i += 1;


        // fetch next block in tail list

        //找到超级块并且名称是"littlefs"的目录的tag

        lfs_stag_t tag = lfs_dir_fetchmatch(lfs, &dir, dir.tail,

                LFS_MKTAG(0x7ff, 0x3ff, 0),             //过滤器掩码 所有type+id都可以,忽略长度

                LFS_MKTAG(LFS_TYPE_SUPERBLOCK, 0, 8),   //超级块标签

                NULL,

                lfs_dir_find_match,                     //目录查找匹配

                &(struct lfs_dir_find_match){

                    lfs, 

                    "littlefs",                         //查找名称为littlefs的目录

                    8

                });

        if (tag < 0) {

            err = tag;

            goto cleanup;

        }


        // 找到超级块且未被擦除

        if (tag && !lfs_tag_isdelete(tag)) {

            // update root

            lfs->root[0] = dir.pair[0];

            lfs->root[1] = dir.pair[1];

            // grab superblock

            lfs_superblock_t superblock;

            //获取超级块的版本与配置信息

            tag = lfs_dir_get(lfs, &dir, LFS_MKTAG(0x7ff, 0x3ff, 0),

            // superblock 条目的内容存储在具有 superblock 类型和 inline-struct 标签的名称标签中。name 标签包含魔术字符串 “littlefs”，而 inline-struct 标签包含版本和配置信息。

                    LFS_MKTAG(LFS_TYPE_INLINESTRUCT, 0, sizeof(superblock)),

                    &superblock);

            // check version

          


            // found older minor version? set an in-device only bit in the

            // gstate so we know we need to rewrite the superblock before

            // the first write

            bool needssuperblock = false;

            if (minor_version < lfs_fs_disk_version_minor(lfs)) {

                LFS_DEBUG("Found older minor version ");

                needssuperblock = true;

            }

            // note this bit is reserved on disk, so fetching more gstate

            // will not interfere here

            lfs_fs_prepsuperblock(lfs, needssuperblock);

        }

        // has gstate?

        err = lfs_dir_getgstate(lfs, &dir, &lfs->gstate);

    }


    // update littlefs with gstate

    if (!lfs_gstate_iszero(&lfs->gstate)) {

        LFS_DEBUG("Found pending gstate 0x%08"PRIx32"%08"PRIx32"%08"PRIx32,

                lfs->gstate.tag,

                lfs->gstate.pair[0],

                lfs->gstate.pair[1]);

    }

    lfs->gstate.tag += !lfs_tag_isvalid(lfs->gstate.tag);

    lfs->gdisk = lfs->gstate;


    // setup free lookahead, to distribute allocations uniformly across

    // boots, we start the allocator at a random location

    lfs->lookahead.start = lfs->seed % lfs->block_count;

    lfs_alloc_drop(lfs);

}

```

### format

```c

staticintlfs_format_(lfs_t *lfs, conststruct lfs_config *cfg) {


        // create root dir

        lfs_mdir_t root;

        err = lfs_dir_alloc(lfs, &root);


        err = lfs_dir_commit(lfs, &root, LFS_MKATTRS(

                {LFS_MKTAG(LFS_TYPE_CREATE, 0, 0), NULL},

                {LFS_MKTAG(LFS_TYPE_SUPERBLOCK, 0, 8), "littlefs"},

                {LFS_MKTAG(LFS_TYPE_INLINESTRUCT, 0, sizeof(superblock)),

                    &superblock}));

}

```

