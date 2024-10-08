+++

date = 2021-11-22T16:05:00+08:00
title = "简述redis的基本数据结构"
url = "/internet/depth/redis_base_design"
tags = ["Redis"]
toc = true 

+++

很久之前就看过redis的基本设计与实现，但是每次都会忘掉。

前几天又看了一遍，但是最近回顾的时候又忘了。。。

俗话说好记性不如烂笔头，因此写在这里来加深记忆。

_文中会将数据类型的实现与go中的实现进行对比，如有理解错误的地方，望指出_

## 五个基本数据类型

### string

> **go中的string**：在go中，string就是一组字节，且是不可变的。可以视作字节数组。

redis中的字符串对象的编码可以是int、raw或embstr。

如果保存的对象是整数且可以用long类型来表示，那么就保存为整数，编码为int。

如果保存的对象是字符串且长度小于等于32字节，那么会使用embstr的编码来保存。

如果保存的对象是字符串且长度大于32字节，那么会使用embstr的编码来保存，且存储在SDS中。

embstr是专门用来保存短字符串的一种优化编码方式，与raw的区别在于对于redisObject和sdshdr（redisObject是redis对象中的一个属性，sdshdr是SDS的实现），embstr只需一次内存分配，而raw需要两次。

#### SDS

简单动态字符串（SDS）组成：

- buf: 字节数组
- len: 字符串长度（即buf数组中已使用的字节数量）
- free: buf数组中未使用的字节数量

SDS遵循C字符串以空字符结尾的惯例，保存空字符串的1字节空间不计算在SDS的属性中。

**空间预分配策略**：修改之后的SDS长度小于1M，那么程序会分配同样大小的预留空间，即len=free；如果修改之后的SDS长度大于1M，那么程序会分配1M的预留空间。

**空间惰性释放策略**：SDS中的字符串长度减小时，并不直接释放空间，而是增大free，可供未来使用，避免频繁释放/分配空间。

### list

> **go中的slice**
>
> 构成：由三个属性构成：长度、容量、底层数组。
>
> 扩容策略：当容量小于1024时，每次扩容为原来容量的一倍；否则扩容1/4
>
> 缩容策略：无

当list中元素的**字符串长度都小于64字节**且**元素数量小于512**时，使用**压缩列表**实现，否则使用**双端链表**实现。

#### 双端链表

双端链表有如下几个属性：

- 表头节点
- 表尾结点
- 节点长度
- 节点复制函数
- 节点释放函数
- 节点值对比函数

节点有如下属性：

- 前置节点地址
- 后置节点地址

- 节点值

#### 压缩列表

压缩列表包含的属性：

- 整个压缩列表占用的字节数
- 计算列表尾结点距离压缩列表的起始地址有多少字节
- 记录压缩列表包含的节点的数量（当总数大于65535时，这个字段失效，需要遍历整个压缩列表才能计算出来）
- 列表节点数组（每个节点可以保存为一个字节数组或者整数）

列表节点包含的属性：

- 上一个节点的长度
- 编码类型与长度
- 节点内容

压缩列表的优点就是节省内存，缺点就是增加、删除、更新可能会造成“连锁更新”，因此只有在包含少量元素时才使用。

### hash

> **go中的map**：涉及内容太多，todo

当hash中的**key和value的长度都小于64字节**，且**键值对的数量小于512个**时，使用**压缩列表**实现，否则使用**字典**实现。

#### 压缩列表

key和value都作为节点存到列表中，且一个键值对的两个节点总是按着。新加的键值对节点置于表尾。

#### 字典

字典中包含以下几个属性：

- 类型特定函数
- 私有数据
- 哈希表数组：数组长度固定为2
- rehash索引，为-1时，表示没有进行rehash

哈希表包含以下几个属性：

- size: 哈希表大小
- sizemask: 哈希表大小掩码，用于计算索引值。总是等于size-1
- used: 已使用的数量
- 哈希表数组，每个数组都是一个节点

哈希节点包含的属性：

- key
- value
- 下个节点的地址（用于组成解决哈希冲突的链表）

**哈希算法**

将一个新值添加到字典中时，首先根据key计算出哈希值和索引值，根据索引值将此新节点放入对应的哈希表数组上（计算索引值就是新通过哈希算法计算出一个值，再根据哈希表长度进行取模）。

**rehash步骤**

1. 对“备胎”分配空间

   1. 如果为扩容，那么“备胎”的大小为“正主”已使用大小2倍，并“向上取整为”2的n次幂。
   2. 如果为缩容，那么“备胎”的大小为“正主”已使用大小的2倍。

   扩/缩容条件：负载因子小于0.1则缩容；负载因子大于1且目前未执行BGSAVE或BGREWRITEAOF命令，或负载因子大于5且正在执行BGSAVE或BGREWRITEAOF命令，则扩容

2. 将“正主”的键值rehash到“备胎”上面。
3. “正主”所有键值都rehash到“备胎”后，将两者身份转换，并将“新备胎”初始化。

**渐进式rehash**

将一次性复制到“备胎”的成本分摊到每次的增删改查。

在rehash开始时，会设置一个索引值，每次对该hash进行增删改查是，就将当前索引的数据复制到“备胎”上。

**键冲突**

使用链表来解决键冲突

### set

当集中中的**元素都是整数且元素数量小于512**时，使用**整数集合**实现；否则使用**字典**实现。

#### 整数集合

使用整数集合时，每次添加新元素都要判断是否已存在。

整数集合包含三个属性：元素数组、长度、编码方式。数组中的元素**按照顺序排列**，且**不存在重复项**。

**升级**

将一个新元素添加入后，如果新元素的类型比现有的类型长时，就需要对整数集合进行升级。

1. 根据新元素的类型，扩展整数集合底层数组的大小，并为新元素分配空间
2. 将底层数组现有的所有数据转换为新类型，并存入新底层数组，保持排序
3. 将新元素添加到新底层数组中

不支持降级。

#### 字典

使用字典时，value会全部被置为NULL

### sorted set

有序集合中的元素长度都小于64字节并且元素数量小于128时使用压缩列表，否则使用跳跃表。

#### 压缩列表

如在hash中使用压缩链表，在实现有序集合时，对于每个元素对（成员-分数）都存储为两个挨着的节点，成员在前，分数在后。且分数较小的元素对在前，分数较大的元素对在后。

#### 字典

在使用跳跃表实现有序集合时，也使用了字典。

字典中记录成员与分数的映射。这使得查找成员的分数的时间复杂度为O(1)。

为了节省内存，字典和跳跃表在记录成员和分数时使用并共享其地址，因此使用字典并不会多耗费内存。

#### 跳跃表

如果有序集合中元素较多，或者元素的成员是比较长的字符串时，redis就会使用跳跃表来实现有序集合。

跳跃表包含：

- 长度，即元素（节点）个数
- level，即层数最大的节点的层数
- header：头结点
- tail：尾结点

每个元素节点包含：

- level：每个节点在生成时都会随机分配一个层数（最大默认为32层），每层都包含前进指针和跨度。前进指针表示访问节点的地址，跨度表示前进节点和当前节点的距离。跨度实际是用来计算排位的，在查找节点的过程中，将沿途访问的节点的跨度加起来就是其排位。
- 后退指针：指向当前节点的前一个节点
- 分值：节点按所存储分值从小到大排列
- 成员对象：节点对应的数据

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/20211125142306.png)
