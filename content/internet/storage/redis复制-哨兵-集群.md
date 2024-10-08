+++

date = 2022-03-24T11:33:00+08:00
title = "Redis复制、哨兵、集群"
url = "/internet/design/redis_multi_server"
tags = ["Redis", "集群"]
toc = true

+++

随着访问量增多，我们常常对存储服务进行**读写分离**来降低主服务器的压力，读写分离最常用的方式就是增加从服务器。从服务器复制主服务器的数据，并提供给外部处理读请求。

## 主从复制

### 同步

当客户端向从服务器发送`SLAVEOF`命令，要求从服务器复制主服务器时，从服务器会先执行**同步**操作。

1. 从服务器向主服务器发送`SYNC`命令。
2. 收到`SYNC`命令的主服务器执行`BGSAVE`命令，在后台生成一个`RDB`文件，并将新产生的命令放入到一个**缓冲区**中
3. `BGSAVE`命令执行完后，主服务器将生成的`RDB`文件发往从服务器，从服务器载入`RDB`文件。
4. 从服务器载入`RDB`文件完毕后，主服务器将**缓冲区**中的写命令发送给从服务器。

同步完成后，如果主服务器再次接收到新的写命令，那么主服务器会将命令发送给从服务器，来保持数据一致。

### 复制积压缓冲区

主服务器在执行完命令后将该命令传播到从服务器，如果这时从服务器发出故障或者网络波动导致命令未在从服务器执行，那么主从之间的数据就会不一致。

为了判断主从之间的数据是否一致需要引入**复制偏移量**。每当主服务器发送N个字节或者从服务器接收N个字节的数据时，就将复制偏移量加上N。

如果主从之间的复制偏移量不同，那么就需要进行同步。如果只丢失了一小部分数据，那么没必要进行完整的数据同步，所以需要一个结构来**存储最近的命令**，这个结构就是**复制积压缓冲区**。

复制积压缓冲区是一个FIFO队列，当主服务器执行完命令后，就会将该命令写入到复制积压缓冲区，然后再将该命令传播到从服务器。

当发现主从服务器之间的复制偏移量不同时（通过ping或者从服务器重启），**主服务器会判断从服务器的复制偏移量后的数据是否还在复制积压缓冲区内，如果在，就直接将复制偏移量后的数据发送给从服务器，否则，进行完整的数据同步**。

## 哨兵模式

在主从复制的模式，一旦主服务器发生故障，从服务器并不会主动选举出新的master，需要运维手动设置master，这势必会造成一段时间内的服务不可用。为了提高可用性，Redis提供了**哨兵**来监控服务器。

### 服务发现

哨兵会定期发送`INFO`命令到其监控的服务器中，**主服务器**会将其**角色**和**从服务器地址**返回给哨兵，因此**哨兵只要监控主服务器就能获得从服务器的地址**。

**哨兵会监听同一个频道信息，也会向这个频道报告自己的信息，因此哨兵之间都能够发现彼此。**

### 选举领头哨兵

当主服务器发生故障后，需要**领头哨兵**进行故障转移，Redis通过raft算法实现了选举功能。

1. 发起选举后，每个哨兵在每个配置纪元里都能够设置自己认可的leader，一旦确认，在这个配置纪元里就不能再修改
2. 每次选举，配置纪元都会自增
3. “认可”leader的规则依据先来先得，即先接收到的认可请求会被接受，后接受的会被拒绝
4. 选举规则采用多数服从少数，一个哨兵只要被半数以上的哨兵认可就会被选举为leader
5. 如果在给定期限内没有选举出leader，那么会再次进行选举

### 主服务器故障确认

哨兵会定期向其监控的服务器发送`PING`命令，如果主服务器在一段时间内没有回复，那么哨兵就会认为主服务器故障。

但是每个哨兵配置的超时时间可以是不同的，因此这个**哨兵会向其他哨兵确认主服务器是否故障，当超过quorum数量的哨兵认为主服务器已发生故障，那么就可以认为主服务器发生了故障，需要进行转移**。需要注意每个哨兵的quorum可以是不同的。

### 故障转移

故障转移需要先**在从服务器中选举出主服务器**。

1. 排除掉已经下线的从服务器
2. 排除掉与哨兵存在通信故障的从服务器
3. 选择出数据最新的从服务器（根据与旧的主服务器断开时长来判断）
4. 在剩余的从服务器中选择优先级比较高的从服务器
5. 在剩余的从服务器中选择复制偏移量最大的从服务器
6. 在剩余的从服务器中选择id排序最小的从服务器

选出主服务器后，哨兵会向候选服务器发送`slaveof no one`明确将其“提升”为主服务器。然后向其他从服务器发送命令修改复制目标为新主服务器。

如果旧的主服务器上线，上线后会成为从服务器。

## 集群

随着数据量不断膨胀，分布式存储变得日趋重要。Redis集群中舍弃了“哨兵”这类管理者，使用**分片**进行主节点之间的数据切分，使用`Gossip`协议实现了各个主节点之间的信息共享。

### 分片

Redis集群通过分片实现了主节点之间的数据分配。整个集群就是一个数据库，数据库被分为了`16384`个槽，需要手动分配这些槽到指定节点上。

每个节点都通过长度为`16384`的**二进制数组**来**标记该节点负责哪些槽**，同时又通过**另外一个长度为16384的槽来记录每个槽对应的节点信息**。

**分片规则**是通过对键进行CRC16，并对16384取余（实际是&16383），结果即为目标槽，通过上边提到的数组就能获取到目标节点。

当客户端访问一个节点时，如果**所需的数据不在当前节点**，则当前节点会返回一个`MOVE`错误，同时返回数据所在的节点地址。客户端收到`MOVE`错误后，会**重新向目标节点请求数据**。如果数据所在的节点正在进行**重新分片**，并且**目标数据已被迁移至分片后的节点**，那么当前节点会返回一个`ASK`错误，同时返回数据所在的节点地址，客户端收到`ASK`错误后，会**重新访问分片后的节点请求数据**。

### 更智能的客户端

客户端可以自己维护键->槽->节点的映射关系，这样就不需要每次都“猜”目标节点是哪个。

### 节点信息共享：Gossip

两个节点之间通过“三次握手”进行连接，连接之后，将彼此的信息通过`Gossip`协议扩散到其他节点，这些信息包括：

- 节点自身数据，包括分片后的槽的分配信息
- 整个集群1/10的节点的状态数据

集群的节点间会定期发送`PING`消息来**检测对方是否在线**，如果每个节点都向所有节点发送消息那么会凭空增大服务器压力，因此对于每个节点，**先随机从节点列表中选出5个节点，然后从这5个节点中获取最长时间没有发送PING消息的节点发送PING消息**。此外，每100毫秒节点都会遍历自己的节点列表，找到超过某段时间内没有通信的节点，然后将其加入到发送名单中。

### 故障转移

集群中的每个节点都会定期向其他节点发送`PING`消息来检测对方是否在线，如果对方没有及时回复则会被视为**疑似下线**，节点之间会分享彼此的信息，当集群中**半数以上的主节点**都认为该节点已下线时，那么这个节点会被标记为**已下线**，将该节点标记为已下线的主节点会在集群中广播一条`FAIL`消息，收到`FAIL`消息的主节点会**立即将该节点标记为已下线**。

#### 选举主节点

集群会**从已下线的主节点的所有从节点中选举出新的主节点**：

1. 对从节点进行**资格筛选**：如果从节点与下线的主节点的最后通信的时间间隔超过一个阈值，那么这个从节点就失去了选举资格（如果所有的从节点都失去了资格，就需要手动进行强制转移）
2. **设置选举优先级**：通过对比从节点的复制偏移量来获得其优先级，复制偏移量越大的从节点的优先级越高，对这些从节点进行优先级排序，优先级低的节点的选举发起时间会比前一个优先级更高的节点的选举发起时间晚1秒。
3. **广播选举消息**：每个有资格发起选举的从节点根据自己的选举发起时间进行消息广播。
4. 每个有投票权的主节点（有负责的槽）在每个配置纪元里都有一次投票的机会，选举采用**先到先得**的方式，会投票给第一个收到请求的来源从节点。
5. 当一个从节点获得了**半数以上**的选票时，会被“升级”为主节点。落选的从节点修改复制目标为新的主节点，当旧的主节点上线时也会自动成为新的主节点的从节点。
6. 如果在一个配置纪元中没有从节点能够获得半数以上的选票，则再次进行选举。

#### 加快故障转移时间

节点间通过Gossip协议来交流彼此的信息，包括节点的状态。但如果只通过Gossip来传播，那么下线故障节点会很慢。

**为了解决故障节点的转播效率问题**：首先，在分享节点信息时，**节点会优先将故障节点的信息放入消息体内**。其次，**节点会对超过某段时间内未通信的节点直接发起ping消息**。通过这样来保证在比较短的时间内收集到半数以上主节点的疑似下线报告。
