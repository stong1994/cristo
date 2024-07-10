---
title: "相较于go, rust好在哪"
date: 2023-03-18T14:35:00+08:00
url: "/note/rust/the_content_rust_better_than_go"
isCJKLanguage: true
draft: false
toc: true
keywords:
  - rust
authors:
  - stong
tags: ["rust", "go"]
---

## 前言

作为程序员，在学习一门新语言时，总是会将新的语言与已学的内容进行比较。

这种类比能力能够实现知识的迁移。实际上，这正是人类能够快速学习、掌握知识的原因。

作为一名资深gopher，学习一门语言自然是优先与go进行类比。

## rust中好的地方

### 表达式作为返回值

```rust
// rust
fn add(i32: a, i32: b) -> i32 {
	a+b
}
// go
func add(a, b int) int {
  return a+b;
}
```

这个能够让我们少些一个return，还是不错的！

### 复用变量名

```rust
let id: i32 = 10;
let id = String::from("10");
```

go没有办法对不同类型的变量复用变量名:

```rust
id := 10
idStr := strconv.Itoa(id)
```

所以rust这里确实好些~

### 三元表达式

```rust
let number = if condition {
  5
} else {
  6
};
```

虽然rust中也不支持那种极简的三元表达式`let number = if conditon ? 5 : 6;`，不过最起码还是有的。如果是go的话，只能：

```go
var number int
if condition {
  number = 5
}else {
  number = 6
}
```

### 结构体：字段初始化简写

```rust
struct User {
    username: String,
    email: String,
    sign_in_count: u64,
    active: bool,
}
fn build_user(email: String, username: String) -> User {
    User {
        email,
        username,
        active: true,
        sign_in_count: 1,
    }
}
```

go里边不能简写:

```go
type  User  struct {
    username string
    email string
    sign_in_count uint64
    active bool
}

func build_user(email string, username string) User {
    return User {
        email:email,
        username: username,
        active: true,
        sign_in_count: 1,
    }
}
```

### 结构体：更新部分字段

```rust
let user2 = User {
    email: String::from("another@example.com"),
    username: String::from("anotherusername567"),
    ..user1
};
```

go里边虽然不支持`..user1`这种语法，但是可以直接复制一个user，然后只更新这两个字段。

```go
user2 := user1
user2.email = "another@example.com"
user1.username = "anotherusername567"
```

### 元组结构体：

元组和结构体的结合——拥有表明自身含义的名称&无需为每个字段命名。

```rust
struct Color(i32, i32, i32);
struct Point(i32, i32, i32);

let black = Color(0, 0, 0);
let origin = Point(0, 0, 0);”
```

这种无需为每个字段命名的场景确实存在，所以这方面确实比go做得好。

### 关联函数

我们常常为结构体初始化写一个函数，比如NewXxxx，在rust中，可以将这个函数放到impl中成为一个关联函数，比如：

```rust
struct User {
    age: u8,
}

impl User {
    fn new(age: u8) -> User {
        User { age }
    }
}
```

在go中，只能靠程序员自觉将New函数与结构体放在一起：

```go
type User struct {
    age uint8
}

func NewUser(age uint8) User {
    return User {
        age: age,
    }
}
```

### 枚举

```rust
enum IpAddr {
    V4(u8, u8, u8, u8),
    V6(String),
}
```

rust中的枚举要比go更丰富一些，可以携带不能类型的值，go中只能用iota做一些简单的枚举：

```rust
type Color int

const (
    Red Color = iota
    Green
    Blue
)
```

### 没有空值

空值的存在会导致很多问题，比如说空指针，或者频繁的非空判断。

在rust中表示不存在，要使用一个名为Null的Option。在标准库中是这样定义的：

```rust
enum Option<T> {
    Some(T),
    None,
}
```

**这意味着一个有数据的变量和一个不存在的变量的类型是不一样的**，一个是T,一个是`Option<T>`，这能够避免**假设某个值存在，实际却为空**的问题。

### 对字符串切片按索引获取

在rust中，不能对一个不完整的字符进行切片，否则会直接panic：

```rust
let s = String::from("我是谁");
let s2 = &s[0..3];
println!("{}", s2); // 我
let s3 = &s[0..2];
println!("{}", s3); // panic
```

在go中是可以的：

```rust
s := "我是谁"
println(s[0:2]) // �
```

我个人比较喜欢rust这种处理方式，能够减少很多生产上的问题。

### rust支持CTFE(Compile-Time Function Execution)

rust可以在编译期间执行函数，比如初始化一个有N个0的数组：

```rust
const fn init_len() -> usize {
    5
}

fn main() {
    let arr = [0, init_len()];
}
```

go不支持CTFE。

### 自动释放资源

go中经常使用defer来释放资源，这是相比较其他语言的一种设计优势————能够更清晰、稳定的释放资源。

```go
package main

import (
	"fmt"
	"os"
)

func main() {
	file, err := os.Open("file.txt")
	if err != nil {
		fmt.Println("Error opening file:", err)
		return
	}

	// Ensure the file is closed when the function returns
	defer file.Close()

	// Do some operations with the file
	// ...
}
```

但是Rust在这种场景下是一种降维打击————**资源的释放是自动的**:

```rust
use std::fs::File;
use std::io::prelude::*;
use std::io::Error;

fn main() -> Result<(), Error> {
    let mut file = File::open("file.txt")?;

    let mut contents = String::new();
    file.read_to_string(&mut contents)?;

    // Do some operations with the file
    // ...

    // The file is automatically closed when `file` goes out of scope.

    Ok(())
}
```

这是因为Rust的所有权系统，当file超出作用域时，会自动调用drop方法，释放资源。

对于自定义的资源，可以实现Drop trait来释放资源。

## go中好的地方

**大道至简！**

go最好的地方不在于其channel、goroutine的设计，而在于其简单性，这种简单性是说go的设计很简单，不需要那么复杂的语法，看go代码很轻松，不需要很大的心智负担。

比如下面这段不是很复杂的rust代码（同时使用了泛型、生命周期、trait约束）：

```rust
use std::fmt::Display;

fn longest_with_an_announcement<'a, T>(x: &'a str, y: &'a str, ann: T) -> &'a str
    where T: Display
{
    println!("Announcement! {}", ann);
    if x.len() > y.len() {
        x
    } else {
        y
    }
}
```

这可能会导致一名rust新手的cpu飙升！

而如果你让我去写一段go中最复杂的代码，我只能说做不到！

当然，go中确实有好的设计，比如goroutine、channel，这些就不展开说了。

## Trait vs 接口

了解一个语言的使用方式，可以看其对象之间的组合方式，比如java中的继承，go中的组合。**开发代码的设计应该遵循语言的设计**。

对于rust而言，我们可以通过和go的接口对比，来看下其trait的使用。

### 异同

1. Rust 中的 trait 和 Go 中的 接口 都是通过方法签名来描述一个类型或对象需要实现的行为规范。但是，Rust 的 trait 可以添加默**认实现**，而 Go 中的接口 禁止添加默认实现。

   ```rust
   // rust
   trait MyTrait {
       fn say_hello(&self) {
           println!("Hello, world!");
       }
   }
   // go
   type MyTrait interface {
     say_hello()
   }
   ```

2. 由于没有默认实现，在 Go 中，如果一个类型要实现接口，则要定义接口中的的所有方法。

3. GO中的接口是鸭子类型，不用显式声明一个结构体实现了哪些接口。

4. Rust 的 trait 可以包含**关联常量**，而 Go 中的接口不支持。

   ```rust
   trait MyTrait {
       const PI: f64;

       fn calc_area(&self) -> f64;
   }

   struct Circle {
       radius: f64,
   }

   impl MyTrait for Circle {
       const PI: f64 = 3.1415926535;

       fn calc_area(&self) -> f64 {
           Self::PI * self.radius * self.radius
       }
   }
   ```

5. 在 Rust 中，一个类型可以实现多个 trait ，在 Go 中，一个类型也能实现多个接口，只不过前者需要显式声明，或者则不需要。

```rust
fn some_function<T: Display + Clone, U: Clone + Debug>(t: T, u: U) -> i32
```

在这段代码中，由于参数实现的接口较多，因此可以使用where语法优化：

```rust
fn some_function<T, U>(t: T, u: U) -> i32
    where T: Display + Clone,
          U: Clone + Debug
{}
```

但给开发者的体验仍然较差！

### 使用差异

我们可以通过其使用方式来探究一些差异：

```rust
// rust
impl MyTrait for Cirle {}
```

这是一段rust代码，可以看到语义为为Cirle实现MyTrait，主体是Cirle而非MyTrait。

而在go中，接口往往用于适配，比如:

```go
type User interface {
	ID() string
}

type Emp struct {}
func (Emp) ID() string {
	return ""
}

type Admin struct {}
func (Admin) ID() string {
	return ""
}
```

主体是接口User，Emp和Admin只是做的适配！

我们可以看到，**rust中的trait是结构体的组件或者约束，因此一个结构体可以有多个trait来做组件或者约束。而go中的结构体只是用来做接口的适配！**

因此，**在使用方式上，Rust 的 trait 更适合描述一个类型的一组行为，而 Go 的接口更适合描述具有一组行为的一个类型！**
