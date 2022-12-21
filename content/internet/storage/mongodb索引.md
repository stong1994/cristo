+++

date = 2022-12-22T16:05:00+08:00
title = "MongoDB索引"
url = "/internet/depth/mongo_index"

toc = true 

+++



## 基本操作

### 创建普通索引

```js
db.users.createIndex({"username" : 1, "age": -1})
```

1代表升序，-1代表逆序。

### 创建唯一索引

```js
db.users.createIndex({"username" : 1}, {"unique": true})
```

### 创建稀疏索引

在上边的唯一索引，如果字段为null，那么null值也会被写入唯一索引中。当再次插入该字段为null的数据时会报错。这时可以使用稀疏索引。

```js
db.users.createIndex({"username" : 1}, {"unique": true, "sparse": true})
```

### 创建部分索引

有时候需要对一部分数据建立索引，这时可以使用部分索引。如需要对非null部分创建索引：

```js
> db.users.createIndex({"username" : 1}, {"unique": true, "partialFilterExpression":{"firstname": {$exists: true } } })
```

### 后台创建索引

```js
db.users.createIndex({"username" : 1}, {"background": true})
```

### 查看索引

```js
db.users.getIndexes() 
```

### 删除索引

```js
db.users.dropIndexe("username_1") 
```



## 理论知识

### 如何选择索引

假如在一个查询有3个索引被标识为该查询的候选索引，那么MongoDB会创建3个查询计划，并在3个并行线程中分别运行这3个计划。最快返回结果的计划会赢得这次”竞赛“。

MongoDB会将”竞赛“结果缓存在服务端，对于有相同特征的查询，会直接拿到缓存的结果。

### 复合索引创建顺序

1. 等值过滤的键应该在最前面；
2. 用于排序的键应该在多值字段之前；
3. 多值过滤的键应该在最后面。

### B-树

MongoDB中的索引采用的数据结构为B-树。



## WiredTiger存储引擎

WiredTiger 存储引擎是 MongoDB 的默认存储引擎。

当服务器启动时，它会打开数据文件并开始检查点和日志记录过程。

默认情况下对集合和索引会启用压缩。默认的压缩算法是谷歌的 snappy。

WiredTiger 使用多版本并发控制（MVCC）来隔离读写操作，以确保客户端可以看到操作开始时数据的一致性视图。

检查点机制可以为数据创建一致的时间点快照，每 60 秒发生一次。这包括将快照中的所有数据写入磁盘并更新相关的元数据。

带有检查点的日志记录机制可以确保当 mongod 进程出现故障时，不会在任何时间点发生数据丢失。

WiredTiger 使用预写式日志来存储那些还没有被应用的修改。

