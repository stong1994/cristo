---
date: 2024-07-01T10:43:00+08:00
title: "Rust中的惰性计算"
url: "/internet/rust/lay_evaluation"
toc: true
draft: false
description: "Rust中的惰性计算"
slug: "惰性计算"
tags: ["惰性计算", "rust", "lazy evaluation"]
showDateUpdated: true
---


## 什么是惰性计算（lazy evaluation）

> 惰性计算是一种程序设计，其中表达式的计算被推迟到它们的值被需要的时候。这种技术可以用来提高性能，因为它允许程序只计算那些真正需要的值。

Rust中的**迭代器**就使用了（或者说实现了）这种设计.

举个例子：假设有一个数组，我们想对数组中的每一个元素进行平方，然后再将结果转换为字符串，最后将结果收集到一个新的数组中。在Rust中，我们可以使用迭代器来实现这个功能。这样做的好处是，我们可以在每个元素上执行一个操作，而不必在内存中保存中间结果。

```rust
fn main() {
    let nums = vec![1, 2, 3, 4, 5];
    let nums: Vec<_> = nums
        .into_iter()
        .map(|x| x * x)
        .map(|x| x.to_string())
        .collect();
    println!("{:?}", nums);
}
```

让我们逐步看下这段代码：

1. 在第2行代码中，我们定义了一个动态数组`nums`，其中包含了一些整数。
2. 在第3,4行代码中，我们将`nums`转换为一个迭代器. Rust中的数组本身是不支持惰性计算的，所以需要通过`into_iter()`或`iter()`转换为迭代器。
3. 在第5行代码中，我们使用`map`方法对每个元素进行平方操作。
4. 在第6行代码中，再次使用`map`方法将每个元素转换为字符串。
5. 在第7行代码中，我们使用`collect`方法将迭代器收集到一个新的数组中。

Ok, 让我们用`python`写一个“等价”的程序：

```python
nums = [1, 2, 3, 4, 5]
nums = list(map(str, [x * x for x in nums]))
print(nums)
```

思考一下，这两个程序有什么区别？🤔

> 尽管两个程序的输出一样，但是Rust的程序更加高效。在Rust中，我们只需要遍历一次数组，而在Python中，我们需要遍历两次数组。这是因为Python中的`map`函数会创建一个新的列表，而Rust中的`map`方法只是返回一个迭代器，不会创建新的列表。

看一下Rust的迭代器可能会更容易理解一些。下边这个代码使用迭代器实现了菲波那切数列，并打印了前10个菲波那切数：

```rust
struct Fibonacci {
    curr: u64,
    next: u64,
}

impl Fibonacci {
    fn new() -> Fibonacci {
        Fibonacci { curr: 0, next: 1 }
    }
}

impl Iterator for Fibonacci {
    type Item = u64;

    fn next(&mut self) -> Option<Self::Item> {
        let new_next = self.curr + self.next;

        self.curr = self.next;
        self.next = new_next;

        Some(self.curr)
    }
}

fn main() {
    let fib = Fibonacci::new();

    // Print the first 10 Fibonacci numbers
    for i in fib.take(10) {
        println!("{}", i);
    }
}
```

实现`Iterator`，只需要实现`next`方法。`next`方法也很简单，就是更新`self.curr`和`self.next`.
在`main`代码块调用`take`方法之前,我们并没有做任何实际的计算。在调用`take(10)`之后，迭代器内部会维护一个计数器，执行10次`next`.
在开头的代码中的`map`方法也一样，它只是创建了一个新的迭代器，只有在调用`collect`方法时才会去旧的迭代器中获取值，然后进行计算。

## 一个代码块只做一件事

惰性计算的意义不仅仅在于提升了性能，还能让代码更清晰，实现一个代码块只做一件事！
例如在一个需要遍历的场景中，需要对每个元素进行做数据处理、筛选、转换。。。直接遍历的代码是这样的:

```rust
fn main() {
    let nums = vec![1, 2, 3, 4, 5];
    let mut target = vec![];
    for ele in nums {
        if ele % 2 == 0 {
            continue;
        }
        let ele = (ele * 2).to_string();
        target.push(ele);
    }
    println!("{:?}", target);
}

```

使用迭代器实现的代码是这样的：

```rust
fn main() {
    let nums = vec![1, 2, 3, 4, 5];
    let target: Vec<_> = nums
        .into_iter()
        .filter(|x| x % 2 != 0)
        .map(|x| x * 2)
        .map(|x| x.to_string())
        .collect();
    println!("{:?}", target);
}
```

可以明显看到，使用迭代器的代码更加简洁，每个代码块只做一件事，代码的逻辑更加清晰。

 

## 感受下Haskell的魅力

Rust语言在一些设计上借鉴了Haskell的实现，比如说惰性计算。

将上边的代码改为`Haskell`实现：

```haskell
let nums = [1, 2, 3, 4, 5]
let target = map show $ map (*2) $ filter odd nums
print target
```

代码更精炼了！
