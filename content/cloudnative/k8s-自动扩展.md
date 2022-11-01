+++

date = 2022-10-15T21:19:00+08:00
title = "k8s-自动伸缩"
url = "/cloudnative/k8s/autoscaling"

toc = true

draft = false

+++



## Pod水平伸缩-HorizontalPodAutoscaler

### 自动伸缩过程

1. 获取所有被伸缩资源对象管理的所有pod的指标。
2. 计算使指标达到（或接近）指定目的值所需的pod数量。
3. 更新伸缩对象的`replicas`字段。

### 三种指标类型

1. Resource：如cpu、内存
2. Pods：关联到Pod上的任意指标，如QPS
3. Object：适用于不直接关联到pod上的指标，如其他对象的指标是否达到目的值

## Pod垂直伸缩

相对于水平伸缩的调整pod的数量，垂直伸缩是调整pod的cpu、内存请求/限制数量。

## Node水平伸缩

当请求数量猛增时，需要增加pod的数量来应对。k8s会匹配到合适的node，但是如果node资源紧缺，则无法找到合适的node，这时就需要node的自动伸缩。

node的自动伸缩需要云服务商提供支持。

### 自动扩容过程

1. 自动伸缩器发现pod不能被调度到存在的节点上。
2. 自动伸缩器找到能够适用于该pod的节点类型。
3. 自动伸缩器进行node扩容。

### 自动缩容

为了减少云服务器的开销，当一个节点上所有的pod的cpu和内存的请求都低于50%，则可以认为该节点是多余的。当然还需要考虑其他情况，如是否是系统pod。

当一个节点被关闭时，该节点会先被标记为不可调度，然后再驱逐节点上的pod。

### PodDisruptionBudget

一些服务需要保证最少数量的pod能够运行，这时可使用`PodDisruptionBudget`资源来避免自动缩容。

```yaml
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  name: kubia-pdb
spec:
  minAvailable: 3 # 最少3个pod可用
  selector:
    matchLabels:
      app: kubia
...
```

