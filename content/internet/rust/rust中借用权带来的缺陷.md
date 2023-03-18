---
title: "rust中引入所有权所带来的麻烦"
date: 2023-03-16T14:35:00+08:00
url: "/note/rust/defect_by_ownership"
isCJKLanguage: true
draft: false
toc:  true
keywords:
  - rust
authors:
  - stong
---



编程语言中主要有两种回收内存的方式：手动回收和后台系统自动回收。rust提出了第三种回收方式——内存会自动地在拥有它的变量离开作用域后进行释放——也就是rust中的所有权系统。

这种方式兼具手动回收和后台系统自动回收的优点：

1. 确保内存能够及时释放（手动回收的优点）
1. 无需开发者手动管理，降低心智负担（自动回收的优点）

但事物总是具有两面性的，所有权系统也为rust带了了一些缺点。

## 时刻戒备所有权

>  一个数据在同一时间只能被一个变量拥有所有权。

开发者在使用一个变量的时候需要戒备这个变量是否还拥有数据的所有权.

- 数据类型是否实现了Copy trait或者Clone trait?
- 这个语句是否会转移所有权？
- 数据被借用了吗，会被修改吗？

## 严格的引用与借用

由于所有权的限制会导致变量在函数间的传递非常麻烦——变量进入函数后会导致函数外的变量失去所有权，因此如果函数外仍要使用这个变量，只能通过接收返回值的方式来实现。

```rust
fn main() {
    let name = String::from("stong");
    let new_name = handle_name(name);

    // println!("{}", name); // 所有权已被转移，因此无法使用
    println!("{}", new_name);
}

fn handle_name(name: String) -> String{
    // 业务逻辑代码
    name
}
```

为了解决这个问题，rust引入了**引用和借用**

于是现在我们就不用这么麻烦的返回数据了。

```rust
fn main() {
    let name = String::from("stong");
    handle_name(&name);

    println!("{}", name); 
}

fn handle_name(name: &String) {
    // 业务逻辑代码
}
```

在这个例子中，我们使用的是**不可变引用**，也就是说不能再handle_name中对name进行修改，如果要修改的话，则需要使用**可变引用**。

```rust
fn main() {
    let mut name = String::from("stong");
    handle_name(&mut name);

    println!("{}", name);  // stong are you ok?
}

fn handle_name(name: &mut String) {
    name.push_str(" are you ok?");
}
```

在这段代码中，我需要

1. 先声明name是可变的:`let mut name`
2. 声明函数handle_name需要的是可变引用: `(name: &mut String)`
3. 将name的可变引用传入函数中: `handle_name(&mut name);`

所有mut在变量声明、函数声明、传参这三个过程中都要参与！

## 引入Clone trait

如果要复制一个独立（拥有数据所有权）的结构体，需要怎样呢？由于所有权的限制，我们需要单独复制每个字段：

```rust
#[derive(Debug)]
struct Person {
    name: String,
    age: u8,
}

fn main() {
    let person1 = Person {
        name: String::from("Alice"),
        age: 20,
    };
    let person2 = Person{
        name: person1.name.clone(), // String类型没有实现Copy trait，但实现了Clone trait, 所以使用clone方法进行复制
        age: person1.age,
    };
    println!("person1: {:?}, person2: {:?}", person1, person2);
}
```

这太麻烦了，为了方便复制结构体，rust提供了Clone trait：

 ```rust
 #[derive(Clone, Debug)]
 struct Person {
     name: String,
     age: u8,
 }
 
 fn main() {
     let person1 = Person {
         name: String::from("Alice"),
         age: 20,
     };
     let person2 = person1.clone();
     println!("person1: {:?}, person2: {:?}", person1, person2);
 }
 ```

## 引入Copy trait

Clone trait需要显式调用clone方法，还是比较麻烦，rust又提供了Copy trait来直接进行复制。

```rust
#[derive(Copy, Clone, Debug)]
struct Person {
    age: u8,
}

fn main() {
    let person1 = Person {
        age: 20,
    };
    let person2 = person1;
    println!("person1: {:?}, person2: {:?}", person1, person2);
}
```

仔细看上边代码，可以看到我去掉了name字段，因为Copy 结构体时要求所有的字段都已实现了Copy trait，而String没有实现Copy trait，因此我将其移除了。

## 手动标注生命周期

所有权系统规定了变量在离开作用域的时候会进行释放，但有时候编译器没办法确定一个变量的作用域，因此需要手动标注生命周期。 看下边这个例子中中存在哪些问题？

```rust
fn longest(x: &str, y: &str) -> &str {
    if x.len() > y.len() {
        x
    } else {
        y
    }
}

fn main() {
    let s1 = String::from("hello");
    let s2 = "world";

    let result = longest(s1.as_str(), s2);
    println!("The longest string is {}", result);
}
```

编译器会告诉我们：longest函数缺少生命周期标注，因为返回值是引用类型，但是不能确定是引用的x还是y。

rust要保证引用一定是有效的，那么引用的生命周期一定不能长于被引用的数据，因此编译器需要知道返回值引用的究竟是谁，更具体的说法是编译器需要知道返回值的生命周期是与x保持一致，还是与y保持一致。

在这个例子中，我们会告诉编译器x和y的生命周期是一样的：

```rust
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() {
        x
    } else {
        y
    }
}

fn main() {
    let s1 = String::from("hello");
    let s2 = "world";

    let result = longest(s1.as_str(), s2);
    println!("The longest string is {}", result);
}
```

对生命周期的标注会让程序员痛不欲生——可以看到这么简单的一个函数签名中竟然需要多写4个`'a`！于是rust团队有规定了在一些情况下无需标注，编辑器可自行推断。

**计算生命周期的三个原则**

> 函数参数或方法参数中的生命周期被称为输入生命周期（input lifetime），而返回值的生命周期则被称为输出生命周期（output lifetime）。

在没有显式标注的情况下，编译器目前使用了3种规则来计算引用的生命周期:

1. 每一个引用参数都会拥有自己的生命周期参数。换句话说，单参数函数拥有一个生命周期参数：`fn foo<'a>(x: &'a i32)；`，双参数函数拥有两个不同的生命周期参数：`fn foo<'a, 'b>(x: &'a i32, y: &'b i32)；`以此类推。
2. 当只存在一个输入生命周期参数时，这个生命周期会被赋予给所有输出生命周期参数，例如`fn foo<'a>(x: &'a i32) -> &'a i32`。
3. 当拥有多个输入生命周期参数，而其中一个是`&self`或`&mut self`时，self的生命周期会被赋予给所有的输出生命周期参数。这条规则使方法更加易于阅读和编写，因为它省略了一些不必要的符号。

## 闭包中引入move

闭包需要变量所有权是因为它们可能在定义时捕获了变量，并在任意时间执行。因此，如果不将变量所有权转移到闭包内部，那么这些变量可能在后面的代码中被修改或删除，从而导致闭包中的代码无法正常运行。

例如，假设我们有一个线程池，该线程池使用闭包来执行一些任务。这些闭包可能需要访问线程池中的数据，例如计数器或其他状态变量。如果这些变量的所有权不被转移到闭包内部，那么在执行闭包时，这些变量可能已经被其他线程修改或删除，从而导致问题。

为了解决这个问题，Rust 引入了闭包变量所有权的概念，使得闭包可以在定义时捕获变量，并将它们的所有权转移到闭包内部。这样做的好处是，一旦变量的所有权移动到闭包内部，程序就可以保证这些变量在闭包执行期间是有效的，并且不会受到任何其他线程或代码的影响。

```rust
fn main() {
    let mut x = vec![1, 2, 3];

    let closure = move || {
        x.push(4);
        println!("{:?}", x);
    };

    closure();
    // 这里再次调用 closure 会出现编译错误，因为 x 的所有权已经被转移到闭包内部
    //closure();
}
```



## 最后

上面的例子只是简单的介绍了一些由使用所有权系统所带来的复杂性，实际使用中，这些“规则”会不断地重复、叠加，因此对新手来说，确实需要一些时间去适应这些规则。而正是由于存在这种陡峭的学习曲线，我们才更应该知道为什么会有这些规则，这也是我写这篇文章的目的！













