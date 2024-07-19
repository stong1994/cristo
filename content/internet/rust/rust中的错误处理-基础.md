---
date: 2024-07-14T01:43:00+08:00
title: "Rust中的错误处理——基础"
url: "/internet/rust/error-base"
toc: true
draft: false
description: "Rust中基础的错误处理"
slug: "错误处理"
tags: ["rust", "错误处理"]
showDateUpdated: true
---

## Error trait——错误处理的基石

Error trait 是rust标准库对于错误类型的基本抽象，主要包含以下几个方法：

```rust
pub trait Error: Debug + Display {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        None
    }

    fn cause(&self) -> Option<&dyn Error> {
        self.source()
    }

    fn provide<'a>(&'a self, request: &mut Request<'a>) {}
}
```

其中：

- source: 用于展示错误的来源
- cause: source()的别名
- provide: 提供基于指定错误类型的访问

### source

借用官方的例子，我们自定义两个错误类型：`SuperError`和`SuperErrorSideKick`,其中`SuperErrorSideKick`是`SuperError`的来源。

```rust
use std::error::Error;
use std::fmt;

#[derive(Debug)]
struct SuperError {
    source: SuperErrorSideKick,
}

impl fmt::Display for SuperError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "SuperError is here!")
    }
}

impl Error for SuperError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        Some(&self.source)
    }
}

#[derive(Debug)]
struct SuperErrorSideKick;

impl fmt::Display for SuperErrorSideKick {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "SuperErrorSideKick is here!")
    }
}

impl Error for SuperErrorSideKick {}

```

然后构造一个`SuperError`实例，并打印出错误信息：

```rust
fn get_super_error() -> Result<(), SuperError> {
    Err(SuperError {
        source: SuperErrorSideKick,
    })
}

fn main() {
    match get_super_error() {
        Err(e) => {
            println!("Error: {e}");
            println!("Caused by: {}", e.source().unwrap());
        }
        _ => println!("No error"),
    }
}
// Output:
// Error: SuperError is here!
// Caused by: SuperErrorSideKick is here!
```

每个自定义错误类型都实现了`Display`用于展示自定义的错误信息，并且通过`source`来构造了一条简短的错误信息链用于错误的追溯。

也可以使用`source`来打印整条错误链:

```rust
fn error_chain_fmt(
    e: &impl std::error::Error,
    f: &mut std::fmt::Formatter<'_>,
) -> std::fmt::Result {
    writeln!(f, "{}\n", e)?;
    let mut current = e.source();
    while let Some(cause) = current {
        writeln!(f, "Caused by:\n\t{}", cause)?;
        current = cause.source();
    }
    Ok(())
}

```

### provide

将上面的代码改造下，对`SuperError`实现`provide`方法：

```rust
impl Error for SuperError {
    // ....

    fn provide<'a>(&'a self, request: &mut std::error::Request<'a>) {
        request.provide_ref::<SuperErrorSideKick>(&self.source);
    }
}
```

更改下`main`函数：

```rust
fn main() {
    let side_kick = SuperErrorSideKick;
    let error = SuperError { source: side_kick };
    let dyn_error = &error as &dyn std::error::Error; // dyn_error是一个trait object
    let side_kick2 = request_ref::<SuperErrorSideKick>(dyn_error).unwrap(); // 通过provide来获取类型为`SuperErrorSideKick`的错误
    assert!(core::ptr::eq(&error.source, side_kick2)) // 通过assert来判断是否获取到了对应类型的错误
}
```

需要注意的是`provide`是一个`unstable`方法，使用它需要在文件头部增加标识：

```rust
#![feature(error_generic_member_access)]
```

上面的例子能够说明，使用`provide`能够让我们根据**指定类型**来找到所需的错误.

## Result——明确的结果

在我多年的开发经验中(大部分时间用go)，判断是否存在错误、是否有值，是否是空指针耗费了我非常多的精力，比如一个函数签名是这样的：

```go
type User struct {
    ID   string
    Name string
}

func GetUser(userID string) (*User, error)
```

当我去使用这个函数时，出于“防御性编程”，我会这样写：

```go
user, err := GetUser("123"")
if err !=nil {
  return err
}
if user == nil || user.ID == "" {
  return errors.New("user not found")
  }
}
// 处理用户逻辑
```

在写业务规则前，我需要：

- 判断是否有错误
- 判断user是否是空指针
- 判断user是否是零值
  这非常痛苦, 因为**我只想写业务规则**，而且编写代码时容易遗漏上述某种情况。

在早年的一个同事告诉我，如果你确定只有在存在错误时user才为nil，那么就可以不用判断第二种情况。但是这说不通，毕竟代码是团队一起写的，我不能保证其他人会不会在不存在错误时返回一个user的空指针。比如在用户不存在时，我认为返回一个空指针是合理的。

上述问题的根本原因在于无法从返回结果中明确是否含有合法的User。Rust中用`Result`解决了这个问题。

Result是一个枚举值，它含有两个变体：`Ok`和`Err`:

```rust
pub enum Result<T, E> {
    /// Contains the success value
    Ok(#[stable(feature = "rust1", since = "1.0.0")] T),

    /// Contains the error value
    Err(#[stable(feature = "rust1", since = "1.0.0")] E),
}
```

`Ok`表示成功, `T`为数据的类型，`Err`表示失败, `E`为错误类型.然后通过模式匹配就能正常处理数据或者错误：

```rust
fn main() {
    match read_file() {
        Ok(content) => println!("File content: {}", content),
        Err(error) => println!("Error reading file: {}", error),
    }
}

fn read_file() -> Result<String, std::io::Error> {
    std::fs::read_to_string("foo.txt")
}

```

如果错误无需传递，可以使用`unwrap`或者`expect`方法来直接处理错误，以精简代码：

```rust
    let file = read_file().unwrap();
    // let file = read_file().expect("read file failed");
    println!("File content: {}", file);
```

`unwrap`和`expect`方法本质上都是对`Result`做模式匹配，对`Ok`不做处理，对`Err`进行`panic`操作：

```rust
pub fn expect(self, msg: &str) -> T
    where
        E: fmt::Debug,
    {
        match self {
            Ok(t) => t,
            Err(e) => unwrap_failed(msg, &e),
        }
    }

pub fn unwrap(self) -> T
    where
        E: fmt::Debug,
    {
        match self {
            Ok(t) => t,
            Err(e) => unwrap_failed("called `Result::unwrap()` on an `Err` value", &e),
        }
    }
```

如果错误需要传递到更上层,可以使用`?`操作符(实现了`Try trait`的对象)：

```rust
fn print_file() -> Result<(), std::io::Error> {
    let file = read_file()?;
    println!("File content: {}", file);
    Ok(())
}

```

## panic!——意料之外的错误

从是否在意料之中来看，错误分为两种：

- 意料之中的错误: 如文件不存在，网络超时等属于“可预知&处理的错误”
- 意料之外的错误: 如订单出现了不在规则内的状态

对于“意料之内”的错误可以有多种处理方式（在下一篇讲），而“意料之外”的错误则遵循“尽早暴露问题”的原则——直接用`panic`来处理:

```rust
panic!("no possible")
```

也可以用`catch_unwind`来捕获panic:

```rust
use std::panic::{self, AssertUnwindSafe};

fn main() {
    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        panic!("panicked here");
    }));

    match result {
        Ok(_) => println!("Everything went fine!"),
        Err(_) => println!("The function panicked"),
    }
}

```
