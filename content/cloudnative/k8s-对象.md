+++

date = 2022-10-01T21:19:00+08:00
title = "k8s-对象"
url = "/cloudnative/k8s/pod"
tags = ["云原生", "k8s"]

toc = true

draft = false

+++

## 对象范畴

对象包括：

- pod：简写po
- node
- ReplicationController：简写rc
- ReplicaSet：简写rs
- events
- ServiceAccount：简写sc
- Secret
- ConfigMap
- PodSecurityPolicy：简写psp
- LimitRange
- ResourceQuota：简写quota
- HorizontalPodAutoscaler：简写hpa
- PodDisruptionBudget

## label

label用于对象分组。

可以通过label来筛选对象。

## annotation

annotation以键值对的形式存在，它不存储标识信息，也不能用于分组、筛选，它起到注释的作用，用于解释、说明。

## namespace

namespace实现了更大粒度上的分组，往往用于隔离不同环境中的资源（如实现开发、测试、正式环境之间的资源隔离）以及不同的团队使用相同的集群。

### 通过yaml文件创建

```yaml
apiVersion: vl
kind: Namespace
metadata:
	name: custom-ns
```

### 通过命令创建

`kubectl create namespace xxx`

## 命令

### 对象说明

通过`kubectl explain pods` 可获取pod的使用说明。

通过`kubectl explain pod.spec`可获取pod下的spec的使用说明。

其他对象同理。

### 对象描述

通过`kubectl describe rc xxx`可获取名为xxx的rc的信息。

其他对象同理。

### 根据yaml文件创建资源

`kubectl create -f xxx.yaml`

1. 指定namespace：`-n custom-namespace`
2.

### 修改对象

| 命令              | 描述                                                                                                                                                            |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| kubectl edit      | 使用默认编辑器打开对象的声明文件，一旦保存就会进行更新。ex：kubect1 edit deployment kubia                                                                       |
| kubectl patch     | 更改对象的单个属性，ex: kubect1 patch deployment kubia -p' {"spec" : {"template": {"spec": {"containers": [{"name": "nodejs", "image" : "luksa/kubia:v2"}]}}}}' |
| kubectl apply     | 根据配置文件更新（不存在时创建）对象，ex: kubect1 apply -f kubia-deployment-v2. yaml                                                                            |
| kubectl replace   | 根据配置文件替换（不存在则报错）对象，ex: kubect1 replace -f kubia-deployment-v2. yaml                                                                          |
| kubectl set image | 更改声明文件（Pod、RC、RS、Deployment、Demonset、Job）中指定的容器镜像，ex: kubectl set image deployment kubia nodejs=luksa/kubia:v2                            |
