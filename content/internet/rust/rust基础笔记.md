---
title: "rust基础笔记"
date: 2022-06-04T14:35:00+08:00
url: "/note/rust/base"
isCJKLanguage: true
draft: false
toc: true
keywords:
  - rust
authors:
  - stong
tags: ["rust"]
---

## 数据类型

### 标量类型（scalar）

#### 整数类型

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202209040012877.png)

除了Byte，其余所有的字面量都可以使用类型后缀，比如57u8，代表一个使用了u8类型的整数57。同时你也可以使用\_作为分隔符以方便读数，比如1_000。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202209040102726.png)

#### 浮点类型

浮点类型有两种：f32和f64，它们分别占用32位和64位空间。

#### 布尔类型

布尔类型只有两种值：true和false。

注意：单个布尔类型的值占据单个字节的空间大小

#### 字符类型

在Rust中，char类型被用于描述语言中最基础的单个字符。下面的代码展示了它的使用方式，但需要注意的是，char类型使用单引号指定，而不同于字符串使用双引号指定。

### 复合类型（compound）

#### 元组

元组是一种相当常见的复合类型，它可以将其他不同类型的多个值组合进一个复合类型中。元组还拥有一个固定的长度：你无法在声明结束后增加或减少其中的元素数量.

两种获取元组内元素值的方式：

1. 通过索引并使用点号（.）来访问元组中的值

2. 模式匹配来解构元组

```rust
fn main() {
    let tup = (1, 1.0, '1');
    let (x, y, _) = tup;
    println!("The value of x is: {}", x);
    println!("The value of y is: {}", y);
    println!("The value of z is: {}", tup.2);
}
```

#### 数组Array `[T;N]`

与元组不同，数组中的每一个元素都必须是相同的类型。Rust中的数组拥有固定的长度，一旦声明就再也不能随意更改大小。

为了写出数组的类型，你需要使用一对方括号，并在方括号中填写数组内所有元素的类型、一个分号及数组内元素的数量，如下所示：
`let a: [i32; 5] = [1, 2, 3, 4, 5];`

“即假如你想要创建一个含有相同元素的数组，那么你可以在方括号中指定元素的值，并接着填入一个分号及数组的长度，如下所示：
`let a = [3; 5]；`
以a命名的数组将会拥有5个元素，而这些元素全部拥有相同的初始值3。这一写法等价于`let a = [3, 3, 3, 3, 3];`，但却更加精简。”

#### 向量Vector `Vec<T>`

Vector能够动态分配，分配在堆上。

```rust
let mut primes = vec![2, 3, 5, 7]; // vec! 等同于Vec::new()
assert_eq!(primes.iter().product::<i32>(), 210);

primes.push(11);
primes.push(13);
assert_eq!(primes.iter().product::<i32>(), 30030);
```

#### 切片Slice `&[T]`

`&[T]`是能够共享读而不允许修改的切片， `&mut [T]`是能够修改单不允许共享读的切片。

## 函数

Rust代码使用蛇形命名法（snake case）来作为规范函数和变量名称的风格。蛇形命名法只使用小写的字母进行命名，并以下画线分隔单词。

### 函数的返回值

函数可以向调用它的代码返回值。虽然你不用为这个返回值命名，但需要在箭头符号（->）的后面声明它的类型。在Rust中，函数的返回值等同于函数体最后一个表达式的值。你可以使用return关键字并指定一个值来提前从函数中返回，但大多数函数都隐式地返回了最后的表达式。

返回值只能有一个，需要返回多个可以使用元组，如果是数据+错误的返回，可以使用Option。

```rust
fn main() {
    let rst = one();
    println!("{}", rst);
}

fn one() ->i32 {
    1
}
```

## 注释

// 行注释

//！ 内部行文档注释

/// 外部行文档注释

`/*...*/`块注释

`/*!...*/`内部块文档注释

`/**...*/`部块文档注释

## 变量

在Rust中，变量都是默认不可变的。

可变变量需要声明mut，如`let mut a = 10;`

### shadow

Rust允许使用同名的新变量guess来隐藏（shadow）旧变量的值。这一特性通常被用在需要转换值类型的场景中.

> 在同一个作用域中，新的同名变量可以是不同的类型，避免了amount_str这种业务+类型的名称定义。

## 常量

在Rust程序中，我们约定俗成地使用以下画线分隔的全大写字母来命名一个常量，并在数值中插入下画线来提高可读性。

如`const MAX_POINTS: u32 = 100_000;`

## 字符串

### 字符串字面量

固定大小的字符串，一旦声明则不可改变。存储在栈中。

### 字符串类型

大小不固定、可变的字符串。存储在堆中。

字符串类型的底层由三个属性构成：

- 长度
- 容量
- 数据地址指针

同golang中的slice一模一样。

当字符串类型的值被赋值给另外一个字符串类型的值时，底层数据地址指针相同（同golang中的slice,即浅拷贝）,但由于rust的内存机制，同一个地址不能被两个变量使用，因此会报错。

```rust
fn main() {
    let s = String::from("hello");
    let s2 = s;
    println!("{}, {}", s, s2);
}
// 报错内容：
// error[E0382]: borrow of moved value: `s
```

此时需要深度拷贝数据——即移动（move）数据。

```rust
fn main() {
    let s = String::from("hello");
    let s2 = s.clone();
    println!("{}, {}", s, s2);
}

```

## 所有权

三个原则：

• Rust中的每一个值都有一个对应的变量作为它的所有者。

• 在同一时间内，值有且仅有一个所有者。

• 当所有者离开自己的作用域时，它持有的值就会被释放掉。

```rust
fn main() {
    let s = String::from("hello"); // 变量s进入作用域

    abc(s); // s被移动到abc中，在当前作用域中无效；同时s2进入作用域

    let x = 5; // 变量x进入作用域

    def(x); // x是i32类型，是Copy的，因此x仍旧有效；同时 x2进入作用域

} // x 先离开作用域，然后是x。因为s的值已经发生了移动，因此无事发生。

fn abc(s: String) { // s进入作用域
    println!("{}", s)
} // s离开作用域，自动调用drop函数进行销毁

fn def(x: i32) { // x进入作用域
    println!("{}", x)
} // x离开作用域，无事发生
```

### 引用与借用

所有权则规定了每个值有且只有一个所有者，决定了在哪里和何时释放内存。

引用是一种机制，让程序在不移动数据所有权的情况下访问和操作数据。

引用表现为指向变量的指针，可以把引用看成是一个指针地址。

借用则是创建了一个引用，并为这个引用赋予操作权限。

```rust
let mut a = String::from("hello"); // 对于变量a, 指针地址为&a，即引用为&a
let b = &mut a; // b借用了a的引用，权限是可编辑。&表示引用,mut表示权限为可编辑
```

```rust
let mut a = String::from("hello");
{ // b是一个引用，具备访问和修改a的值的权限。但a仍是数据所有权的所有者
	let b = &mut a;
} // b被释放
```

### 解引用

有引用就会有解引用，解引用之后就可以对原数据进行修改。

```rust
let mut x = 42;
let z = &mut x; // 创建一个可变引用z指向x
println!("x = {}", z); // 输出x当前的值：42
*z += 1; // 使用*z来修改x的值
println!("x = {}", z); // 输出x当前的值：43
```

引用特征：

- 在任何一段给定的时间里，你要么只能拥有一个**可变引用**，要么只能拥有任意数量的**不可变引用**。
- 引用总是有效的：在 Rust 中使用引用（指针）访问数据时，Rust 能够在编译时检查出数据是否有效，从而避免了悬空指针和空指针引用问题

#### 可变引用

即可以修改引用的值。

```rust
fn main() {
    let mut s = String::from("hello");

    abc(&mut s);
}

fn abc(s: &mut String) {
    s.push_str(" world");
    println!("{}", s)
}

```

#### 不可变引用

即不可以修改引用的值。

```rust
fn main() {
    let s = String::from("hello");

    abc(&s);
}

fn abc(s: &String) {
    println!("{}", s)
}
```

### 切片

> 切片允许我们引用集合中某一段连续的元素序列，而不是整个集合（类比golang中切片就是对底层数组中的某段连续元素序列的引用）。

```rust
fn main() {
    let s = String::from("hello");
    let s2 = &s[1..3];
    let s3 = &s[..3];
    let s4 = &s[1..];
    let s5 = &s[..];
    println!("{}", s2);
    println!("{}", s3);
    println!("{}", s4);
    println!("{}", s5);
}
// output
// el
// hel
// ello
// hello
```

**字符串字面量就是切片**

## 结构体

知识点：

1. **字段初始化简写**
2. **根据已有结构体覆盖未定义字段**
3. **一旦实例可变，那么实例中的所有字段都将是可变的。Rust不允许我们单独声明某一部分字段的可变性。**
4. **元组结构体**

```rust
#[derive(Debug)] // “添加注解来派生Debug trait，并使用调试格式打印出Rectangle实例”
struct User {
    name: String,
    email: String,
    age: u8,
    active: bool,
}

#[derive(Debug)]
struct Color(i8, i8, i8);

fn main() {
    let u = User {
        name: String::from("alice"),
        email: String::from("alice@outlook.com"),
        age: 1,
        active: true,
    };
    println!("{:?}", u);

    let u2 = build_user(String::from("bob@outlook.com"), String::from("bob"));
    println!("{:?}", u2);

    let u3 = build_user(String::from("chris@outlook.com"), String::from("chris"));
    println!("{:?}", u3);

    let u4 = User{
        name: String::from("david"),
        email: String::from("david@outlook.com"),
        ..u3 // 根据已有结构体覆盖未定义字段
    };
    println!("{:?}", u4);

    let white = Color(0, 0, 0);
    println!("{:?}", white);
}

fn build_user(email: String, name: String) -> User {
    User{
        name: name,
        email: email,
        age: 1,
        active: true,
    }
}

fn build_user2(email: String, name: String) -> User {
    User{
        name, // 字段初始化简写
        email,
        age: 1,
        active: true,
    }
}
```

### 方法

1. 第一个参数永远是self。
2. 隐式转换：当你使用object.something()调用方法时，Rust会自动为调用者object添加&、&mut或\*，以使其能够符合方法的签名。

```rust
#[derive(Debug)] // “添加注解来派生Debug trait，并使用调试格式打印出Rectangle实例”
struct User {
    name: String,
    email: String,
    age: u8,
    active: bool,
}

impl User {
    fn get_name(self) -> String {
        self.name
    }
}

fn main() {
    let u = User {
        name: String::from("alice"),
        email: String::from("alice@outlook.com"),
        age: 1,
        active: true,
    };
    let name = u.get_name();
    println!("{}", name);
}
```

### 关联函数

1. 不接收self的方法。
2. 常用来构造结构体。

```rust
#[derive(Debug)] // “添加注解来派生Debug trait，并使用调试格式打印出Rectangle实例”
struct User {
    name: String,
    email: String,
    age: u8,
    active: bool,
}

impl User {
    fn default_user(name: String) -> User {
        User{
            name,
            email: String::from(""),
            age: 0,
            active: false,
        }
    }

    fn get_name(self) -> String {
        self.name
    }
}

fn main() {
    let u = User::default_user(String::from("alice"));
    let name = u.get_name();
    println!("{}", name);
}
```

## 枚举

1. 将同一类数据定义为同一个枚举类型。注意：”同一类数据“可以是不同类型，可以关联不同类型的数据。
2. 可以通过impl来定义枚举的方法。

```rust
#[derive(Debug)] // “添加注解来派生Debug trait，并使用调试格式打印出Rectangle实例”
struct Emp {
    id: String,
    name: String,
}

enum User {
    Vistor(String), // 游客, 关联数据为ip字符串
    Employee(Emp), // 员工, 关联数据为Emp结构体
    Admin(i32), // 管理员，关联数据为id
}

impl User {
    fn say_hi(self) {
        println!("hi");
    }
}

fn main() {
    let user = User::Vistor(String::from("127.0.0.1"));
    user.say_hi();
}
```

### Option枚举

1. 内置于标准库
2. rust中没有空值，但是可以通过Option枚举来实现
3. 假如我们使用了None而不是Some变体来进行赋值，那么我们需要明确地告知Rust这个`Option<T>`的具体类型。这是因为单独的None变体值与持有数据的Some变体不一样，编译器无法根据这些信息来正确推导出值的完整类型

```rust
// 内置库中的样子
enum Option<T> {
    Some(T),
    None,
}
```

```rust
fn main() {
    let one = Some(1); // 内置Option，不用引用库，也不用这样Option::Some(1)
    let a = Some(b'a');
    let none: Option<i32> = None;
}
```

### Result枚举

1. 内置于标准库
2. 常用于结果返回——Ok代表正常，Err代表发生错误

```rust
use std::fs::File;

fn main() {
    let f = File::open("hello.txt");

    let f = match f {
        Ok(file) => file,
        Err(error) => {
            panic!("There was a problem opening the file: {:?}", error)
        },
    };
}
```

## 流程控制

### if-else

```rust
fn main() {
    let a = 1;
    if a == 0 {
        println!("0");
    } else if a == 1 {
        println!("1")
    } else {
        println!("2")
    }
}
```

if是一个表达式，所以我们可以在let语句的右侧使用它来生成一个值.

```rust
fn main() {
    let a = 1;
    let b = if a == 0 {
        10
    } else if a == 1 {
        11
    } else {
        12
    };
    println!("{}", b);
}
```

### loop

```rust
fn main() {
    let mut n = 0;
    loop {
        n += 1;
        if n == 10 {
            break;
        }
    }
    println!("{}", n)
}
```

loop同样是表达式，因此可以使用loop来生成一个值。

```rust
fn main() {
    let mut n = 0;
    let n2 = loop {
        n += 1;
        if n == 10 {
            break n*2;
        }
    };
    println!("{}, {}", n, n2);
}
```

### while

```
fn main() {
    let mut n = 10;
    while n != 3 {
        println!("{}", n);
        n -= 1;
    }
    println!("end");
}
```

### for

相比while，for提供了更便利、安全的迭代器。

```rust
fn main() {
    let arr = [1,2,3,4,5];
    for n in arr.iter() {
        println!("{}", n)
    }
}
```

将数组转为元组进行遍历。

```rust
fn main() {
    let arr = [1,2,3,4,5];
    for (n, &item) in arr.iter().enumerate() {
        println!("{}, {}", n, &item)
    }
}
```

翻转遍历：

```rust
fn main() {
    for n in (1..6).rev() {
        println!("{}", n)
    }
}
```

break:

```rust
'search:
for room in apartment {
    for spot in room.hiding_spots() {
        if spot.contains(keys) {
            println!("Your keys are {} in the {}.", spot, room);
            break 'search;
        }
    }
}
```

表达式中的break

```rust
let sqrt = 'outer: loop {
    let n = next_number();
    for i in 1.. {
        let square = i * i;
        if square == n {
            // Found a square root.
            break 'outer i;
        }
        if square > n {
            // `n` isn't a perfect square, try the next
            break;
        }
    }
};
```

### match

1. 必须穷举所有可能
2. 可以使用通配符\_来过滤未穷举的可能
3. if let提供了对单个条件筛选的能力

```rust
enum Grade {
    ZERO,
    DISAPPOINT,
    ORDINARY,
    EXCELLENT,
    PERFECT,
    NOT_POSSIBLE,
}

fn main() {
    let msg = grade_msg(Grade::ZERO);
    println!("{}", msg);

    let zero = Some(0);
    if let Some(100) = zero {
        println!("oh my god!");
    }else {
        println!("you are kidding");
    }
}

fn grade_msg(grade: Grade) -> String {
    match grade {
        Grade::PERFECT => String::from("perfect!"),
        Grade::EXCELLENT => String::from("good!"),
        Grade::ORDINARY => String::from("common on!"),
        Grade::DISAPPOINT => String::from("fighting!"),
        Grade::ZERO => {
            println!("what fuck!");
            String::from("what's wrong with you!")
        },
        _ => String::from("impossible"),
    }
}
```

## 动态数组

1. 数组中只能存储同一类型的元素
2. 当需要存储不同类型的元素时，可以将其定义为同一种枚举类型

```rust
fn main() {
    let arr1: Vec<i32> = Vec::new(); // []
    let mut arr2 = vec![1,2,3]; // [1, 2, 3]
    let arr3 = vec!([1,2,3]); // [[1, 2, 3]]
    println!("{:?}, {:?}, {:?}", arr1, arr2, arr3);

    // 添加
    arr2.push(4); // [1, 2, 3, 4]
    println!("{:?}", arr2);

    // 两种读取
    let two: &i32 = &arr2[1]; // 2，数组越界会panic
    println!("{}", two);
    match arr2.get(1) { // get方法返回Option<&T>类型，数组越界会返回None
        Some(two) => println!("second elem is {}", two),
        None => println!("not found"),
    }
    // 遍历
    for i in &mut arr2 {
        *i *= 2;
    }
    println!("{:?}", arr2); // [2, 4, 6, 8]
} // 离开作用域，销毁

```

## 字符串

1. Rust中的字符串使用了UTF-8编码
2. 编译器可以自动将&String类型的参数强制转换为&str类型
3. Rust不允许我们通过索引来获得String中的字符

```rust
fn main() {
    // 三种创建方式
    let s1 = String::new();
    let s2 = String::from("hello");
    let s3 = "hello".to_string();
    println!("{}, {}, {}", s1, s2, s3);

    // 更新: push_str() push() + fromat!
    let mut h = String::from("hello");
    h.push_str(" world"); // push 字符串
    println!("{}", h);  // hello world
    h.push('!'); // push 字符
    println!("{}", h);// hello world!

    let a1 = String::from("hi");
    let a2 = String::from("world");
    let a3 = a1 + &a2; // a1失效，a2仍有效
    println!("{}", a3);

    let a1 = String::from("hi");
    let a2 = String::from("world");
    let a3 = format!("{} {}", a1, a2); // a1 a2仍有效
    println!("{}", a3);

    // 索引获取,要注意正确的字节计算
    let c1 = String::from("你好！");
    // let c2 = &c1[0..4]; // panicked at 'byte index 4 is not a char boundary; it is inside '好' (bytes 3..6) of `你好！`'
    let c2 = &c1[0..3]; // 你
    println!("{}", c2);

    // 遍历
    for c in c1.chars() { // 能正常遍历 你好！
        println!("{}", c);
    }
    for c in c1.bytes() { // 按照字节遍历，每个汉字三个字节
        println!("{}", c);
    }

}
```

### raw string

使用`r###`能够获得原始的字符串，类似于go中的飘号。

```rust
println!(r###"
    This raw string started with 'r###"'.
    Therefore it does not end until we reach a quote mark ('"')
    followed immediately by three pound signs ('###'):
"###);
```

### byte string

```rust
let method = b"GET"; // method's type is &[u8; 3]
```

### strings in memory

```rust
let noodles = "noodles".to_string(); // &str => String
let oodles = &noodles[1..];
let poodles = "ಠ_ಠ";
```

- noodles是String类型，数据存储在堆中，在栈中存储地址与长度、容量。
- oodles是&str类型，引用了noodles的后7个字符。
- poodles也是&str类型。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202311131709513.png)

[_图片来自《Programming Rust》_]()

## 哈希表

1. 所有的键必须拥有相同的类型，所有的值也必须拥有相同的类型。
1. 对于具有控制权的file_name和field_value，在调用insert方法后，field_name和field_value变量被移动到哈希映射中，我们再也没有办法使用这两个变量了.

```rust
use std::collections::HashMap;

fn main() {
    // 初始化空哈希表——insert
    let mut scores = HashMap::new() ;
    scores.insert(String::from("Blue"), 10);
    scores.insert(String::from("Yellow"), 50);
    println!("{:?}", scores);

    // 通过zip来构建元组的数组，通过collect来将数组转为哈希
    let team = vec![String::from("blue"), String::from("yellow")];
    let init_score = vec![1, 5];
    let mut score: HashMap<_,_> = team.iter().zip(init_score.iter()).collect();
    println!("{:?}", score);

    // 读取
    let blue = score.get(&String::from("blue")); // 返回值为Option类型 ： Some(1)
    println!("{:?}", blue);

    // 遍历
    for (k, v) in &score {
        println!("{}, {}", k, v);
    }

    // 不存在时再插入
    let k_b = String::from("blue");
    let k_r = String::from("red");
    score.entry(&k_b).or_insert(&2);
    score.entry(&k_r).or_insert(&3);
    println!("{:?}", score);

    // 基于旧值更新
    let words = "h e l l o";
    let mut word_map = HashMap::new();
    for word in words.split_whitespace() {
        let count = word_map.entry(word).or_insert(0);
        *count+=1;
    }
    println!("{:?}", word_map);
}
```

## 泛型

1. Rust实现泛型的方式决定了使用泛型的代码与使用具体类型的代码相比不会有任何速度上的差异。
   为了实现这一点，Rust会在编译时执行泛型代码的**单态化**（monomorphization）。单态化
   是一个在编译期将泛型代码转换为特定代码的过程，它会将所有使用过的具体类型填入泛型参数从而得到有具体类型的代码。
   在这个过程中，编译器所做的工作建泛型函数时相反：它会寻找所有泛型代码被调用过的地方，并基于该泛型代码所使用的具体类型生成代码。

```rust
#[derive(Debug)]
struct Point<T, U> {
    x: T,
    y: U,
}

impl<T,U> Point<T, U> {
    fn mix_up<V, W>(self, other: Point<V, W>) -> Point<T, W> {
        Point{
            x: self.x,
            y: other.y,
        }
    }
}

fn main() {
    let p1 = Point{
        x: 1,
        y: 2.0,
    };
    let p2 = Point{
        x: "hello",
        y: "world",
    };
    let p3 = p1.mix_up(p2); // Point { x: 1, y: "world" }
    println!("{:?}", p3);
}

```

## 关联类型（associate trait）

关联类型是在 trait 中定义的类型占位符。一个 trait 可以定义一个或多个关联类型，这些关联类型在 trait 中使用，但没有定义具体的类型。具体类型的定义由实现 trait 的类型来提供。例如：

```rust
pub trait Iterator {
    type Item;
    fn next(&mut self) -> Option<Self::Item>;
}

struct Counter {
    count: i32,
}

impl Iterator for Counter {
    type Item = i32;
    fn next(&mut self) -> Option<Self::Item> {
        self.count+=1;
        Some(self.count)
    }
}

fn main() {
    let mut count = Counter{count:0};
    println!("{:?}", count.next());
    println!("{:?}", count.next());
}
```

关联类型通常用于定义某个 trait 中依赖的类型，让实现者来提供其具体类型。具体类型的定义可以根据参数或其他条件变化，从而实现更灵活、更通用的代码。

使用泛型实现的版本：

```rust
pub trait Iterator<T> {
    fn next(&mut self) -> Option<T>;
}

struct Counter {
    count: i32,
}

impl Iterator<i32> for Counter {
    fn next(&mut self) -> Option<i32> {
        self.count += 1;
        Some(self.count) // 返回计数器的值
    }
}

fn main() {
    let mut counter = Counter { count: 0 };
    println!("{:?}", counter.next()); // Some(1)
    println!("{:?}", counter.next()); // Some(2)
}
```

使用关联类型有何优势？

> 使用关联类型可以使迭代器更加灵活和可扩展。
>
> 首先，关联类型允许将迭代器的项类型动态确定，也就是说，在实现 `Iterator` trait 时，可以指定 `Item` 类型是什么，不需要将其硬编码为具体的类型。这样可以使迭代器更加通用，同时也使代码更加清晰。
>
> 例如，如果一个实现 `Iterator` trait的类型可能返回多种类型的元素，使用关联类型可以让实现该 trait 的代码更加清晰易懂。
>
> 其次，使用关联类型可以允许在实现 `Iterator` trait 的类型中使用 trait bounds 进行更严格的类型检查，以避免类型错误和运行时错误。这种方法可以使代码更加可靠，并且可以让 Rust 编译器在编译期间发现潜在的错误。
>
> 总的来说，使用关联类型可以使迭代器更加灵活和通用，并且可以在编译期间发现类型错误，从而提高代码的可靠性。

## trait

trait（特征）被用来向Rust编译器描述某些特定类型拥有的且能够被其他类型共享的功能，它使我们可以以一种抽象的方式来定义共享行为。我们还可以使用trait约束来将泛型参数指定为实现了某些特定行为的类型。

```rust
use std::fmt::Debug;

// 定义trait
pub trait User {
    fn ID(self) -> String;
}

// 提供trait默认行为
pub trait User {
    fn ID(self) -> String {
      String::from("default id")
  	}
}

// 实现User
pub struct Emp {
    id: String,
}

impl User for Emp {
    fn ID(self) -> String {
        self.id
    }
}

// trait作为参数
fn print_user(user: impl User) {
    println!("{:?}", user.ID());
}
// 等价于
fn print_user2<T: User>(user: T) {
    println!("{:?}", user.ID());
}

// 通过+来指定多个trait
pub trait Teacher{
    fn Grade(self) -> i32;
}

fn print_teacher(teacher: impl User+Teacher+ Debug) {
    println!("{:?}", teacher);
}

// 使用where语句优化trait约束
fn print_teacher2<T:User+Debug, U: User+Teacher+ Debug>(teacher: T , user: U) {
    println!("{:?}", teacher);
    println!("{:?}", user);
}
// 优化后：
fn print_teacher3<T, U>(teacher:T, user:U)
    where T: User+Debug,
          U: User+Teacher+ Debug
{
    println!("{:?}", teacher);
    println!("{:?}", user);
}

// 返回值中使用trait
fn return_user() -> impl User {
    Emp{
        id: String::from("default_user"),
    }
}

fn main() {
    let bob = Emp{
        id: String::from("bob"),
    };
    print_user(bob);

}
```

### Debug trait

DEBUG trait 定义了一种用于在调试时输出调试信息的方式。使用DEBUG trait，可以让我们以一种更加简单、可读性更高的方式打印出调试信息，从而帮助定位问题。

DEBUG trait 定义了一个名为 `fmt` 的方法，该方法将一个格式化器对象与当前对象进行交互，以生成用于调试输出的字符串。具体来说，DEBUG trait 适用于任何可以通过某种方式转换为字符串的类型，例如数字、字符串、集合和自定义类型。DEBUG trait 的实现需要返回一个字符串，该字符串包含该类型的当前状态和信息。

在 Rust 中，程序员可以使用 `println!` 宏或者 `format!` 宏来输出调试信息。这些宏本质上就是使用了 DEBUG trait 来将相关变量打印为字符串进行输出的。这些宏支持多种调试格式，例如 `%?` 表示使用 DEBUG trait 输出，`{:?}` 表示使用调试格式输出。

```rust
#[derive(Debug)]
struct Person {
    name: String,
    age: i32,
}

fn main() {
    let p = Person {
        name: "Alice".to_string(),
        age: 30,
    };

    println!("{:?}", p); // 使用 Debug 格式化输出

    // 或者可以使用 format! 宏输出
    let s = format!("{:?}", p);
    println!("{}", s);

   // 输出
   //Person { name: "Alice", age: 30 }
   //Person { name: "Alice", age: 30 }
}
```

### Copy trait

Copy trait定义了一种类型可以直接复制的方式。具体来说，如果一个类型实现了 Copy trait，那么它的值可以直接进行复制，而不会发生所有权转移的情况。这意味着，不需要使用 `clone()` 方法对值进行复制，而是可以使用赋值语句来进行复制操作。

需要注意的是，实现 Copy trait 的类型必须是满足以下条件的类型：

- 它的大小是固定的（即在编译时已知）。

- 它的所有的成员也都满足 Copy trait。

因为 Copy trait 只是进行了一次 bit-by-bit 的复制，所以只有内置类型和某些可以直接进行内存复制的自定义类型才能实现 Copy trait。

```rust
#[derive(Copy, Clone)]
struct Point {
    x: i32,
    y: i32,
}

fn main() {
    let p1 = Point { x: 0, y: 0 };
    let p2 = p1; // 进行一次复制操作 不需要使用 `clone()` 方法，因为 `Point` 类型已经实现了 Copy trait

    println!("p1: ({}, {})", p1.x, p1.y);
    println!("p2: ({}, {})", p2.x, p2.y);
}
```

**实现了copy trait的内置类型：**

• 所有的整数类型，诸如u32。
• 仅拥有两种值（true和false）的布尔类型：bool。
• 字符类型：char。
• 所有的浮点类型，诸如f64。
• 如果元组包含的所有字段的类型都是Copy的，那么这个元组也是Copy的。例如，(i32, i32)是Copy的，但(i32, String)则不是。”

### Clone trait

Clone trait是一个标记trait，它允许程序员手动实现类型的克隆语义。任何类型都可以实现Clone trait，但是需要手动调用clone方法才能发挥作用。Clone trait没有任何前提条件，任何类型都可以实现（unsized类型除外）。

举个例子，假设有一个结构体Person，它有两个字段name和age，我们可以通过实现Clone trait来克隆一个Person类型的实例，如下所示

```rust
#[derive(Clone)]
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

这里我们通过实现Clone trait来克隆一个Person类型的实例，这样我们就可以得到一个新的Person类型的实例，而不是对原始实例的引用。这个新的实例和原始实例是完全独立的，它们的内存地址不同，但是它们的值是相同的。

### Display trait

`Display trait` 用于将类型转换为字符串并进行打印。它通常与格式化宏 `println!()` 或者 `format!()` 一起使用，用于将自定义类型转换为可打印的字符串。

实现 `Display` trait 需要使用 `fmt::Display` 模块，该模块提供了 `fmt` 宏，可以将值转换为字符串并输出。

以下是实现 `Display` trait 的示例代码：

```rust
use std::fmt;

struct Student {
    name: String,

    age: u8,
}

impl fmt::Display for Student {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Name: {}, Age: {}", self.name, self.age)
    }
}

fn main() {
    let student = Student {
        name: String::from("Alice"),
        age: 20,
    };

    println!("{}", student); // Name: Alice, Age: 20
}
```

在上面的代码中，我们定义了一个结构体 `Student`，其中包含学生的姓名和年龄。接着，我们为其实现了 `Display` trait，将学生的姓名和年龄格式化为字符串并输出。在该示例中，我们使用了 `write!()` 宏，该宏用于将数据写入缓冲区，通常与 `fmt::Result` 结合使用。最后，我们使用 `println!()` 宏输出学生信息。

### **Fn trait**

`Fn` 是最通用的 trait，适用于不可变引用调用的函数。这意味着它只适用于不修改它们的函数或闭包，以及使用 `&T` 语法或 `.borrow()` 方法在引用类型上调用它们。

```rust
fn foo(x: i32) -> i32 {
    x * 2
}

fn call_fn<F: Fn(i32) -> i32>(f: F) -> i32 {
    f(10)
}

fn main() {
    let result = call_fn(foo);
    assert_eq!(result, 20);
    let closure = |x| x * 3;
    let result = call_fn(closure);

    assert_eq!(result, 30);
}
```

在这个例子中，`call_fn` 函数参数中的 `Fn` trait 约束限制了传递的函数参数必须实现该 trait。

### **FnMut trait**

`FnMut` 与 `Fn` 类似，但是它只适用于可变引用调用的函数。这意味着它适用于通过 `&mut T` 语法或 `.borrow_mut()` 方法在引用类型上调用的函数或闭包。

```rust
fn bar(x: &mut i32) {
    *x *= 3;
}

fn call_fn_mut<F: FnMut(&mut i32)>(mut f: F) -> i32 {
    let mut x = 5;
    f(&mut x);
    x
}

fn main() {
    let result = call_fn_mut(|x| *x *= 2);
    assert_eq!(result, 10);
    let result = call_fn_mut(|z| bar(z));
    assert_eq!(result, 6);
}
```

在这个例子中，`call_fn_mut` 函数参数中的 `FnMut` trait 约束限制了传递的函数参数必须实现该 trait。

### **FnOnce trait**

`FnOnce` 是最具体的 trait，只适用于通过所有权调用的函数。这意味着它只适用于可移动值，即那些可以在调用过程中被移动的值，例如，在闭包中使用 `move` 关键字实现的闭包。

```rust
fn call_fn_once<F: FnOnce(i32) -> R, R>(f: F, x: i32) -> R {
    f(x)
}

fn main() {
    let result = call_fn_once(|x| x * 4, 3);
    assert_eq!(result, 12);

    let closure = |_: i32| "hello".to_string();
    let result = call_fn_once(closure, 0);
    assert_eq!(result, "hello".to_string());
}

// example2:
fn main() {
    let s = String::from("hello");
    let closure = |_: i32| {
        let s = s; // 函数体内移动s
        println!("{}", s);
    };
    closure(0);
    // println!("{}", s); // 会报错，因为s的所有权已经被转移
  	// closure(1); // 会报错，因为s的所有权已经被转移
}

// example3:
fn main() {
    let s = String::from("hello");
    let closure = move |_: i32| { // 使用move声明s被move
        println!("{}", s);
    };
    closure(0);
    println!("{}", s); //会报错，因为s被移动了
}
```

- `Fn` trait 适用于不可变引用调用的函数。

- `FnMut` trait 适用于可变引用调用的函数。

- `FnOnce` trait 适用于通过所有权调用的函数。

### Extension trait

为其他人的类型实现trait，比如为char类型实现：

```go
trait IsEmoji {
    fn is_emoji(&self) -> bool;
}

/// Implement IsEmoji for the built-in character type.
impl IsEmoji for char {
    fn is_emoji(&self) -> bool {
        ...
    }
}

assert_eq!('$'.is_emoji(), false);
```

或者为Write trait实现：

```rust
use std::io::{self, Write};

/// Trait for values to which you can send HTML.
trait WriteHtml {
    fn write_html(&mut self, html: &HtmlDocument) -> io::Result<()>;
}

/// You can write HTML to any std::io writer.
impl<W: Write> WriteHtml for W {
    fn write_html(&mut self, html: &HtmlDocument) -> io::Result<()> {
        ...
    }
}
```

### Self

可以用Self来表示当前类型：

```rust
pub trait Spliceable {
    fn splice(&self, other: &Self) -> Self;
}
```

注意：Self类型不能用于trait objects.

> trait object: 对于trait类型的引用称为trait object，如writer:
>
> ```rust
> let mut buf: Vec<u8> = vec![];
> let writer: &mut dyn Write = &mut buf;
> ```

### Sub trait

```rust
trait Creature: Visible {
    fn position(&self) -> (i32, i32);
    fn facing(&self) -> Direction;
    ...
}
```

所有实现了Creature的类型都实现了Visible。

## 引用中的生命周期

当引用的生命周期可能以不同的方式相互关联时，我们就必须手动标注生命周期。Rust需要我们注明泛型生命周期参数之间的关系，来确保运行时实际使用的引用一定是有效的。

生命周期的标注使用了一种明显不同的语法：**它们的参数名称必须以撇号（'）开头，且通常使用全小写字符**。与泛型一样，它们的名称通常也会非常简短。'a(读作tick a)被大部分开发者选择作为默认使用的名称。我们会将生命周期参数的标注填写在&引用运算符之后，并通过一个空格符来将标注与引用类型区分开来。

```rust
fn main() {
    let s = longest("hi", "hello");
    println!("{}", s);
}

fn longest<'a> (x: &'a str, y: &'a str) -> &'a str { // 泛型生命周期'a会被具体化为x与y两者中生命周期较短的那一个
    if x.len() > y.len() {
        x
    }else {
        y
    }
}

```

> 当我们在函数签名中指定生命周期参数时，我们并没有改变任何传入值或返回值的生命周期。我们只是向借用检查器指出了一些可以用于检查非法调用的约束。

### 计算生命周期的三个原则

> 函数参数或方法参数中的生命周期被称为输入生命周期（input lifetime），而返回值的生命周期则被称为输出生命周期（output lifetime）。

在没有显式标注的情况下，编译器目前使用了3种规则来计算引用的生命周期:

1. 每一个引用参数都会拥有自己的生命周期参数。换句话说，单参数函数拥有一个生命周期参数：fn foo<'a>(x: &'a i32)；双参数函数拥有两个不同的生命周期参数：fn foo<'a, 'b>(x: &'a i32, y: &'b i32)；以此类推。
2. 当只存在一个输入生命周期参数时，这个生命周期会被赋予给所有输出生命周期参数，例如fn foo<'a>(x: &'a i32) -> &'a i32。
3. 当拥有多个输入生命周期参数，而其中一个是&self或&mut self时，self的生命周期会被赋予给所有的输出生命周期参数。这条规则使方法更加易于阅读和编写，因为它省略了一些不必要的符号。

当不满足以上三个原则时，编译器无法确认生命周期，于是会报错。

### 静态生命周期

Rust中还存在一种特殊的生命周期'static，它表示整个程序的执行期。所有的字符串字面量都拥有'static生命周期。

```rust
let s: &'static str = "I have a static lifetime.";
```

## 迭代器

1. 所有的迭代器都实现了定义于标准库中的`Iterator trait`

2. Iterator trait只要求实现者手动定义一个方法：`next`方法，它会在每次被调用时返回一个包裹在`Some`中的迭代器元素，并在迭代结束时返回`None`。

3. iter方法生成的是一个不可变引用的迭代器，我们通过`next`取得的值实际上是指向动态数组中各个元素的**不可变引用**。如果你需要创建一个**取得v1所有权并返回元素本身的迭代器**，那么你可以使用`into_iter`方法。类似地，如果你需要**可变引用的迭代器**，那么你可以使用`iter_mut`方法。
4. 迭代器适配器是**惰性**的，除非我们消耗迭代器，否则什么事情都不会发生。

5. 尽管迭代器是一种高层次的抽象，但它在编译后生成了与手写底层代码几乎一样的产物。迭代器是Rust语言中的一种**零开销抽象**（zero-cost abstraction），这个词意味着我们在使用这些抽象时不会引入额外的运行时开销

```rust
fn main() {
    let v1 = vec![1,2,3];
    let mut v1_iter = v1.iter();
    let n1 = v1_iter.next();
    println!("{:#?}", n1);
}
//Some(
//    1,
//)
```

```rust
fn main() {
    let v1: Vec<i32> = vec![1,2,3];
    let v2: Vec<_> = v1.iter().map(|x| x+1).collect();
    println!("{:#?}", v2);
    let shoes: Vec<_> = shoes_in_my_size(vec![Shoe{size: 10},Shoe{size: 30}], 10);
    println!("{:#?}", shoes);
}

#[derive (PartialEq, Debug) ]
struct Shoe {
    size: u32,
}

fn shoes_in_my_size (shoes: Vec<Shoe>, shoe_size: u32) ->Vec<Shoe> {
    shoes.into_iter().filter(|s| s.size==shoe_size).collect ()
}

// [
//     2,
//     3,
//     4,
// ]
// [
//     Shoe {
//         size: 10,
//     },
// ]
```

## 错误处理

1. 失败时触发panic的快捷方式：

   1. unwrap：`let f = File::open("a.txt").unwrap();`，当open()出错时，直接panic，当没有错误时，将open()返回的Result<T,E>中的正常返回值解析出来赋值给f。
   2. expect：区别于unwrap，expect能够指定报错信息。`let f = File::open("a.txt").expect("open Failed");`

2. 错误传播：使用`?`运算符来将错误返回给调用者(`?`运算符只能被用于返回Result的函数)

   ```rust
   use std::io;
   use std::io::Read;
   use std::fs::File;

   fn read_username_from_file() -> Result<String, io::Error> {
       let f = File::open("hello. txt");
       let mut f = match f {
           Ok(file) => file,
           Err(e) => return Err(e),
       };
       let mut s = String::new();
       match f.read_to_string(&mut s) {
           Ok(_) => Ok(s),
           Err(e) => return Err(e),
       }
   }
   ```

   使用`?`运算符。

   ```rust
   use std::io;
   use std::io::Read;
   use std::fs::File;

   fn read_username_from_file() -> Result<String, io::Error> {
       let mut f = File::open("hello. txt")?;
       let mut s = String::new();
       f.read_to_string(&mut s)?;
       Ok (s)
   }
   ```

   使用**链式调用**进一步优化

   ```rust
   use std::io;
   use std::io::Read;
   use std::fs::File;

   fn read_username_from_file() -> Result<String, io::Error> {
       let mut s = String::new();
       File::open("hello. txt")?.read_to_string(&mut s)?;
       Ok(s)
   }
   ```

## 模块

rust 使用 `mod` 关键词用来定义模块和引入模块。

`mod` 和 `use` 进行区分：**`use` 仅仅是在存在模块的前提下，调整调用路径，而没有引入模块的功能，引入模块使用 `mod`**。

mod调用”本地“函数，需要使用`super`：

```rust
fn hi() {
    print!("hi")
}

mod world {
    pub fn en() {
        super::hi();
        print!("world");
    }
}
```

mod之间的调用：

```rust
mod world {
    pub fn en() {
        print!("world");
    }
}

mod hi {
    pub fn en() {
        print!("hello");
        crate::world::en(); // 绝对路径
        super::world::en(); // 相对路径
    }
}
// 或者使用use导入
mod hi {
  use crate::world as world2;
  pub fn en() {
    print!("hello");
    world2::en();
  }
}
```

### 重新导入-pub use

```rust
mod hello {
    pub mod hello_mod {
        pub fn hi() {
            println!("Hello from hello_mod!");
        }
    }
}

mod say {
    pub use super::hello::hello_mod;
}

fn main() {
    say::hello_mod::hi();
}
```

通过 pub use 能够将被use的模块hello_mod重新导入到say，此时hello_mod就是say的一个子模块。

如果不使用pub，那么只能在say中使用hello_mod，使用pub后，可以在导入了say模块的地方使用hello_mod.

### **文件模块**

以下代码可以用文件隔离：

原代码：

```rust
// main.rs
mod hello {
    pub mod hello_mod {
        pub fn hi() {
            println!("Hello from hello_mod!");
        }
    }
}
```

隔离后的代码

```rust
// main.rs
mod hello;
// hello.rs
pub mod hello_mod {
    pub fn hi() {
        println!("Hello from hello_mod!");
    }
}
```

即文件就是模块。

### **目录模块**

```shell
├── ho
│   ├── hello.rs
│   └── mod.rs
└── main.rs
```

将hello_mod移动到ho目录下：

```rust
// hello.rs
pub mod hello_mod {
    pub fn hi() {
        println!("Hello from hello_mod!");
    }
}
```

对于目录来说，如果要作为模块，需要创建`mod.rs`，并标记要导出的模块（也就是文件）：

```rust
pub mod hello;
```

此时可以引入该模块需要：

```rust
mod ho; // 引入目录模块

fn main() {
    ho::hello::hello_mod::hi(); // 分别是目录模块::文件模块::文件内第一层模块::函数
}
```

## 闭包

闭包vs函数：

```rust
// 闭包实现
let say_hi = |lan| {
  match lan {
    "en" => String::from("hi"),
    _ => String::from("你好"),
  }
};
// 函数实现
fn say_hi(lan: &str) -> String {
    match lan {
        "en" => String::from("hi"),
        _ => String::from("你好"),
    }
}
// 闭包实现
let x = 4;
let equal = |z| z==x;
equal(5);
// 函数实现
fn equal(x: i32, z: i32) -> bool{
  x == z
}
```

主要的区别在于

1. **闭包中的参数和返回值不需要声明类型**，这是因为使用闭包的场景通常比较简单，编译器很容易推断出参数和返回值的类型。
2. **闭包可以引用当前环境上下文中的变量**，而函数只能通过参数引入。

标准库中提供了一系列Fn trait，而**所有的闭包都至少实现了Fn、FnMut及FnOnce中的一个trait**。这些 trait 作为约束来确保我们的函数接收一个符合要求的函数类型。

**返回闭包**

rust中需要确定类型大小，因此需要用Box来包裹函数。

```rust
fn returns_closure() -> Box<dyn Fn(i32) -> i32> {
    Box::new(|x| x + 1)
}
```

## 智能指针

智能指针是一些数据结构，其行为类似于指针但拥有额外的元数据和附加功能。

这些用来实现智能指针的结构体会实现Deref和Drop这两个trait.“Deref trait使得智能指针结构体的实例拥有与引用一致的行为，它使你可以编写出能够同时用于引用和智能指针的代码。Drop trait则使你可以自定义智能指针离开作用域时运行的代码。”

### `Box<T>`

box可以让我们将数据存储在堆上，并在栈上保留指向堆数据的指针。

常用场景：

1. 当你拥有一个无法在编译时确定大小的类型，但又想要在一个要求固定尺寸的上下文环境中使用这个类型的值时。

   ```rust
   // 这段代码编译报错：`recursive type List has infinite size`。通过box可以设置List的大小。
   enum List {
       Cons(i32, List),
       Nil,
   }
   // 正常编译的代码
   enum List {
       Cons(i32, Box<List>),
       Nil,
   }
   ```

2. 当你需要传递大量数据的所有权，但又不希望产生大量数据的复制行为时。

   转移大量数据的所有权可能会花费较多的时间，因为这些数据需要在栈上进行逐一复制。为了提高性能，你可以借助装箱将这些数据存储到堆上。通过这种方式，我们只需要在转移所有权时复制指针本身即可，而不必复制它指向的全部堆数据

3. 当你希望拥有一个实现了指定trait的类型值，但又不关心具体的类型时。

### `Rc<T>`

基于引用计数（reference counting）的智能指针类型会通过记录所有者的数量来使**一份数据被多个所有者同时持有，并在没有任何所有者时自动清理数据**。

只能用于单线程。

```rust
struct Person {
    name: String,
    age: u8,
}

fn main() {
    let person = Person {
        name: "Alice".to_string(),
        age: 25,
    };

    let shared_person = Rc::new(person); // 创建一个 Rc 智能指针，共享 Person

    let alice = shared_person.clone(); // 增加引用计数, 执行深度拷贝
    println!("Alice reference count: {:?}", Rc::strong_count(&alice)); // 输出 2
    let bob = Rc::clone(&shared_person); // 增加引用计数, 执行浅度拷贝
    println!("Bob reference count: {:?}", Rc::strong_count(&bob)); // 输出 3

    // 读取共享的 Person
    println!("Alice: {} is {} years old", alice.name, alice.age);
    println!("Bob: {} is {} years old", bob.name, bob.age);

    drop(bob); // 减少 Bob 的引用计数，释放智能指针

    println!("Alice reference count: {:?}", Rc::strong_count(&alice)); // 输出 2
}
```

### `RefCell<T>`

对于使用一般引用和Box<T>的代码，Rust会在编译阶段强制代码遵守这些借用规则。而对于使用RefCell<T>的代码，Rust则只会在运行时检查这些规则，并在出现违反借用规则的情况下触发panic来提前中止程序。

RefCell<T>会记录当前存在多少个活跃的Ref<T>和RefMut<T>智能指针。每次调用borrow方法时，RefCell<T>会将活跃的不可变借用计数加1，并且在任何一个Ref<T>的值离开作用域被释放时，不可变借用计数将减1。RefCell<T>会基于这一技术来维护和编译器同样的借用检查规则：在任何一个给定的时间里，它只允许你拥有多个不可变借用或一个可变借用。

```rust
struct Person {
    name: String,
    age: RefCell<u8>,
}

fn main() {
    let person = Person {
        name: "Alice".to_string(),
        age: RefCell::new(25),
    };

    {
        let mut age = person.age.borrow_mut(); // 获取可变引用，并在代码块结束时自动释放
        *age += 1; // 修改年龄
    }

    let age = person.age.borrow(); // 获取不可变引用
    println!("{} is now {} years old", person.name, *age);
}
```

### `Weak<T>`

通过`Weak<T>`来避免Rc中互相引用而导致的内存泄漏。

```rust
use std::rc::{Rc, Weak};
use std::cell::RefCell;

struct Person {
    name: String,
    partner: RefCell<Option<Weak<Person>>>,
}

impl Person {
    fn new(name: &str) -> Rc<Self> {
        let person = Rc::new(Self {
            name: name.to_string(),
            partner: RefCell::new(None),
        });

        // 将自己存储到伴侣的引用中
        let weak_person = Rc::downgrade(&person); // 将person降级为Weak<Person>
        *person.partner.borrow_mut() = Some(weak_person);

        person
    }

    fn get_partner(&self) -> Option<Rc<Self>> {
        self.partner.borrow().as_ref().and_then(|weak| weak.upgrade()) // 将partner升级为Rc<Person>并返回
    }
}

fn main() {
    let alice = Person::new("Alice");
    let bob = Person::new("Bob");

    // 设置伴侣
    alice.get_partner().unwrap().partner.borrow_mut().replace(Rc::downgrade(&bob));
    bob.get_partner().unwrap().partner.borrow_mut().replace(Rc::downgrade(&alice));

    // 输出伴侣名字
    println!("{}'s partner is {}", alice.name, alice.get_partner().unwrap().name);
    println!("{}'s partner is {}", bob.name, bob.get_partner().unwrap().name);

    // Alice 被回收
    drop(alice);

    // Bob 的伴侣为空
    assert!(bob.get_partner().is_none());
}

```

### 结合Rc和RefCell实现可变链表

```rust
#[derive(Debug)]
enum List {
    Cons(Rc<RefCell<i32>>, Rc<List>),
    Nil,
}

use crate::List::{Cons, Nil};

fn main() {
    let value = Rc::new(RefCell::new(5));

    let a = Rc::new(Cons(Rc::clone(&value), Rc::new(Nil)));

    let b = Cons(Rc::new(RefCell::new(6)), Rc::clone(&a));
    let c = Cons(Rc::new(RefCell::new(10)), Rc::clone(&a));

    *value.borrow_mut() += 10;

    println!("a after = {:?}", a); // a after = Cons(RefCell { value: 15 }, Nil)
    println!("b after = {:?}", b); // b after = Cons(RefCell { value: 6 }, Cons(RefCell { value: 15 }, Nil))
    println!("c after = {:?}", c); // c after = Cons(RefCell { value: 10 }, Cons(RefCell { value: 15 }, Nil))
}
```

通过使用RefCell<T>，我们拥有的List保持了表面上的不可变状态，并能够在必要时借由RefCell<T>提供的方法来修改其内部存储的数据。

## 并发

### 线程

```rust
use std::{sync::mpsc, thread, time::Duration};

fn example() {
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || { // 通过thread::spawn创建线程 通过move实现所有权转移
        let vals = vec![
            String::from("hi"),
            String::from("你好"),
            String::from("hello"),
        ];
        for val in vals {
            tx.send(val).unwrap();
            thread::sleep(Duration::from_secs(1));
        }
    });
    for received in rx { // 接收数据
        println!("Got： {}", received);
    }
}
```

### 锁+原子

```rust
use std::sync::{Mutex, Arc};
use std::thread;

fn main() {
    let counter = Arc::new(Mutex::new(0)); // 原子数据
    let mut handles = vec![];

    for _ in 0..10 {
        let counter = Arc::clone(&counter);
        let handle = thread::spawn(move || {
            let mut num = counter.lock().unwrap();

            *num += 1;
        });
        handles.push(handle);
    }

    for handle in handles {
        handle.join().unwrap();
    }

    println!("Result: {}", *counter.lock().unwrap());
}
```

## 模式

### 范围模式

左闭右开：`..`

左闭右闭：`..=`

```rust
let arr: Vec<i32> = vec![1,2,3,4,5];
println!("{:?}", &arr[1..2]); // [2]
println!("{:?}", &arr[1..=2]); // [2, 3]
```

对于`@绑定`只能使用`..=`?

```rust
fn main() {
    let msg = Message::Hello { id: 5 };

    match msg {
        Message::Hello {
            id: id_variable @ 3..=7,
        } => {
            println!("Found an id in range: {}", id_variable)
        }
        Message::Hello { id: 10..=12 } => {
            println!("Found an id in another range")
        }
        Message::Hello { id } => {
            println!("Found some other id: {}", id)
        }
    }
}

enum Message {
    Hello { id: i32 },
}

```

### match中的模式

多重模式——使用|来表示or：

```rust
let x = 1;
match x {
    1 | 2 => println!("one or two"),
    3 => println!("three"),
    _ => println!("anything"),
}
```

解构赋值：

```rust
struct Point {
    x: i32,
    y: i32,
}

fn main() {
    let p = Point{x:1, y:2};

  	match p {
        Point { x, y: 0 } => println!("on the x axis at {}", x),
        Point { x: 0, y } => println!("on the y axis at {}", y),
        Point { x, y } => print!("other at ({}, {})", x, y),
    }
}
```

匹配守卫：

```rust
let num = Some(4);
match num {
    Some(x) if x < 5 => println!("less than five: {}", x), // 增强意图
    Some(x) => println!("{}", x),
    None() => println!("none"),
}
```

@绑定：

```rust
enum Message {
    Hello { id: i32 },
}

let msg = Message::Hello { id: 5 };

match msg {
    Message::Hello { id: id_variable @ 3..=7 } => {
        println!("Found an id in range: {}", id_variable)
    },
    Message::Hello { id: 10..=12 } => {
        println!("Found an id in another range")
    },
    Message::Hello { id } => {
        println!("Found some other id: {}", id)
    },
}
```

@绑定可以在模式中测试一个值的同时将它绑定到变量中。（在范围匹配时，只能使用右关闭的模式）

### 解构赋值

这一模式可以用来**分解结构体、枚举、元组或引用，从而使用这些值中的不同部分**

```rust
struct Point {
    x: i32,
    y: i32,
}

fn main() {
    let p = Point{x:1, y:2};
    let Point { x: a, y: b } = p; // 自动生成a和b的值，对应x和y
    assert_eq!(a, 1);
    assert_eq!(b, 2);
  	// 或者使用更简洁的同名字段
    let Point{x, y} = p;
    assert_eq!(x, 1);
    assert_eq!(y, 2);
  	// 或者在match中
  	match p {
        Point { x, y: 0 } => println!("on the x axis at {}", x),
        Point { x: 0, y } => println!("on the y axis at {}", y),
        Point { x, y } => print!("other at ({}, {})", x, y),
    }
}
```

枚举：

```rust
enum Message {
    Quit,
    Move { x: i32, y: i32 },
    Write(String),
    ChangeColor(i32, i32, i32),
}

fn main() {
 let msg = Message::ChangeColor(0, 160, 255);

    match msg {
      Message::Quit => {
            println!("The Quit variant has no data to destructure.")
        },
      Message::Move { x, y } => {
            println!(
                "Move in the x direction {} and in the y direction {}",
                x,
                y
            );
        }
      Message::Write(text) => println!("Text message: {}", text),
      Message::ChangeColor(r, g, b) => {
            println!(
                "Change the color to red {}, green {}, and blue {}",
                r,
                g,
                b
            )
        }
    }
}
```

### 忽略值

使用下划线`_`来忽略整个值或者元组中的某个值。

下换线`_`不会绑定值。

rust对没有引用的变量、枚举、函数等会进行warning，使用下划线开头可避免warning。但是这种变量仍会获取所有权。

```
let a = 3;
let _b = a;
```

使用`..`忽略剩余部分。`..`会自动展开并填充所需值。

```rust
let origin = Point { x: 0, y: 0, z: 0 };

match origin {
    Point { x, .. } => println!("x is {}", x),
}
```

## 版本控制

当你第一次构建项目时，Cargo会依次遍历我们声明的依赖及其对应的语义化版本，找到符合要求的具体版本号，并将它们写入Cargo.lock文件中。随后再次构建项目时，Cargo就会优先检索Cargo.lock
，假如文件中存在已经指明具体版本的依赖库，那么它就会跳过计算版本号的过程，并直接使用文件中指明的版本。这使得我们拥有了一个自动化的、可重现的构建系统。

当你确实想要升级某个依赖包时，Cargo提供了一个专用命令：update，它会强制Cargo忽略Cargo.lock
文件，并重新计算出所有依赖包中符合Cargo.toml声明的最新版本。假如命令运行成功，Cargo就会将更新后的版本号写入Cargo.lock文件，并覆盖之前的内容。

## 其他

### doc

你当然无法在使用第三方包时凭空知晓自己究竟需要使用什么样的trait或什么样的函数，而是需要在各类包的文档中找到相关的使用说明。值得一提的是，Cargo提供了一个特别有用的命令：cargo doc --open，它可以为你在本地构建一份有关所有依赖的文档，并自动地在浏览器中将文档打开来供你查阅

## 资料

- [rust在线编辑器](https://play.rust-lang.org)
