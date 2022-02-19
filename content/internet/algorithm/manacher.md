+++

date = 2022-02-12T16:32:00+08:00
title = "Manacher算法"
url = "/internet/algorithm/manacher"

toc = true

+++



## Manacher算法是什么

Manacher算法俗称马拉车算法，用于解决**在一个字符串中找到最长的回文子串问题**。

**回文串**”是一个正读和反读都一样的**字符串**，如level，noon等都是回文串。

## 基础思路-中心扩展

为了找到最长的回文串，需要先找到回文串的中心，然后从中心向外扩展。

```go
// 例如我们找到中心处的索引为mid,那么找到以mid为中心的回文串的逻辑代码为：
func findPalindrome(s string, mid int) string{
	l,r := mid-1, mid+1
    for ; l >= 0 && r < len(s); l,r = l-1, r+1 {
		if s[l] != s[r] {
			break
		}
	}
    return s[l+1: r]
}
```

需要注意**中心处可能是一个元素（如aba），也可能是两个元素（如abba）**。所以上述函数要优化为

```go
func findPalindrome(s string, l, r int) string {
	for ; l >= 0 && r < len(s); l,r = l-1, r+1 {
		if s[l] != s[r] {
			break
		}
	}
	return s[l+1: r]
}
```

那么一个完整的找最长回文子串的算法为

```go
func findPalindrome(s string, l, r int) string {
	for ; l >= 0 && r < len(s); l,r = l-1, r+1 {
		if s[l] != s[r] {
			break
		}
	}
	return s[l+1: r]
}

func findLongestPalindrome(s string) string{
	if len(s) <= 1 {
		return s
	}
	var result string
	for i := 0; i <len(s)-1; i++ {
		s1 := findPalindrome(s, i, i)
		s2 := findPalindrome(s, i, i+1)
		if len(s1) < len(s2) {
			s1 = s2
		}
		if len(s1) > len(result) {
			result = s1
		}
	}
	return result
}
```

时间复杂度为O(n^2)

## Manacher算法

### 改造字符串，避免中心元素为偶数个

在“中心扩展”算法中每次都要“猜测”中心元素是奇数还是偶数，Manacher算法将原字符串改造后避免了这个问题。改造逻辑为：**在元素间镶嵌特殊字符井号符(#)**，如：

- 原字符串为`abba`，改造后为`a#b#b#a`，中间元素为第二个`#`
- 原字符串为`aba`，改造后为`a#b#a`，中间元素为`b`

因此改造后的字符串能够避免“猜测”中心元素是奇数还是偶数。

### 继续改造，增加哨兵以避免边界问题

如“中心扩展”算法中，对于l和r两个变量每次都要校验以避免溢出边界。

Manacher算法在**字符串前后增加两个不同的特殊字符作为哨兵**，当`l`或者`r`到达哨兵处时，与另一元素相比总是不等，因此不用每次都校验l和r是否溢出边界。

一般前哨兵采用`^`，后哨兵采用`$`。

根据“老规矩”，元素之间要加井号符（其实是为了保证原字符串以首字符为中心的回文子串的半径长度为1），因此：

- 原字符串为`aba`，改造后为`^#a#b#a#$`，中间元素为`b`，`^#a#b`中以`a`为中心的回文串半径长度为1

改造代码为：

```go
func preProcess(s string) string {
   if len(s) == 0 {
      return "^$"
   }
   result := []byte("^")
   for _, v := range s {
      result = append(result, '#', byte(v))
   }
   result = append(result, '#', '$')
   return string(result)
}
```

### 利用已有经验，引入回环长度数组

有了改造后的字符串`rebuild`后，我们开始根据“中心”元素找其回环长度。

假设改造后的字符串为`^#a#b#c#b#a#$`。

按照以往经验，我们需要从左到右遍历字符串，利用“中心扩展”算法找到已当前元素为中心的最长回环串。

```go
for i := 1; i < len(rebuild)-1; i++ { // 首尾两个哨兵不用管
	...
}
```

当我们遍历到第二个b时，此时已知的最长回环串为`#a#b#c#b#a#`，中心为字符`c`。我们既然已经知道`#a#b#c`与`c#b#a#`是镜像关系，那么`前边的b`应该和`后边的b`的回环是**相同**的。因此以`第二个字符b`为中心的回环是**不用计算**的。

于是我们引入`回环长度数组p`，p中的元素与改造后的字符串字符一一对应，值为以其为中心的**回环的半径长度**。

| i              | 0    | 1    | 2    | 3    | 4    | 5    | 6    | 7    | 8    | 9    | 10   | 11   | 12   |
| -------------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| 改造后的字符串 | ^    | #    | a    | #    | b    | #    | c    | #    | b    | #    | a    | #    | $    |
| 回环长度数组p  | -    | 0    | 1    | 0    | 1    | 0    | 3    | 0    | 1    | 0    | 1    | 0    | -    |

当我们遍历到第`9`（i=8）个字符时，其值`p[i]`等于其以当前右边界最大的回环串（`#a#b#c#b#a#`）的中心（字符`c`）的**镜像字符**（i=4）的值，即`p[8] = p[4]`.

> 当前索引的镜像索引 等于 当前最长回环字符中心索引 乘以 2 减去当前索引
>
> `iMirror = mid * 2 - i`

**这种“已有经验”不是随时都能使用的**，需要考虑其边界：

- 如果**当前索引已经超出了已知的回环串的右边界**，如计算第`5`（i=4）个字符`b`时，就没有办法利用已有经验（最长回环串`#a#`的经验对其没有任何作用）。所以在代码中我们需要用一个变量`rMax`标识当前“右边界”，当当前索引超过了`rMax`后，我们就只能**将当前元素作为中心进行“中心扩展”**。

  ```go
  if i > rMax {
  	p[i] = 0
  	for rebuild[i+p[i]] == rebuild[i-p[i]] { // 因为哨兵一定与其他元素不等，因此无需考虑边界溢出
  		p[i]++
      }
  }
  ```

- 能找到其镜像索引也不表示其值就等于镜像索引的值

  - 如果其镜像处于回文子串内，此时**其“保底”值为镜像索引的值**。如字符串`^#c#c#c#c#c#c#$`，`第三个c`虽然能够根据历史经验`#c#c#c#`找到其镜像索引（`第一个c`）的值，但是其仍可以“**向外扩展**”。
  - 如果镜像值不是当前`rMax`所在的回文子串对应的值，即**镜像值对应的回文串超出了rMax所在的回文串**，那么就不能取镜像值。由于**对称性**可知**当前索引到右边界的长度即为其保底半径长度**。

  ```go
  if i <= rMax {
  	p[i] = min(rMax-i, p[mid*2-i]) // 借鉴下历史经验——镜像值,如果镜像值超过rMax-i，说明借鉴的不是当前的历史经验
  	for rebuild[i+p[i]] == rebuild[i-p[i]] {
  		p[i]++
      }
  }
  ```

#### 动态更新右边界和中心索引

随着遍历的进行，回环串的长度越来越大，回环串的中心索引`min`与右边界`rMax`的值也要随时更新。此时比较的条件是回环串的右边界`rMax`而不是中心索引`mid`，因为我们能够使用的“已有经验”就是`rMax`内的回环串

```go
// 右边界`rMax`与其中心索引`mid`的关系为
// rMax = mid + p[mid] // 右边界索引 = 当前中心索引+半径长度
if i + p[i] > rMax {
	mid = i
	rMax = mid + p[mid]
}
```

### 根据回环长度数组找到最长回环子串

在改造后的字符串中，对于每个回环子串，每半边的真实元素与井号符的数量相同，因此此时的半径长度就是真实的回环串的长度）

| i                    | 0    | 1    | 2    | 3    | 4    | 5    | 6    | 7    | 8    | 9    | 10   | 11   | 12   |
| -------------------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| 改造后的字符串       | ^    | #    | a    | #    | b    | #    | c    | #    | b    | #    | a    | #    | $    |
| 回环长度数组p        | -    | 0    | 1    | 0    | 1    | 0    | 3    | 0    | 1    | 0    | 1    | 0    | -    |
| 原始字符串的回环长度 |      |      | 1    |      | 1    |      | 3    |      | 1    |      | 1    |      |      |
| 对应原始字符串的索引 |      |      | 0    |      | 1    |      | 2    |      | 3    |      | 4    |      |      |

> 原始字符串的索引`j`对应改造后的字符串索引`i`的关系为 `j = i/2-1`
>
> 当**中心索引**位于**井号符**时
>
> - 说明对应的原始回文子串的中心元素有两个
> - 此时改造后的回文字符串的半径maxLen为**偶数**，正好等于其原始回文子串的元素数量
> - 对应的原始回文子串的左中心索引为 (centerIdx-1)/2-1，由因为**井号符都位于奇数位**，因此(centerIdx-1)/2-1 = centerIdx/2-1
> - **对应的原始回文子串的起始索引**为 centerIdx/2-1 - (maxLen/2-1) = `(centerIdx-maxLen)/2`
>
> 当**中心索引**位于**非井号符**时
>
> - 说明对应的原始回文子串的中心元素只有一个
>
> - 此时改造后的回文字符串的半径maxLen为**奇数**，正好等于其原始回文子串的元素数量
>
> - 对应的原始回文子串的中心索引为 centerIdx/2-1，centerIdx一定为偶数，因为所有**非井号符都位于偶数位**
> - **对应的原始回文子串的起始索引**为 centerIdx/2-1 - (maxLen-1)/2 = (centerIdx-2-maxLen+1)/2 = (centerIdx-maxLen-1)/2，由上可知centerIdx与maxLen相减一定是奇数，因此（centerIdx-maxLen-1)/2 = （centerIdx-maxLen)/2
>
> 综上，根据改造后的中心索引centerIdx和最大回文子串半径maxLen能够获得**原始字符串的起始索引**为 `startIdx := (centerIdx- length)/2`，对应的**原始回文子串**为`s[startIdx: startIdx+maxLen]`

```go
var (
    maxLen = 0
    centerIdx = 0
)
for i := 1; i < len(p) -1; i++ {
    if p[i] > maxLen {
        maxLen = p[i]
        centerIdx = i
    }
}
startIdx := (centerIdx - maxLen)/2
result := s[startIdx: startIdx+maxLen]
```

### 综合

综合以上内容，完整算法即为

```go
func manacher(s string) string {
	rebuild := preProcess(s)
	var (
		rMax = 0 // 当前右边界
		p = make([]int, len(rebuild)) // 回环长度数组
		mid = 0 // 当前右边界为rMax的回环子串的中心索引
	)
	for i := 1; i < len(rebuild)-1; i++ { // 首尾两个哨兵不用管
		if i > rMax { // 没有经验可供借鉴，需要从零开始进行中心扩展
			p[i] = 0
		}else {
			p[i] = min(rMax-i, p[mid*2-i]) // 借鉴下历史经验——镜像值,如果镜像值超过rMax-i，说明借鉴的不是当前的历史经验
		}
		// 中心扩展
		for rebuild[i+p[i]+1] == rebuild[i-p[i]-1] { // 因为哨兵一定与其他元素不等，因此无需考虑边界溢出
			p[i]++
		}
		// 动态更新右边界和中心索引
		if i + p[i] > rMax {
			mid = i
			rMax = mid + p[mid] // 右边界索引 = 当前中心索引+半径长度
		}
	}
	var (
		maxLen = 0
		centerIdx = 0
	)
	for i := 1; i < len(p) -1; i++ {
		if p[i] > maxLen {
			maxLen = p[i]
			centerIdx = i
		}
	}
	startIdx := (centerIdx - maxLen)/2
	return s[startIdx: startIdx+maxLen]
}

func preProcess(s string) string {
   if len(s) == 0 {
      return "^$"
   }
   result := []byte("^")
   for _, v := range s {
      result = append(result, '#', byte(v))
   }
   result = append(result, '#', '$')
   return string(result)
}
```

## 扩展

### 统计字符串中回文子串的数量

[leetcode第647题](https://leetcode-cn.com/problems/palindromic-substrings)要求统计字符串中回文子串的数量，能否利用Manacher算法解决？

虽然Manacher算法解决的是找到最长回文子串问题，但是其构建的回文长度数组能够帮助我们解决回文子串的数量问题（回文子串的数量等于其长度除以2后的向上取整值）。

```go
cnt := 0
for _, v := range p {
	cnt += (v+1)/2 // v/2的向上取整 = (v+1)/2
}
```

这种利用中间状态或者数据的算法很常见，如在一个数组中找到中位数时可以使用快速排序时的partition。

## 相关资料

- [Manacher 算法详解](https://www.acwing.com/file_system/file/content/whole/index/content/446985/#fn:1)
- [动图](http://manacher-viz.s3-website-us-east-1.amazonaws.com/#/)
