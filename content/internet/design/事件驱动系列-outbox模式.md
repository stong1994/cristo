+++

date = 2024-07-21T03:00:00+08:00
title = "事件驱动系列—outbox模式"
url = "/internet/event-driven/outbox"
tags = ["事件驱动", "outbox"]
toc = true

+++

## 情景假设

比如我们需要在用户注册完成后需要：

1. 在数据库中插入一条用户数据。
2. 通过消息队列发送一条短信通知用户注册成功。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202407210146844.png)

我们的代码可能是这样的：

```go

func registUser(user User) error {
  if err := insertUser(user); err != nil {
    return err
  }
  if err := sendSMS(user); err != nil {
    return err
  }
  return nil
  }
}
```

这段代码有什么问题呢？

细想一下，如果数据库操作成功，而发送短信失败，那么用户就不再会接收到通知短信了。这就造成了”业务逻辑的不一致“ (你可能认为这个问题并不大，可以换一个支付场景: 这两个操作就对应一个账户的余额增加，另一个账户的余额减少，现在这个问题是不是严重了？)

## 优化方案——在事务中发送短信

将数据库操作放到事务中运行，先插入数据，然后在提交事务前再发送短信：

1. 发送失败，回滚事务
2. 发送成功，提交事务

```go
func insertUserInTx(user User, after func() error) error {
  tx, err := db.Begin()
  if err != nil {
    return err
  }
  if err := insertUser(user); err != nil {
    tx.Rollback()
    return err
  }
  if err := after(); err != nil {
    tx.Rollback()
    return err
  }
  return tx.Commit()
}

func registUser(user User) error {
  return insertUserInTx(user, func() error {
    return sendSMS(user)
  })
}
```

这样是不是好了很多，但是仍然存在一些问题：在数据库提交时数据库崩溃或者网络故障，这会导致用户收到了短信但是数据库实际上没有将用户的数据插入到数据库中。

所以还得继续优化方案。

## 最终方案——outbox模式

`outbox`模式通过将数据库之外的操作抽象为事件记录在数据库中，然后提供一个消费者去消费事件来解决这个问题。
![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202407210210860.png)

这样，通过：

1. 通过数据库的事务来保证发送短信的事件存储和用户数据存储的一致性。
2. 消费端使用消息队列来保证短息发送的可靠性（这里的可靠性是指一定会给用户发，但不可能指望用户一定能收到）。
3. 如果短信发送失败，还可以标记用户的状态为不可触达（以实际需求为准）

### outbox的缺点

要说`outbox`的缺点，那就是由于使用了”最少一次投递“的消息队列模式，因此处理业务逻辑的服务可能会对同一请求处理多次，因此需要做”幂等“处理。

## 其他方案

### Inbox pattern

与`Outbox`相对，这里还有一种`Inbox`的设计模式.

顾名思义，`outbox`是在当前服务提供一个`outbox`表来存放这些即将发送的事件; `inbox`是在当前服务提供一个`inbox`表来存放接收到的事件。

这两种模式的变体有很多，但是本质上都是将事件存储到数据库中来保持一致性，然后通过消息队列消费来保证最少一次投递。

这两者的区别在于，谁会为事件的处理负责：

1. `outbox`模式下，发送事件的服务(`Sending service`)负责处理事件的成功和失败的逻辑。
2. `inbox`模式下，接收事件的服务(`Receiving service`)会负责处理事件的成功和失败的逻辑。

### 2PC

有些消息队列支持两阶段提交（`2PC`), 如`RocketMQ`, 使用这种消息队列可以解决分布式一致性问题。

## go中的outbox实现

有一个开源库`watermill`实现了`outbox`模式的封装。

> TODO: 没有找到例子，后续自己写一个补上
