+++

date = 2022-03-10T14:43:00+08:00
title = "go中的测试"
url = "/internet/go/component_test"
tags = ["go", "测试"]

toc = true

+++

因目的与范畴的不同，代码中的测试通常可以分为单元测试、组件测试、场景测试等等。

但是从一名程序员的角度来看，所有的测试都是为了保证代码的正确性。

相信每个程序员都知道要写测试代码，但是这些人中也有很多不怎么写测试代码，有些可能是懒的写，另外一些可能就是不知道如何下手。

我会在这篇博客里记录go中的一些测试技巧。

## assert

`github.com/stretchr/testify`是go测试代码中常用的进行比较判断的库：其中`assert`模块用于做比较的判断, eg：

```go
num, err := getNum()
assert.NoError(t, err)
assert.Equal(t, 1, num)
```

assert模块提供了非常多的API，用的时候可以顺便看下。

## require

同样是`github.com/stretchr/testify`下，`require`模块提供的API和`assert`基本一致，区别在于`require`模块对`assert`模块进行了一层包装：

```go
func NoError(t TestingT, err error, msgAndArgs ...interface{}) {
	if h, ok := t.(tHelper); ok {
		h.Helper()
	}
	if assert.NoError(t, err, msgAndArgs...) {
		return
	}
	t.FailNow()
}
```

`t.FailNow()`可是会直接退出程序的，这意味着，如果使用`require`模块的API，一旦校验没通过，剩下的测试代码就不会跑了。

## 测试表格

我们常常将一类测试放到一个测试表格中进行统一处理，这个测试表格就是一个“范畴”——包含了被测试代码的所有场景。

比如我们创建了一个函数`func doubleNum(num int) (int, error)`，要对其进行测试，就可以将相关的测试用例存到一个测试表格中：

```go
import (
	"github.com/stretchr/testify/require"
	"testing"
)

func TestDoubleNum(t *testing.T) {
	tests := []struct {
		name    string
		num    int
		wantNum int
	}{
		{
			"test 0",
			0,
			0,
		},
		{
			"test 2",
			2,
			4,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gotNum, err := doubleNum(tt.num)
			require.NoError(t, err)
			t.Errorf("getNum() wantNum = %d, wantErr %d", tt.wantNum, gotNum)
		})
	}
}

func doubleNum(num int) (int, error) {
	return num*2, nil
}
```

## 适配器模式

适配器模式是一种设计模式，其目的在于维护业务规则的完整性，避免调用下游服务过程中造成的代码侵蚀。但是这种模式在用于测试时也十分契合。

比如我们的业务代码需要数据库提供更新用户名称的接口，传统的方式是这样：

```go
// dao层
type DB struct {
	client *gorm.DB
}

func (db DB) UpdateUserName(name string) error {
	// update user
}

// 注入
type UserService struct{
	repo dao.DB
}

func (us UserService) updateName(name string) error {
  // some code....
  err := us.repo.UpdateUserName(name)
  if err != nil {
    // handle error
  }
  // some code....
}
```

当我们要测试UserService中的updateName方法时，因为UserService依赖DB实例，因此只能创建DB实例，也就需要一套数据库的地址、账号、密码等等。

这造成了大量的工作负担，也难怪很多程序员不写测试。

使用适配器模式就完全不同了。

定义一个仓库适配器：

```go
type Repo interface{
	UpdateUserName(name string) error
}
```

然后在用户服务中注入：

```go
type UserService struct{
	repo Repo
}

func (us UserService) updateName(name string) error {
  // some code....
  err := us.repo.UpdateUserName(name)
  if err != nil {
    // handle error
  }
  // some code....
}
```

这时候UserService依赖的是Repo接口，我们可以直接mock即可：

```go
type RepoMock struct{}
func (RepoMock) UpdateUserName(name string) error {}
```

这样就解决了数据库操作难以测试的大难题！

## 异步结果测试

编写测试时还有一个很繁琐的问题是如何检测异步的结果，比如在编写组件测试时要启动一个http服务，启动过程是异步的，如果检测http服务已经启动成功了？

可以使用`EventuallyWithT`:

```go
require.EventuallyWithT(
  t,
  func(collect *assert.CollectT) {
    resp, err := stdHttp.Get("http://localhost:8080/health") // 健康检查接口
    if !assert.NoError(collect, err) {
      return
    }
    defer resp.Body.Close()

    if assert.Less(collect, resp.StatusCode, 300, "API not ready, http status: %d", resp.StatusCode) {
      return
    }
  },
  time.Second*10,
  time.Millisecond*50,
)
```

在上面这个例子中，规定了每50毫秒调用一次`health`接口，如果`assert`校验通过，则结束，否则会一直持续这个过程。如果10s内都没能校验通过，则校验失败。

注意，EventuallyWithT中的函数做校验用到的是assert而非require，这因为require中使用了`t.FailNow()`而`t.FailNow()`必须运行在执行测试的goroutine中，相关讨论可见[How to handle failed expectations inside of a goroutine? · Issue #772 · stretchr/testify · GitHub](https://github.com/stretchr/testify/issues/772#)

## 相关阅读

- [4 practical principles of high-quality database integration tests in Go (threedots.tech)](https://threedots.tech/post/database-integration-testing/)
