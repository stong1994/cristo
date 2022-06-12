---
title: "Solidity笔记"
date: 2022-06-10T19:37:00+08:00
url: "/blockchain/solidity_note"
isCJKLanguage: true
draft: true
toc:  true
keywords:
  - solidity
authors:
  - atong
---



## 基础知识

### 数据类型

#### mapping

键值对存储/哈希表。

没有内置的查询长度的方法。

`mapping (string => address) public keyValueMap`

### 函数和构造函数

```solidity
func getPrice(address user) public view returns(int price, int status){}
```

- getPrice: 函数名称
- (address user) ：实参列表，用逗号间隔
- public：可见性修饰符
- view：可变性修饰符
- returns(int price, int status)：返回语句类型

构造函数用于设置初始状态，第一次创建合约时调用。

```
contract BoardAction {
	address public president;
	adddress public vicePresident;
	
	constructor(address initialPrisident, address initalVP) public {
		president = initialPrisident;
		vicePresident = initalVP;
	}
}
```



### 可见性和可变性修饰符

可见性-于函数：

- public: anyone
- internal：只能被合约中的另一个函数调用

可见性-于实例变量：

- public：会自动生成getter方法
- private：不会自动生成getter方法，只能在合约内使用

可变性：

- 默认：能够修改状态、调用其他函数
- view：不能修改状态、不能调用非view函数
- pure：甚至不能读取状态

### 访问区块链元数据

```
block.timestamp // 区块
```



### 使用内置货币

必须使用payable来声明函数

```
func pay(int amount) public payable {
	payable(msg.sender).transfer(amount)
}
```



### 事件

事件可以用于记录数据上链或者用做日志（开发时使用），一旦触发，事件订阅者就会接收到。

```
event Registered(address registrant, string domain);
func registerDomain(string memory domain) public {
	require(registry[domain] == address(0));
	registry[domain] = msg.sender;
	emit Registered(msg.sender, domain);
}
```

### 合约之间的交互



## EVM

## 相关资源

- [领取以太坊测试环境空头地址](https://faucets.chain.link)