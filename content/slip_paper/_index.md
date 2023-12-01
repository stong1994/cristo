## 2023.11.08

### 日本版的量化宽松

1. 日本央行增发货币
2. 用增发的货币买日本的银行债，导致银行债价格提升
3. 把日本的银行债交给越南(example)的银行作为越南增发货币的抵押
4. 越南增发了越南盾，为了避免本土通货膨胀，这些钱定向交给日资企业
5. 日资企业得到大量资金，占据市场

> 越南为什么要增发货币，对越南有何好处？

来源：[温铁军：日本没有军事霸权，为何还能学美国搞量化宽松？【践闻录】 - 北京大学 Peking University - YouTube](https://www.youtube.com/watch?v=E0S2e8Y2MmI&ab_channel=北京大学PekingUniversity)



## 2023.10.27

### 王阳明的“心外无物”中的“物”

> 王阳明的“心外无物”中的“物”并不是指客观存在的事物本身，而是指事物带来的感觉、道德、意境等。
>
> 比如《传习录》中记载的：
>
> “先生游南镇，一友指岩中花树问曰：“天下无心外之物，如此花树在深山中自开自落，于我心亦何相关？”先生曰：“你未看此花时，此花与汝心同归于寂。你来看此花时，则此花颜色一时明白起来，便知此花不在你心外”
>

## 2023.09.09

### 为什么要看书而不是看博客？

> 因为一本书就是一个范畴，是词语的”无法之地“。因此需要使用一本书的内容去构建这个范畴。否则对作者之外的人来说，无法理解这个知识——因为没有构建范畴——通过构建一个一个类比，来构成一条通往知识的道路。

### 选择的同时也是放弃

> 甚至于，选择的同时意味着放弃了更多。
>
> 比如说我们构建一个消息中台，需要用到消息队列，实现消息队列的中间件有很多，比如kafka、rabbitmq、redis、rocketmq等等。那我们要如何选择呢？
>
> 首先，要明确需求。
>
> 其次，要明确各个中间件支持的功能甚至于实现方式。
>
> 最后，比较、排除，得到最优的中间件。
>
> 在这个选择的过程中，我们要做很多的取舍，“得”的同时也要看到“失”。



## 2023.09.05

### Prometheus'Pull vs Jaeger's Push

> 对于数据的采集，Prometheus使用服务器Pull的方式而Jaeger使用客户端Push的方式，或许是由于Jaeger采集**的链路对象生命周期短**，Prometheus采集的指标对象生命周期长。这样服务器能够更快的释放链路对象所占用的内存；对于指标对象，通常占用内存少，因此不必考虑内存问题，而使用PULL的方式实现更简单。可参考[关于Push与Pull的对比](http://bit.ly/3aJEPxE)
