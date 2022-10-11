+++

date = 2022-08-07T21:19:00+08:00
title = "k8s架构设计"
url = "/cloudnative/k8s/architecture"

toc = true

draft = true

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

### 通知

