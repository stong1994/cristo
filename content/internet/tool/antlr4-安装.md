+++

date = 2022-10-27T20:43:00+08:00
title = "antlr4-安装"
url = "/internet/tool/antlr4-install"

toc = true

+++

## 安装

## 1. 安装antlr4

直接按照 [官网步骤](https://github.com/antlr/antlr4/blob/master/doc/getting-started.md)安装即可。

## 2. 运行example

创建calc.g4并填入以下内容（文件名称和grammar要相同，否则报错）：

```shell
grammar calc;

// Tokens
MUL: '*';
DIV: '/';
ADD: '+';
SUB: '-';
NUMBER: [0-9]+;
WHITESPACE: [ \r\n\t]+ -> skip;

// Rules
start : expression EOF;

expression
   : expression op=('*'|'/') expression # MulDiv
   | expression op=('+'|'-') expression # AddSub
   | NUMBER                             # Number
   ;
```

生成go解析文件：

```shell
antlr -Dlanguage=Go -o parser calc.g4
```

执行完命令后会生成go文件：

```shell
➜  antlr4-go-example tree
.
├── calc.g4
└── parser
    ├── CalcLexer.interp
    ├── CalcLexer.tokens
    ├── calc.interp
    ├── calc.tokens
    ├── calc_base_listener.go
    ├── calc_lexer.go
    ├── calc_listener.go
    └── calc_parser.go
```

添加运行文件：

```go
package main

import (
	"antlr4-go-example/parser"
	"fmt"
	"github.com/antlr/antlr4/runtime/Go/antlr/v4"
)

func main() {
	// Setup the input
	is := antlr.NewInputStream("1 + 2 * 3")

	// Create the Lexer
	lexer := parser.NewcalcLexer(is)

	// Read all tokens
	for {
		t := lexer.NextToken()
		if t.GetTokenType() == antlr.TokenEOF {
			break
		}
		fmt.Printf("%s (%q)\n",
			lexer.SymbolicNames[t.GetTokenType()], t.GetText())
	}
}

```

安装go依赖包：

```shell
go mod init antlr4-go-example
go mod tidy
```

运行`main.go`，控制台输出：

```sh
NUMBER ("1")
ADD ("+")
NUMBER ("2")
MUL ("*")
NUMBER ("3")
```



## 填坑记录

1. java1.8的版本生成的go文件有可能存在一些找不到的方法，最好用更高版本的jdk。

## 相关文档

1. [Parsing with ANTLR 4 and Go]( https://blog.gopheracademy.com/advent-2017/parsing-with-antlr4-and-go/)
1. [antlr4用例汇总](https://github.com/antlr/grammars-v4)

