+++

date = 2024-07-22T03:00:00+08:00
title = "事件驱动系列—saga"
url = "/internet/event-driven/saga"
tags = ["事件驱动", "saga"]
toc = true

+++

## 情景假设

在上一篇博客[事件驱动系列-outbox模式](./事件驱动系列-outbox模式.md), 我们通过一个简单的注册流程来讲解如何通过`outbox模式`来解决分布式一致性问题。现在让我们把这个问题变得更复杂些。


![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202407222126700.png)

现在用户的注册功能涉及到三个服务：

1. 用户服务——提供数据落地到数据库。
2. 通知服务——提供消息推送的用户管理功能。
3. 短信服务——提供短信发送功能。

用户点击注册按钮后, 如何保证用户“数据落地”，“加入通知列表”，“发送通知短信”这三个操作的一致性呢？

## Saga模式

上述问题是一个经典的分布式一致性问题，`saga`是这一领域的解决方案之一。

### 协作式(Orchestration) VS 编排式(Choreography)

Saga模式有两种实现方式：协作式和编排式。其主要区别在于是否需要一个中央协调者来协调任务.

协作式中服务之间是平等的，没有一个中央协调者, 各个服务之间通过事件来通信.
![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202407221527584.png)
协作式中需要一个协调器来统一发送命令，然后通过事件来更改自身状态，并根据状态发送下一个命令。
![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202407221529894.png)

> 协作式更像是`inbox`模式的扩展，而编排式更像是`outbox`模式的扩展。

## 编排式

通过`inbox`模式可以很容易的实现协作式，所以我们主要讲编排式。

### 命令(Command)与事件(Event)

根据编排式的时序图，我们可以绘制更详细的状态流转图:
![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202407221913872.png)
其中，黑色矩形的节点代表的是命令，绿色椭圆的节点代表的是事件。

> 命令代表的是一个服务的请求，表示希望目的服务执行的操作。
> 事件代表的是已经发生的事情，通过事件来通知其他服务。

构建好这个状态图后，让我们来定义这些命令和事件。

#### 命令

```go
type LoadUser2DB struct {
	RegistID string `json:"regist_id"`
	Name     string `json:"name"`
	Phone    string `json:"phone"`
}

type AddToNoticeList struct {
	RegistID string `json:"regist_id"`
	UserID   string `json:"user_id"`
}

type SendSms struct {
	RegistID string `json:"regist_id"`
	Phone    string `json:"phone"`
}

```

#### 事件

```go
type RegistUserInitialized struct {
	Name  string `json:"name"`
	Phone string `json:"phone"`
}
type NoticeListAddedSuccessed struct {
	Header EventHeader `json:"header"`

	RegistID string `json:"regist_id"`
	NoticeID string `json:"notice_id"`
}

type NoticeListAddedFailed struct {
	Header EventHeader `json:"header"`

	RegistID     string `json:"regist_id"`
	NoticeID     string `json:"notice_id"`
	FailedReason string `json:"failed_reason"`
}

type SmsSendFailed struct {
	Header EventHeader `json:"header"`

	RegistID     string `json:"regist_id"`
	SmsRecordID  string `json:"sms_record_id"`
	FailedReason string `json:"failed_reason"`
}

type SmsSendSuccessed struct {
	Header EventHeader `json:"header"`

	RegistID    string `json:"regist_id"`
	SmsRecordID string `json:"sms_record_id"`
}

type RegistUserLoadedInDBSuccessed struct {
	Header   EventHeader `json:"header"`
	RegistID string      `json:"regist_id"`
	UserID   string      `json:"user_id"`
}

type RegistUserLoadedInDBFailed struct {
	Header       EventHeader `json:"header"`
	RegistID     string      `json:"regist_id"`
	UserID       string      `json:"user_id"`
	FailedReason string      `json:"failed_reason"`
}
```

注意到这里的事件都有一个`EventHeader`字段，这是一个公共的字段，用来标记事件的一些信息，如事件ID，事件发生时间等。

```go
type EventHeader struct {
	ID             string    `json:"id"`
	PublishedAt    time.Time `json:"published_at"`
	IdempotencyKey string    `json:"idempotency_key"`
}
```

### 抽象依赖服务

go里边常用端口适配器模式来抽象所依赖的底层的服务实现.

```go
type RegistUserRepository interface {
	Get(ctx context.Context, registID string) (RegistUser, error)
	Create(ctx context.Context, name, phone string) (string, error)
	SaveUserID(ctx context.Context, registID, userID string) error
	SaveNoticeID(ctx context.Context, registID, noticeID string) error
	SaveSmsRecord(ctx context.Context, registID, smsRecordID string) error
	Failed(ctx context.Context, registID, failedReason string) error
	Finished(ctx context.Context, registID string) error
}

type CommandBus interface {
	Send(ctx context.Context, command any) error
}

type EventBus interface {
	Publish(ctx context.Context, event any) error
}
```

### 实现事件的处理函数

```go
type RegistUser struct {
	RegistID     string
	UserID       string
	Name         string
	Phone        string
	FailedReason string
	IsFailed     bool
	IsFinished   bool
}

type RegistUserProcessManager struct {
	commandBus CommandBus
	eventBus   EventBus
	repository RegistUserRepository
}

func NewVipBundleProcessManager(
	commandBus CommandBus,
	eventBus EventBus,
	repository RegistUserRepository,
) *RegistUserProcessManager {
	return &RegistUserProcessManager{
		commandBus: commandBus,
		eventBus:   eventBus,
		repository: repository,
	}
}

func (v RegistUserProcessManager) OnRegistUserInitialized(ctx context.Context, event *RegistUserInitialized) error {
	registID, err := v.repository.Create(ctx, event.Name, event.Phone)
	if err != nil {
		return fmt.Errorf("create user id failed: %w", err)
	}

	return v.commandBus.Send(ctx, LoadUser2DB{
		RegistID: registID,
		Name:     event.Name,
		Phone:    event.Phone,
	})
}

func (v RegistUserProcessManager) OnRegistUserLoadedInDBSuccessed(ctx context.Context, event *RegistUserLoadedInDBSuccessed) error {
	if err := v.repository.SaveUserID(ctx, event.RegistID, event.UserID); err != nil {
		return fmt.Errorf("save user id failed: %w", err)
	}

	return v.commandBus.Send(ctx, AddToNoticeList{
		RegistID: event.RegistID,
		UserID:   event.UserID,
	})
}

func (v RegistUserProcessManager) OnRegistUserLoadedInDBFailed(ctx context.Context, event *RegistUserLoadedInDBFailed) error {
	if err := v.repository.SaveUserID(ctx, event.RegistID, event.UserID); err != nil {
		return fmt.Errorf("save user id failed: %w", err)
	}
	return v.repository.Failed(ctx, event.RegistID, event.FailedReason)
}

func (v RegistUserProcessManager) OnNoticeListAdded(ctx context.Context, event *NoticeListAddedSuccessed) error {
	err := v.repository.SaveNoticeID(ctx, event.RegistID, event.NoticeID)
	if err != nil {
		return fmt.Errorf("save notice id failed:%w", err)
	}
	registUser, err := v.repository.Get(ctx, event.RegistID)
	if err != nil {
		return fmt.Errorf("get regist user failed:%w", err)
	}

	return v.commandBus.Send(ctx, SendSms{
		RegistID: event.RegistID,
		Phone:    registUser.Phone,
	})
}

func (v RegistUserProcessManager) OnNoticeListFailed(ctx context.Context, event *NoticeListAddedFailed) error {
	err := v.repository.SaveNoticeID(ctx, event.RegistID, event.NoticeID)
	if err != nil {
		return fmt.Errorf("save notice id failed:%w", err)
	}
	return v.repository.Failed(ctx, event.RegistID, event.FailedReason)
}

func (v RegistUserProcessManager) OnSmsSendFailed(ctx context.Context, event *SmsSendFailed) error {
	if err := v.repository.SaveSmsRecord(ctx, event.RegistID, event.SmsRecordID); err != nil {
		return fmt.Errorf("save sms record failed:%w", err)
	}
	return v.repository.Failed(ctx, event.RegistID, event.FailedReason)
}

func (v RegistUserProcessManager) OnSmsSendSuccessed(ctx context.Context, event *SmsSendSuccessed) error {
	if err := v.repository.SaveSmsRecord(ctx, event.RegistID, event.SmsRecordID); err != nil {
		return fmt.Errorf("save sms record failed:%w", err)
	}
	return v.repository.Finished(ctx, event.RegistID)
}

```

这样我们核心的`Saga`协调器就基本实现了。

## 小结

在这篇博客里，我们通过一个简单的例子讲解了如何使用saga来实现分布式下的一致性。

核心的点在于那张事件和命令的状态流转图，只要掌握这些事件的状态流转，那么代码编写也是水到渠成的事情！



## 推荐读物

- [Event-driven systems & architecture](https://changelog.com/gotime/297) : 一期讨论事件驱动架构的播客，里边有很精彩的编排模式or协作模式的讨论。

