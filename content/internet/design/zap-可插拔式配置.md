+++

date = 2022-11-02T17:23:00+08:00
title = "zap-优雅的可选配置"
url = "/internet/go/zap/options"

toc = true

+++



## 前瞻

代码中有些对象具有多种行为，而展示哪种行为方式则需要根据配置来抉择。

根据配置来实例化对象，最简单的方式是提供一个New函数来实例化对象，将配置参数作为函数入参，如：

```go
// name和age是必传的参数，而isAdmin是可选的配置——如果是管理员，则具有更多的行为。
func NewUser(name string, age int, isAdmin bool) *User {...}
```

在这个例子中，User只有一个可选参数(isAdmin)，在产品迭代过程中（甚至在开发过程中），会存在越来越多的功能，也会需要越来越多的可选参数，这个时候就需要去修改这个函数签名以加入更多的参数:

```go
func NewUser(name string, age int, isAdmin bool, isTeacher bool, isStudent bool, location string) *User {...}
```

但是直接修改函数签名会带来一些负面效果：

- 函数签名越来越长，调用的时候需要设置很多不需要的参数
- 函数体越来越复杂，看起来很乱
- 需要修改调用方
- 。。。

所以我们一般不在New方法中存入可选参数。

我们可以借鉴下zap。

## zap

[zap](https://github.com/uber-go/zap)是uber开源的一款基础golang的日志库，以性能卓越著称。

### Option接口

**Option是一个接口，每个可选参数都实例化为一个函数，函数的返回值都实现了这个接口**。

```go
// An Option configures a Logger.
type Option interface {
	apply(*Logger)
}

// optionFunc wraps a func so it satisfies the Option interface.
type optionFunc func(*Logger)

func (f optionFunc) apply(log *Logger) {
	f(log)
}
```

Option定义了apply方法，用于将配置应用于日志对象上。

optionFunc是zap中实现了Option的结构，zap中内置的可选参数所实例化的函数的返回值都是optionFunc类型。

### 可选参数封装为函数实例：

这些例子有：

```go
// Development puts the logger in development mode, which makes DPanic-level
// logs panic instead of simply logging an error.
func Development() Option {
	return optionFunc(func(log *Logger) {
		log.development = true
	})
}

// AddCaller configures the Logger to annotate each message with the filename
// and line number of zap's caller.  See also WithCaller.
func AddCaller() Option {
	return WithCaller(true)
}

// WithCaller configures the Logger to annotate each message with the filename
// and line number of zap's caller, or not, depending on the value of enabled.
// This is a generalized form of AddCaller.
func WithCaller(enabled bool) Option {
	return optionFunc(func(log *Logger) {
		log.addCaller = enabled
	})
}

// AddCallerSkip increases the number of callers skipped by caller annotation
// (as enabled by the AddCaller option). When building wrappers around the
// Logger and SugaredLogger, supplying this Option prevents zap from always
// reporting the wrapper code as the caller.
func AddCallerSkip(skip int) Option {
	return optionFunc(func(log *Logger) {
		log.callerSkip += skip
	})
}

// AddStacktrace configures the Logger to record a stack trace for all messages at
// or above a given level.
func AddStacktrace(lvl zapcore.LevelEnabler) Option {
	return optionFunc(func(log *Logger) {
		log.addStack = lvl
	})
}
```

这些函数的返回值都是optionFunc，即都实现了Option。

### 应用Option

zap中通过WithOptions方法来应用可选配置：

```go
// WithOptions clones the current Logger, applies the supplied Options, and
// returns the resulting Logger. It's safe to use concurrently.
func (log *Logger) WithOptions(opts ...Option) *Logger {
	c := log.clone()
	for _, opt := range opts {
		opt.apply(c)
	}
	return c
}
```

### example

**设置CallerSkip：**

```go
// NewStdLog returns a *log.Logger which writes to the supplied zap Logger at
// InfoLevel. To redirect the standard library's package-global logging
// functions, use RedirectStdLog instead.
func NewStdLog(l *Logger) *log.Logger {
	logger := l.WithOptions(AddCallerSkip(_stdLogDefaultDepth + _loggerWriterDepth))
	f := logger.Info
	return log.New(&loggerWriter{f}, "" /* prefix */, 0 /* flags */)
}
```

**替换日志核心：**

```go
func ExampleWrapCore_replace() {
	// Replacing a Logger's core can alter fundamental behaviors.
	// For example, it can convert a Logger to a no-op.
	nop := zap.WrapCore(func(zapcore.Core) zapcore.Core {
		return zapcore.NewNopCore()
	})

	logger := zap.NewExample()
	defer logger.Sync()

	logger.Info("working")
	logger.WithOptions(nop).Info("no-op")
	logger.Info("original logger still works")
	// Output:
	// {"level":"info","msg":"working"}
	// {"level":"info","msg":"original logger still works"}
}
```

**设置为开发模式：**

```go
L().With(Int("foo", 42)).Named("main").WithOptions(Development()).Info("")
```

**设置日志级别：**

```go
logger.WithOptions(IncreaseLevel(ErrorLevel))
```

## 总结

zap通过Option的设计，**将可选配置与日志初始化实现了“实例化的解耦”**，使用者可以根据其需求而使用不同的可选项，而不同的使用者之间不会互相影响。
