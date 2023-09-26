+++

date = 2023-09-12T19:43:00+08:00
title = "事件驱动系列—watermill"
url = "/internet/event-driven/watermill"

toc = true

+++



## 背景
使用HTTP构建应用时无需关注HTTP的底层协议，同样，使用事件驱动时同样也应无需关注事件的底层协议——[watermill](https://github.com/ThreeDotsLabs/watermill)为我们封装好了这些功能。

## Base Usage

### Event

事件由两方面构成：数据结构和命名。

数据结构由发送方定义，但往往也要综合考虑订阅方的需求，比如员工离职事件可以只包含企业ID和员工ID，但员工更新事件可能就要包含更新字段的新旧两种数据，就像MySQL的binlog（Row格式）一样。

数据结构也不能任意改动，实际上数据结构是订阅双方的一种协议。如果一定要改数据结构，需要了解都有哪些订阅方，会造成哪些影响。

#### 命名

在事件驱动的系统中会存在大量的事件，事件成了业务逻辑的“枢纽”，因此事件的命名尤为重要。

**事件要命名为过去式，表示已发生的事件。**

场景举例：当用户注册后，需要发送邮件。让我们看下这个事件应如何命名：`UserSignedUp` 还是`SendWelcomeEmailIsReadyToSend`?

前者代表了**用户已经注册**，后者表示**将要发送邮件**。看起来差别不大？

现在有个新需求，要在用户注册后将用户加入消息推送列表。

- 对于`UserSignedUp`，只需要添加一个新的订阅者即可。
- 对于`SendWelcomeEmailIsReadyToSend`，则需要在原有的代码基础上再发送一个`JoinMessageSubscribeList`事件。

这就是为什么要将事件命名为过去式！

### Publisher

事件需要发送者和订阅者，watermill自然也对这些进行了封装。

```go
type Publisher interface {
	Publish(topic string, messages ...*Message) error
	Close() error
}
```

Publisher的API相当简洁（这也是watermill的一个设计哲学）

#### Constructor

watermill中已经集成了多种Publisher，如kafka、rabbitmq、nats等等。我们以使用redis stream为例创建一个publisher：

```go
func NewRedisPublisher(rdb *redis.Client, watermillLogger watermill.LoggerAdapter) message.Publisher {
	var pub message.Publisher
	pub, err := redisstream.NewPublisher(redisstream.PublisherConfig{Client: rdb}, watermillLogger)
	if err != nil {
		panic(err)
	}
	pub = observability.TracingPublisherDecorator{pub}
	return pub
}
```

#### Decortor

可以使用装饰器来包装publisher，如在消息中加入链路信息：

```go
type TracingPublisherDecorator struct {
	message.Publisher
}

func (p TracingPublisherDecorator) Publish(topic string, messages ...*message.Message) error {
	for i := range messages {
		otel.GetTextMapPropagator().Inject(messages[i].Context(), propagation.MapCarrier(messages[i].Metadata))
	}
	return p.Publisher.Publish(topic, messages...)
}
```

我们构造了一个TracingPublisherDecorator，使用时直接“套”在publisher上就可以了：

```go
pub, err := redisstream.NewPublisher(redisstream.PublisherConfig{Client: rdb}, watermillLogger)
if err != nil {
  panic(err)
}
pub = observability.TracingPublisherDecorator{pub}
```

#### Config

每个发送者的实现都依赖于“消息队列”，而每个消息队列支持的功能不同，配置也不同。基于redis的stream实现的发送者的配置如下：

```go
type PublisherConfig struct {
	Client     redis.UniversalClient
	Marshaller Marshaller
	Maxlens    map[string]int64
}
```



### Subscriber

订阅者的封装逻辑基本上与Publisher一致，不再赘述。



## Router

router的用法和HTTP框架的router很像。

### 基本用法

```go
  logger := watermill.NewStdLogger(false, false)

  router, err := message.NewRouter(message.RouterConfig{}, logger)
  if err != nil {
    panic(err)
  }
  rdb := redis.NewClient(&redis.Options{
    Addr: os.Getenv("REDIS_ADDR"),
  })
  sub, err := redisstream.NewSubscriber(redisstream.SubscriberConfig{
    Client: rdb,
  }, logger)
  if err != nil {
    panic(err)
  }

  pub, err := redisstream.NewPublisher(redisstream.PublisherConfig{
    Client: rdb,
  }, logger)
  if err != nil {
    panic(err)
  }

  router.AddHandler(
    "handler for test",
    "subscriber_topic",
    sub,
    "publisher_topic",
    pub,
    func(msg *message.Message) ([]*message.Message, error) {
      // 处理逻辑
      return []*message.Message{msg}, nil
    },
  )
	err = router.Run(context.Background())
	if err != nil {
		panic(err)
	}
```

上面的代码很像我们平时使用的HTTP框架。其中主要的元素为：

- sub: 通过redis的stream构造的订阅者
- pub: 通过redis的stream构造的发布者
- subscriber_topic: 这个路由订阅的主题
- publisher_topic: 这个路由发布的主题

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202309121528483.png)

### AddNoPublisherHandler

如果只是处理事件而无需再次发布事件，可以使用`NoPublisherHandler`.

```go
router.AddNoPublisherHandler(
		"handler for test",
		"subscriber_topic",
		sub,
		func(msg *message.Message) error {
			// 处理逻辑
			return nil
		},
	)
```

可以对同一个topic添加了多个Handler，这样同一个topic的数据就可以被多个Handler处理。

> 实现了类似消费者组的功能，但不同于消费者组的消费逻辑，这里实现的是路由逻辑。比如说如果需要将事件保存到数据湖，则应该在路由层添加Handler。

### Middleware

中间件可以用来处理鉴权、增加日志、添加链路信息等等。

#### Log

```go
  router.AddMiddleware(func(h message.HandlerFunc) message.HandlerFunc {
		return func(msg *message.Message) ([]*message.Message, error) {
			logger.Info("log", watermill.LogFields{"payload":string(msg.Payload)})
			return h(msg)
		}
	})
```

#### Recover

```go
router.AddMiddleware(middleware.Recoverer)
```

#### Retry

```
router.AddMiddleware(middleware.Retry{
		MaxRetries:      10,
		InitialInterval: time.Millisecond * 100,
		MaxInterval:     time.Second,
		Multiplier:      2,
		Logger:          watermillLogger,
	}.Middleware)
```

#### Prometheus

```go
var (
	messageProcessTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Namespace: "messages",
			Name:      "processed_total",
			Help:      "The total processed messages",
		},
		[]string{"topic", "handler"},
	)
	messageProcessFailedTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Namespace: "messages",
			Name:      "processed_failed_total",
			Help:      "The total processed messages",
		},
		[]string{"topic", "handler"},
	)
	messagesProcessingDuration = promauto.NewSummaryVec(
		prometheus.SummaryOpts{
			Namespace:  "messages",
			Name:       "processing_duration_seconds",
			Help:       "The total time spent processing messages",
			Objectives: map[float64]float64{0.5: 0.05, 0.9: 0.01, 0.99: 0.001},
		},
		[]string{"topic", "handler"},
	)
)

router.AddMiddleware(func(h message.HandlerFunc) message.HandlerFunc {
		return func(msg *message.Message) ([]*message.Message, error) {
			topic := message.SubscribeTopicFromCtx(msg.Context())
			handler := message.HandlerNameFromCtx(msg.Context())
			labels := prometheus.Labels{"topic": topic, "handler": handler}
			messageProcessTotal.With(labels).Inc()
			now := time.Now()
			msgs, err := h(msg)
			if err != nil {
				messageProcessFailedTotal.With(labels).Inc()
			}

			messagesProcessingDuration.With(labels).Observe(time.Now().Sub(now).Seconds())
			return msgs, err
		}
	})
```

#### Tracing

```go
router.AddMiddleware(func(h message.HandlerFunc) message.HandlerFunc {
		return func(msg *message.Message) (events []*message.Message, err error) {
			topic := message.SubscribeTopicFromCtx(msg.Context())
			handler := message.HandlerNameFromCtx(msg.Context())

			ctx := otel.GetTextMapPropagator().Extract(msg.Context(), propagation.MapCarrier(msg.Metadata))
			ctx, span := otel.Tracer("").Start(
				ctx,
				fmt.Sprintf("topic: %s, handler: %s", topic, handler),
				trace.WithAttributes(
					attribute.String("topic", topic),
					attribute.String("handler", handler),
				),
			)
			defer span.End()
			msg.SetContext(ctx)

			msgs, err := h(msg)
			if err != nil {
				span.RecordError(err)
				span.SetStatus(codes.Error, err.Error())
			}
			return msgs, err
		}
	})
```



### Decorators

可以分别对订阅者和发布者构造装饰器，如保证每个发布者都携带`correlation_id`标识:

```go
const correlationIDMessageMetadataKey = "correlation_id"
const correlationIDKey = "correlation_key"

type CorrelationPublisherDecorator struct {
	message.Publisher
}

func (c CorrelationPublisherDecorator) Publish(topic string, messages ...*message.Message) error {
	for i := range messages {
		// if correlation_id is already set, let's not override
		if messages[i].Metadata.Get(correlationIDMessageMetadataKey) != "" {
			continue
		}

		// correlation_id as const
		messages[i].Metadata.Set(correlationIDMessageMetadataKey, CorrelationIDFromContext(messages[i].Context()))
	}

	return c.Publisher.Publish(topic, messages...)
}

func CorrelationIDFromContext(ctx context.Context) string {
	v, ok := ctx.Value(correlationIDKey).(string)
	if ok {
		return v
	}

	// add "gen_" prefix to distinguish generated correlation IDs from correlation IDs passed by the client
	// it's useful to detect if correlation ID was not passed properly
	return "gen_" + shortuuid.New()
}

func main() {
  // ....
  router.AddPublisherDecorators(func(pub message.Publisher) (message.Publisher, error) {
		return CorrelationPublisherDecorator{pub}, nil
	})
  // ....
}
```

订阅者同理:

```go
router.AddSubscriberDecorators(func(sub message.Subscriber) (message.Subscriber, error) {
		return CorrelationSubscriberDecorator{pub}, nil
	})
```

### RouterPlugin

RouterPlugin其实就是服务于Router的中间件，在这里可以添加处理路由的操作，比如监听路由启动完成、监听信号关闭路由。。。

```go
router.AddPlugin(func(router *message.Router) error {
		<-router.Running()
		fmt.Println("started")
		return nil
	})
```



## CQRS

watermill提供了一整套框架来在事件驱动的架构中实现CQRS（*Command-query responsibility segregation*），其中主要有三个部分：Event Bus、Event Processor、Event Handler。

操作的时序图如下：

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202309192316583.png)

*[图片来自Three Dots Labs Academy](https://academy.threedots.tech/trainings/go-event-driven/exercise/4c908a02-a3e9-4a20-ad09-20a511c1c912)*

一个实际的使用场景可能是：

![](https://threedots.tech/watermill-io/cqrs-big-picture.svg)

*[图片来自CQRS Component (watermill.io)](https://watermill.io/docs/cqrs/)*

### Event Bus

Event Bus封装了事件的发布，使得发布相关代码更简洁。

#### Constructor

```go
func NewBus(publisher message.Publisher, logger watermill.LoggerAdapter) *cqrs.EventBus {
	eventBus, err := cqrs.NewEventBusWithConfig(
		publisher,
		cqrs.EventBusConfig{
			GeneratePublishTopic: func(params cqrs.GenerateEventPublishTopicParams) (string, error) {
				event, ok := params.Event.(entities.Event)
				if !ok {
					return "", fmt.Errorf("invalid event type: %T doesn't implement entities.Event", params.Event)
				}
				return params.EventName, nil
			},
			Marshaler: cqrs.JSONMarshaler{
				GenerateName: cqrs.StructName,
			},
			Logger: logger,
		})
	if err != nil {
		panic(err)
	}
	return eventBus
}
```

因为需要发送事件，因此构造Event Bus需要一个publisher。在`cqrs.EventBusConfig`中可以增强publisher的能力。

```go
type EventBusConfig struct {
	// GeneratePublishTopic is used to generate topic name for publishing event.
	GeneratePublishTopic GenerateEventPublishTopicFn

	// OnPublish is called before sending the event.
	// The *message.Message can be modified.
	//
	// This option is not required.
	OnPublish OnEventSendFn

	// Marshaler is used to marshal and unmarshal events.
	// It is required.
	Marshaler CommandEventMarshaler

	// Logger instance used to log.
	// If not provided, watermill.NopLogger is used.
	Logger watermill.LoggerAdapter
}
```

- GeneratePublishTopic: 可以针对Event动态生成topic，通常使用事件名称作为topic，也可以加上当前项目名称作为前缀
- OnPublish：publish之前的钩子
- Marshaler：序列化器，用于序列化和反序列化事件。常默认使用json（`cqrs.JSONMarshaler`）或protobuf（`cqrs.ProtobufMarshaler`）
- Logger：日志适配器

需要注意的是`GeneratePublishTopic`中使用的`EventName`是从`Marshaler`的`Name`方法中获取的。

#### Publish

当我们有了Event Bus后，推送事件就变得很简单了, 且EventBus只有一个public API：

```go
func (c EventBus) Publish(ctx context.Context, event any) error {}
```

### Event Processor

Event Bus负责事件的发送，相对应，Event Processor负责事件的接收。

#### Constructor

```go
func NewEventProcessorWithConfig(router *message.Router, config EventProcessorConfig) (*EventProcessor, error) {
	config.setDefaults()

	if err := config.Validate(); err != nil {
		return nil, errors.Wrap(err, "invalid config EventProcessor")
	}
	if router == nil && !config.disableRouterAutoAddHandlers {
		return nil, errors.New("missing router")
	}

	return &EventProcessor{
		router: router,
		config: config,
	}, nil
}
```

Event Processor用到了之前介绍过的Router来管理事件的接收和分发。我们着重看下EventProcessorConfig：

```go
type EventProcessorConfig struct {
	// GenerateSubscribeTopic is used to generate topic for subscribing to events.
	// If event processor is using handler groups, GenerateSubscribeTopic is used instead.
	GenerateSubscribeTopic EventProcessorGenerateSubscribeTopicFn

	// SubscriberConstructor is used to create subscriber for EventHandler.
	//
	// This function is called for every EventHandler instance.
	// If you want to re-use one subscriber for multiple handlers, use GroupEventProcessor instead.
	SubscriberConstructor EventProcessorSubscriberConstructorFn

	// OnHandle is called before handling event.
	// OnHandle works in a similar way to middlewares: you can inject additional logic before and after handling a event.
	//
	// Because of that, you need to explicitly call params.Handler.Handle() to handle the event.
	//
	//  func(params EventProcessorOnHandleParams) (err error) {
	//      // logic before handle
	//      //  (...)
	//
	//      err := params.Handler.Handle(params.Message.Context(), params.Event)
	//
	//      // logic after handle
	//      //  (...)
	//
	//      return err
	//  }
	//
	// This option is not required.
	OnHandle EventProcessorOnHandleFn

	// AckOnUnknownEvent is used to decide if message should be acked if event has no handler defined.
	AckOnUnknownEvent bool

	// Marshaler is used to marshal and unmarshal events.
	// It is required.
	Marshaler CommandEventMarshaler

	// Logger instance used to log.
	// If not provided, watermill.NopLogger is used.
	Logger watermill.LoggerAdapter

	// disableRouterAutoAddHandlers is used to keep backwards compatibility.
	// it is set when EventProcessor is created by NewEventProcessor.
	// Deprecated: please migrate to NewEventProcessorWithConfig.
	disableRouterAutoAddHandlers bool
}
```

- GenerateSubscribeTopic: 用于根据事件动态生成所需订阅的topic，与EventBusConfig的GeneratePublishTopic相对应，两者的函数签名也相似：
  ```go
  type GenerateEventPublishTopicFn func(GenerateEventPublishTopicParams) (string, error)
  
  type GenerateEventPublishTopicParams struct {
  	EventName string
  	Event     any
  }
  
  type EventProcessorGenerateSubscribeTopicFn func(EventProcessorGenerateSubscribeTopicParams) (string, error)
  
  type EventProcessorGenerateSubscribeTopicParams struct {
  	EventName    string
  	EventHandler EventHandler
  }
  ```

  EventName的生成规则在Event Bus和Event Processor中要保持一致，而EventName是由Marshal控制的，因此两者需要使用同一个Marshal。

- SubscriberConstructor：用于构造订阅者。可以根据不同的Event构造不同的订阅者。函数签名为：

  ```go
  type EventProcessorSubscriberConstructorFn func(EventProcessorSubscriberConstructorParams) (message.Subscriber, error)
  
  type EventProcessorSubscriberConstructorParams struct {
  	HandlerName  string
  	EventHandler EventHandler
  }
  ```

  在生成的订阅者中，我们可以配置消费者组。如果消费者组依赖了事件或者Handler的属性，那么需要谨慎修改这些属性！

  ```go
  redisstream.NewSubscriber(
    redisstream.SubscriberConfig{
      Client:        rdb,
      ConsumerGroup: "internal." + params.HandlerName,
    },
  watermillLogger)
  ```

  

#### EventHandler

既然Event Processor是用来管理事件的接收和处理，那么也就需要管理事件处理的对象——EventHandler。其构造函数如下：

```go
func NewEventHandler[T any](handlerName string, handleFunc func(ctx context.Context, event *T) error) EventHandler {
	return &genericEventHandler[T]{
		handleFunc:  handleFunc,
		handlerName: handlerName,
	}
}
```

handlerName只是handler的一个标识，不冲突即可。handlFunc是用来处理事件的函数。

EventHandler是一个接口，因此完全可以定制化的实现自己的Handler：

```go
type EventHandler interface {
	// HandlerName is the name used in message.Router while creating handler.
	//
	// It will be also passed to EventsSubscriberConstructor.
	// May be useful, for example, to create a consumer group per each handler.
	//
	// WARNING: If HandlerName was changed and is used for generating consumer groups,
	// it may result with **reconsuming all messages** !!!
	HandlerName() string

	NewEvent() any

	Handle(ctx context.Context, event any) error
}
```

Event Processor只有一个public API：`func (p *EventProcessor) AddHandlers(handlers ...EventHandler) error `，因此无需考虑复杂的管理操作。



### Command Bus

区别于Event，Command：

- 不使用“过去式”来描述，而是“命令式”
- 常常只有一个消费者

Command往往不关心执行结果，因此无需返回值。如果是异步处理，则往往使用消息队列；否则，可以使用http或者grpc。

虽然Command和Event的使用场景不同，但使用方式十分类似。

```go
func NewBus(redisPublisher message.Publisher, watermillLogger *log.WatermillLogrusAdapter) *cqrs.CommandBus {
	commandBus, err := cqrs.NewCommandBusWithConfig(
		redisPublisher,
		cqrs.CommandBusConfig{
			GeneratePublishTopic: func(params cqrs.CommandBusGeneratePublishTopicParams) (string, error) {
				return "commands." + params.CommandName, nil
			},
			Marshaler: cqrs.JSONMarshaler{
				GenerateName: cqrs.StructName,
			},
			Logger: watermillLogger,
		})
	if err != nil {
		panic(err)
	}
	return commandBus
}

// 使用示例
func Send(/*params*/) {
 bus := NewBus(params)
 bus.Send(ctx, Command)
}
```



### Command Processor

Command Processor用于处理命令接收和命令处理：

```go
type SendNotification struct {
	NotificationID string
	Email          string
	Message        string
}

type Sender interface {
	SendNotification(ctx context.Context, notificationID, email, message string) error
}

func NewProcessor(router *message.Router, sender Sender, sub message.Subscriber, watermillLogger watermill.LoggerAdapter) *cqrs.CommandProcessor {
	eventProcessor, err := cqrs.NewCommandProcessorWithConfig(
		router,
		cqrs.CommandProcessorConfig{
			GenerateSubscribeTopic: func(params cqrs.CommandProcessorGenerateSubscribeTopicParams) (string, error) {
				return "commands." + params.CommandName, nil
			},
			SubscriberConstructor: func(params cqrs.CommandProcessorSubscriberConstructorParams) (message.Subscriber, error) {
				return sub, nil
			},
			Marshaler: cqrs.JSONMarshaler{
				GenerateName: cqrs.StructName,
			},
			Logger: watermillLogger,
		},
	)
	if err != nil {
		panic(err)
	}

	err = eventProcessor.AddHandlers(cqrs.NewCommandHandler(
		"send_notification",
		func(ctx context.Context, event *SendNotification) error {
			return sender.SendNotification(ctx, event.NotificationID, event.Email, event.Message)
		},
	))
	if err != nil {
		panic(err)
	}

	return eventProcessor
}
```

#### RequestReply

对于需要接收请求的同步命令处理，可以使用[`requestreply`](https://github.com/ThreeDotsLabs/watermill/tree/master/components/requestreply) 

执行命令：

```go
err := commandProcessor.AddHandlers(
    requestreply.NewCommandHandler(
        "hotel_room_booking",
        ts.RequestReplyBackend,
        func(ctx context.Context, cmd *BookHotelRoom) error {
            return fmt.Errorf("some error")
        },
    ),
)
```

接受命令返回值：

```go
reply, err := requestreply.SendWithReply[requestreply.NoResult](
    context.Background(),
    ts.CommandBus,
    ts.RequestReplyBackend,
    &BookHotelRoom{ID: "1"},
)
```

也可以在Handler处理返回值：

```go
err := commandProcessor.AddHandlers(
    requestreply.NewCommandHandlerWithResult[PayForRoom, PayForRoomResult](
        "pay_for_room",
        ts.RequestReplyBackend,
        func(ctx context.Context, cmd *PayForRoom) (PayForRoomResult, error) {
            return PayForRoomResult{PaymentReference: "1234"}, nil
        },
    ),
)
// ...
reply, err := requestreply.SendWithReply[requestreply.NoResult](
    context.Background(),
    ts.CommandBus,
    ts.RequestReplyBackend,
    &TestCommand{ID: "1"},
)

// ...

fmt.Println(reply.Result.PaymentReference) // it's equal to "1234"
fmt.Println(reply.Error) // it's nil
```





## Outbox

### 场景

当用户下单成功后，我们既要扣除商品数量，又要发送下单成功通知。那么如何保证两个操作的一致性呢？

消息推送往往使用消息队列，而消息队列往往不支持事务，这时候可以使用数据库来做中转——将事件存入数据库中，然后再异步消费。

watermill中把这种功能进行了封装，称其为outbox。outbox能够确保一个消息最少能够发送成功一次。

> outbox实际上是一种设计模式，可以参考这篇博客——[Outbox, Inbox patterns and delivery guarantees explained - Event-Driven.io](https://event-driven.io/en/outbox_inbox_patterns_and_delivery_guarantees_explained/)
>
> 如果你正在担心使用数据库带来的性能问题，可以参考这篇博客——[Push-based Outbox Pattern with Postgres Logical Replication - Event-Driven.io](https://event-driven.io/en/push_based_outbox_pattern_with_postgres_logical_replication/)
>
> 在设计“中转表”之前，阅读这篇文章可以少走弯路——[How Postgres sequences issues can impact your messaging guarantees - Event-Driven.io](https://event-driven.io/en/ordering_in_postgres_outbox/)



### Publisher

将事件保存在数据库并消费这个过程可以抽象为发送和订阅。因此outbox中的发送者也实现了Publisher.

```go
func PublishInTx(
	message *message.Message,
	tx *sql.Tx,
	logger watermill.LoggerAdapter,
) error {
	publisher, err := watermillSQL.NewPublisher(
		tx,
		watermillSQL.PublisherConfig{
			SchemaAdapter: watermillSQL.DefaultPostgreSQLSchema{},
      AutoInitializeSchema: true,
		},
		logger,
	)
	if err != nil {
		return err
	}
	return publisher.Publish("ItemAddedToCart", message)
}
```

- SchemaAdapter: 配置数据库Schema

- AutoInitializeSchema：是否自动初始化Schema，执行的SQL如下：

  ```sql
  CREATE TABLE IF NOT EXISTS [table name] (
      "offset" SERIAL,
      "uuid" VARCHAR(36) NOT NULL,
      "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "payload" JSON DEFAULT NULL,
      "metadata" JSON DEFAULT NULL,
      "transaction_id" xid8 NOT NULL,
      PRIMARY KEY ("transaction_id", "offset")
  );
  ```

### Subscriber

outbox中的订阅者使用方式如下：

```go
func SubscribeForMessages(db *sqlx.DB, topic string, logger watermill.LoggerAdapter) (<-chan *message.Message, error) {
	subscriber, err := sql.NewSubscriber(
		db,
		sql.SubscriberConfig{
			SchemaAdapter:    sql.DefaultPostgreSQLSchema{},
			OffsetsAdapter:   sql.DefaultPostgreSQLOffsetsAdapter{},
			InitializeSchema: true,
		},
		logger,
	)
	if err != nil {
		return nil, err
	}
	messages, err := subscriber.Subscribe(context.Background(), topic)
	if err != nil {
		panic(err)
	}
	return messages, nil
}
```

SubscriberConfig提供了更丰富的配置，比如消费者组，重试间隔，backoff等等。

如果设置了自动初始化Schema，则会执行SQL:

```sql
CREATE TABLE IF NOT EXISTS [table name] (
    consumer_group VARCHAR(255) NOT NULL,
    offset_acked BIGINT,
    offset_consumed BIGINT NOT NULL,
    PRIMARY KEY(consumer_group)
;
```

### Forwarder

上述方式需要为每个topic设置两个表，可以使用Forwarder来让topic共用同一张表（实际是两个）。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202309231057464.png)

#### Publisher

将消息封装在一个更上层的topic上，比`events_to_forward`为例：

```go
var outboxTopic = "events_to_forward"

func PublishInTx(
	msg *message.Message,
	tx *sql.Tx,
	logger watermill.LoggerAdapter,
) error {
	publisher, err := watermillSQL.NewPublisher(
		tx,
		watermillSQL.PublisherConfig{
			SchemaAdapter: watermillSQL.DefaultPostgreSQLSchema{},
		},
		logger,
	)
	if err != nil {
		return err
	}

	fp := forwarder.NewPublisher(publisher, forwarder.PublisherConfig{
		ForwarderTopic: outboxTopic,
	})
	defer fp.Close()
	return fp.Publish("TopicName", msg)
}
```

#### Subscriber

对应的订阅为：

```go
func RunForwarder(
	db *sqlx.DB,
	rdb *redis.Client,
	outboxTopic string,
	logger watermill.LoggerAdapter,
) error {
	publisher, err := redisstream.NewPublisher(
		redisstream.PublisherConfig{
			Client: rdb,
		},
		logger,
	)
	if err != nil {
		return err
	}
	subscriber, err := sql.NewSubscriber(
		db,
		sql.SubscriberConfig{
			SchemaAdapter:    sql.DefaultPostgreSQLSchema{},
			OffsetsAdapter:   sql.DefaultPostgreSQLOffsetsAdapter{},
			InitializeSchema: true,
		}, logger,
	)
	if err != nil {
		return err
	}
	fd, err := forwarder.NewForwarder(subscriber, publisher, logger, forwarder.Config{
		ForwarderTopic: outboxTopic,
	})
	if err != nil {
		return err
	}
	go func() {
		err = fd.Run(context.Background())
		if err != nil {
			panic(err)
		}
	}()
	<-fd.Running()
	return nil
}
```



## 事件顺序

在事件驱动的架构中，事件往往以topic的方式展现，而对topic的消费又往往是并行处理。

有些事件需要严格控制执行顺序，否则会导致数据错乱：比如说员工调岗事件和员工离职事件，如果先处理了员工离职事件，那么处理员工调岗事件就会造成相当大的困惑。

### 使用消费者组订阅所有事件

可以将所有的事件都放到同一个topic（比如`events`）中，然后使用消费者组——以达到事件`fan-out`到多个消费者的效果。

然后将相关的事件放入一个Group中进行处理，忽略不相关的事件：

```go
	eventProcessor, err := cqrs.NewEventGroupProcessorWithConfig(
		router,
		cqrs.EventGroupProcessorConfig{
			GenerateSubscribeTopic: func(params cqrs.EventGroupProcessorGenerateSubscribeTopicParams) (string, error) {
				return "events", nil
			},
			SubscriberConstructor: func(params cqrs.EventGroupProcessorSubscriberConstructorParams) (message.Subscriber, error) {
        // use ConsumerGroup
				sub, err := kafka.NewSubscriber(kafka.SubscriberConfig{
					Brokers:               []string{kafkaAddr},
					Unmarshaler:           kafka.DefaultMarshaler{},
					OverwriteSaramaConfig: newConfig(),
					ConsumerGroup:         params.EventGroupName,
				}, logger)
				if err != nil {
					return nil, err
				}
				return sub, nil
			},
			AckOnUnknownEvent: true,
			Marshaler:         cqrs.JSONMarshaler{},
			Logger:            logger,
		},
	)
	if err != nil {
		panic(err)
	}

	pub, _ := kafka.NewPublisher(kafka.PublisherConfig{
		Brokers:   []string{kafkaAddr},
		Marshaler: kafka.DefaultMarshaler{},
	}, logger)

	eventProcessor.AddHandlersGroup(
		"employee-related",
		cqrs.NewGroupEventHandler(HandleEmployeePositionTransfered),
		cqrs.NewGroupEventHandler(HandleEmployeeLeft),
	)

// newConfig
func newConfig() *sarama.Config {
	cfg := sarama.NewConfig()
	cfg.Consumer.Offsets.Initial = sarama.OffsetOldest
	return cfg
}
```

### 分片

上述方案是在消费端进行处理，缺点是消费端需要消费所有的事件。另外一种办法就是按照“实例ID”来进行分片，比如使用员工ID进行分片，那么同一个员工的事件就会顺序消费。以kafka为例：

```go
pub, err := kafka.NewPublisher(kafka.PublisherConfig{
		Brokers: []string{kafkaAddr},
		Marshaler: kafka.NewWithPartitioningMarshaler(func(topic string, msg *message.Message) (string, error) {
			return msg.Metadata.Get("employee_id"), nil
		}),
	}, logger)
```

### 乐观锁

可以使用乐观锁来避免并发问题。我们使用version字段来标记当前记录的版本，每当发送一个事件时，将version放入事件实体中，然后在消费时，判断version的值是否正常。

```go
cqrs.NewEventHandler("OnEmployeeLeft", func(ctx context.Context, event *EmployeeLeft) error {
			employee := getEmployee(event.EmployeeID)
			
			if event.Version-1 != employee.Version {
				return fmt.Errorf("version not match")
			}

			employee.IsLeft = true
			employee.Version = event.Version

			return nil
})
```

### 独自更新

有一种无需考虑并发问题的解决办法，那就是从源头解决问题：每个事件都不互相影响。

比如说员工离职事件只是将离职状态进行更改，员工调岗事件只是改变员工岗位而无需查询员工状态。这样两个事件就可以实现“独自更新”互不影响。

## Metrics

### Prometheus

Prometheus是一个用于监控和告警的工具包，由Cloud Native Computing Foundation (CNCF) 开发。它用于从各种来源收集、处理和显示指标，例如Kubernetes、节点和应用程序。

#### 全局指标

全局变量往往会由于其众多的引用关系从而导致项目难以维护，但有些例外，如：监控指标、日志。

下面是一些基本指标：处理的消息数量、失败的消息数量、处理的时间分布。

```go
var (
	messageProcessTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Namespace: "messages",
			Name:      "processed_total",
			Help:      "The total processed messages",
		},
		[]string{"topic", "handler"},
	)
	messageProcessFailedTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Namespace: "messages",
			Name:      "processed_failed_total",
			Help:      "The total processed messages",
		},
		[]string{"topic", "handler"},
	)
	messagesProcessingDuration = promauto.NewSummaryVec(
		prometheus.SummaryOpts{
			Namespace:  "messages",
			Name:       "processing_duration_seconds",
			Help:       "The total time spent processing messages",
			Objectives: map[float64]float64{0.5: 0.05, 0.9: 0.01, 0.99: 0.001},
		},
		[]string{"topic", "handler"},
	)
)
```

#### 注入到中间件

基本的监控指标在中间件中注入即可，无需影响业务代码。

```go
func useMiddlewares(router *message.Router, watermillLogger watermill.LoggerAdapter) {
	router.AddMiddleware(func(h message.HandlerFunc) message.HandlerFunc {
		return func(msg *message.Message) ([]*message.Message, error) {
			topic := message.SubscribeTopicFromCtx(msg.Context())
			handler := message.HandlerNameFromCtx(msg.Context())
			labels := prometheus.Labels{"topic": topic, "handler": handler}
			messageProcessTotal.With(labels).Inc()
			now := time.Now()
			msgs, err := h(msg)
			if err != nil {
				messageProcessFailedTotal.With(labels).Inc()
			}

			messagesProcessingDuration.With(labels).Observe(time.Now().Sub(now).Seconds())
			return msgs, err
		}
	})
}
```

#### 开放入口

Prometheus基本上都是采用服务端拉取的方式进行采集，因此作为客户端的服务需要提供接口：

```go
// echo
import (
  libHttp "github.com/ThreeDotsLabs/go-event-driven/common/http"
  "github.com/prometheus/client_golang/prometheus/promhttp"
  "github.com/labstack/echo/v4"
)

func NewHttpRouter(){
  e := libHttp.NewEcho()
	e.GET("/metrics", echo.WrapHandler(promhttp.Handler()))
}
```

```go
// iris
import (
	"github.com/kataras/iris/v12"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func NewHttpRouter(){
	app := iris.New()
	app.Get("/metrics", iris.FromStd(promhttp.Handler()))
}
```

#### 消息队列exporter

对于消息队列的Pub/Sub监控，可以在[Prometheus官网](https://prometheus.io/docs/instrumenting/exporters/#messaging-systems)找到对应的exporter。

### Tracing

链路追踪与指标监控一样，都是微服务时代必不可少的组件。链路追踪能够将追踪一个请求的完整信息，从而能让使用者更了解系统的运作，也能够快速定位错误。

目前常用的链路协议为OpenTelemetry。

> OpenTelemetry和Jaeger的区别：
>
> OpenTelemetry和Jaeger都是用于分布式跟踪的工具，但是它们之间有一些区别。OpenTelemetry是一种开放标准，它提供了一组API和SDK，用于在应用程序中生成和传输跟踪数据。OpenTelemetry支持多种编程语言和框架，并且可以与多种后端跟踪系统集成。
>
> Jaeger是一个实现了OpenTracing标准的开源跟踪系统。它提供了一个完整的跟踪解决方案，包括收集、存储和查询跟踪数据的组件。Jaeger支持多种后端存储，包括Cassandra、Elasticsearch和Memory等。
>
> 因此，OpenTelemetry是一种标准和API/SDK，而Jaeger是一个完整的跟踪系统。OpenTelemetry可以与Jaeger一起使用，或者与其他跟踪系统集成。

#### 消息系统中的链路传播

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202309241622154.png)

链路传播需要维护上下文信息，OpenTelemetry推荐的格式为 [W3C Trace Context](https://www.w3.org/TR/trace-context/)。

#### Publisher

在发送事件时需要携带链路信息（将上下文中的链路信息提取出来放到消息header中），我们可以通过装饰器模式实现：

```go
type TracingPublisherDecorator struct {
	message.Publisher
}

func (p TracingPublisherDecorator) Publish(topic string, messages ...*message.Message) error {
	for i := range messages {
		otel.GetTextMapPropagator().Inject(messages[i].Context(), propagation.MapCarrier(messages[i].Metadata))
	}
	return p.Publisher.Publish(topic, messages...)
}
```

使用装饰器：

```go
var pub message.Publisher
pub, _ = redisstream.NewPublisher(...)
pub = PublishDecorator{pub}
```

#### Middleware

在路由层，我们需要从消息的header中提取链路信息，然后保存到上下文中：

```go
func useMiddlewares(router *message.Router, watermillLogger watermill.LoggerAdapter) {
	router.AddMiddleware(func(h message.HandlerFunc) message.HandlerFunc {
		return func(msg *message.Message) (events []*message.Message, err error) {
			topic := message.SubscribeTopicFromCtx(msg.Context())
			handler := message.HandlerNameFromCtx(msg.Context())

			ctx := otel.GetTextMapPropagator().Extract(msg.Context(), propagation.MapCarrier(msg.Metadata))
			ctx, span := otel.Tracer("").Start(
				ctx,
				fmt.Sprintf("topic: %s, handler: %s", topic, handler),
				trace.WithAttributes(
					attribute.String("topic", topic),
					attribute.String("handler", handler),
				),
			)
			defer span.End()
			msg.SetContext(ctx)

			msgs, err := h(msg)
			if err != nil {
				span.RecordError(err)
				span.SetStatus(codes.Error, err.Error())
			}
			return msgs, err
		}
	})
}
```

在这个过程中，我们启动了一个新的`Span`，并记录了topic和handler（保存在Span的属性中），并且如果发生了错误还会记录错误状态。

#### Handler

我们通过Publisher和Middleware成功的在异步消息中传递了链路信息，那么当我们执行sql、调用接口等等操作时如何上报链路呢？

##### Postgres

Opentelemetry已经提供了Postgres的插件：

```go
import (
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
	"github.com/uptrace/opentelemetry-go-extra/otelsql"
	"go.opentelemetry.io/otel/semconv/v1.4.0"
)

func getDB() *sqlx.DB {
	traceDB, err := otelsql.Open(
		"postgres",
		os.Getenv("POSTGRES_URL"),
		otelsql.WithAttributes(semconv.DBSystemPostgreSQL),
		otelsql.WithDBName("db"),
	)
	if err != nil {
		panic(err)
	}
	dbConn := sqlx.NewDb(traceDB, "postgres")
	return dbConn
}
```

##### Http

Opentelemetry也提供了http的插件：

```go
import (
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
  "net/http"
)

func getHttpClient() *http.Client {
	traceHttpClient := &http.Client{
		Transport: otelhttp.NewTransport(
			http.DefaultTransport,
			otelhttp.WithSpanNameFormatter(func(operation string, r *http.Request) string {
				return fmt.Sprintf("HTTP %s %s %s", r.Method, r.URL.String(), operation)
			})),
	}
}
```

#### TraceProvider

Opentelemetry是链路追踪的一个SDK，那么链路信息要上报到哪里呢？OpenTelemetry提供了多种Provider，最常用的是Jaeger。

```go
package observability

import (
	"fmt"
	"github.com/ThreeDotsLabs/watermill/message"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/jaeger"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	"go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/semconv/v1.21.0"
	"os"
)

func ConfigureTraceProvider() *trace.TracerProvider {
	jaegerEndpoint := os.Getenv("JAEGER_ENDPOINT")
	if jaegerEndpoint == "" {
		jaegerEndpoint = fmt.Sprintf("%s/jaeger-api/api/traces", os.Getenv("GATEWAY_ADDR"))
	}

	exp, err := jaeger.New(
		jaeger.WithCollectorEndpoint(
			jaeger.WithEndpoint(jaegerEndpoint),
		),
	)
	if err != nil {
		panic(err)
	}

	tp := trace.NewTracerProvider(
		// WARNING: `tracesdk.WithSyncer` should be not used in production.
		// For production, you should use `tracesdk.WithBatcher`.
		trace.WithSyncer(exp),
		trace.WithResource(resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceName("tickets"),
		)),
	)

	otel.SetTracerProvider(tp)

	// Don't forget this line! Omitting it will cause the trace to not be propagated via messages.
	otel.SetTextMapPropagator(propagation.TraceContext{})

	return tp
}
```

#### Outbox兼容

之前我们提到，为了实现一致性，我们先通过事务将一些事件存储到数据库，这时候要如何保存链路信息呢？

其实也很简单，因为我们本来就存储了事件的header，所以只需要在存储到数据库之前将上下文信息存入header即可（利用之前写好的装饰器可以很方便的实现这一功能）：

```go
func PublishInTx(
	msg *message.Message,
	tx *sql.Tx,
	logger watermill.LoggerAdapter,
) error {
	var publisher message.Publisher
	var err error

	publisher, err = watermillSQL.NewPublisher(
		tx,
		watermillSQL.PublisherConfig{
			SchemaAdapter: watermillSQL.DefaultPostgreSQLSchema{},
		},
		logger,
	)
	if err != nil {
		return fmt.Errorf("failed to create outbox publisher: %w", err)
	}

	publisher = TracingPublisherDecorator{publisher}

	publisher = forwarder.NewPublisher(publisher, forwarder.PublisherConfig{
		ForwarderTopic: outboxTopic,
	})

	publisher = TracingPublisherDecorator{publisher}

	return publisher.Publish("ItemAddedToCart", msg)
}
```

值得注意的是在`PublishInTx`中，我们使用了两次装饰器：

1. 第一次装饰了`watermillSQL.Publisher`: 将上下文的链路信息提取到header，并保存到数据库
2. 第二次装饰了`forwarder.Publisher`：将从数据库中的事件发布到forwarder这个过程的上下文信息中的链路信息提取到header。

第二次装饰器并不是简单的重复提取链路信息，而是携带了`forwarder`过程中的数据库信息。

## 可用性

### 限流

如果高并发地消费事件会对下游服务造成压力，那么可以考虑限流。

watermill中提供了限流中间件：

```go
router, _ := message.NewRouter(message.RouterConfig{}, logger)
router.AddMiddleware(middleware.NewThrottle(10, time.Second).Middleware) // 允许一秒最多处理10个消息
```

### 熔断

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202309241806158.png)

熔断也是常用的微服务治理工具：当下游服务出现大量报错后，身为上游服务不应再给予下游服务大量压力，而应该等待一段时间后再去访问，以防止整个系统雪崩。

watermill中使用`gobreaker`作为其熔断中间件的实现：

```go
import (
	"github.com/ThreeDotsLabs/watermill/message/router/middleware"
	"github.com/sony/gobreaker"
  "github.com/ThreeDotsLabs/watermill/message"
)


router, err := message.NewRouter(message.RouterConfig{}, logger)
if err != nil {
  return err
}
router.AddMiddleware(middleware.NewCircuitBreaker(gobreaker.Settings{
  Name:        "breaker",
  MaxRequests: 1,
  Timeout:     time.Second,
}).Middleware)
```

### 死信队列

如果一个消息被损坏而不能正常消费，这时候就要把它放入“死信队列”，以待更进一步的检查。

watermill中提供了该功能的中间件：

```go
router.AddMiddleware(middleware.PoisonQueue(publisher, "poison_queue"))
```

设置了上述中间件后，如果消息在消费过程中遇到了错误，并且返回了错误，那么这个消息会被ACK，并发送到`poison_queue`中。

上面的中间件有些过于“粗暴”，因为有些消息在消费过程中可能遇到了临时性的错误，那么NACK后过一段时间再次消费即可。这时候可以使用过滤器：

```go
pq, err := middleware.PoisonQueueWithFilter(pub, "PoisonQueue", func(err error) bool {
	var permErr PermanentError
	if errors.As(err, &permErr) && permErr.IsPermanent() {
		return true
	}
	
	return false
})
router.AddMiddleware(pq)
```

当然，也可以搭配Retry中间件使用——重试几次后依然报错，则放入死信队列：

```go
router.AddMiddleware(
	middleware.PoisonQueue(publisher, "poison_queue"), 
	middleware.Retry{
		// Config
	}.Middleware,
)
```

watermill会将一些元数据放到header中，这些key为：

- `middleware.ReasonForPoisonedKey`: 消息被放到死信队列的原因，通常是报错信息
- `middleware.PoisonedTopicKey`: 消息被放到死信队列前的队列名称
- `middleware.PoisonedHandlerKey`：消息被放到死信队列前的Handler名称
- `middleware.PoisonedSubscriberKey`:消息被放到死信队列前的订阅者的名称

使用方式如：`reason := msg.Metadata.Get(middleware.ReasonForPoisonedKey)`
