---
title: "rust基础笔记"
date: 2022-06-04T14:35:00+08:00
url: "/note/rust/base"
isCJKLanguage: true
draft: false
toc:  true
keywords:
  - rust
authors:
  - stong
---



## 数据类型

### 标量类型（scalar）

#### 整数类型



![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202209040012877.png)

除了Byte，其余所有的字面量都可以使用类型后缀，比如57u8，代表一个使用了u8类型的整数57。同时你也可以使用_作为分隔符以方便读数，比如1_000。

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

2. 式匹配来解构元组

```rust
fn main() {
    let tup = (1, 1.0, '1');
    let (x, y, _) = tup;
    println!("The value of x is: {}", x);
    println!("The value of y is: {}", y);
    println!("The value of z is: {}", tup.2);
}
```

#### 数组类型

与元组不同，数组中的每一个元素都必须是相同的类型。Rust中的数组拥有固定的长度，一旦声明就再也不能随意更改大小。

为了写出数组的类型，你需要使用一对方括号，并在方括号中填写数组内所有元素的类型、一个分号及数组内元素的数量，如下所示：
`let a: [i32; 5] = [1, 2, 3, 4, 5];`

“即假如你想要创建一个含有相同元素的数组，那么你可以在方括号中指定元素的值，并接着填入一个分号及数组的长度，如下所示：
`let a = [3; 5]；`
以a命名的数组将会拥有5个元素，而这些元素全部拥有相同的初始值3。这一写法等价于`let a = [3, 3, 3, 3, 3];`，但却更加精简。”

## 函数

Rust代码使用蛇形命名法（snake case）来作为规范函数和变量名称的风格。蛇形命名法只使用小写的字母进行命名，并以下画线分隔单词。

### 函数的返回值
函数可以向调用它的代码返回值。虽然你不用为这个返回值命名，但需要在箭头符号（->）的后面声明它的类型。在Rust中，函数的返回值等同于函数体最后一个表达式的值。你可以使用return关键字并指定一个值来提前从函数中返回，但大多数函数都隐式地返回了最后的表达式。

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

//

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



### 引用(借用)

为了避免在函数调用过程中对同一个值的重复移动（每次都要定义为函数的返回值），引入了“引用”。特征：

- 在任何一段给定的时间里，你要么只能拥有一个**可变引用**，要么只能拥有任意数量的**不可变引用**。
- 引用总是有效的

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
2. 隐式转换：当你使用object.something()调用方法时，Rust会自动为调用者object添加&、&mut或*，以使其能够符合方法的签名。

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
3. 假如我们使用了None而不是Some变体来进行赋值，那么我们需要明确地告知Rust这个Option<T>的具体类型。这是因为单独的None变体值与持有数据的Some变体不一样，编译器无法根据这些信息来正确推导出值的完整类型

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

### match

1. 必须穷举所有可能
2. 可以使用通配符_来过滤未穷举的可能
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
       Ok(s) // 此处不能加;
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