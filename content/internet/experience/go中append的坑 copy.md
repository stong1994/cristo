---
title: "go中对测试代码使用不同的包名"
date: 2023-09-19T14:10:51+08:00
url: "/internet/go/package_name"
isCJKLanguage: false
draft: false
toc:  true
keywords:
  - package name
authors:
  - stong
---



## package

我们在编程时往往需要通过模块来对代码进行“划分”——这个代码属于登录模块，那个代码属于充值模块。划分后的代码会更清晰，更方便查找、维护。

常用的语言中往往使用`import`关键字来引入其他模块。

在python中，这个模块是以文件为单位的，而在go中，这个模块是以目录为单位的。

### go中的package

在go中，同一个目录中的代码要使用相同的`package name`，否则会编译失败：

```
├── a.go
├──── package a
└── b.go
├──── package b
```

执行`go build`报错：`found packages a (a.go) and b (b.go) in xxxx`.

但是，测试用的代码例外。

### 测试代码的package

```
├── a.go
├──── package a
└── a_test.go
├──── package a_test
```

上面的package命名是符合规则的。

对于测试代码的package有两种命名：

- 使用相同的package name，即`a`
- 使用携带`_test`后缀的package name，即`a_test`

## 两种测试代码package的命名

### 使用相同的package name

在这种情况下，可以针对一些私有的函数、方法、字段进行测试，因为这些unexported字段、函数能够被同一个包下的其他文件使用。

缺点就是测试代码的依赖库也会加入到整个项目中，那么当其他项目引用这个项目时，就会产生”多余“的依赖库。

### 使用携带`_test`后缀的package name

在这种情况下，因为测试代码和被测代码属于不同的模块，只能测试代码只能使用被测代码的exported字段、函数、方法（以下统称为public API）。

这是有一定好处的：**public API往往不会变化，因此在维护过程中不会花费大量精力在测试上**。

但缺点就是**有些需要使用unexported字段的代码测试会覆盖不到**。

使用这种方式的另一个好处是可以**将测试代码的依赖库从`go.mod`中去除**，这样当别人引用这个项目时就无需下载这些”多余“的依赖库。

> 当然在项目中执行测试时仍需下载这些依赖库，因此还是需要进行管理的。这时可以通过命令`go mod tidy -modfile go_test.mod`将依赖管理文件指定为`go_test.mod`
>
> 关于这点可参考[nats.go](https://github.com/nats-io/nats.go)
>
> 对于如何避免依赖这些”多余“的依赖库，可参考[这里](https://github.com/nats-io/nats.go/issues/1311)的讨论。



