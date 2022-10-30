+++

date = 2022-10-15T21:19:00+08:00
title = "k8s架构设计"
url = "/cloudnative/k8s/architecture"

toc = true

draft = false

+++

## 组件

k8s可分为三大块：控制平面、节点和其他。

控制平面包括：

- API Server
- Scheduler
- Controller Manager
- etcd

节点包括：

- kubelet
- kube-proxy
- 容器运行时（docker、rkt等）

其他包括：

- DNS Server
- Dashboard
- Ingress
- Heapster
- 网络插件
- 等

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210072025710.png)

## 插件化

### 数据流向

1. k8s中的组件只与API server交流
2. API server只能与etcd交流
3. 组件如果需要存储/读取数据，统一通过API server处理

### 数据一致性

k8s中存在大量组件，这些组件需要更新大量数据，如何保证高并发下的数据一致性？

通过约束组件统一通过API server存储/读取数据，因此，只需在API server处使用乐观并发锁，就可以实现数据一致性。

## API server

### 鉴权&准入

一个对API server的请求需要经过多个插件。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210072131829.png)

1. 鉴权插件

​		API server中有多个鉴权插件，API server会遍历这些插件直到找到一个能够识别请求用户的插件。

2. 鉴权插件again

   再次遍历鉴权插件，判断用户是否有权限执行这个请求。

3. 准入插件

   如果请求需要修改、创建、删除资源，那么就会进入准入插件。准入插件也有多个，其目的是为了保证相关数据的一致性，如ServiceAccount插件保证了如用户未明确serviceaccount，则为其使用默认的serviceaccount

### 异步通知

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210131222890.png)

1. 客户端通过HTTP连接API Server，用于获取对象更新事件
2. 修改对象
3. API Server更新对象到etcd
4. etcd通知API server对象更新
5. API Server将对象更新事件发送到所有监听该对象的客户端

### 调度器

## Controller Manager

k8s中有大量的控制器，如ReplicationController、ReplicaSet、Job等等，这些控制器实际上并不会直接控制其名义上控制的资源（如ReplicaSet之于Pod），而是通过其Manager进行控制。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210152100050.png)





这些控制器有：

- Replication Manager
- eplicaSet, DaemonSet, and Job controllers
- Deployment controller 
- StatefulSet controller
- Node controller
- Service controller
- Endpoints controller
- Namespace controller
- PersistentVolume controller
- 等等

大部分控制器的逻辑都相同，以ReplicationManager为例：

### Replication Manager

ReplicationController不会直接创建或删除Pod，而是通过监听机制，让ReplicationManager来监听到pod变更，并创建或修改Pod声明文件，调度器和kubelet会根据pod声明文件进行调度。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210151441710.png)

### Endpoints controller

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210152103527.png)

Endpoint控制器会监听Service和Pod两种资源，一旦Service增加或修改了Pod，或者Pod被新增、修改和删除后，Endpoint控制器会根据Service的pod选择器来选择合适的pod，并且将选择的pod的ip和端口更新到Endpoint资源上。 

## kubelet

kubelet是一个节点上用来为所有正在运行的事物负责的组件。

1. 当kubelet启动时，会将所在节点的信息注册到API server。
2. kubelet会持续监听API server，一旦有pod被调度到该节点，则创建该pod对应的容器。
3. kubelet会监控节点上所有容器，并上报其状态、事件和资源消耗情况到API server。

除监听API server外，kubelet还能通过指定声明文件来创建pod。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210152059337.png)



## 事件

### 部署Deployment时的事件链

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210152100135.png)





## 高可用

todo