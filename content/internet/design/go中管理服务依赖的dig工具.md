---
date: 2024-07-04T12:43:00+08:00
title: "go中管理服务依赖的dig工具"
url: "/internet/design/dig"
toc: true
draft: false
description: "go中管理服务依赖的dig工具"
slug: "dig工具"
tags: ["dig", "go", "服务依赖"]
showDateUpdated: true
---

## 为什么要用dig

我们来模拟一个订单系统，在最一开始的版本中，它只依赖用户系统和数据库。

### 1. 抽象数据库接口

```go
type Order struct {
	ID string
}

type Repo interface {
	Get() Order
	Set(Order)
}
```

### 2. 抽象用户系统接口

```go
type User struct {
	Name string
}

type UserService interface {
	GetUser() User
}
```

### 3. 集成到订单服务

```go
type OrderService struct {
	repo        Repo
	userService UserService
}

func NewOrderService(repo Repo, userService UserService) *OrderService {
	return &OrderService{
		repo:        repo,
		userService: userService,
	}
}

func (o *OrderService) HandleOrder(){
	// handle order
}
```

> 这里我们通过抽象接口来实现了依赖倒置原则，使得订单服务不依赖具体的实现，整体服务更添加解耦。

### 4. 实现数据库接口

```go
type RepoImpl struct{}

func NewRepoImpl() *RepoImpl {
	return &RepoImpl{}
}

func (r *RepoImpl) Get() Order {
	return Order{}
}

func (r *RepoImpl) Set(o Order) {}

```

### 5. 实现用户系统接口

```go
type UserServiceImpl struct{}

func NewUserServiceImpl() *UserServiceImpl {
	return &UserServiceImpl{}
}

func (u *UserServiceImpl) GetUser() User {
	return User{}
}
```

### 6. 依赖注入

```go
func main() {
	repo := NewRepoImpl()
	userService := NewUserServiceImpl()

	order := NewOrderService(repo, userService)
	_ = order // do somehing
}

```

### 7. 更复杂的状况

目前来看，整个系统的依赖关系还是比较简单的，但是随着系统的增长，依赖关系会变得越来越复杂，比如说在后续的迭代中我们会加入缓存服务、搜索系统、邮件系统、通知系统等等（为了”轻量化“讲解，我们不再模拟更复杂的现实系统）。这时候构造订单服务的构造器会变成这个样子：

```go
type OrderService struct {
	repo          Repo
	userService   UserService
	cache         Cache
	emailService  EmailService
	searchService SearchService
	noticeService NoticeService
}

func NewOrderService(repo Repo, userService UserService, cache Cache, emailService EmailService, searchService SearchService, noticeSerivce NoticeService) *OrderService {
	return &OrderService{
		repo:          repo,
		userService:   userService,
		cache:         cache,
		emailService:  emailService,
		searchService: searchService,
		noticeService: noticeSerivce,
	}
}
```

初始化的时候会变成这样：

```go
func main() {
	repo := NewRepoImpl()
	userService := NewUserServiceImpl()
	cache := NewCacheImpl()
	emailService := NewEmailServiceImpl()
	searchService := NewSearchServiceImpl()
	noticService := NewNoticeServiceImpl()

	order := NewOrderService(repo, userService, cache, emailService, searchService, noticService)
	_ = order // do somehing
}
```

已经开始变得有点复杂了。
一般来说，这个系统中不仅仅有订单服务，还会有其他模块（尤其是在使用DDD设计的系统中）,这些模块可以复用底层依赖，比如说我们有一个定时服务,它依赖了数据库服务、用户系统、缓存服务、邮件服务、通知服务：

```go
	timer := NewTimerService(repo, userService, cache, emailService, noticService)
```

依赖注入已经有点臃肿了，可以想象一下比这个复杂10倍的真实系统中，依赖注入会多么的臃肿！

### 用 dig 优化

其实我们可以不用手动进行依赖注入！
我们只需要把每个依赖放到一个大的池子中，标注好它的类型，然后在依赖注入时根据所需的类型从这个池子里拿出来就可以了！
这就是dig的基本原理。

```go
func main() {
	c := dig.New()

	c.Provide(NewRepoImpl, dig.As(new(Repo)))
	c.Provide(NewUserServiceImpl, dig.As(new(UserService)))
	c.Provide(NewOrderService)

	c.Invoke(func(orderService *OrderService) {
		fmt.Println("hi there")
		_ = orderService // do somehing
	})
}
```

通过`Provide`来将构造器存入`dig的container`中，dig会自动解析依赖关系，按照指定类型(`dig.As`)生成对应的对象，然后就可以通过`Invode`来获取所需要的对象。
可以看到整个代码中，没有手动进行依赖注入，而是通过`dig`来自动解析依赖关系，这样就避免了手动注入的臃肿。

## dig的常用用法

### 1. 一个对象对应多个接口

比如说在订单服务和定时服务中都要用到用户系统，所以各自都抽象了自己的用户系统接口，这时可以在`dig.As`中传入多个类型：

```go
	c.Provide(NewUserServiceImpl, dig.As(new(order.UserService), new(timer.UserService)))

```

但是，如果你需要嵌入`NewUserServiceImpl`函数生成的原始类型，即`*UserServiceImpl`,则还需要额外的`Provide`.

```go
  c.Provide(NewUserServiceImpl, dig.As(new(order.UserService), new(timer.UserService)))
  c.Provide(NewUserServiceImpl)
```

这是因为：

1. `dig.As`只接受接口类型的指针，而不是具体类型的指针。
2. 如果在`Provide`中指定了目的类型，即`dig.As`,那么就不会生成原始类型的对象。

````
### 2. 构造函数中含有其他类型的参数
比如说在构造订单服务时，需要传入一个字符串表示是否当前环境，如：
```go
func NewOrderService(env string, repo Repo, userService UserService) *OrderService {
	return &OrderService{
		env:         env,
		repo:        repo,
		userService: userService,
	}
}
````

dig是没有办法自动解析`env`的，这时候可以通过构造一个匿名的构造函数来解决：

```go
	config := ReadConfig()
	c.Provide(func(repo Repo, userService UserService) *OrderService{
		return NewOrderService(config.Env, repo, userService)
	})
```

## 其他

在这篇博客里只记录了我自己使用上的一些经验，`dig`还支持更多的功能和用法，留给各位自己去寻找。
