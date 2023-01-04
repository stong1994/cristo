---
title: "go中append的坑"
date: 2023-01-03T14:10:51+08:00
url: "/internet/go/append_trap"
isCJKLanguage: false
draft: false
toc:  true
keywords:
  - append
authors:
  - stong
---



## 问题复现

```go
func main() {
	a := []int{3, 1, 5, 8}
	b := append(a[:1], a[2:]...)
	fmt.Println(a)
	fmt.Println(b)
}
```

`append(slice[:i], slice[i+1:]...)`是很常见的用于去除切片slice中第i个元素的操作。打印b会得到`[3,5,8]`.

但是打印a会显示什么呢？

理想情况是a没有任何变化，但实际情况是：

```go
[3 5 8 8]
```

a被修改了！

## 猜想

依稀记得append操作会判断当前切片的容量，如何切片的容量足够容纳添加进来的值，就会复用这个切片。

因此，在操作`append(a[:1], a[2:]...)`时，程序发现a的容量足够，不需要扩容，因此会复用a，因此将`5, 8 (即a[2]...)`添加到了`3 (即a[:1])`后边，于是就有了`3,5,8`, 同时，`a[3]`没有被修改，因此仍是8，所以b的结果就是`3, 5, 8, 8`

## 证实

可以通过阅读append函数的实现代码来证实，但是append是一个内置函数，看不到底层实现。但是我们可以在[官方的博客](https://go.dev/blog/slices)中看到其实现逻辑：

```go
func Append(slice []int, elements ...int) []int {
    n := len(slice)
    total := len(slice) + len(elements)
    if total > cap(slice) {
        // Reallocate. Grow to 1.5 times the new size, so we can still grow.
        newSize := total*3/2 + 1
        newSlice := make([]int, total, newSize)
        copy(newSlice, slice)
        slice = newSlice
    }
    slice = slice[:total]
    copy(slice[n:], elements)
    return slice
}
```

可以看到，如果旧切片的容量已经足够（`len(slice) + len(elements) < cap(slice)`），则不会新建切片！

也可以看到，新的元素会覆盖掉`a[:1]`之后的数据(`copy(slice[n:], elements)`.

## 验证

通过打印一些关键数据，就可以验证上边的想法：

```go
func main() {
	a := []int{3, 1, 5, 8}
	// a[:1]数据
	fmt.Printf("len:%d, cap:%d, array:%p\n", len(a[:1]), cap(a[:1]), a[:1])
	b := append(a[:1], a[2:]...)
	// 底层数组地址
	fmt.Printf("array of a: %p\n", a)
	fmt.Printf("array of b: %p\n", b)
	// 切片地址
	fmt.Printf("slice of a: %p\n", &a)
	fmt.Printf("slice of b: %p\n", &b)
}

// 终端输出
len:1, cap:4, array:0x14000130000
array of a: 0x14000130000
array of b: 0x14000130000
slice of a: 0x1400010e030
slice of b: 0x1400010e060
```

可以看到a和b使用的同一个底层数组，说明append之后没有产生新的底层数组。

