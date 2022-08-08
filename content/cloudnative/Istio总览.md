+++

date = 2022-08-07T21:19:00+08:00
title = "Istio总览"
url = "/cloudnative/istio/overview"

toc = true

draft = true

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

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202208080030577.png)

## 控制平面

### Pilot

Pilot是控制控制平面的中枢系统，用于**管理和配置部署在Istio数据平面的边车代理**。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202208082339619.png)

### Citadel

Citadel是Istio中负责身份认证和证书管理的核心安全组件，主要包括CA服务器、SDS服务器、证书密钥控制器和证书轮换等模块。

### Galley

Galley是整个控制平面的配置管理中心，负责配置校验、管理和分发。Galley可以使用网格配置协议（Mesh Configuration Protocol）和其他组件进行配置的交互。



## Any Question？

1. 边车模式使得网络请求在每次服务访问中都增加了两跳（进入服务前被拦截&从服务出来后又被拦截），这会不会对整体的系统性能造成影响？

   Istio中不存在复杂的流量处理，因此处理速度非常快。一次请求的响应时间更多的取决于对底层数据库的请求和复杂业务逻辑的处理，因此Istio并不会对整体系统造成明显的性能影响。

   

## 相关阅读

- [What Is a Service Mesh?](https://www.nginx.com/blog/what-is-a-service-mesh/)