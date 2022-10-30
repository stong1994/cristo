+++

date = 2022-10-16T21:19:00+08:00
title = "k8s-调度器"
url = "/cloudnative/k8s/autoscaling"

toc = true

draft = false

+++



## taint & toleration

taint和toleration用来限制pod部署到特定的node。taint是node的属性，toleration是pod的属性。一个pod只会被调度到能够容忍（toleration）它的污点（taint）的节点上。

taints的格式为`<key>=<value>:<effect>`，其中effect可以为：

- NoSchedule：如果pod不容忍节点的污点，则不会被调度到该节点。
- PreferNoSchedule：一个软NoSchedule，pod尽量不被调度到这些有不能容忍的污点的节点上，但是如果没有其他可用的节点，那么仍会部署到这些节点上。
- NoExecute：前两者只会影响待调度的pod，而NoExecute则也会影响已经运行的pod，如果向节点添加一个NoExecute污点，那么节点上的pod会被驱逐。

查看k8s的主节点：`kubectl describe node master.k8s`

```shell
Name: master.k8s
Role:
Labels:
              beta.kubernetes.io/arch=amd64
              beta.kubernetes.io/os=linux
              kubernetes.io/hostname=master.k8s
              node-role.kubernetes.io/master=
Annotations:  node.alpha.kubernetes.io/ttl=0
              volumes.kubernetes.io/controller-managed-attach-detach=true
Taints:       node-role.kubernetes.io/master:NoSchedule
```

## affinity

affinity是pod的属性，每个pod都可以定义其亲和性（affinity）规则，这意味着k8s会更青睐于将其调度到对应的节点上。

