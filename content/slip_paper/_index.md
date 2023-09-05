## Prometheus'Pull vs Jaeger's Push — 2022.09.05

> 对于数据的采集，Prometheus使用服务器Pull的方式而Jaeger使用客户端Push的方式，或许是由于Jaeger采集**的链路对象生命周期短**，Prometheus采集的指标对象生命周期长。这样服务器能够更快的释放链路对象所占用的内存；对于指标对象，通常占用内存少，因此不必考虑内存问题，而使用PULL的方式实现更简单。可参考[关于Push与Pull的对比](http://bit.ly/3aJEPxE)