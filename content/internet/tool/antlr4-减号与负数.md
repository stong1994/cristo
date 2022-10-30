+++

date = 2022-03-27T20:43:00+08:00
title = "antlr4-减号和负号"
url = "/internet/tool/antlr4-negative-and-minus"

toc = true

+++



## 一切正常的正整数运算

```js
grammar calculator;

stat : expr;

expr : expr op=('*'|'/') expr # MulDiv
     | expr op=('+'|'-') expr # AddSub
     | '(' expr ')' # parens
     | INT # num
     ;

MUL : '*' ;
DIV : '/' ;
ADD : '+' ;
SUB : '-' ;

INT  : [0-9]+ ;
WS : [ \t\r\n]+ -> skip ;
```

此时，正整数的加减乘除能够正常计算。然而如果计算负数，则不能正常计算。这是因为我们没有处理负号。

## 支持负数运算

### 负号和减号冲突

支持使用负号，则需要修改INT规则，修改为`INT  : '-'? [0-9]+ ;`即可。

```js
grammar calculator;

stat : expr;

expr : expr op=('*'|'/') expr # MulDiv
     | expr op=('+'|'-') expr # AddSub
     | '(' expr ')' # parens
     | INT # num
     ;

MUL : '*' ;
DIV : '/' ;
ADD : '+' ;
SUB : '-' ;

INT  : '-'? [0-9]+ ;
WS : [ \t\r\n]+ -> skip ;
```

此时解析`-1+1`，一切正常：

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210271445282.png)

但如果解析`1-1`，则会解析失败：

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210271446900.png)

这是因为在词法解析的过程中，将`1-1`解析为了两个token`1`和`-1`，并由于不符合语法规则而自动忽略了第二个token。

### 使用~表示负号

如果能够使用其他符号来表示负号，则能够解决负号和减号冲突的问题。

```js
grammar calculator;

stat : expr;

expr :  expr op=('*'|'/') expr # MulDiv
     | expr op=('+'|'-') expr # AddSub
     | '(' expr ')' # parens
     | INT # num
     ;

MUL : '*' ;
DIV : '/' ;
ADD : '+' ;
SUB : '-' ;

INT  : '~'? [0-9]+ ;
WS : [ \t\r\n]+ -> skip ;
```

当然，这不是一个优雅的解决方案，因为~会让用户或者开发者感到困惑。

### 使用括号或者空格

使用括号来将负数包括，或者使用空格都可以使得解析正常，然而使用上还是比较复杂，且很容易漏掉。

### 独立为语法规则

可以将负数处理为语法规则，如：

```js
grammar calculator;

stat : expr;

expr : 
     expr op=('*'|'/') expr # MulDiv
     | expr op=('+'|'-') expr # AddSub
     | '(' expr ')' # parens
     | '-' INT # NegNum
     | INT # num
     ;

MUL : '*' ;
DIV : '/' ;
ADD : '+' ;
SUB : '-' ;

INT  : [0-9]+ ;
WS : [ \t\r\n]+ -> skip ;
```

这时候能够正常解析`1-1`,`1--2`等负数运算。如`-1--1`

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210271501198.png)

但是对于`-(2+3)`则会解析失败：

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210271502747.png)

所以需要修改下规则：

```js
grammar calculator;

stat : expr;

expr :
     expr op=('*'|'/') expr # MulDiv
     | expr op=('+'|'-') expr # AddSub
     | '(' expr ')' # parens
     | '-' expr # NegNum
     | INT # num
     ;

MUL : '*' ;
DIV : '/' ;
ADD : '+' ;
SUB : '-' ;

INT  : [0-9]+ ;
WS : [ \t\r\n]+ -> skip ;
```

此时一切正常：

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210271504664.png)



但是`-2+3`会解析为：

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210271506988.png)



此时会先计算`2+3`，再将结果取负。

需要提高负数规则的优先级：

```js
grammar calculator;

stat : expr;

expr : '-' expr # NegNum
     | expr op=('*'|'/') expr # MulDiv
     | expr op=('+'|'-') expr # AddSub
     | '(' expr ')' # parens
     | INT # num
     ;

MUL : '*' ;
DIV : '/' ;
ADD : '+' ;
SUB : '-' ;

INT  : [0-9]+ ;
WS : [ \t\r\n]+ -> skip ;
```

此时一切正常。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202210271508309.png)

### 单元测试

用单元测试测一下，确保所有的场景都能够正常解析：

```go
package main

import (
	. "antlr4-go-example/calculator/parser"
	"github.com/antlr/antlr4/runtime/Go/antlr/v4"
	"testing"
)

func TestNegativeNum(t *testing.T) {
	var tests = []struct {
		Input string
		Want  int
	}{
		{
			Input: "-1",
			Want:  -1,
		},
		{
			Input: "1-3",
			Want:  -2,
		},
		{
			Input: "1--3",
			Want:  4,
		},
		{
			Input: "1-2*3",
			Want:  -5,
		},
		{
			Input: "1-2*3",
			Want:  -5,
		},
		{
			Input: "-1+3",
			Want:  2,
		},
		{
			Input: "1---3",
			Want:  -2,
		},
		{
			Input: "-1-(2+3)",
			Want:  -6,
		},
	}
	for _, v := range tests {
		t.Run(v.Input, func(t *testing.T) {
			input := antlr.NewInputStream(v.Input)
			lexer := NewcalculatorLexer(input)
			stream := antlr.NewCommonTokenStream(lexer, antlr.TokenDefaultChannel)
			parser := NewcalculatorParser(stream)

			calculator := NewCalcListener()
			antlr.ParseTreeWalkerDefault.Walk(calculator, parser.Stat())
			result := calculator.pop()
			if result != v.Want {
				t.Errorf("want %d got %d", v.Want, result)
			}
		})
	}
}
```



## 相关文档

1. [ANTLR 4中处理负号]( https://liucs.net/cs664s16/antlr.html)

2. [文中的代码地址](https://github.com/stong1994/antlr4-go-example/blob/master/calculator/calculator.g4)
