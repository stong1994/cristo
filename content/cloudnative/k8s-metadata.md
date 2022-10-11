+++

date = 2022-08-07T21:19:00+08:00
title = "k8s-metadata"
url = "/cloudnative/k8s/metadata"

toc = true

draft = true

+++



## Downward API

我们可以使用volume或者secret来将配置信息注入容器，但这些配置信息是需要在pod创建前已知的。对于那些在pod创建后才能确定的信息，如pod的ip、名称等，则无法通过volume和secret配置。

downward API能够解决这个问题。

downward API能够将pod的元数据注入到pod中运行的进程。这些元数据有：

- pod名称
- pod ip
- pod所属namespace
- pod所在的节点名称
- pod所属的Service account
- 每个容器的CPU和内 请求数量
- 每个容器的CPU和内存限制数量
- pod的标签
- pod的注释

大部分元数据都可以通过环境变量和挂载卷的方式注入，只有pod的标签和注释只能通过挂载卷的方式注入。

### 通过环境变量注入

```yaml
apiVersion: vl
kind: Pod
metadata: 
	name: downward
spec: 
	containers:
  - name: main
  	image: busybox 
  	command: ["sleep", "9999999"]
  	resources:
  		requests: 
  			cpu: 15m 
  			memory: 100Ki
    	limits: 
    		cpu: 100m 
    		memory: 4Mi
  	env:
    - name: POD_NAME
    	valueFrom: 
    		fieldRef: 
    			fieldPath: metadata.name
    - name: POD_NAMESPACE
    	valueFrom: 
    	fieldRef: 
    			fieldPath: metadata.namespace
    - name: POD_IP
    	valueFrom: 
    		fieldRef: 
    			fieldPath: status.podIP
    - name: NODE_NAME
    	valueFrom: 
    		fieldRef: 
    			fieldPath: spec.nodeName
    - name: SERVICE_ACCOUNT
    	valueFrom: 
    		fieldRef: 
    			fieldPath: spec.serviceAccountName
    - name: CONTAINER_CPU_REQUEST_MILLICORES
    	valueFrom: 
    		resourceFieldRef: # request和limit只能通过resourceFieldRef来引用
       	  resource: requests.cpu
          divisor: 1m # 指定单位
    - name: CONTAINER_MEMORY_LIMIT_KIBIBYTES
    	valueFrom: 
    		resourceFieldRef: 
    			resource: limits.memory
          divisor: 1Ki
```

### 通过挂载卷注入

```yaml
apiVersion: v1
kind: Pod
metadata: 
	name: downward 
labels: 
	foo: bar
annotations:
	keyl: valuel
  key2: |
  	multi 
  	line
    value
spec: 
	containers:
  - name: main
  	image: busybox
    command: ["sleep", "9999999"]
    resources: 
    	requests: 
    		cpu: 15m 
    		memory: 100Ki 
    	limits: 
    		cpu: 100m
        memory: 4Mi 
    volumeMounts: 
    - name: downward
    	mountPath: /etc/downward
  volumes: 
  - name: downward 
  	downwardAPI: 
  		items:
      - path: "podName"
      	fieldRef: 
      		fieldPath: metadata.name
      - path: "podNamespace" 
      	fieldRef: 
      		fieldPath: metadata.namespace
      - path: "labels"
      	fieldRef:
        	fieldPath: metadata.labels
      - path: "annotations"
      	fieldRef: 
      		fieldPath: metadata.annotations
      - path: "containerCpuRequestMilliCores"
      	resourceFieldRef:
        	containerName: main
          resource: requests.cpu
          divisor: 1m
      - path: "containerMemoryLimitBytes"
      	resourceFieldRef:
        	containerName: main
          resource: limits.memory
          divisor: 1
```

上述配置将元数据挂载到了`/etc/downward`下，其中配置中的每个item下的path，就是`/etc/downward`下的一个个文件，文件内容就是其对应的元数据，如`/etc/downward/annotations`中的内容为：

```
keyl="valuel" 
key2="multi\nline\nvalue\n"
kubernetes.io/config.seen-"2016-11-28T14:27:45.664924282z"
kubernetes.io/config. source-"api"
```

#### 注意

1. 标签和注释支持热更新，即修改pod的标签和注释，k8s会自动将容器下对应的downward文件更新，这可能也是标签和注释不支持环境变量注入的原因。
1. 当注入容器水平的元数据时，需要指定容器的名称。比如上述配置中的containerCpuRequestMilliCores

## 访问API Server

当容器中的程序需要访问其他资源的信息或者获取最新的数据，这时就需要通过访问API Server来获取。

### 本地通过kubectl proxy访问

通过curl访问API Server需要提前获取API Server的地址、本地证书等信息，`kubectl proxy`提供了代理服务使得用户免于获取这些信息。

1. 查看代理地址: 

   ```shell
   $ kubectl proxy 
   Starting to serve on 127.0.0.1:80012. 访问
   ```

2. 访问代理：

   ```shell
   $ curl localhost:8001
   {
   	"paths": [
     	"/api",
       "/api/v1",
       ...
   ```

   该接口会访问分组和版本信息

3. 访问指定分组，如：

   ```shell
   $ curl http://localhost:8001/apis/batch
   { 
   	"kind": "APIGroup",
     "apiVersion": "v1",
     "name" : "batch",
     "versions": [
     	{ 
     		"groupVersion": "batch/v1",
         "version": "v1"
       },
       {
       	"groupVersion": "batch/v2alphal",
         "version": "v2alphal"
       }
     ],
     "preferredVersion": {
   		 "groupVersion": "batch/v1",
        "version": "v1"
      },
      "serverAddressByClientCIDRs": null
   }
   ```

4. 访问指定版本，如：

   ```shell
   $ curl http://localhost:8001/apis/batch/vl
   {
   	"kind": "APIResourceList",
     "apiVersion": "v1",
     "groupVersion": "batch/vl", 
     "resources": [
     	{
     		"name": "jobs",
       	"namespaced": true,
         "kind": "Job",
         "verbs": [
         	"create",
           "delete",
           "deletecollection",
           "get",
           "list",
           "patch",
           "update",
           "watch"
         ]
       },
       {
       	"name" : "jobs/status",
         "namespaced": true,
         "kind": "Job",
         "verbs": [
         	"get",
         	"patch",
           "update"
         ]
       }
   }
   ```

5. 访问具体的资源列表，如:

   ```yaml
   $ curl http://localhost:8001/apis/batch/vl/jobs
   {
   	"kind": "JobList",
     "apiVersion": "batch/v1",
     "metadata": {
     	"selfLink": "/apis/batch/v1/jobs",
       "resourceVersion": "225162"
     },
     "items": [
     	{
     		"metadata":
         	{
         		"name" : "my-job",
             "namespace" : "default",
             ...
   ```

6. 访问具体的资源，如

   ```yaml
   $ curl http://localhost:8001/apis/batch/vl/namespaces/default/jobs/my-job
   {
   	"kind": "Job",
     "apiVersion": "batch/vl",
     "metadata":
     	{ 
     		"name": "my-job",
         "namespace": "default",
         ...
   ```

   

### pod内通过ambassador容器访问

同上述过程，访问API Server需要获取其地址、权限信息，这些信息可以通过ambassador容器进行代理。

1. 定义pod

```yaml
apiVersion: vl
kind: Pod
metadata: 
	name: curl-with-ambassador
spec:
	containers:
  - name: main
  	image: tutum/curl
    command: ["sleep", "9999999"]
  - name: ambassador
  	image: luksa/kubectl-proxy:1.6.2
```

2. 通过ambassdor进行访问

   ```shell
   root@curl-with-ambassador:/# curl localhost:8001 
   {
   	"paths":
     	[
     		"/api",
     		...
   ```

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210071604508.png)
