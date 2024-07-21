+++

date = 2022-10-11T21:19:00+08:00
title = "k8s-service"
url = "/cloudnative/k8s/service"
tags = ["云原生", "k8s"]

toc = true

draft = false

+++

在k8s中，容器代表着提供具体服务的程序，有些程序是需要被“外部”访问的。

在“云原生”之前，开发者往往通过网关来提供对外的访问能力。但容器是灵活的、可变的，可能随时被创建、销毁，因此外部访问者不能直接访问容器。而容器之上的pod也只是一个概念实体，并且pod也存在“临时”性，pod分配到哪个节点是不能确定的，因此并不能提供稳定的服务（如稳定的ip）。

于是k8s增加了service用于提供稳定的对外访问的服务（ip+port）。

## 创建Service

### 通过命令创建

`kubectl expose`

### 通过yaml文件创建

```yaml
apiVersion: vl
kind: Service
metadata:
	name: kubia
spec:
	ports:
		port: 80 # service提供的端口，用于外部访问
    targetPort: 8080 # 容器开放的端口，用于service访问
  selector: # pod的标签选择器
  	app: kubia
```

## 服务发现

### 通过环境变量

Service创建后，可在容器内部通过环境变量获取到Service的ip和port。

对于上文创建的kubia，容器内部的环境变量为KUBIA_SERVICE_HOST和KUBIA_SERVICE_PORT.

如果Service的名称具有中划线，则转为环境变量时会转为下划线。

### 通过DNS

k8s提供了DNS服务，每个Service在DNS服务中都具有一个DNS实体，每个pod的客户端都可以通过FQDN（full qualified domain name）来访问Service。

FQDN EXAMPLE: `kubia.default.svc.cluster.local`

- kubia: Service名称
- default: Service所在的namespace
- svc.cluster.local：可配置的集群域名前缀

访问Service时可只使用Service名称，即kubia。

## Endpoint

Service并不直接连接pod，而是使用另外一种资源：Endpoint。

Endpoint是一个地址（ip+端口）列表，

如果在创建Service是指定了pod选择器，那么Service会自动生成endpoint。

可以通过配置文件来创建一个Endpoint：

```yaml
apiVersion: v1
kind: Endpoints
metadata:
	name: external-service # 需要与Service的名称相同
subsets:
  - addresses: # service将连接指向这些ip
  	- ip: 11.11.11.11
  	- ip: 22.22.22.22
  	ports: # 后端的端口
  	- port: 80
```

Endpoint的name需要和Service保持一致。

可通过定制Endpoint来将集群外的服务“融入”Service中。

### 别名

可以为外部的Service设置别名，这样内部服务就可以通过这个别名来进行访问。

```yaml
apiVersion: v1
kind: Service
metadata:
	name: baidu
spec:
	type: ExternalName # 必须指定为ExternalName
  externalName: baidu.com
  ports:
  -	port: 80
```

这样就可以通过baidu.default.svc.cluster.local访问baidu.com

## 暴露服务到集群外

因为Service设置的是虚拟ip，因此只能供集群内访问。如果集群外的客户端想要访问Service，可以有几种方式

### NodePort

NodePort是一种Service，它会在集群所有的节点中保留一个端口，用于访问该Service。

```yaml
apiVersion: v1
kind: Service
metadata:
	name: kubia-nodeport
spec:
	type: NodePort # 类型设置
  ports:
  	port: 80 # Service内部的集群端口
    targetPort: 8080 # 后端pod暴露的端口
    nodePort: 30123 # 集群中的每个节点都能通过30123访问Service
	selector:
  	app: kubia
```

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210021611556.png)

### LoadBalancer

LoadBalancer在NodePort的基础上提供了负载均衡能力。

```yaml
apiVersion: v1
kind: Service
metadata:
	name: kubia-loadbalancer
spec:
	type: LoadBalancer
  ports:
  - port: 80
  	targetPort: 8080
  selector:
  	app: kubia
```

创建LoadBalancer之后，k8s会为其分配一个外部ip，通过这个ip就可以实现负载均衡的外部访问。

### Ingress

LoadBalancer的缺点在于需要为每个需要暴露的Service都要设置一个LoadBalancer，并且每个LoadBalancer都需要分配一个静态ip，因此并不是很实用。

Ingress则只需要一个静态ip就可以维护多个Service，就像nginx那样。

LoadBalancer之所以只能服务一个Service，在于k8s本身是只处理到tcp/udp层次的包，而不处理七层协议的包，ingress则可以处理http层次的包，因此可以解析路由。

example：

```yaml
apiVersion: extensions/vlbetal
kind: Ingress
metadata:
	name: kubia
spec:
	rules:
	- host: kubia.example.com
  http:
  	paths:
    	path: /
      backend:
      	serviceName: kubia-nodeport
        servicePort: 80
```

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210021637342.png)

## Headless Service

客户端通过Service会随机访问到一个pod，但有时需要访问Service下所有的pod，这时就需要设置为Headless Service。

Headless Service就是clusterIP为None的Service。

```yaml
apiVersion: v1
kind: Service
metadata:
	name: kubia-headless
spec:
	clusterIP: None
  ports:
  - port: 80
  	targetPort: 8080
  selector:
  	app: kubia
```

当使用DNS查询时，DNS Server会返回一系列pod的ip而不是一个pod的ip。

## 特性

1. 如果想要让同一个客户端每次都访问同一个pod，可以设置**spec.sessionAffinity**为**ClientIP**。该选项只有**ClientIP**和**None**两种，不支持cookie，因为k8s不处理HTTP级别的数据。

2. 一个service可以开放多个端口。

   ```yaml
   spec:
   	ports:
   	-	name: http
       port: 80
       targetPort: 8080
     - name: https
     	port: 443
       targetPort: 8443
     selector:
     	app: kubia
   ```

3. targetPort可以使用名称，前提是pod对port进行了命名

   ```yaml
   kind: Pod
   spec:
   	containers:
   	-	name: kubia
       ports:
       -	name: http
         containerPort: 8080
       - name: https
       	containerPort: 8443
   ```

   ```yaml
   apiVersion: v1
   kind: Service
   spec:
   	ports:
   	-	name: http
     	port: 80
       target Port: http
     - name: https
       port: 443
       targetPort: https
   ```

   好处是当需要修改port时，只修改pod的端口即可。

4. Service ip不能ping通，这是因为Service的ip是一个虚拟ip，只有和port一起使用才有意义。
