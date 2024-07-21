+++

date = 2022-08-17T21:19:00+08:00
title = "Istio可观测性"
url = "cloudnative/istio/observe/"
tags = ["云原生", "Istio", "Jaeger","ELK", "Prometheus"]
toc = true

draft = false

+++

Isito作为服务网格，本身并不提供可观测行的能力，但是Istio可以非常方便的集成这些工具。

可观测性可分为三大块：监控、日志和链路追踪。

## 监控

### Prometheus

Prometheus是当下最流行的监控工具，其主要组件包括：

- Prometheus server：核心组件，拉取数据并存入时序数据库
- Pushgateway：一般情况下，Prometheus Server会主动拉取数据，但是无法适用于生命周期短的任务服务，对于这些服务，Prometheus提供了Pushgateway以供服务进行上报数据。
- Service discovery：服务发现组件基本上已经成为微服务时代的标配。
- Alertmanager：Prometheus支持自定义指标和报警策略，当触发了配置的条件，则进行报警处理。
- Web UI：Prometheus支持客户端通过PromQL来查询数据，常用的开源客户端为Grafana。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202208171239086.png)

### Grafana

Grafana能够将存储的指标、追踪信息通过可视化的方式展示出来。

Grafana支持多种数据来源，包括：Prometheus、Zipkin、Jaeger、MySQL、Elasticsearch等。

Grafana支持可配置的可视化、自定义的查询，并提供了报警系统。

另外，Grafana还有一系列的”周边“开源项目，如：

- [Grafana Loki](https://grafana.com/docs/loki/latest/)：提供了更丰富的日志堆栈。
- [Grafana Tempo](https://grafana.com/docs/tempo/latest/?pg=oss-tempo&plcmt=hero-txt/): 提供了更强大的分布式追踪能力。
- [Grafana Mimir](https://grafana.com/docs/mimir/latest/): 为Prometheus提供了可扩展的长期存储服务。

### Kiali

Kiali是专用于Istio服务网格的管理工具，其核心功能包括：

1. 可视化网格拓扑结构：通过监控网格中的数据流动来推断网格的拓扑结构，让用户更直观地了解服务之间的调用关系。
1. 健康状态可视化：通过Kiali，可以直观的看到网格中服务的健康状态。
1. 更强大的追踪能力：Kiali集成了Jaeger并提供了更丰富的能力，包括：工作负载可视化、随时间推移而聚合的持续时间指标等等
1. 监控Istio基础设施的状态。
1. Istio配置工具：提供了web页面来配置Istio，并提供校验能力。

## 日志

### 日志采集

日志文件的采集方式有两种，一种是构建单独的日志采集Pod，另一种是在Pod内构建日志采集Sidecar。Filebeat是目前常用的采集工具。

#### 单独的日志采集Pod

基于节点的部署方式，在k8s中，以DaemonSet方式部署，将容器的日志挂载到Filebeat Pod中。

<img src="https://raw.githubusercontent.com/stong1994/images/master/picgo/202208151236876.png" style="zoom:25%;" />

#### 日志采集Sidecar

Envoy和Filebeat 部署在同一个Pod内，共享日志数据卷，Envoy 写，Filebeat读，实现对Envoy 访问日志的采集。

<img src="https://raw.githubusercontent.com/stong1994/images/master/picgo/202208151241562.png" style="zoom:25%;" />

### ELK Stack

ELK是三种工具的简称：

- Elasticarch: 开源分布式搜索引擎，提供搜集、分析、存储数据三大功能。
- Logstash：数据处理工具，将多个数据源采集到的数据进行解析、转换，并存储到指定的数据库中。
- Kibana：具有日志分析、查询、汇总等功能的web管理端。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202208151256899.png)

### EFK

区别于ELK，EFK使用Fluentd替代了Logstash，更准确的说，是替代了Logstash+Filebeat。

不同类型的、不同来源的日志都通过Fluentd进行统一的日志聚合和处理，并发送到后端进行存储，实现了较小的资源消耗和高性能的处理。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202208151308500.png)

## 链路追踪

链路追踪已经成为微服务时代的不可缺少的组件。当一个系统中的微服务往往分配给多个开发人员维护，每个开发人员只能了解自己负责的服务逻辑，对于一个请求的整体链路缺少认知。通过链路追踪，开发人员能够更清晰的了解一个请求的整体面貌。

### OpenTracing & Jaeger

OpenTracing是一个项目，也是一套规范，这套规范已经成为了云原生下链路追踪的实现标准。重点概念包括：

- Trace：一个请求从开始到结束的整个过程。
- Span：一个追踪单位，由名称和一段时间来定义，一个Trace由多个Span组成。
- Span Context：一次追踪中的上下文信息，包括TraceID、SpanID以及存储的log等信息。在服务之间调用时，往往将信息进行序列化存储在请求头部，接受服务接收到请求后将信息提取出来，并构建自己的Span Context。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202208161255535.png)

Jaeger已经成为了OpenTracing首选的实现组件，[OpenTracing官网](https://opentracing.io)使用的项目正是Jaeger。其他实现了OpenTracing的开源项目有：Zipkin、SkyWalking等。

### 架构

Jaeger的整体架构由以下部分组成：

- jaeger-client：通过代码在服务内部推送Jaeger数据到jaeger-agent，社区内已实现了常用语言的框架，开发能够以非常低的成本进行接入。
- jaeger-agent：收集agent-client推送的数据，并推送到jager-collector。jaeger-agent可以单独部署在pod中，也可以直接部署在container中（以边车的方式）。
- jaeger-collector：接受agent发送的数据，验证追踪数据并建立索引，最后异步存入数据库
- DB：链路数据存储器，支持内存、Cassandra、Elasticsearch、Kafka。
- UI：主要的用户交互页面，用于查询、展示数据。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202208161257799.png)
