---
date : 2024-06-05T10:43:00+08:00
title : "使用vim实现多光标功能"
url : "/internet/tool/vim-multi-op"
toc : true
draft: false
description: "Icon support in Congo."
slug: "多光标"
tags: ["vim", "gn", "virtual"]
showDateUpdated: true
---


在编写代码的过程中，我们经常会遇到“批量修改”的功能。vim中有多种方式可以批量操作。

## 1. virtual模式

原代码：

```go
package main

type Op string

const (
	Add Op = "add"
	Sub Op = "sub"
	Div Op = "div"
	Mul Op = "mul"
)
```

如果我们要在变量名前增加其类型，如Add改为OpAdd，我们有多个变量名，这时可以进入virtual模式进行批量更改。

1. ctrl+v进入virtual模式，按j进行多行选择
2. shift+i进入插入模式，鼠标移动到第一行
3. 增加两个字符Op
4. 按Esc进行批量插入

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202406051035866.gif)



## 2. gn

gn能够快速操作搜索命中的字符串，这意味着在使用gn前需要先进行搜索。

gn命令通常和一些操作模式一起使用，比如cgn用于插入,dgn用于删除.

### 1. cgn

原代码：

```go
package main

type Op string

const (
	Add = "add"
	Sub = "sub"
	Div = "div"
	Mul = "mul"
)
```

我们要为每个变量增加变量名，如`Add = "add"` 要改为`Add Op = "add"`

这时可以使用cgn来实现：

1. 使用`/=`来搜索`=`
2. 使用`cgn`进入插入模式
3. 将`=`替换为` Op =`
4. 按`Esc`退出插入模式
5. 按`n`跳转到下一个匹配字符串，然后按点`.`进行替换（重复按`.`可以直接替换下一个）

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202406051058285.gif)

如果想要跳过某个不想替换的单词，可以使用`n`进行跳过。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202406051123632.gif)

## 

### 2. dgn

可以使用dgn进行快速删除多个：

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202406051127733.gif)

## 3. lsp

说到批量修改，我们常用的是对某个变量重命名，这其实是用到了lsp，比如go用的是gopls。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202406051146424.gif)

## 相关文档

- [Operating on search matches using gn](http://vimcasts.org/episodes/operating-on-search-matches-using-gn/)
- [You don’t need more than one cursor in vim](https://medium.com/@schtoeffel/you-don-t-need-more-than-one-cursor-in-vim-2c44117d51db#.10y7wvl5y)