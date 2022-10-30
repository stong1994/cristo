+++

date = 2022-10-16T21:19:00+08:00
title = "k8s-可计算资源管理"
url = "/cloudnative/k8s/computational_resource"

toc = true

draft = false

+++



## LimitRange

LimitRange校验一个pod的资源消耗，被用于LimitRanger准入控制插件中，当一个pod声明文件被发往API server时，这个插件会校验pod中声明的资源限制，一旦校验不通过，则API server会拒绝接收这个pod声明文件。

example：

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: example
spec:
  limits:
  - type: Pod
    min:
      cpu: 50m
      memory: 5Mi
		max: 
			cpu: 1
      memory: 1Gi
  - type: Container
    defaultRequest: # 若pod中未声明资源请求(requests)数量，则使用默认的请求数量
			cpu: 100m
      memory: 10Mi
    default: # 若pod中未声明资源的限制(limits)数量，则使用默认的限制数量
			cpu: 200m
      memory: 100Mi
    min:
			cpu: 50m
      memory: 5Mi
    max:
			cpu: 1
      memory: 1Gi
    maxLimitRequestRatio:
      cpu: 4 # 容器的CPU limit不能超过request的4倍
      memory: 10
  - type: PersistentVolumeClaim
  	min:
    	storage: 1Gi
  	max:
    	storage: 10Gi
```

## ResourceQuota

用于限制一个namespace下的总资源消耗。

ResourceQuota被用于资源额度准入控制插件中，当创建pod时，判断该namespace下是否有足够的额度创建pod，若没有，则拒绝创建pod。

限制cpu和内存example：

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
	name: cpu-and-mem
spec:
	hard:
		requests.cpu: 400m
		requests.memory: 200Mi
		limits.cpu: 600m
		limits.memory: 500Mi
```

限制对象数量example：

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: objects
spec:
  hard:
    pods: 10 # 最多10个pod
    replicationcontrollers: 5 # 最多5个rc
    secrets: 10
    configmaps: 10
    persistentvolumeclaims: 4
    services: 5
    services.loadbalancers: 1
    services.nodeports: 2
    ssd.storageclass.storage.k8s.io/persistentvolumeclaims: 2
```

## 资源使用监控

k8s的每个节点上都有一个名为**cAdvisor**的代理，用于收集这个节点中所有容器的资源使用情况，并上报给**Heapster**——集群水平的组件，用于收集资源使用情况。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210161528539.png)

可通过`kubectl top`命令来查看所收集的数据，如`kubectl top node`，也可通过INFLUXDB和GRAFANA来存储和展示数据。