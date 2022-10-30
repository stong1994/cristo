+++

date = 2022-10-08T21:19:00+08:00
title = "k8s-pod"
url = "/cloudnative/k8s/pod"

toc = true

draft = false

+++

## 什么是pod

Pod是一个逻辑概念——它代表了一组共同协作的容器。

Pod是一组容器——这意味着它可以只包含一个容器，也可以包含多个容器。

## 最小的构建单元&为什么需要pod

Pod是k8s中的最小的构建单元。这是因为容器的“隔离”特性导致的。

容器通过namespace实现了隔离，但实际使用中往往需要多个容器进行协作，如一个容器生产日志文件，另一个容器解析日志文件。

通过指定相同的namespace可以实现多个容器之间”取消隔离“，但这无疑会增加运维的工作复杂性。所以k8s将这一功能抽象出来，形成了一个新的概念——pod。 

### pause container—实现pod内容器”去隔离“

在节点上执行命令`docker ps`，会看到一个`pause`容器，这个容器的作用是持有pod的namespace——**该pod下的用户定义的容器都使用`pause`容器的namespace**。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210152100795.png)



## 决策：是否将容器放到同一个pod

1. 如果容器之间一定要共享namespace（如文件）就要放到同一个pod
2. 如果多个容器中的进程是一个“整体”，那么就应该放到同一个pod
3. 如果容器之间的scale策略、条件不同，那么就不应该放到同一个pod

## 配置

### 一个最简单的配置

```yml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.14.2
    ports:
    - containerPort: 80
```

### 使用宿主机的PID和IPC namespace

```yaml
spec:
  hostPID: true
  hostIPC: true
```

### 使用宿主机的网络namespace

```yaml
spec:
  hostNetwork: true
```

### 绑定宿主机的端口但不使用hostNetwork

```yaml
spec:
  containers:
  - image: luksa/kubia
    name: kubia
    ports: 
    - containerPort: 8080 # 指定容器端口为8080
      hostPort: 9000 # 指定宿主机端口为9000
      protocol: TCP
```

### PodSecurityPolicy

PodSecurityPolicy定义了pod的安全策略。包括：

- 是否能够使用宿主机的IPC、PID、网络等命名空间
- 能够绑定宿主机的哪些端口
- 能够使用哪些userID
- 能否创建privileged container
- 限定内核能力
- 能够使用哪些SELinux标签
- 能够使用哪些文件系统
- 能够使用哪些挂载卷
- 等

example；

```yaml
	apiVersion: extensions/v1beta1
  kind: PodSecurityPolicy
  metadata:
    name: default
  spec:
    hostIPC: false
    hostPID: false
    hostNetwork: false
    hostPorts:
    - min: 10000
      max: 11000
    - min: 13000
      max: 14000
    privileged: false
    readOnlyRootFilesystem: true
    runAsUser:
      rule: RunAsAny
    fsGroup:
      rule: RunAsAny
    supplementalGroups:
      rule: RunAsAny
    seLinux:
      rule: RunAsAny
    volumes:
		- '*'
```

PodSecurityPolicy是一个集群水平的资源，可以绑定到Role和ClusterRole。



### 命令

| 命令                                                | 说明                                                         |
| --------------------------------------------------- | ------------------------------------------------------------ |
| kubectl explain pods                                | 查看pod相关的配置说明，如查看下一级对象使用说明，则通过英文句号来连接属性，如kubectl explain pod.spec |
| kubectl create -f xx.yaml                           | 通过xx.yaml创建资源，如pod                                   |
| kubectl get pod  ex_pod -o yaml                     | 将ex_pod资源定义以yaml格式输出，可支持json格式               |
| kubectl logs ex_pod                                 | 查看ex_pod的日志                                             |
| kubectl logs ex_pod -c ex_container                 | 查看ex_pod下的ex_container容器日志                           |
| kubectl port-forward ex_pod 8888:8000               | 将本地端口8888映射到ex_pod的8000端口，即可通过本地8888访问到ex_pod的8000端口中 |
| kubectl label po xx_pod xx_tag=xx_value --overwrite | 将xx_pod的label的xx_tag设置/改为xx_value，如果是修改，则需要overwrite参数 |
| kubectl get po -l xx_tag=xx_vlaue                   | 展示label中xx_tag是xx_value的pod                             |
| kubectl get po -l env                               | 展示label中含有env标签的pod                                  |
| kubectl get po -l '!env'                            | 展示label中不含有env标签的pod                                |
| kubectl get po -l env in (prod, dev)                | 展示label中含有env标签为prod或者dev的pod                     |
| kubectl get po -l env notin (prod, dev)             | 展示label中含有env标签为不为prod且不为dev的pod               |

### 

## Pod lifecycle

### init container—初始化pod

init容器用于pod的初始化，pod可拥有任意数量的init容器。

pod定义的init容器会在pod启动后一个接一个的线性执行，当所有init容器执行完后才会执行主容器。

init容器往往用于等待主容器所依赖的service或者资源准备就绪。

example：

```yaml
spec:
  initContainers: # 定义init容器
  - name: init
    image: busybox
    command: # 循环等待http://fortune准备就绪
    - sh
    - -c
	  - 'while true; do echo "Waiting for fortune service to come up...";
    wget http://fortune -q -T 1 -O /dev/null >/dev/null 2>/dev/null 
    && break; sleep 1; done; echo "Service is up! Starting main container."'
```

### post-start hook

当容器的主程序启动后，会执行post-start钩子。

可以用于执行额外的应用命令而不用修改服务代码。

如果post-start钩子退出状态不是0，则主容器会被kill。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-poststart-hook
spec:
containers:
- image: luksa/kubia
  name: kubia
  lifecycle:
    postStart: # 定义posst-start钩子
      exec:
        command:
        - sh
        - -c
        - "echo 'hook will fail with exit code 15'; sleep 5; exit 15"
```

### pre-stop hook

当容器中断前会运行pre-stop钩子。主要用于实现容易的优雅退出。

example：

```yaml
lifecycle:
    preStop: # 定义pre-stop钩子
      httpGet:
        port: 8080
        path: shutdown
```

当容器中断后会发送`SIGTERM`信号到钩子。钩子会发送一个http请求，地址为`http:// POD_IP:8080/shutdown`.

### pod关闭流程

在k8s中，API server控制所有的对象的生命周期。

当API server收到一个请求删除对象的请求后，并不会直接删除对象，而是设置`deletionTimestamp`字段到这个对象上。pod上的kubelet监听到`deletionTimestamp`字段生成，会执行关闭流程。

1. 执行pre-stop钩子
2. 发送`SIGTERM`信号到容器的主程序。
3. 等待程序优雅关闭或者关闭超时。
4. 如果程序没有优雅关闭，则使用`SIGKILL`信号强制关闭。



## Pod Manager

### 存活探针（liveness probe）

pod管理器管理pod的生命周期，因此需要知道pod当前的状态，即pod是否存活。

目前有三种存活探针：

1. HTTP：能够正常响应（http响应状态码是2xx或者3xx）
2. TCP SOCKET：能够正常完成连接
3. EXEC：命令的退出状态码是0

HTTP 探针excample：

```yaml
apiVersion: vl
kind: pod
metadata:
	name: kubia-liveness
spec: 
	containers:
  	- image: luksa/kubia-unhealthy
    	name: kubia
      livenessProbe:
      	httpGet: 
      		path: / 
      		port: 8080
```

k8s存在重试机制，如果探针检测到异常，会重试多次，因此客户端无需实现重试。

### 就绪探针（readiness probe）

pod对外提供服务时，作为为其代理流量的Service需要知道pod是否已准备接收流量。

同存活探针相同，就绪探针也有三种：

1. HTTP
2. TCP SOCKET
3. EXEC

一旦就绪探针检测到某个pod没有就绪，就将其移出Endpoints。

EXEC探针example：

```yaml
apiVersion: v1
kind: ReplicationController
...
spec: 
	...
	template: 
		spec: 
			containers:
      - name: kubia
      	image: luksa/kubia
        readinessProbe:
        	exec: 
        		command:
            - ls
            - /var/ready
```

探针会在容器内执行 `ls /var/ready`，如果命令返回状态码不是0，则说明命令失败——pod未就绪。



### ReplicationController

ReplicationController是k8s中的一种资源，用来保证pod一直running。

如果pod由于某种原因消失，那么ReplicationController就会新建一个。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210021129017.png)

三个关键元素：

1. 标签选择器：RC使用标签选择器来控制管理范围
2. 副本数量: 即期望的pod数量
3. pod模版：创建pod副本时使用

example：

```yaml
apiVersion: v1
kind: ReplicationController
metadata: 
	name: kubia
spec:
	replicas: 3
  selector:
  	app: kubia
  template:
  	metadata: 
  		labels: 
  			app: kubia
    spec: 
    	containers: 
    		name: kubia
        image: luksa/kubia
        ports: containerPort: 8080
```

注意：

1. 改变模版不会影响正在运行的pod
2. 修改pod的标签，会导致rc创建新的pod
3. 修改rc中的标签选择，会导致rc创建新的pod
4. 默认情况下删除rc会导致其管理的pod被删除，如不想pod被删除，需使用参数cascade。`kubectl delete rc xxx --cascade=false`

### ReplicaSet

RS是升级版的RC，相较于RC，RS提供了更丰富的标签选择机制。如

1. RS可以同时匹配一个标签的多个值，如env=dev和env=pd两种标签，而RC不可以。
2. RS可以匹配标签而不管其值如何，RC不可以。

RS支持的操作符：

1. In：标签的值匹配任意指定的值
2. NotIn：与上相反
3. Exists：必须存在指定标签，不关心值如何
4. DoesNotExist：不存在指定标签

如果指定了多个操作符，则最终的匹配为这些规则都必须满足。

```yaml
selector: 
	matchExpressions: 
		key: app 
		operator: In 
		values: kubia
```

也可以像RC那样不使用操作符：

```yaml
selector: 
	matchLabels: 
		app: kubia
```

### DaemonSet

DS保证一个pod在每个节点有且只有一个，常用于基础组件相关的pod。

DS使用节点选择器来筛选节点。

```yaml
apiVersion: apps/v1beta2
kind: DaemonSet
metadata: 
	name: ssd-monitor
spec:
	selector: 
		matchLabels:
    	app: ssd-monitor
  template: 
  	metadata: 
  		labels: 
  			app: ssd-monitor
    spec: 
    	nodeSelector: 
    		disk: ssd
      containers:
      	name: main
        image: luksa/ssd-monitor
```

以上配置会在标签disk为ssd的节点上部署一个只有一个容器的pod，容器镜像为luksa/ssd-monitor

### Job

Job用于那些只执行一次任务的pod。

```yaml
apiVersion: batch/v1
kind: Job
metadata: 
	name: batch-job
spec: 
	completions: 5 # 运行5个pod，默认串行执行
	parallelism: 2 # 设置为2，则表示允许最大并行数为2
	activeDeadlineSeconds: 10 # 超时时间，超过此配置则终止pod
	backoffLimit: 6 # 重试次数
	template: 
		metadata: 
			labels: 
				app: batch-job
    spec: 
    	restartPolicy: OnFailure
    containers: 
    name: main
    image: luksa/batch-job
```

### CronJob

CronJob用于执行定时任务。

```yaml
apiVersion: batch/v1betal
kind: CronJob
metadata: 
	name: batch-job-every-fifteen-minutes
spec: 
	schedule: "0,15,30,45 * * * *" # cron规则
	startingDeadlineSeconds: 15 # 必须在指定时间的15s内执行，否则不执行并视为失败
  jobTemplate: 
  	spec:
    	template: 
    		metadata: 
    			labels: 
    				app: periodic-batch-job
    		spec: 
    			restartPolicy: OnFailure
        	containers: 
        		name: main
            image: luksa/batch-job
```

### 滚动更新-kubectl命令

升级版本时往往使用滚动更新的方式来避免服务不可用。kubectl提供了命令来实现。

```shell
$ kubectl rolling-update kubia-vl kubia-v2 --image=luksa/kubia:v2
Created kubia-v2 Scaling up kubia-v2 from 0 to 3, scaling down kubia-vl from 3 to 0 (keep 3 pods available, don't exceed 4 pods)
```

该命令为：已有旧版本kubia-v1，想要更新为kubia-v2，新的镜像标签为kubia:v2。

命令执行后会立即创建新的RC：kubia-v2，并且逐渐替换掉旧有的三个pod

### Deployment

相较于RC、RS这些对象而言，Deployment是更高级的对象。Deployment并不直接管理pod，它使用RS来管理pod。当创建一个Deployment后，会自动创建一个RS。

k8s的核心理念之一就是声明式设计，因此滚动更新也应该通过声明的方式来实现，Deployment正是这样包含滚动更新的pod管理工具。

#### 部署

```yaml
apiVersion: apps/vibetal
kind: Deployment
metadata: 
	name : kubia
spec:
	replicas: 3
  template: 
  	metadata: 
  		name : kubia
    labels: app: kubia
  spec: 
  	containers:
    - image: luksa/kubia:v1
    	name : nodejs
```

部署后可以看到该Deployment创建的RS

```shell
$ kubectl get replicasets 
NAME 							DESIRED CURRENT AGE 
kubia-1506449474  3 		  3 		  10s
```

#### 滚动更新

更新Deployment中的镜像标签

```shell
$ kubectl set image deployment kubia nodejs=luksa/kubia:v2 
deployment "kubia" image updated
```

命令执行后kubia就会由v1滚动更新至v2

#### 查看滚动状态

```shell
$ kubectl rollout status deployment kubia
Waiting for rollout to finish: 1 out of 3 new replicas have been updated... 
Waiting for rollout to finish: 2 out of 3 new replicas have been updated... 
Waiting for rollout to finish: 1 old replicas are pending termination... 
deployment "kubia" successfully rolled out
```

#### 回滚

```shell
$ kubectl rollout undo deployment kubia
deployment "kubia" rolled back
```

指定版本

```
kubectl rollout undo deployment kubia --to-revision=1
```

#### 控制滚动频率

```yaml
spec:
	strategy:
  	rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
  type: RollingUpdate
```

- maxSurge: pod能够同时退出的最大数量，最多且默认是25%
- maxUnavailable：相对于期望的pod数量能够允许多少pod是不可用的，默认是25%

#### 暂停滚动

```shell
$ kubectl rollout pause deployment kubia
deployment "kubia" paused
```

#### 启动滚动

```shell
$ kubectl rollout resume deployment kubia
deployment "kubia" resumed
```

#### 配置就绪探针

如果就绪探针获取到pod未就绪，则不会向外提供该pod的服务。

```yaml
apiVersion: apps/v1beta1
...
spec:
	...
	template:
		...
		spec:
			...
			containers:
			- image: luksa/kubia:v3
				...
				readinessProbe:
					periodSeconds: 1
					httpGet:
						path: /
						port: 8080
```

### StatefulSet

RC、RS、Deployment这些都是用来管理无状态的服务的，对于有状态的服务则需要使用StatefulSet。

StatefulSet将每个pod视为不可替代的，并且具有固定名称和状态。

#### 稳定的标识

每个被SS创建的pod都会被分配一个有序的索引号，这个索引号被用来生成pod的name和hostname，并且用了关联一个稳定的存储。序列号从0开始递增。

由于每个pod都是不可替代的，因此需要使用HeadlessService来提供服务。于是在DNS Server中，每个pod都拥有自己的DNS实体，每个pod都能够通过hostname进行访问。

当一个pod意外结束后，SS会再创建一个相同标识的pod。

#### 扩展策略

1. 在缩容场景下，SS会自动结束高序列号的pod
2. 缩容时，SS在同一时间只会关闭一个pod，防止在分布式场景下丢失数据。
3. 缩容时，只会删除pod而不会删除PVC，防止PV被回收或者删除导致数据丢失。

#### example

```yaml
apiVersion: apps/v1beta1
kind: StatefulSet
metadata:
  name: kubia
spec:
  serviceName: kubia
  replicas: 2
  template:
    metadata:
      labels:
        app: kubia
    spec:
      containers:
      - name: kubia
        image: luksa/kubia-pet
        ports:
        - name: http
          containerPort: 8080
        volumeMounts:
        - name: data
          mountPath: /var/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      resources:
        requests:
          storage: 1Mi
      accessModes:
      - ReadWriteOnce
```

与RS相比，多了一个`volumeClaimTemplates`，上述配置中名为`data`的`volumeClaimTemplates`会在创建pod的PVC时使用.

在部署时，只有前一个pod准备好才会创建下一个pod。

#### 服务发现

##### SRV记录

k8s通过创建SRV记录来指向headlessService下的pod的hostname和port。

```shell
$ kubectl run -it srvlookup --image=tutum/dnsutils --rm
	--restart=Never -- dig SRV kubia.default.svc.cluster.local
```



如果一个pod想要查找同一个SS下的其他pod，可以通过SRV DNS查找.

#### 服务故障

假设一个节点的网络出现故障无法与其他节点交流，如果api server重新生成一个pod，那么这新旧两个pod的名称可能相同，这意味着他们使用的存储也是相同的。这时数据就有可能出现问题。

为了避免这种问题，k8s只有在确定一个pod被删掉才会重新创建pod。

对于上述假设，k8s的处理流程是：

1. api server将该故障节点状态改为NotReady，pod状态改为Unknown
2. pod状态持续一段时间后仍没有恢复，会被k8s驱逐——删除pod的资源，但是由于节点服务获取到消息，因此pod一直在运行。

3. 这种情况下，只能通过手动删除pod。

