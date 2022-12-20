+++

date = 2022-12-20T14:50:00+08:00
title = "Marshal具有相同json tag的结构体"
url = "/internet/go/marshal_same_tag"

toc = true

+++

如果结构体中有两个具有相同json tag的字段，那么对其使用json库的Marshal函数后，两个”冲突“的字段会如何显示呢？

比如下方这段代码：

```go
package main

import (
	"encoding/json"
	"fmt"
)

type User struct {
	Name  string `json:"name"`
	Age   int    `json:"age"`
	Name2 string `json:"name"`
}

func main() {
	a := User{
		Name:  "John",
		Age:   20,
		Name2: "Doe",
	}
	bytes, err := json.Marshal(&a)
	if err != nil {
		panic(err)
	}
	fmt.Println(string(bytes))
}
```

输出什么？

A: `{"age":20, "name": "John"}`

B: `{"age":20, "name": "Doe"}`

C: `{"age":20}`

答案是C。



在`src/encoding/json/encode.go`中的`typeFields`函数中中有这样一段代码：

```go
	out := fields[:0]
	for advance, i := 0, 0; i < len(fields); i += advance {
		fi := fields[i]
		name := fi.name
		for advance = 1; i+advance < len(fields); advance++ {
			fj := fields[i+advance]
      // 前面对fields按照name排过序，因此只需要判断相邻字段的name是否相等。
      // 如果有相同name的字段，则继续循环，最终的advance就是具有相同name字段的数量
			if fj.name != name {
				break
			}
		}
		if advance == 1 { // Only one field with this name
			out = append(out, fi)
			continue
		}
    // 对这些有相同name的字段，进行优先级判断
		dominant, ok := dominantField(fields[i : i+advance])
		if ok {
			out = append(out, dominant)
		}
	}
```

重点就在于这个`dominantField`函数：

```go
func dominantField(fields []field) (field, bool) {
	// 如果两个字段位于同一层级，并且两个都被打了tag或者都没打tag，那么两者”不分胜负“，否则判断第一个字段为优先字段。这是因为fields已经是排过序的。
  // 这里只需要判断前两个字段。实际上只有第一个字段有可能获得优先级（还是因为fields已排序），第二个字段的作用就是协助判断，而第三个及以后的字段则完全无需关心。
	if len(fields) > 1 && len(fields[0].index) == len(fields[1].index) && fields[0].tag == fields[1].tag {
		return field{}, false
	}
	return fields[0], true
}
```

了解了上述代码后，不仅解决了我们的疑惑，也可以让我们理直气壮的使用字段覆盖掉嵌套结构的字段。如：

```go
package main

import (
	"encoding/json"
	"fmt"
)

type User struct {
	Person
	Tag int `json:"tag"`
}

type Person struct {
	Name string `json:"name"`
	Age  int    `json:"age"`
	Tag  int    `json:"tag"`
}

func main() {
	p := Person{
		Name: "John",
		Age:  10,
		Tag:  1,
	}
	a := User{
		Tag:    2,
		Person: p,
	}
	bytes, err := json.Marshal(&a)
	if err != nil {
		panic(err)
	}
	fmt.Println(string(bytes))
}
```

结果输出为：

```
{"name":"John","age":10,"tag":2}
```

tag被覆盖了！
