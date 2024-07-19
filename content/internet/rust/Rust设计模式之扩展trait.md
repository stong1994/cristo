---
date: 2024-07-18T01:43:00+08:00
title: "Rust设计模式之扩展trait"
url: "/internet/rust/extension-trait"
toc: true
draft: false
description: "Rust设计模式之扩展trait"
slug: "extension trait"
tags: ["rust", "trait", "extension trait"]
showDateUpdated: true
---

## Extension Trait Pattern

扩展trait是一种设计模式，常用于扩展所依赖的外部类型的能力。

比如说在`rust`中常用`println`来打印内容：

```rust
fn main() {
    let hello = "Hello, world!".to_string();
    println!("{}", hello);
}
```

`hello`的类型是`String`，没有实现`Display trait`, 因此无法直接`println(helo)`，而是通过占位符的方式进行打印。

如果代码里有非常多的地方需要打印，那么会非常麻烦。要是可以直接使用`print`方法就好了。

这时就可以使用`扩展trait`来实现这个功能。

```rust
trait StringExt {
    fn print(&self);
}

impl StringExt for String {
    fn print(&self) {
        println!("{}", self);
    }
}

fn main() {
    let hello = "Hello, world!".to_string();
    hello.print();
}
```

## 为外部类型新增方法

上面的例子中，我们为`String`类型新增了一个`print`方法, 只需要以下几个步骤：

1. 定义一个`trait`, 通常以类型名称开头，以`Ext`结尾。
2. 为`String`类型实现这个`trait`。
3. 在实现中增加方法`print`。
4. 在需要的地方使用这个方法。

让我们再实现一个练练手: 为动态数组添加一个`sum`方法:

```rust
trait VecExt<T> {
    fn sum(&self) -> T;
}

impl VecExt<i32> for Vec<i32> {
    fn sum(&self) -> i32 {
        self.iter().sum()
    }
}

fn main() {
    let numbers = vec![1, 2, 3, 4, 5];
    println!("{}", numbers.sum()); // Outputs: 15
}
```

## 为外部trait新增方法

很多依赖库的方法返回值是`trait`，为外部`trait`新增方法能够减少很多重复的代码。

让我们为`std::error::Error`实现`StringExt`:

```rust
impl StringExt for std::error::Error {
    fn print(&self) {
        println!("{}", self);
    }
}
```

上边的代码会编译失败，因为`Rust`不允许为外部`trait`实现本地`trait`。但是我们可以"曲线救国":

```rust
impl<T: std::error::Error> StringExt for T {
    fn print(&self) {
        println!("{}", self);
    }
}
```

这个代码是可以编译通过的，因为我们不是在为`std::error::Error`实现本地`trait`, 而是为所有实现了`std::error::Error`的具体类型实现本地`trait`!!

测试一下：

```rust
use std::fs::File;

trait StringExt {
    fn print(&self);
}

impl<T: std::error::Error> StringExt for T {
    fn print(&self) {
        println!("{}", self);
    }
}

fn main() {
    let result = File::open("non_existent_file.txt");

    match result {
        Ok(_) => println!("File opened successfully."),
        Err(e) => e.print(), // Outputs: No such file or directory (os error 2)
    }
}
```

## 孤儿限制

`Rust`通过`孤儿规则`来保证类型安全，其具体内容如下:

1. 可以为任意类型实现本地`trait`
2. 可以为本地类型实现外部`trait`
3. 不能为外部类型实现外部`trait`

第一条我们在上述内容中已经看到了，第二条是`trait`的基本使用，第三条需要注意下: 如果我们为外部类型`String`实现外部`trait` `std::error::Error`会发生什么?

如果我们可以这么做的话，别人也可以这么做。这意味程序中可能会有多个实现，而编译器无法判断应该使用哪一个。这就是孤儿限制的缘由。

## 推荐阅读

- [Type-Driven API Design in Rust](https://www.youtube.com/watch?v=bnnacleqg6k)
