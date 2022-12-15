---
title: "go中unmarshal的坑"
date: 2022-12-11T13:10:51+08:00
url: "/internet/go/unmarshal_trap"
isCJKLanguage: false
draft: false
toc:  true
keywords:
  - unmarshal
authors:
  - stong
---



`encoding/json`是go中内置的json序列化工具库，但是如果随意使用而不了解其内部实现的话就可能会带来一些困扰。

## 问题复现

```go
type User struct {
	Name    string   `json:"name"`
	Hobbies []string `json:"hobbies"`
}

func main() {
	var u User
	alice := `{"name": "alice", "hobbies": ["readBook", "watchTV"]}`
	bob := `{"name": "bob"}`
	err := json.Unmarshal([]byte(alice), &u)
	if err != nil {
		panic(err)
	}
	fmt.Printf("%+v\n", u)
	err = json.Unmarshal([]byte(bob), &u)
	if err != nil {
		panic(err)
	}
	fmt.Printf("%+v\n", u)
}
```

我们有两个user：alice和bob。alice有readBook和watchTV两个Hobbies，而bob没有任何Hobbies。

我们用同一个变量u分别对alice和bob进行反序列化，终端会输出什么呢？

理想情况是：

```
{Name:alice Hobbies:[readBook watchTV]}
{Name:bob Hobbies:[]}
```

但实际情况是：

```
{Name:alice Hobbies:[readBook watchTV]}
{Name:bob Hobbies:[readBook watchTV]}
```

bob“继承”了alice的Hobbies，这显然是错误的结果！

## 猜想

alice和bob共用同一个变量u，并且bob没有Hobbies，但是“继承”了alice的Hobbies。那么可能是Unmarshal方法没有对空的字段进行初始化。

## 证实

猜想直到被证实的前都没有任何意义。

代码问题只能通过代码来解决。

在`src/encoding/json/decode.go`中有一个`object`方法，作用就是对对象类型的json进行解析。

*已删掉非关键代码*

```go
func (d *decodeState) object(v reflect.Value) error {
	for {
    item := d.data[start:d.readIndex()]
		key, ok := unquoteBytes(item)

		// Figure out field corresponding to key.
		var subv reflect.Value
		var f *field
		if i, ok := fields.nameIndex[string(key)]; ok {
			// Found an exact name match.
			f = &fields.list[i]
		}
		// ...
	}
	return nil
}
```

可以看到，decodeState会读取json数据流中的数据，找到key后再去目的结构中找到对应字段进行赋值。

但是bob的json字符串中不存在Hobbies字符串，因此就不会进行赋值，因此沿用了对alice反序列时的Hobbies值。

## 验证

在上一阶段，我们了解到json.Unmarshal会忽略没有key的字段，因此如果我们对bob的Hobbies增加默认值，那么bob的数据就不会再出错！

修改bob的数据为：

```go
bob := `{"name": "bob", "hobbies": []}`
```

执行代码，终端结果输出为：

```go
{Name:alice Hobbies:[readBook watchTV]}
{Name:bob Hobbies:[]}
```

验证了猜想！

## 反思

这算是json.Unmarshal的bug吗？当然不是，json.Unmarshal又没有承诺对空值字段进行初始化！

**工具虽然提高了生产效率，但同时也提高了系统的复杂性。**

构建一个系统所使用的工具已经达到了一个离谱的数量。这些工具就像隐藏的炸弹一样，在某个时刻“砰”的一下炸掉整个系统。当然，结果就是又产生了一批专门解决这些“炸弹”的工具。。。

不管怎样，我们在享受工具带来的便利的同时，也应该谨记**如非必要，勿增实体**。

