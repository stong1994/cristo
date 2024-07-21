+++

date = 2022-11-04T17:23:00+08:00
title = "SOLID原则"
url = "/internet/design/solid"

tags = ["设计模式", "编程思想", "SOLID"]
toc = true

+++

对于一个刚入行的程序员来说，写好的代码是很难的。这并不是说他们（或者说那时的我们）不了解编程语言的写法，也不是说他们不了解设计模式，而是说他们缺少编程思想，这种思想是需要通过经验总结出来的，也需要经验才能体会的到。SOLID原则就是面向对象编程中的一种思想的体现。

## S-单一职责

全称：Single-responsiblity Principle

> A class should have one and only one reason to change, meaning that a class should have only one job.

单一职责并不是说一个对象只能有一个功能，而是说**一个对象应该对其使用方负责，当一方更改它时，不应该需要考虑其他使用方是否会被影响，也就是说，一个对象只能对一个使用方负责。**

换句话说，**一个对象不能够混合关注点**。

比如说我们有一个Employee，Employee需要：

- 上报工作时间（ReportHours）
- 计薪（CalcPay）
- 写入到数据库（WriteEmployee）。

如果我们使用Employee实现了这三个功能，那么Employee就同时对工时汇总人员、计薪人员、员工三方负责。当我们修改计薪人员提出的bug或者功能时，就需要考虑会不会对工时汇总人员和员工产生影响。

此时，Employee违反了单一职责原则。

## O-开闭原则

全称：Open-closed Principle

> Objects or entities should be open for extension but closed for modification.

当产品经理提出新的需求时，应该**将新业务扩展为新的对象，而不是在原有对象上修改**。

比如说我们有一个Employee，它有一个计薪（CalcPay）的功能。

```go
func (e Employee) CalcPay() float64{
  return 1000
}
```

现在，我们需要对管理员（Admin）额外提供200块钱的补助。

```go
func (e Employee) CalcPay() float64{
  salary := float64(1000)
  if e.isAdmin() {
    salary += 200
  }
  return salary
}
```

这段代码有什么缺点呢？**它将普通员工和负责人耦合在了一起！**

- 如果又多了一个角色，比如说主管，这里又要多一个`if/else`，而不断叠加的`if/else`则会让代码愈发的臃肿。
- 新添加的角色的代码和已有角色的代码耦合在一起，在编写代码的同时，也会影响已有的角色的代码。
- 如果我们需要对管理员增加其他行为，这时要抽象为Admin，则需要将其`CalcPay`抽出来，这时就需要小心是否会影响到普通员工的行为。

耦合的缺点要比我能列出来的多很多。

正确的做法应该是扩展一个新的角色：

```go
type Admin struct{}
func (a Admin) CalcPay() float64{
  return 1000 + 200
}
```

如果我们需要为公司的所有人计薪，则可以将所有人都抽象为`CalcPayUser`:

```go
type CalcPayUser interface {
	CalcPay() float64
}

func CalcAllUser(users []CalcPayUser) {
  for _, user := range users {
    salry := user.CalcPay()
    fmt.Println(salary)
  }
}
```

## L-里氏替换

全称：Liskov Substitution Principle

> Derived classes must be usable through the base class interface, without the need for the user to know the difference.

里氏替换对衍生对象提出了要求：**衍生对象及其继承的方法必须是可用的，且对用户来说是没有区别的（不需要用户区别处理）。**

比如说我们已经有了一个长方形，它有长和宽两个属性，也有设置长和宽的两个方法和计算面积的方法。

```go
type rectangle struct {
	height int
	width int
}

func (r *rectangle) SetHeight(height int) {
  r.height = height
}

func (r *rectangle) SetWidth(width int) {
  r.width = width
}

func (r rectangle) Area() int {
	return r.height * r.width
}
```

现在我们想要一个正方形，然后我们让正方形"继承"了长方形。

```go
type square struct {
	rectangle
}

func (s square) Area() int {
	return s.height * s.width
}

func (s *square) SetHeight(height int) {
  s.height = height
}

func (s *square) SetWidth(width int) {
  s.width = width
}
```

现在正方形已经实现了长方形的三个方法已经。但是因为正方形的长度等于宽度，因此在使用方使用时，需要注意区分形状，并做不同的处理：

```go
func (s Shape) SetHeight(height int) {
  if s.isRectangle {
    s.SetHeight(height)
  }
  if s.isSquare {
    s.SetHeight(height)
    s.SetWidth(height)
  }
}

func (s Shape) SetWidth(height int) {
  if s.isRectangle {
    s.SetWidth(height)
  }
  if s.isSquare {
    s.SetHeight(height)
    s.SetWidth(height)
  }
}
```

这就违反了里氏替换原则。

**如果代码违反了里氏替换原则，说明衍生对象不应该继承/组合基础对象，应考虑其他写法。**

## I-接口隔离

全称：Interface Segregation Principle

> A client should never be forced to implement an interface that it doesn’t use, or clients shouldn’t be forced to depend on methods they do not use.

接口隔离是指导接口之间进行隔离的一个原则：**不能强迫一个对象实现它不需要的接口，也不能强迫它一来它不需要的方法。**所以在抽象接口时，要注意划分。

比如Admin实现了IUser接口, IUser有获取ID和禁用员工两个方法：

```go
type IUser interface{
  GetID() string
  ForbiddenUser(user string)
}
```

现在我们需要一个Employee，它有User的性质，因此也实现了IUser，但是Employee没有禁用员工的行为，因此没有办法实现这个方法。

我们应该如何处理？实现ForbiddenUser但是不处理吗？如果这样，就违反了接口隔离原则！

我们应该将接口细化、划分为多个接口：

```go
type IUser interface{
	GetID() string
}

type IAdmin interface{
	IUser
  ForbiddenUser(user string)
}
```

这样，对于Employee和Admin，都有其“恰好所需”的接口来实现。

## D-依赖倒置

全称：Dependency Inversion Principle

> Entities must depend on abstractions, not on concretions. It states that the high-level module must not depend on the low-level module, but they should depend on abstractions.

依赖倒置是指导服务内层级划分的一个准则——**上层模块不应依赖下层模块，而应该依赖于它们的接口。其核心理念是上层模块不应该关心下层模块的实现细节。**

依赖倒置这一原则在很多模式中都有体现，比如说仓库模式（Repository Pattern）。

```go
type IRepo interface{
  GetUser(id string) User
  GetCompany(id string) Company
}
```

业务对象或者领域对象依赖于IRepo接口，而不关心底层数据库是用MySQL还是MongoDB亦或Redis，也不关心它们的SQL语句、实现细节。

业务对象只关心它需要什么数据，IRepo则按需提供即可。**其核心理念是业务对象只关心自己的业务规则，尽可能最大程度的降低业务方法的复杂程度。**

《HeadFirst设计模式》中，描述了一些避免违反依赖倒置原则的指导方针：

- 变量不可以持有具体类的引用（应该持有抽象接口）
- 不要让类派生自具体类（派生自具体类就是在依赖类，应该派生于抽象接口）
- 不要覆盖基类中已实现的方法（如果覆盖基类己实现的方法，那么你的基类就不是一个真正适合继承的基类。基类中已实现的方法，应该由所有的子类共享）

当然，并不是说所有的代码都要这样严格要求，否则会优化过度！应该把以上三点当做”触发点“，当你的代码具有这些特点的时候，就要想一想代码需不需要优化了！

## 总结

- 原则之间并不是互斥的，实际中的问题可能同时违反了多个原则。
- 文中只给出了错误的使用，并且没有提供纠错实例。这样做是因为解决问题的方式有很多种，举例反而容易造成固化解决方式的误解（如，认为这种问题只能这样解决）。
- 代码需要不断被重构，写代码也需要不断精进。

## 相关文档

- [bob大叔亲自讲解SOLID](https://www.youtube.com/watch?v=zHiWqnTWsn4&ab_channel=FucktheCommunism)
- [SOLID原则-digitalocean](https://www.digitalocean.com/community/conceptual-articles/s-o-l-i-d-the-first-five-principles-of-object-oriented-design)
