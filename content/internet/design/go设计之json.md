+++

date = 2022-12-15T14:50:00+08:00
title = "go设计之json"
url = "/internet/go/json"

tags = ["go", "json"]

toc = true

+++

json是目前最常用的数据序列化格式，go中内置的json库的实现使用了状态机。

## 状态机

### scanner

```go
type scanner struct {
	// 读取下一个字节，并返回状态
	step func(*scanner, byte) int

  // 是否已扫描完顶层对象，如对象{}或者数组[1,2,3]
	endTop bool

  // 扫描一个具有多层嵌套结构(对象、数组)的状态栈
	parseState []int

	err error

	// 消费的总的字节数量
	bytes int64
}
```

scanner就是json在反序列化时使用的状态机。

可以看到，状态机只包含状态和处理状态的函数，并不包含真实的json数据。

### 状态

在scanner中使用的状态有：

```go
const (
	scanContinue     = iota // uninteresting byte
	scanBeginLiteral        // end implied by next result != scanContinue
	scanBeginObject         // begin object
	scanObjectKey           // just finished object key (string)
	scanObjectValue         // just finished non-last object value
	scanEndObject           // end object (implies scanObjectValue if possible)
	scanBeginArray          // begin array
	scanArrayValue          // just finished array value
	scanEndArray            // end array (implies scanArrayValue if possible)
	scanSkipSpace           // space byte; can skip; known to be last "continue" result

	// Stop.
	scanEnd   // top-level value ended *before* this byte; known to be first "stop" result
	scanError // hit an error, scanner.err.
)
```

- scanContinue: 使用频率最高的一个状态，也是一个”索然无味“的状态，因为它代表的是”继续扫描下一个字节，不要关心当前状态“，比如说在扫描数字`100`时，扫描完第一个字节`1`后，继续扫描下一个字节`0`。
- scanBeginLiteral：表示开始扫描一个字面量，比如在开始扫描一个数据并且当前字节是双引号、负号、`0`、`'t'`、`'f'`、`'n'` 或者`1`到`9`时,表示这个对象是字符串、数字、布尔类型、null这些字面量，而不是对象或者数组。
- scanBeginObject：表示当前扫描的数据是一个对象，在刚开始扫描数据，并且扫描到的是`{`时会返回该状态。
- scanObjectKey：刚刚扫描完一个对象的key。
- scanObjectValue：刚刚扫描完一个对象的非最后一个值。
- scanEndObject：刚刚扫描完一个对象。
- scanBeginArray：表示当前扫描的数据是一个数组，在刚开始扫描数据，并且扫描到的是`[`时会返回该状态。
- scanArrayValue: 刚刚扫描完一个数组的元素
- scanEndArray：刚刚扫描完一个数组。
- scanSkipSpace：当扫描的字节是一个可以忽略的空格时返回该状态。如上一个状态是scanBeginObject时，这些扫描到的空格都是无效的字节。
- scanEnd：扫描已结束。

### 状态函数

状态函数的表达式可以抽象为`func stateXXX(s *scanner, c byte) int`.

每次调度入参都是scanner和需要扫描的一个字节，输出为当前状态。

对每一种扫描场景都有对应的状态函数。

#### 扫描输入的第一个字节

```go
// stateBeginValue is the state at the beginning of the input.
func stateBeginValue(s *scanner, c byte) int {
	if isSpace(c) {
		return scanSkipSpace
	}
	switch c {
	case '{':
		s.step = stateBeginStringOrEmpty
		return s.pushParseState(c, parseObjectKey, scanBeginObject)
	case '[':
		s.step = stateBeginValueOrEmpty
		return s.pushParseState(c, parseArrayValue, scanBeginArray)
	case '"':
		s.step = stateInString
		return scanBeginLiteral
	case '-':
		s.step = stateNeg
		return scanBeginLiteral
	case '0': // beginning of 0.123
		s.step = state0
		return scanBeginLiteral
	case 't': // beginning of true
		s.step = stateT
		return scanBeginLiteral
	case 'f': // beginning of false
		s.step = stateF
		return scanBeginLiteral
	case 'n': // beginning of null
		s.step = stateN
		return scanBeginLiteral
	}
	if '1' <= c && c <= '9' { // beginning of 1234.5
		s.step = state1
		return scanBeginLiteral
	}
	return s.error(c, "looking for beginning of value")
}
```

可以看到json格式支持对象、数组以及字符串、数字等字面量。

通过判断当前字节，并根据当前字节判断出json的数据类型，对setp函数赋值，并返回对应状态。

#### 扫描false

```go

// stateF is the state after reading `f`.
func stateF(s *scanner, c byte) int {
	if c == 'a' {
		s.step = stateFa
		return scanContinue
	}
	return s.error(c, "in literal false (expecting 'a')")
}

// stateFa is the state after reading `fa`.
func stateFa(s *scanner, c byte) int {
	if c == 'l' {
		s.step = stateFal
		return scanContinue
	}
	return s.error(c, "in literal false (expecting 'l')")
}

// stateFal is the state after reading `fal`.
func stateFal(s *scanner, c byte) int {
	if c == 's' {
		s.step = stateFals
		return scanContinue
	}
	return s.error(c, "in literal false (expecting 's')")
}

// stateFals is the state after reading `fals`.
func stateFals(s *scanner, c byte) int {
	if c == 'e' {
		s.step = stateEndValue
		return scanContinue
	}
	return s.error(c, "in literal false (expecting 'e')")
}
```

如果第一个字节是`f`, 那么可以判断出数据类型是布尔并且值可能是false，因此会依次调用函数`stateF、stateFa、stateFal、stateFals`

一旦没有扫描到预料到的字节，那么就会返回错误的状态。

#### 总结

通过各个场景的的状态函数，可以及时反馈给状态机当前的状态，而状态机以这种方式简化了整体复杂的逻辑判断，每个状态函数只需维护好自己有限的”可能性“即可。

## decode

状态机只会扫描一个数据并返回状态，实际的数据存储还要在decode中实现。

```go
func Unmarshal(data []byte, v any) error {
	// Check for well-formedness.
	// Avoids filling out half a data structure
	// before discovering a JSON syntax error.
	var d decodeState
	err := checkValid(data, &d.scan)
	if err != nil {
		return err
	}

	d.init(data)
	return d.unmarshal(v)
}

```

### 校验数据格式

```go
func checkValid(data []byte, scan *scanner) error {
	scan.reset()
	for _, c := range data {
		scan.bytes++
		if scan.step(scan, c) == scanError {
			return scan.err
		}
	}
	if scan.eof() == scanError {
		return scan.err
	}
	return nil
}
```

Unmarshal在进行实际的反序列化前，会先校验输入的json数据是否是有效的，方法就是扫描每一个字节，并通过状态机返回的状态来判断是否有错误。

### 定位到第一个状态

```go
func (d *decodeState) unmarshal(v any) error {
	rv := reflect.ValueOf(v)
	if rv.Kind() != reflect.Pointer || rv.IsNil() {
		return &InvalidUnmarshalError{reflect.TypeOf(v)}
	}

	d.scan.reset()
	d.scanWhile(scanSkipSpace)
	// We decode rv not rv.Elem because the Unmarshaler interface
	// test must be applied at the top level of the value.
	err := d.value(rv)
	if err != nil {
		return d.addErrorContext(err)
	}
	return d.savedError
}

// scanWhile processes bytes in d.data[d.off:] until it
// receives a scan code not equal to op.
func (d *decodeState) scanWhile(op int) {
	s, data, i := &d.scan, d.data, d.off
	for i < len(data) {
		newOp := s.step(s, data[i])
		i++
		if newOp != op {
			d.opcode = newOp
			d.off = i
			return
		}
	}

	d.off = len(data) + 1 // mark processed EOF with len+1
	d.opcode = d.scan.eof()
}
```

通过`d.scanWhile(scanSkipSpace)`来过滤掉前置空格，以获取到json数据的第一个状态以及位置。

### 解析value

对于json格式来说，有三种大的数据类型：数组、对象、字面量。因此，解析的开始一定会是scanBeginArray、scanBeginObject或者scanBeginLiteral这三种状态之一。

_删除了部分非关键代码_

```go
func (d *decodeState) value(v reflect.Value) error {
	switch d.opcode {
	default:
		panic(phasePanicMsg)

	case scanBeginArray:
		if v.IsValid() {
			if err := d.array(v); err != nil {
				return err
			}
		} else {
			d.skip()
		}
		d.scanNext()

	case scanBeginObject:
		if v.IsValid() {
			if err := d.object(v); err != nil {
				return err
			}
		} else {
			d.skip()
		}
		d.scanNext()

	case scanBeginLiteral:
		// All bytes inside literal return scanContinue op code.
		start := d.readIndex()
		d.rescanLiteral()

		if v.IsValid() {
			if err := d.literalStore(d.data[start:d.readIndex()], v, false); err != nil {
				return err
			}
		}
	}
	return nil
}
```

### 解析字面量

在解析字面量之前，需要获取字面量所在的字符串。字面量第一个字节在json的索引值已经知道（通过状态机扫描到的offset-1），最后一个索引则根据字面量的规则来找到最后一个字面量字节所在的索引。

```go
func (d *decodeState) rescanLiteral() {
	data, i := d.data, d.off
Switch:
	switch data[i-1] {
	case '"': // string
		for ; i < len(data); i++ {
			switch data[i] {
			case '\\':
				i++ // escaped char
			case '"':
				i++ // tokenize the closing quote too
				break Switch
			}
		}
	case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '-': // number
		for ; i < len(data); i++ {
			switch data[i] {
			case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
				'.', 'e', 'E', '+', '-':
			default:
				break Switch
			}
		}
	case 't': // true
		i += len("rue")
	case 'f': // false
		i += len("alse")
	case 'n': // null
		i += len("ull")
	}
	if i < len(data) {
		d.opcode = stateEndValue(&d.scan, data[i])
	} else {
		d.opcode = scanEnd
	}
	d.off = i + 1
}
```

获取到字面量所在的索引后，现在需要将这个数据通过反射设置到指定字段上去。

```go
func (d *decodeState) literalStore(item []byte, v reflect.Value, fromQuoted bool) error {
	isNull := item[0] == 'n' // null
	// 检查v是否有自己的json解析器，或者text解析器，都不存在的话会获取v的非指针类型数据
	u, ut, pv := indirect(v, isNull)
	if u != nil {
		// 如果存在自定义的json解析器，则使用自定义解析器
		return u.UnmarshalJSON(item)
	}
	if ut != nil {
		// 如果不存在自定义json解析器，但是存在text解析器，则使用text解析器。
		s, ok := unquoteBytes(item)
		if !ok {
			if fromQuoted {
				return fmt.Errorf("json: invalid use of ,string struct tag, trying to unmarshal %q into %v", item, v.Type())
			}
			panic(phasePanicMsg)
		}
		return ut.UnmarshalText(s)
	}

	v = pv

	switch c := item[0]; c {
	case 'n': // null
		// 只能是null，否则不符合预期，返回错误
		if fromQuoted && string(item) != "null" {
			d.saveError(fmt.Errorf("json: invalid use of ,string struct tag, trying to unmarshal %q into %v", item, v.Type()))
			break
		}
		switch v.Kind() {
		// 只会对interface{}、指针、map和slice进行初始化为零值，字面量（数字、字符串、布尔等）直接忽略
		case reflect.Interface, reflect.Pointer, reflect.Map, reflect.Slice:
			v.Set(reflect.Zero(v.Type()))
		}
	case 't', 'f': // true, false
		value := item[0] == 't'
		// 只能是true或者false，否则返回错误
		if fromQuoted && string(item) != "true" && string(item) != "false" {
			d.saveError(fmt.Errorf("json: invalid use of ,string struct tag, trying to unmarshal %q into %v", item, v.Type()))
			break
		}
		switch v.Kind() {
		default:
			if fromQuoted {
				d.saveError(fmt.Errorf("json: invalid use of ,string struct tag, trying to unmarshal %q into %v", item, v.Type()))
			} else {
				d.saveError(&UnmarshalTypeError{Value: "bool", Type: v.Type(), Offset: int64(d.readIndex())})
			}
		case reflect.Bool:
			// 设置值
			v.SetBool(value)
		case reflect.Interface:
			// 如果是简单类型，那么直接设置值，否则报错
			if v.NumMethod() == 0 {
				v.Set(reflect.ValueOf(value))
			} else {
				d.saveError(&UnmarshalTypeError{Value: "bool", Type: v.Type(), Offset: int64(d.readIndex())})
			}
		}

	case '"': // string
		s, ok := unquoteBytes(item)
		if !ok {
			if fromQuoted {
				return fmt.Errorf("json: invalid use of ,string struct tag, trying to unmarshal %q into %v", item, v.Type())
			}
			panic(phasePanicMsg)
		}
		switch v.Kind() {
		default:
			d.saveError(&UnmarshalTypeError{Value: "string", Type: v.Type(), Offset: int64(d.readIndex())})
		case reflect.Slice:
			if v.Type().Elem().Kind() != reflect.Uint8 {
				d.saveError(&UnmarshalTypeError{Value: "string", Type: v.Type(), Offset: int64(d.readIndex())})
				break
			}
			b := make([]byte, base64.StdEncoding.DecodedLen(len(s)))
			n, err := base64.StdEncoding.Decode(b, s)
			if err != nil {
				d.saveError(err)
				break
			}
			v.SetBytes(b[:n])
		case reflect.String:
			if v.Type() == numberType && !isValidNumber(string(s)) {
				return fmt.Errorf("json: invalid number literal, trying to unmarshal %q into Number", item)
			}
			v.SetString(string(s))
		case reflect.Interface:
			if v.NumMethod() == 0 {
				v.Set(reflect.ValueOf(string(s)))
			} else {
				d.saveError(&UnmarshalTypeError{Value: "string", Type: v.Type(), Offset: int64(d.readIndex())})
			}
		}

	default: // number
		if c != '-' && (c < '0' || c > '9') {
			if fromQuoted {
				return fmt.Errorf("json: invalid use of ,string struct tag, trying to unmarshal %q into %v", item, v.Type())
			}
			panic(phasePanicMsg)
		}
		s := string(item)
		switch v.Kind() {
		default:
			if v.Kind() == reflect.String && v.Type() == numberType {
				// s must be a valid number, because it's
				// already been tokenized.
				v.SetString(s)
				break
			}
			if fromQuoted {
				return fmt.Errorf("json: invalid use of ,string struct tag, trying to unmarshal %q into %v", item, v.Type())
			}
			d.saveError(&UnmarshalTypeError{Value: "number", Type: v.Type(), Offset: int64(d.readIndex())})
		case reflect.Interface:
			n, err := d.convertNumber(s)
			if err != nil {
				d.saveError(err)
				break
			}
			if v.NumMethod() != 0 {
				d.saveError(&UnmarshalTypeError{Value: "number", Type: v.Type(), Offset: int64(d.readIndex())})
				break
			}
			v.Set(reflect.ValueOf(n))

		case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
			n, err := strconv.ParseInt(s, 10, 64)
			if err != nil || v.OverflowInt(n) {
				d.saveError(&UnmarshalTypeError{Value: "number " + s, Type: v.Type(), Offset: int64(d.readIndex())})
				break
			}
			v.SetInt(n)

		case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64, reflect.Uintptr:
			n, err := strconv.ParseUint(s, 10, 64)
			if err != nil || v.OverflowUint(n) {
				d.saveError(&UnmarshalTypeError{Value: "number " + s, Type: v.Type(), Offset: int64(d.readIndex())})
				break
			}
			v.SetUint(n)

		case reflect.Float32, reflect.Float64:
			n, err := strconv.ParseFloat(s, v.Type().Bits())
			if err != nil || v.OverflowFloat(n) {
				d.saveError(&UnmarshalTypeError{Value: "number " + s, Type: v.Type(), Offset: int64(d.readIndex())})
				break
			}
			v.SetFloat(n)
		}
	}
	return nil
}
```

### 解析对象和数组

对象和数组也是一样的逻辑，只是要遍历其中的字段，因此逻辑上更复杂。
