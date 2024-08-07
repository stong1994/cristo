+++

date = 2022-08-07T21:19:00+08:00
title = "Istio总览"
url = "/cloudnative/istio/overview"
tags = ["云原生", "Istio"]
toc = true

draft = false

+++

## 什么是Istio

**Istio是一个服务网格形态的平台，用于治理云原生中的服务。**

### 治理什么

微服务带来了更高的可用性、可维护性等一系列好处，同时也带来了更复杂的服务调用，复杂的服务调用导致了流量控制非常繁琐，而Istio的使命就是让流量控制更简单。

### 如何治理

治理手段应尽量避免对服务代码的侵入，否则维护成本会非常高。Istio是一个**服务网格形态**的平台，通过**边车代理**的方式实现了对服务实例的流量的管控。

Istio平台整体上可分为两部分：

- 控制平面：Istio平台的**中央控制器**，负责维护配置信息、响应管理员并控制整个网络。
- 数据平面：**拦截服务实例的流量**，并根据控制平面下发的配置来管控流量。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202208091941688.svg)

## 控制平面

控制平面的职责是管理数据平面中的边车代理，完成服务发现、配置分发、授权鉴权等功能。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202208092022467.png)

### Pilot

Pilot是控制控制平面的中枢系统，用于**管理和配置部署在Istio数据平面的边车代理**。

<img src="https://raw.githubusercontent.com/stong1994/images/master/picgo/202208082339619.png" style="zoom: 33%;" />

- **抽象模型**：为了实现对不同服务注册中心（Kubernetes、Consul等）的支持，Pilot需要对不同来源的输入数据进行统一格式的存储，即抽象模型。
- **平台适配器**： Pilot的实现是基于平台适配器的，借助平台适配器Pilot可以实现服务注册中心数据和抽象模型数据之间的转换。
- **xDS API**：Pilot使用了一套源于Envoy项目的标准数据平面API，将服务信息和流量规则下发到数据平面的Sidecar中。这套标准数据平面API，也被称为 xDS。
  - LDS，Listener发现服务：Listener控制Sidecar启动端口监听（目前支持的协议只有TCP），并配置L3/L4层过滤器，当网络连接完成时，配置好的网络过滤器堆栈开始处理后续事件。
  - RDS，Router发现服务：用于HTTP连接管理过滤器动态获取路由配置，路由配置包含HTTP 头部修改（增加、删除HTTP 头部键值）、Virtual Hosts（虚拟主机），以及Virtual Hosts定义的各个路由条目。
  - CDS，Cluster发现服务：用于动态获取Cluster信息。
  - EDS，Endpoint发现服务：用于动态维护端点信息，端点信息中还包括负载均衡权重、金丝雀状态等。基于这些信息，Sidecar可以做出智能的负载均衡决策。

### Citadel

Citadel是Istio中负责身份认证和证书管理的核心安全组件，主要包括CA服务器、SDS服务器、证书密钥控制器和证书轮换等模块。

#### CA服务器

Citadel中的CA 签发机构是一个gRPC服务器，启动时会注册两个gRPC服务：一个是CA服务，用来处理CSR请求（Certificate Signing Request）；另一个是证书服务，用来签发证书。CA 首先通过HandleCSR接口处理来自客户端的CSR请求，然后对客户端进行身份认证（包括TLS认证和JWT认证），认证成功后会调用CreateCertificate进行证书签发。

#### 安全发现服务器（SDS）

SDS是一种在运行时动态获取证书私钥的API，Istio中的SDS服务器负责证书管理，并实现了安全配置的自动化。

#### 证书密钥控制器

证书密钥控制器可以监听istio.io/key-and-cert类型的Secret资源，还会周期性地检查证书是否过期，并更新证书。

#### 证书轮换

Istio通过一个轮换器（Rotator）自动检查自签名的根证书，并在证书即将过期时进行更新。它本质上是一个协程（Goroutine），在后台轮询中实现。

#### 秘钥和证书的轮换过程

1. Envoy通过SDS API发送证书和密钥请求。
2. istio-agent作为Envoy的代理，创建一个私钥和证书签名请求（CSR），并发送给istiod。
3. 证书签发机构验证收到CSR并生成证书。
4. istio-agent将私钥和从istiod中收到的证书通过SDS API发送给Envoy。

<img src="https://raw.githubusercontent.com/stong1994/images/master/picgo/202208092036855.png" style="zoom:25%;" />

### Galley

Galley是整个控制平面的配置管理中心，负责配置校验、管理和分发。Galley可以使用网格配置协议（Mesh Configuration Protocol）和其他组件进行配置的交互。Galley解决了各个组件“各自为政”导致的可复用度低、缺乏统一管理、配置隔离、ACL管理等方面的问题。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202208092048416.png)

#### MCP协议

MCP提供了一套用于配置订阅和分发的API，这些API在MCP中可以被抽象为以下模型。

- source：“配置”的提供端，在Istio中，Galley即source。
- sink：“配置”的消费端，在Istio中，典型的sink包括Pilot和Mixer组件。
- resource：source和sink关注的资源体，就是Istio中的“配置”。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202208092053509.png)

## 数据平面

Istio数据平面核心是以Sidecar模式运行的智能代理。Sidecar模式将数据平面核心组件部署到单独的流程或容器中，以提供隔离和封装。

数据平面的Sidecar代理可以调节和控制微服务之间所有的网络通信，每个服务Pod在启动时会伴随启动istio-init和Proxy容器。其中，istio-init容器的主要功能是初始化Pod 网络和对Pod设置iptable规则，在设置完成后自动结束。

<img src="https://raw.githubusercontent.com/stong1994/images/master/picgo/202208091209833.png" style="zoom:33%;" />

### 数据平面的功能

- 服务发现：探测所有可用的上游或后端服务实例。
- 健康检测：探测上游或后端服务实例是否健康，是否准备好接收网络流量。
- 流量路由：将网络请求路由到正确的上游或后端服务。
- 负载均衡：在对上游或后端服务进行请求时，选择合适的服务实例接收请求，同时负责处理超时、断路、重试等情况。
- 身份认证和授权：在istio-agent与istiod的配合下，对网络请求进行身份认证、权限认证，以决定是否响应及如何响应，还可以使用mTLS或其他机制对链路进行加密等。
- 链路追踪：对每个请求生成详细的统计信息、日志记录和分布式追踪数据，以便操作人员能够明确调用路径并在出现问题时进行调试。

### 数据平面实现

- Envoy：Istio默认使用的数据平面实现方案，使用C++开发，性能较高。
- MOSN：由阿里巴巴公司开源，设计类似 Envoy，使用Go 语言开发，优化了过多协议支持的问题。
- Linkerd：一个提供弹性云原生应用服务网格的开源项目，也是面向微服务的开源RPC代理，使用Scala开发。它的核心是一个透明代理，因此也可作为典型的数据平面实现方案。

## Any Question？

1. 边车模式使得网络请求在每次服务访问中都增加了两跳（进入服务前被拦截&从服务出来后又被拦截），这会不会对整体的系统性能造成影响？

   Istio中不存在复杂的流量处理，因此处理速度非常快。一次请求的响应时间更多的取决于对底层数据库的请求和复杂业务逻辑的处理，因此Istio并不会对整体系统造成明显的性能影响。

## 相关阅读

- [What Is a Service Mesh?](https://www.nginx.com/blog/what-is-a-service-mesh/)
