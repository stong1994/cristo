+++

date = 2022-10-29T20:43:00+08:00
title = "antlr4实战"
url = "/internet/tool/antlr4-with-go"

toc = true

+++



## 官方例子-hello

1. 创建文件hello.g4，写入内容：

   ```js
   // Define a grammar called Hello
   grammar hello;
   r  : 'hello' ID ;         // match keyword hello followed by an identifier
   ID : [a-z]+ ;             // match lower-case identifiers
   WS : [ \t\r\n]+ -> skip ; // skip spaces, tabs, newlines
   ```

2. 解析为java文件并编译

   ```shell
   antlr4 hello.g4
   javac hello*.java
   ```

3. 解析语法中的r规则

   *输入hello world后需要按`Ctrl+D`来结束输入。*

   1. 以LISP格式打印法分析树。

      ```shell
      $ grun hello r -tree
      hello world
      (r hello world)
      ```

   2. 打印出词法符号流。

      ```shell
      $ grun hello r -tokens
      hello world
      [@0,0:4='hello',<'hello'>,1:0]
      [@1,6:10='world',<ID>,1:6]
      [@2,12:11='<EOF>',<EOF>,2:0]
      ```

      以`[@1,6:10='world',<ID>,1:6]`为例，表示第1个（从0开始）词法符号，由第6-10个字符组成，包含的文本是world，匹配到的类型是ID，位于输入文本的第1行（从1开始）第6个字符。

   3. 在对话框中以可视化方式显示语法分析树

<img src="https://raw.githubusercontent.com/stong1994/images/master/picgo/202210221953622.png" style="zoom: 33%;" />

## 计算器1-堆栈存储值

### 编写calculator.g4文件

```js
grammar calculator;

stat : expr;

expr : expr op=('*'|'/') expr # MulDiv
     | expr op=('+'|'-') expr # AddSub
     | INT # int
     | '(' expr ')' # parens
     ;

MUL : '*' ;
DIV : '/' ;
ADD : '+' ;
SUB : '-' ;

INT  : [0-9]+ ;
WS : [ \t\r\n]+ -> skip ;
```

### 生成go文件

执行`antlr4  calculator.g4 -Dlanguage=Go -o parser`可看到生成了一堆go文件，其中calculator_listener.go中生成了接口calculatorListener，并提供了默认实现。

```go
// calculatorListener is a complete listener for a parse tree produced by calculatorParser.
type calculatorListener interface {
	antlr.ParseTreeListener

	// EnterStat is called when entering the stat production.
	EnterStat(c *StatContext)

	// EnterParens is called when entering the parens production.
	EnterParens(c *ParensContext)

	// EnterMulDiv is called when entering the MulDiv production.
	EnterMulDiv(c *MulDivContext)

	// EnterAddSub is called when entering the AddSub production.
	EnterAddSub(c *AddSubContext)

	// EnterInt is called when entering the int production.
	EnterInt(c *IntContext)

	// ExitStat is called when exiting the stat production.
	ExitStat(c *StatContext)

	// ExitParens is called when exiting the parens production.
	ExitParens(c *ParensContext)

	// ExitMulDiv is called when exiting the MulDiv production.
	ExitMulDiv(c *MulDivContext)

	// ExitAddSub is called when exiting the AddSub production.
	ExitAddSub(c *AddSubContext)

	// ExitInt is called when exiting the int production.
	ExitInt(c *IntContext)
}
```

### 实现监听器(内置堆栈)

由于antlr只提供解析功能，具体的操作还需要开发者自行处理，因此我们需要实现这个接口，并嵌入自己的逻辑。

```go
package main

import (
	. "antlr4-go-example/calculator/parser"
	"strconv"
)

type calcListener struct {
	*BasecalculatorListener
	stack []int
}

func NewCalcListener() *calcListener {
	return &calcListener{
		BasecalculatorListener: &BasecalculatorListener{},
	}
}

func (c *calcListener) push(i int) {
	c.stack = append(c.stack, i)
}

func (c *calcListener) pop() int {
	if len(c.stack) == 0 {
		panic("stack is empty, unable to pop")
	}
	rst := c.stack[len(c.stack)-1]
	c.stack = c.stack[:len(c.stack)-1]
	return rst
}

// ExitMulDiv is called when production MulDiv is exited.
func (c *calcListener) ExitMulDiv(ctx *MulDivContext) {
	right, left := c.pop(), c.pop()
	switch ctx.GetOp().GetText() {
	case "*":
		c.push(left * right)
	case "/":
		c.push(left / right)
	default:
		panic("unexpected op: " + ctx.GetOp().GetText())
	}
}

// ExitAddSub is called when production AddSub is exited.
func (c *calcListener) ExitAddSub(ctx *AddSubContext) {
	right, left := c.pop(), c.pop()
	switch ctx.GetOp().GetText() {
	case "+":
		c.push(left + right)
	case "-":
		c.push(left - right)
	default:
		panic("unexpected op: " + ctx.GetOp().GetText())
	}
}

// ExitId is called when production id is exited.
func (c *calcListener) ExitInt(ctx *IntContext) {
	n, err := strconv.Atoi(ctx.GetText())
	if err != nil {
		panic(err)
	}
	c.push(n)
}
```

这个版本的实现通过内置的堆栈来记录各个节点的值。

### 编写运行文件

```go
func main() {
	input := antlr.NewInputStream("2+3*4")
	lexer := NewcalculatorLexer(input)
	stream := antlr.NewCommonTokenStream(lexer, antlr.TokenDefaultChannel)
	parser := NewcalculatorParser(stream)

	calculator := NewCalcListener()
	antlr.ParseTreeWalkerDefault.Walk(calculator, parser.Stat())
	result := calculator.pop()
	fmt.Println(result)
}
```

执行命令：`go run main.go`得到结果：14。符合预期。

## 计算器2-节点存储值

上述办法通过在实现监听器时内置一个堆栈来存储节点值，另一个方法是在节点本身存储值。

### 修改calcultator.g4文件

```js
grammar calculator;

stat : expr;

expr returns [int value]
     : expr op=('*'|'/') expr # MulDiv
     | expr op=('+'|'-') expr # AddSub
     | INT # num
     | '(' expr ')' # parens
     ;

MUL : '*' ;
DIV : '/' ;
ADD : '+' ;
SUB : '-' ;

INT  : [0-9]+ | '-' [0-9]+ ;
WS : [ \t\r\n]+ -> skip ;
```

区别在于expr后增加了return，并且指定返回值为int类型的value。

### 修改监听器

```go
package main

import (
	. "antlr4-go-example/calculator2/parser"
	"strconv"
)

type calcListener struct {
	*BasecalculatorListener
	result int
}

func NewCalcListener() *calcListener {
	return &calcListener{
		BasecalculatorListener: &BasecalculatorListener{},
	}
}

// ExitMulDiv is called when production MulDiv is exited.
func (c *calcListener) ExitMulDiv(ctx *MulDivContext) {
	switch ctx.GetOp().GetText() {
	case "*":
		ctx.SetValue(ctx.Expr(0).GetValue() * ctx.Expr(1).GetValue())
	case "/":
		ctx.SetValue(ctx.Expr(0).GetValue() / ctx.Expr(1).GetValue())
	default:
		panic("unexpected op: " + ctx.GetOp().GetText())
	}
}

// ExitAddSub is called when production AddSub is exited.
func (c *calcListener) ExitAddSub(ctx *AddSubContext) {
	switch ctx.GetOp().GetText() {
	case "+":
		ctx.SetValue(ctx.Expr(0).GetValue() + ctx.Expr(1).GetValue())
	case "-":
		ctx.SetValue(ctx.Expr(0).GetValue() - ctx.Expr(1).GetValue())
	default:
		panic("unexpected op: " + ctx.GetOp().GetText())
	}
}

// ExitId is called when production id is exited.
func (c *calcListener) ExitNum(ctx *NumContext) {
	n, err := strconv.Atoi(ctx.GetText())
	if err != nil {
		panic(err)
	}
	ctx.SetValue(n)
}

func (c *calcListener) ExitStat(ctx *StatContext) {
	c.result = ctx.Expr().GetValue()
}

func (c *calcListener) Result() int {
	return c.result
}
```

修改内容就是将堆栈删掉，然后对每个节点计算值，并存入对应节点的value。

### 修改运行文件

```go
package main

import (
	. "antlr4-go-example/calculator2/parser"
	"fmt"
	"github.com/antlr/antlr4/runtime/Go/antlr/v4"
)

func main() {
	input := antlr.NewInputStream("2--4)")
	lexer := NewcalculatorLexer(input)
	stream := antlr.NewCommonTokenStream(lexer, antlr.TokenDefaultChannel)
	parser := NewcalculatorParser(stream)

	calculator := NewCalcListener()
	antlr.ParseTreeWalkerDefault.Walk(calculator, parser.Stat())
	fmt.Println(calculator.Result())
}
```

## 计算器3-访问者模式

上述两种方式都是通过监听器模式来实现的，还可以使用访问者模式实现。

### 生成go文件

g4文件无需修改，修改执行命令为：

```sh
antlr4  calculator.g4 -Dlanguage=Go -o parser -no-listener -visitor
```

可以看到生成的`calculator_base_visitor.go`文件中的内容减少了很多：

```go
type BasecalculatorVisitor struct {
	*antlr.BaseParseTreeVisitor
}

func (v *BasecalculatorVisitor) VisitStat(ctx *StatContext) interface{} {
	return v.VisitChildren(ctx)
}

func (v *BasecalculatorVisitor) VisitParens(ctx *ParensContext) interface{} {
	return v.VisitChildren(ctx)
}

func (v *BasecalculatorVisitor) VisitMulDiv(ctx *MulDivContext) interface{} {
	return v.VisitChildren(ctx)
}

func (v *BasecalculatorVisitor) VisitAddSub(ctx *AddSubContext) interface{} {
	return v.VisitChildren(ctx)
}

func (v *BasecalculatorVisitor) VisitNum(ctx *NumContext) interface{} {
	return v.VisitChildren(ctx)
}
```

基本上是减少了一半，由“进入”和“退出”变为了“访问”。

### 实现访问者

```go
package main

import (
	. "antlr4-go-example/calculator3/parser"
	"github.com/antlr/antlr4/runtime/Go/antlr/v4"
	"strconv"
)

type calculator struct {
	*BasecalculatorVisitor
}

func NewCalculator() *calculator {
	return &calculator{
		BasecalculatorVisitor: &BasecalculatorVisitor{},
	}
}

func (c *calculator) VisitStat(ctx *StatContext) interface{} {
	return c.VisitChildren(ctx.Expr())
}

func (c *calculator) VisitMulDiv(ctx *MulDivContext) interface{} {
	switch ctx.GetOp().GetText() {
	case "*":
		return c.VisitChildren(ctx.Expr(0)).(int) * c.VisitChildren(ctx.Expr(1)).(int)
	case "/":
		return c.VisitChildren(ctx.Expr(0)).(int) / c.VisitChildren(ctx.Expr(1)).(int)
	default:
		panic("unexpected op: " + ctx.GetOp().GetText())
	}
}

func (c *calculator) VisitAddSub(ctx *AddSubContext) interface{} {
	switch ctx.GetOp().GetText() {
	case "+":
		return c.VisitChildren(ctx.Expr(0)).(int) + c.VisitChildren(ctx.Expr(1)).(int)
	case "-":
		return c.VisitChildren(ctx.Expr(0)).(int) - c.VisitChildren(ctx.Expr(1)).(int)
	default:
		panic("unexpected op: " + ctx.GetOp().GetText())
	}
}

func (c *calculator) VisitNum(ctx *NumContext) interface{} {
	n, err := strconv.Atoi(ctx.GetText())
	if err != nil {
		panic(err)
	}
	return n
}

func (c *calculator) VisitChildren(node antlr.RuleNode) interface{} {
	return node.Accept(c)
}
```

相较于监听器模式，访问器模式需要返回值，以及手动调用children。

### 修改运行文件

```go
package main

import (
	. "antlr4-go-example/calculator3/parser"
	"fmt"
	"github.com/antlr/antlr4/runtime/Go/antlr/v4"
)

func main() {
	input := antlr.NewInputStream("2--4)")
	lexer := NewcalculatorLexer(input)
	stream := antlr.NewCommonTokenStream(lexer, antlr.TokenDefaultChannel)
	parser := NewcalculatorParser(stream)

	calculator := NewCalculator()
	result := parser.Stat().Accept(calculator)
	fmt.Println(result)
}
```

## 计算器4-嵌入动作

有时为了免于手动编写监听器或者访问者，可以通过在g4文件中嵌入动作。

### calcultator.g4中嵌入动作

```js
grammar calculator;

@parser::members { // 在语法分析器中增加handleExpr函数，词法分析器中不需要
func handleExpr(op, left, right int) int {
    switch op {
    case calculatorParserADD:
        return left+right
    case calculatorParserSUB:
        return left-right
    case calculatorParserMUL:
        return left*right
    case calculatorParserDIV:
        return left/right
    default:
        return 0
    }
}
}

stat : expr;

expr returns [int value]
     : a=expr op=('*'|'/') b=expr
     {
     $ctx.value = handleExpr($op.type, $a.value, $b.value)
     fmt.Printf("%d %s %d = %d\n",$a.value, $op.text, $b.value, $ctx.value)
     }
     # MulDiv
     | a=expr op=('+'|'-') b=expr
     {
     $ctx.value = handleExpr($op.type, $a.value, $b.value)
     fmt.Printf("got %s\n", $op.text)
     fmt.Printf("calculating:\t%d %s %d = %d\n",$a.value, $op.text, $b.value, $ctx.value)
     }
     # AddSub
     | '(' expr ')'
     {
     $ctx.value=$expr.value;
     }
     # parens
     | INT
     {
     $ctx.value = $INT.int;
     fmt.Println("got", $ctx.value)
     }
     # num
     ;

MUL : '*' ;
DIV : '/' ;
ADD : '+' ;
SUB : '-' ;

INT  : [0-9]+ ;
WS : [ \t\r\n]+ -> skip ;
```

### 生成go文件

运行`antlr4 -Dlanguage=Go -o ./parser calculator.g4 -no-listener`. 在这个例子中我们不需要监听器或者访问者。

### 修改运行文件

```go
package main

import (
	. "antlr4-go-example/calculator4/parser"
	"github.com/antlr/antlr4/runtime/Go/antlr/v4"
)

func main() {
	input := antlr.NewInputStream("2-4)")
	lexer := NewcalculatorLexer(input)
	stream := antlr.NewCommonTokenStream(lexer, antlr.TokenDefaultChannel)
	parser := NewcalculatorParser(stream)

	listener := BasecalculatorListener{}
	antlr.ParseTreeWalkerDefault.Walk(&listener, parser.Expr())
}
```

程序执行后输出：

```go
got 2
got 4
got -
calculating:    2 - 4 = -2
```

## 计算器5-词法模式

有时在一个解析器中我们需要多个词法模式，这时候就需要进行词法模式的上下文切换。

在计算器4的基础上，我们可以增加评论。即此时有两个词法模式，一个是默认的计算器，一个是评论。

### 编写词法分析文件

```js
lexer grammar cal_lexer;

// 默认模式下的词法规则
OPEN : '<' -> mode(MARK) ; // 进入MARK模式
MUL : '*' ;
DIV : '/' ;
ADD : '+' ;
SUB : '-' ;

INT  : [0-9]+ ;
WS : [ \t\r\n]+ -> skip ;

// MARK模式下的词法规则
mode MARK;
CLOSE : '>' -> mode(DEFAULT_MODE) ; // 回到SEA模式
CONTENT : ~[>]+ ; // 匹配所有字符
```

除了制定模式外，也可以用pushMode和popMode:

```js
lexer grammar cal_lexer;

// 默认模式下的词法规则
OPEN : '<' -> pushMode(MARK) ; // 进入MARK模式
MUL : '*' ;
DIV : '/' ;
ADD : '+' ;
SUB : '-' ;

INT  : [0-9]+ ;
WS : [ \t\r\n]+ -> skip ;

// MARK模式下的词法规则
mode MARK;
CLOSE : '>' -> popMode ; // 回到SEA模式
CONTENT : ~[>]+ ; // 匹配所有字符
```



### 编写语法分析文件

```js
parser grammar cal_parser;

options { tokenVocab=cal_lexer; }

@parser::members {
func handleExpr(op, left, right int) int {
    switch op {
    case cal_lexerADD:
        return left+right
    case cal_lexerSUB:
        return left-right
    case cal_lexerMUL:
        return left*right
    case cal_lexerDIV:
        return left/right
    default:
        return 0
    }
}
}

stat : (expr|mark)+;

expr returns [int value]
     : a=expr op=('*'|'/') b=expr
     {
     $ctx.value = handleExpr($op.type, $a.value, $b.value)
     fmt.Printf("%d %s %d = %d\n",$a.value, $op.text, $b.value, $ctx.value)
     }
     # MulDiv
     | a=expr op=('+'|'-') b=expr
     {
     $ctx.value = handleExpr($op.type, $a.value, $b.value)
     fmt.Printf("got %s\n", $op.text)
     fmt.Printf("calculating:\t%d %s %d = %d\n",$a.value, $op.text, $b.value, $ctx.value)
     }
     # AddSub
     | INT
     {
     $ctx.value = $INT.int;
     fmt.Println("got", $ctx.value)
     }
     # num
     ;

mark : '<' CONTENT '>' {fmt.Println("comment: ", $CONTENT.text)};
```

### 生成go文件

```sh
$ antlr4 -Dlanguage=Go  cal_lexer.g4 -no-listener
$ antlr4 -Dlanguage=Go cal_parser.g4 -no-listener
```

### 编写运行文件

```go
package parser

import (
	"github.com/antlr/antlr4/runtime/Go/antlr/v4"
	"testing"
)

func TestParser(t *testing.T) {
	input := antlr.NewInputStream("2-4<should be -2> 100+10 <should be 110>")
	lexer := Newcal_lexer(input)
	stream := antlr.NewCommonTokenStream(lexer, antlr.TokenDefaultChannel)
	parser := Newcal_parser(stream)

	antlr.ParseTreeWalkerDefault.Walk(&antlr.BaseParseTreeListener{}, parser.Stat())
}
```

运行，输出为：

```sh
got 2
got 4
got -
calculating:	2 - 4 = -2
comment:  should be -2
got 100
got 10
got +
calculating:	100 + 10 = 110
comment:  should be 110
```



## 计算器6-计算结果赋值

有时我们需要将计算结果赋值给一个变量，比如`a=1+2-3`，这时候需要先计算等号右边，即对等号使用**右结合律**。

一个简单的例子：

```js
grammar right;

stat : expr;

expr : expr AddSub expr
     | <assoc=right> expr '=' expr
     | INT
     | ID
     ;

AddSub : '+' | '-' ;

INT  : [0-9]+ ;
ID : [a-zA-Z]+;
WS : [ \t\r\n]+ -> skip ;
```

关键的语法是`<assoc=right>`，它表示先解析右边，上述的语法树为：

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/202211011605490.png)

## 错误监听器

antlr在解析时会通过一系列手段来跳过错误，但在生产环境中我们需要判断解析是否正确，因此需要捕获解析中的错误。

### 创建错误监听器

```go
package main

import (
	"fmt"
	"github.com/antlr/antlr4/runtime/Go/antlr/v4"
)

type ErrListener struct {
	antlr.DefaultErrorListener
	errList []string
}

func (el *ErrListener) SyntaxError(recognizer antlr.Recognizer, offendingSymbol interface{}, line, column int,
	msg string, e antlr.RecognitionException) {
	el.errList = append(el.errList, fmt.Sprintf("pos: %d:%d, msg: %s", line, column, msg))
}

func (el *ErrListener) Print() {
	for _, err := range el.errList {
		fmt.Println(err)
	}
}
```

### 将监听器嵌入解析解析器

```go
package main

import (
	. "antlr4-go-example/listen_err/parser"
	"github.com/antlr/antlr4/runtime/Go/antlr/v4"
)

func main() {
	input := antlr.NewInputStream("2--4")
	lexer := Newlisten_errLexer(input)

	stream := antlr.NewCommonTokenStream(lexer, antlr.TokenDefaultChannel)
	parser := Newlisten_errParser(stream)
	errListener := &ErrListener{}
	parser.RemoveErrorListeners() // 默认会使用ConsoleErrorListener，需要移除。
	parser.AddErrorListener(errListener)
	parser.GetInterpreter().SetPredictionMode(antlr.PredictionModeLLExactAmbigDetection)
	antlr.ParseTreeWalkerDefault.Walk(&Baselisten_errListener{}, parser.Stat())

	errListener.Print()
}
```

注意：解析器会默认使用`ConsoleErrorListener`来捕获错误，该错误监听器会将错误打印到终端，为了避免该错误监听器对我们的影响，我们需要将其移除。

另外，也需要设置预测模型，如果想要获取所有的错误，将模型设置为`antlr.PredictionModeLLExactAmbigDetection`

## 相关文档

1. [action介绍-github](https://github.com/antlr/antlr4/blob/master/doc/actions.md)
2. [文中的代码地址](https://github.com/stong1994/antlr4-go-example)
