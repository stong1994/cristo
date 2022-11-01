+++

date = 2022-10-31T00:01:00+08:00
title = "go设计之errgroup"
url = "/internet/go/errgroup"

toc=true

+++



## 前瞻

在工作中，如果遇到需要并发访问，并且接受返回值的功能，一般都是使用`sync.WaitGroup+channel`来实现。

但go社区中已经提供了这个功能的封装——[errgroup](https://pkg.go.dev/golang.org/x/sync/errgroup).

虽然errgroup这个轮子和我们自己造的轮子差不多，但是既然别人已经造好了，我们就没必要再重复造轮子了。

## 源码

源码非常简洁，算上注释也才100来行。源码位置：`golang.org/x/sync/errgroup`

### Group

```go
// A Group is a collection of goroutines working on subtasks that are part of
// the same overall task.
//
// A zero Group is valid, has no limit on the number of active goroutines,
// and does not cancel on error.
type Group struct {
	cancel func()

	wg sync.WaitGroup

	sem chan token

	errOnce sync.Once
	err     error
}
```

Group结构非常简单：

- cancel：取消函数，并发请求一般都会使用带cancel的context，能非常方便的控制并发中的请求生命周期。
- wg: 并发中最常用的组件，用于等待异步任务完成。
- sem：一个用于控制并发数量的channel，token的数据类型是一个空结构体（空结构体的好处是不占内存）。
- errOnce: 一个只执行一次的并发控制器，由命名可以推断出并发中的错误只会捕获一次。
- err: 存储error

### sem

sem是一个非常巧妙的设计，一般控制并发数量，可以使用一个原子值来记录当前的并发数，使用锁来控制请求。errgroup中使用了channel来实现了这个功能。我们看下他的用法。

#### SetLimit-设置并发限制数量

```go
func (g *Group) SetLimit(n int) {
	if n < 0 {
		g.sem = nil
		return
	}
	if len(g.sem) != 0 {
		panic(fmt.Errorf("errgroup: modify limit while %v goroutines in the group are still active", len(g.sem)))
	}
	g.sem = make(chan token, n)
}
```

通过SetLimit来设置并发限制数量，这个数量表现为sem的通道长度。

需要注意的是，如果异步任务已经开始执行，这时候不应该再去设置限制数量（虽然代码里没有对这一要求做非常严谨的判断）。

#### TryGo-判断能否运行任务并执行

```go
func (g *Group) TryGo(f func() error) bool {
	if g.sem != nil {
		select {
		case g.sem <- token{}:
			// Note: this allows barging iff channels in general allow barging.
		default:
			return false
		}
	}

	g.wg.Add(1)
	go func() {
		defer g.done()

		if err := f(); err != nil {
			g.errOnce.Do(func() {
				g.err = err
				if g.cancel != nil {
					g.cancel()
				}
			})
		}
	}()
	return true
}
```

TryGo其实包含了两个功能：

1. 判断当前是否能够执行新任务
2. 如果能执行则执行，不能执行就返回false

而能否执行新任务就是判断sem能够立马消费一个token，如果不能的话，说明当前的并发数量已经达到了限制。

#### done-任务执行完毕的清理工作

```go
func (g *Group) done() {
	if g.sem != nil {
		<-g.sem
	}
	g.wg.Done()
}
```

done其实就做了两件事：

1. 消费sem中的一个token，因为任务开启时一定会存入一个token，因此这里一定能够消费到，并且不会被阻塞。
2. 执行wg.Done()

### WithContext & Wait

```go
// WithContext returns a new Group and an associated Context derived from ctx.
//
// The derived Context is canceled the first time a function passed to Go
// returns a non-nil error or the first time Wait returns, whichever occurs
// first.
func WithContext(ctx context.Context) (*Group, context.Context) {
	ctx, cancel := context.WithCancel(ctx)
	return &Group{cancel: cancel}, ctx
}

func (g *Group) Wait() error {
	g.wg.Wait()
	if g.cancel != nil {
		g.cancel()
	}
	return g.err
}
```

- WithContext是一个创建Group的函数，创建的过程中将ctx封装为带有取消函数的ctx。

- Wait会等待所有任务执行完毕。

### Go

```go
// Go calls the given function in a new goroutine.
// It blocks until the new goroutine can be added without the number of
// active goroutines in the group exceeding the configured limit.
//
// The first call to return a non-nil error cancels the group's context, if the
// group was created by calling WithContext. The error will be returned by Wait.
func (g *Group) Go(f func() error) {
	if g.sem != nil {
		g.sem <- token{}
	}

	g.wg.Add(1)
	go func() {
		defer g.done()

		if err := f(); err != nil {
			g.errOnce.Do(func() {
				g.err = err
				if g.cancel != nil {
					g.cancel()
				}
			})
		}
	}()
}
```

Go与TryGo相似，唯一的区别是如果当前并发数量已经达到限制，则会进行阻塞而不是直接返回。

### example

以`errgroup_test.go`中的一个例子为例：

```go
func ExampleGroup_parallel() {
	Google := func(ctx context.Context, query string) ([]Result, error) {
		g, ctx := errgroup.WithContext(ctx)

		searches := []Search{Web, Image, Video}
		results := make([]Result, len(searches))
		for i, search := range searches {
			i, search := i, search // https://golang.org/doc/faq#closures_and_goroutines
			g.Go(func() error {
				result, err := search(ctx, query)
				if err == nil {
					results[i] = result
				}
				return err
			})
		}
		if err := g.Wait(); err != nil {
			return nil, err
		}
		return results, nil
	}

	results, err := Google(context.Background(), "golang")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return
	}
	for _, result := range results {
		fmt.Println(result)
	}

	// Output:
	// web result for "golang"
	// image result for "golang"
	// video result for "golang"
}
```

这个例子会并发访问三个地址，然后将结果写入results切片中。需要注意**切片是并发不安全的**，所以在实际开发中，需要对results切片加锁，或者使用channel来传递至。

