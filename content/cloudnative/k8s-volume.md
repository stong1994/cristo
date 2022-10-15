+++

date = 2022-10-12T21:19:00+08:00
title = "k8s-volume"
url = "/cloudnative/k8s/volume"

toc = true

draft = false

+++

容器内的进程在容器内创建的文件并不是持久的，其生命随着容器的结束而结束，这意味着容器重启后将丢失之前的数据。

volume正是为了解决这一问题而产生的。

## emptyDir

emptyDir是最简单的volume，其随着容器的创建而创建，随着容器的结束而结束。

emptyDir可用于容器内临时的写入，也可以用于容器间共享文件。

```yaml
apiVersion: vl
kind: Pod
metadata: 
	name: fortune
spec:
	containers:
	- image: luksa/fortune
  	name : html-generator
    volumeMounts: 
    - name: html
    	mountPath: /var/htdocs 
  - image: nginx:alpine
  	name: web-server
    volumeMounts: 
    - name: html
    	mountPath: /usr/share/nginx/html
      readOnly: true 
    ports:
    - containerPort: 80
    	protocol: TCP
  volumes: 
  - name: html
  	emptyDir: {}
```

## hostPath

在一些场景中，我们需要访问容器所在节点的文件系统，这时就需要使用hostPath.

由于使用的是节点的文件系统，因此hostPath是持久性的volume。

docker的日志文件存储在宿主机就是最经典的一个例子。

```yaml
Volumes: 
	varlog: 
		Type: HostPath (bare host directory volume)
    Path: /var/log
  varlibdockercontainers:
  	Type: HostPath (bare host directory volume)
    Path: /var/lib/docker/containers
```

## PersistentVolumes & Claim

### PersistentVolumes

在实际的生产中，往往具备多种存储方式，如NFS、GCE的存储服务或者AWS的存储服务等等，每种存储服务又具备多种存储类型、大小等等。这些“复杂的信息”让使用方非常困扰。

k8s的理念之一是使开发者无需关心具体的基础设施细节，只需声明就能够使用。于是产生了PersistentVolumes.

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210052046175.png)

1. 管理者设置某种类型的网络存储
2. 管理者在k8s中注册一个PV
3. 开发者声明存储所需的配置，即PVC
4. k8s找到一个符合条件的PV，将其与PVC绑定
5. 开发者创建一个pod，并关联PVC

通过这种方式，开发者完全无需关心底层存储的细节。

PV没有namespace的概念，即被PV定义的资源是“全局”的。

example：

```yaml
apiVersion: vl
kind: PersistentVolume
metadata:
	name: mongodb-pv
spec: 
	capacity: 
		storage: 1Gi
  accessModes:
  - ReadWriteOnce
  - ReadOnlyMany
  persistentVolumeReclaimPolicy: Retain
  qcePersistentDisk:
  	pdName: mongodb
    fsType: ext4
```

### PersitentVolumeClaim

开发者并不直接使用PV，而是通过声明一个PVC来使用。

example：

```yaml
apiVersion: vl
kind: PersistentVolumeClaim
metadata: 
	name: mongodb-pvc
spec: 
	resources: 
		requests: 
		  storage: 1Gi
  accessModes:
  - ReadWriteOnce
  storageClassName: ""
```

k8s会找到大小为1GiB的具有ReadWriteOnce权限的PV，并绑定到这个PVC。

### 三种权限

- ReadWriteOnce(RWO): 只有一个node能够挂载并读写这个volume
- ReadOnlyMany(ROX): 多个node能够挂载并且只读这个volume
- ReadWriteMany(RWX): 多个node能够挂载并且读写这个volume

### 在pod中使用pvc

```yaml
apiVersion: v1
kind: Pod
metadata: 
	name: mongodb
spec: 
	containers: 
	- image: mongo 
		name: mongodb
    volumeMounts:
    - name: mongodb-data
    	mountPath:/data/db
    ports: 
    - containerPort:27017
    	protocol: TCP
  volumes:
  - name: mongodb-data
  	persistentVolumeClaim:
    	claimName: mongodb-pvc
```

k8s会找到名为mongodb-pvc的PVC，找到与之绑定的PV并挂在到该pod上。

### ReclaimPolicy

当pvc被删除后，PV内存储的数据如何处理有以下几种策略（对应PV配置中的persistentVolumeReclaimPolicy字段）：

- Retain：保留策略，数据不会自动删除。这种策略下只有手动回收PV。
- Recycle: 回收策略，这种策略下删除PVC会自动回收PV。
- Delete：直接删除底层的存储。

## StorageClass

开发者在使用PVC之前，需要运维人员准备好PV，我们可以优化流程：开发者声明了一个PVC之后就自动创建一个PV。实现这种功能的正是StorageClass。

```yaml
apiVersion: storage.k8s.io/vl
kind: StorageClass
metadata: 
	name: fast
provisioner: kubernetes.io/gce-pd
parameters: 
	type: pd-ssd
  zone: europe-westl-b
```

### 在PVC中使用StorageClass

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: 
	name: mongodb-pvc
spec: 
	storageClassName: fast
	resources: 
		requests: 
			storage: 100Mi
  accessModes:
  - ReadWriteOnce
```

如果没有声明storageClassName，则会使用默认的SC。

如果指定storageClassName为空字符串，则会为其绑定预先提供的PV。

如果指定storageClassName不为空字符串，则会为其创建一个新的PV。

### 动态的PV供应

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210052046175.png)

