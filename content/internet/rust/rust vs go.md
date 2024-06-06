---
title: "rust vs go"
date: 2023-12-30T14:35:00+08:00
url: "/note/rust/rust_vs_go"
isCJKLanguage: true
draft: true
toc:  true
keywords:
  - rust
authors:
  - stong
---



## rust有go没有

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

## 都有但不同

### 闭包

go中的闭包可以引用外部的自由变量：

```go
func main() {
	total := 10
	add := func(i, j int) int {
		return total + i + j
	}
	fmt.Println(add(1, 2))
}
```



