+++

date = 2022-01-28T16:32:00+08:00
title = "KMP算法"
url = "/internet/algorithm/kmp"

toc = true

+++



## 背景

在做L[eetCode第572题——另一颗树的子树](https://leetcode-cn.com/problems/subtree-of-another-tree/)时，我看到题解上说可以用KMP算法来解决。虽然以前了解过KMP算法，但是遇到问题时还是对算法的思路、如何实现一头雾水，因此写篇文章总结下。

## KMP是什么

KMP是由三位作者的名称首字母组成的单词。KMP的目的是解决子串查找问题。

## KMP演化

如果只看KMP算法的代码，会很难理解，因此我们从头来演化KMP的思路。

既然KMP算法要解决的是子串查找问题，那我们就从最无脑的暴力破解算法说起。在此之前，我们要规定几个概念。

### 基础概念

- **模式字符串**：要匹配的字符串模板。通常是在初始化时处理的数据。
- **匹配字符串**：要根据模式字符串去匹配的目的字符串。通常是输入数据。往往需要找到和模式字符串相同的子串的首字母索引——即在匹配字符串中找到模式字符串。

### 最无脑的算法

把匹配字符串看做是一把完整的尺子，把模式字符串看做是一把残尺。尺子上的刻度数字都是随机数字。

固定好完整的尺子，将残尺从完整的尺子的第一个刻度处开始比较，如果不匹配就把残尺往后移动一位。直到找到匹配的位置。

```go
func violentSearchSubStr(txt, pat string) int {
    for i := 0; i < len(txt) - len(pat)+1; i++ {
        j := 0
        for ; j < len(pat); j++ {
            if txt[i+j] != pat[j] {
                break
            }
        }
        if j == len(pat) {
            return i
        }
    }
    return -1
}
```

### 利用已有的经验——部分匹配表PMT

在“最无脑的算法”中，每次匹配失败都会将残尺往后移动一位。假设残尺上有10个数字，匹配失败时是在匹配第10个数字时失败，那么这10次匹配经验就浪费掉了。

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/20220206224422.png)

模式字符串的前四个数字为3153，最后匹配的匹配字符串的四个字符串也是3153，因此，我们可以直接将残尺的3153和完整尺的3153对齐，即可以直接移动六位。

显然，利用历史经验一次性移动六位要比移动一位的效率高很多。那么如何利用这些匹配经验，将残尺多移动几位？

于是问题转换为：假设残尺需要移动的位数为M，移动后残尺的前N位能够匹配，如何利用已知条件求出最大的M？

大佬们为此设计了部分匹配表（Partial Match Table）：PMT是一个数组，长度与模式字符串相同。每个元素对应的是其在模式字符串对应的字符串前缀中前后对称的字符的个数。例如：对于第4个元素来说，其对应的模式字符串前缀为3153，其前后对称的字符为3，个数为1；对于第5个元素来说，其对应的模式字符串的前缀为31531，其前后对称的字符为3和1，个数为2，因此可以得到PMT：

![](https://raw.githubusercontent.com/stong1994/images/master/picgo/20220206224651.png)

#### 如何使用PMT

我们在第10个字符匹配时匹配失败，这个时候就能够看到第9个字符对应的PMT的元素为3，即前后匹配的字符为3、1、5三个，那么我们就能够把残尺移动六（9-3）位，并从第四（3+1）个元素处开始匹配。

```
func match(txt, pat string) int{
	pmt := getPMT(pat)
	i, j := 0, 0 // i、j分别为txt和pat当前匹配的索引
	for i < len(txt) && j < len(pat) {
		if txt[i] == pat[j] {
			i++
			j++
			continue
		}
		if j == 0 { // j为0，说明子串中没有能够匹配的前后缀，直接将残尺移动一位
			i++
			continue
		}
		j = pmt[j-1]
	}
	if j == len(pat) {
		return i-j
	}
	return -1
}
```

#### 如何获取PMT

找到一个字符串中前缀和后缀匹配的长度只需要在字符串的前半部分中逆序遍历，找到和字符串的最后一个字符相同的字符，假设这个字符的索引为i，然后再判断0到i的字符是否和最后i个字符相同即可。如果PMT中每个元素的值都是这样计算，那么时间复杂度无疑很高。

可以利用“动态规划“中找子问题的方式找到求PMT的子问题：初始化两个指针i和j分别对应于遍历过程中模式字符串的索引和已匹配的前缀的索引，如果第i个字符和第j个字符相同，那么当前能够匹配的前缀和后缀的长度等于j；如果不同，那么就将第i个字符和第pmt[j]个字符进行比较。

```go
func getPMT(pat string) []int{
	pmt := make([]int, len(pat))
	pmt[0] = 0 // 一个字符没有前缀和后缀（由如何使用决定第一个元素的值为0）
    i, j := 1, 0
    for i < len(pat) {
		if pat[i] == pat[j] {
			j++ // 长度等于索引+1
            pmt[i] = j
            i++
            continue
		}
        if j == 0 {
            pmt[i] = 0
            i++
            continue
        }
        j = pmt[j-1]
	}
    return pmt
}
```

这里的关键是当第i个字符和第j个字符不同时，为什么要比较第i个字符和第pmt[j]个字符。此时有两种情况

- 假设第i-1个字符和第j-1个字符不同，那么pmt[j-1]等于0，此时相当于从头进行匹配。

- 假设第i-1个字符和第j-1个字符相同，那么也就是说在前i-1个字符中，有pmt[j-1]个字符的前缀和后缀是相等的。此时我们就可以比较第pmt[j-1]+1个字符是否和第i个字符相等，如果相等，那么pm[j-1]+1就是前i个字符前后匹配的最大长度。以此类推。

### 更直观的next数组

每当匹配失败时，都需要获取前一个字符对应的pmt的值，业内往往将pmt数组转化为next数组来避免`j-1`。

```go
func getNext(pat string) []int{
	next := make([]int, len(pat))
	next[0] = 0
	i, j := 1, 0
    for i < len(pat)-1 { // 可知next数组和pat的最后一个字符无关
		if pat[i] == pat[j] {
			i++
			j++
			next[i] = j
			continue
		}
        j = next[j]
	}
    return next
}

func match(txt, pat string) int{
	next := getNext(pat)
	i, j := 0, 0 // i、j分别为txt和pat当前匹配的索引
	for i < len(txt) && j < len(pat) {
		if txt[i] == pat[j] {
			i++
			j++
			continue
		}
		if j == 0 { // j为0，说明子串中没有能够匹配的前后缀，直接将残尺移动一位
			i++
			continue
		}
		j = next[j]
	}
	if j == len(pat) {
		return i-j
	}
	return -1
}
```

初始化时将j赋值为-1能够进一步优化代码

```go
func getNext(pat string) []int{
	next := make([]int, len(pat))
	next[0] = -1
	i, j := 1, -1
    for i < len(pat)-1 { // 可知next数组和pat的最后一个字符无关
		if j == -1 || pat[i] == pat[j] {
			i++
			j++
			next[i] = j
			continue
		}
        j = next[j]
	}
	return next
}

func match(txt, pat string) int{
	next := getNext(pat)
	i, j := 0, 0 // i、j分别为txt和pat当前匹配的索引
	for i < len(txt) && j < len(pat) {
		if j == -1 || txt[i] == pat[j] {
			i++
			j++
		}else {
			j = next[j]
		}
	}
	if j == len(pat) {
		return i-j
	}
	return -1
}
```

## 总结

经过上面一系列推理就能够对代码中的一系列疑问，比如为什么要`j = next[j]`，j为什么要初始化为-1等待有了答案。

总的来说，KMP的设计思路就是利用已有的匹配成功的“经验”来定位模板字符串需要移动的位置，有点类似于动态规划中利用过往的计算结果来直接获取当前的计算结果。

我们经常说，历史给人类的最大教训就是人类从不吸取历史中的教训。而像KMP、动态规划这类算法的设计思路恰好就是合理的利用“历史的教训”。

## 最后

### 关于PMT

pmt是KMP算法中的核心，一般来说，pmt中的值会被解释为字符串中前缀和后缀能够匹配的最大长度，比如字符串abcabc对应的前后缀能够匹配的最大长度为3。让我们再看一个例子，字符串aaaa对应的pmt的值为多少？2或者3或者4？对前缀和后缀的定义不同会导致不同的结果，我们先看我们需要它是多少。已知匹配字符串为aaaabaaaac，模式字符串为aaaac，遍历到b时发现b不等于c，此时我们需要将模式串向右移动1位（前缀和后缀的匹配最大长度本可以是4，但是考虑到必须要移动，因此移动1位），此时的pmt对应的值为3(4-1)。

所以我们可以定义前缀和后缀：

- 前缀：排除掉字符串中最后一个字符的字符串
- 后缀：排除掉字符串中第一个字符的字符串



## 相关资料

- [KMP算法之求next数组代码讲解-bilibili](https://www.bilibili.com/video/BV16X4y137qw/?spm_id_from=333.788.recommend_more_video.2)
- [如何更好的掌握KMP-知乎](https://www.zhihu.com/question/21923021)

