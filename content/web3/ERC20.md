---
date: 2024-08-05T01:43:00+08:00
title: 'ERC20'
url: '/web3/erc20'
toc: true
draft: false
description: 'erc20研究'
slug: 'erc20'
tags: ['web3', 'ethereum', 'erc20', 'blockchain']
showDateUpdated: true
---

## 什么是ERC20

`ERC20`是以太坊上的一种**代币标准**，它规定了代币的基本功能和接口，使得代币可以在以太坊上流通。

### 名称起源

`ERC20`是以太坊请求评论（Ethereum Request for Comments）的第20号提案，所以叫`ERC20`。

### 背景

在`ERC20`以前，人们通过智能合约在以太坊上创建自己的token，但是交易很不方便。这主要是因为没有统一的方法：想象一下，如果你想把自己的token放到交易所去，那么交易所还要根据你的代码来调对应的方法进行交易，这样token种类一多，交易所就会很麻烦。因此`ERC20`提供了一套统一的方法来抽象token行为，方便人们对接、交易。

## 源码解析

### ERC20接口

[代码来源](https://app.dedaub.com/ethereum/address/0xb713f1739bc3602efc6c1f26343265d5fa26bc12/source)

```solidity
// ERC20 standard interface definition
interface IERC20 {
    // Token transfer event
    event Transfer(address indexed from, address indexed to, uint256 value);
    // Approval event
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Function to get the total supply
    function totalSupply() external view returns (uint256);
    // Function to get the balance of an account
    function balanceOf(address account) external view returns (uint256);
    // Function to transfer tokens
    function transfer(address recipient, uint256 amount) external returns (bool);
    // Function to get the allowance
    function allowance(address owner, address spender) external view returns (uint256);
    // Function to approve spending
    function approve(address spender, uint256 amount) external returns (bool);
    // Function to transfer tokens on behalf of an owner
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}
```

实现`ERC20`需要实现两个事件和六个方法。

- `Transfer`: 代币转账事件
- `Approval`: 代币授权事件
- `totalSupply`: 获取代币总量
- `balanceOf`: 获取账户余额
- `transfer`: 代币转账
- `allowance`: 获取授权额度
- `approve`: 授权额度
- `transferFrom`: 代币转账

### 合约默认逻辑

`ERC20`提供了一套默认的实现：

```solidity
// Context abstract contract for the current message sender and data
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// Ownable contract managing ownership
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    // Function to transfer ownership
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// ERC20 token contract
contract ERC20 is Context, IERC20, Ownable {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;

    // Constructor with the ability to set the initial owner and token distribution
    constructor(string memory name_, string memory symbol_, uint256 totalSupply_, address initialOwner)
        Ownable(initialOwner) {
        require(initialOwner != address(0), "ERC20: initial owner is the zero address");

        _name = name_;
        _symbol = symbol_;
        _totalSupply = totalSupply_;
        // Assign the total supply to the initial owner
        _balances[initialOwner] = totalSupply_;
        emit Transfer(address(0), initialOwner, totalSupply_);
    }

    // Function to get the token name
    function name() public view returns (string memory) {
        return _name;
    }

    // Function to get the token symbol
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    // Function to get the total supply
    function totalSupply() public override view returns (uint256) {
        return _totalSupply;
    }

    // Function to get an account's balance
    function balanceOf(address account) public override view returns (uint256) {
        return _balances[account];
    }

    // Function to transfer tokens
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    // Function to get the allowance
    function allowance(address owner, address spender) public override view returns (uint256) {
        return _allowances[owner][spender];
    }

    // Function to approve spending
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    // Function for a delegate to transfer tokens
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        // Decrease the spender's allowance
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    // Internal transfer logic
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(_balances[sender] >= amount, "ERC20: transfer amount exceeds balance");

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    // Internal approve logic
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
```

代码定义了构造器函数以及接口的基本实现。
值得一提的是余额与授权额度的存储，都是通过字典来实现的：

```solidity
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
```

因为字典的查找时间复杂度是O(1)，所以这样的设计是非常高效的, 而高效就意味着更少的`gas`。

## 实例-BNB

可以在[etherscan](https://etherscan.io/address/0xb8c77482e45f1f44de1745f52c74426c631bdd52#code)上找到`BNB`的合约代码：

```solidity
/**
 *Submitted for verification at Etherscan.io on 2017-07-06
*/

pragma solidity ^0.4.8;

/**
 * Math operations with safety checks
 */
contract SafeMath {
  function safeMul(uint256 a, uint256 b) internal returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function safeDiv(uint256 a, uint256 b) internal returns (uint256) {
    assert(b > 0);
    uint256 c = a / b;
    assert(a == b * c + a % b);
    return c;
  }

  function safeSub(uint256 a, uint256 b) internal returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function safeAdd(uint256 a, uint256 b) internal returns (uint256) {
    uint256 c = a + b;
    assert(c>=a && c>=b);
    return c;
  }

  function assert(bool assertion) internal {
    if (!assertion) {
      throw;
    }
  }
}
contract BNB is SafeMath{
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
	address public owner;

    /* This creates an array with all balances */
    mapping (address => uint256) public balanceOf;
	mapping (address => uint256) public freezeOf;
    mapping (address => mapping (address => uint256)) public allowance;

    /* This generates a public event on the blockchain that will notify clients */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /* This notifies clients about the amount burnt */
    event Burn(address indexed from, uint256 value);

	/* This notifies clients about the amount frozen */
    event Freeze(address indexed from, uint256 value);

	/* This notifies clients about the amount unfrozen */
    event Unfreeze(address indexed from, uint256 value);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function BNB(
        uint256 initialSupply,
        string tokenName,
        uint8 decimalUnits,
        string tokenSymbol
        ) {
        balanceOf[msg.sender] = initialSupply;              // Give the creator all initial tokens
        totalSupply = initialSupply;                        // Update total supply
        name = tokenName;                                   // Set the name for display purposes
        symbol = tokenSymbol;                               // Set the symbol for display purposes
        decimals = decimalUnits;                            // Amount of decimals for display purposes
		owner = msg.sender;
    }

    /* Send coins */
    function transfer(address _to, uint256 _value) {
        if (_to == 0x0) throw;                               // Prevent transfer to 0x0 address. Use burn() instead
		if (_value <= 0) throw;
        if (balanceOf[msg.sender] < _value) throw;           // Check if the sender has enough
        if (balanceOf[_to] + _value < balanceOf[_to]) throw; // Check for overflows
        balanceOf[msg.sender] = SafeMath.safeSub(balanceOf[msg.sender], _value);                     // Subtract from the sender
        balanceOf[_to] = SafeMath.safeAdd(balanceOf[_to], _value);                            // Add the same to the recipient
        Transfer(msg.sender, _to, _value);                   // Notify anyone listening that this transfer took place
    }

    /* Allow another contract to spend some tokens in your behalf */
    function approve(address _spender, uint256 _value)
        returns (bool success) {
		if (_value <= 0) throw;
        allowance[msg.sender][_spender] = _value;
        return true;
    }


    /* A contract attempts to get the coins */
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        if (_to == 0x0) throw;                                // Prevent transfer to 0x0 address. Use burn() instead
		if (_value <= 0) throw;
        if (balanceOf[_from] < _value) throw;                 // Check if the sender has enough
        if (balanceOf[_to] + _value < balanceOf[_to]) throw;  // Check for overflows
        if (_value > allowance[_from][msg.sender]) throw;     // Check allowance
        balanceOf[_from] = SafeMath.safeSub(balanceOf[_from], _value);                           // Subtract from the sender
        balanceOf[_to] = SafeMath.safeAdd(balanceOf[_to], _value);                             // Add the same to the recipient
        allowance[_from][msg.sender] = SafeMath.safeSub(allowance[_from][msg.sender], _value);
        Transfer(_from, _to, _value);
        return true;
    }

    function burn(uint256 _value) returns (bool success) {
        if (balanceOf[msg.sender] < _value) throw;            // Check if the sender has enough
		if (_value <= 0) throw;
        balanceOf[msg.sender] = SafeMath.safeSub(balanceOf[msg.sender], _value);                      // Subtract from the sender
        totalSupply = SafeMath.safeSub(totalSupply,_value);                                // Updates totalSupply
        Burn(msg.sender, _value);
        return true;
    }

	function freeze(uint256 _value) returns (bool success) {
        if (balanceOf[msg.sender] < _value) throw;            // Check if the sender has enough
		if (_value <= 0) throw;
        balanceOf[msg.sender] = SafeMath.safeSub(balanceOf[msg.sender], _value);                      // Subtract from the sender
        freezeOf[msg.sender] = SafeMath.safeAdd(freezeOf[msg.sender], _value);                                // Updates totalSupply
        Freeze(msg.sender, _value);
        return true;
    }

	function unfreeze(uint256 _value) returns (bool success) {
        if (freezeOf[msg.sender] < _value) throw;            // Check if the sender has enough
		if (_value <= 0) throw;
        freezeOf[msg.sender] = SafeMath.safeSub(freezeOf[msg.sender], _value);                      // Subtract from the sender
		balanceOf[msg.sender] = SafeMath.safeAdd(balanceOf[msg.sender], _value);
        Unfreeze(msg.sender, _value);
        return true;
    }

	// transfer balance to owner
	function withdrawEther(uint256 amount) {
		if(msg.sender != owner)throw;
		owner.transfer(amount);
	}

	// can accept ether
	function() payable {
    }
}
```

整体的代码非常少，只有100多行。而且逻辑也非常清晰：

1. 首先定义了能够安全运行的数学计算
2. 通过`mapping`定义了账户余额、冻结余额和授权额度
3. 通过构造函数定义了代币的基本信息：Symbol,Name,Decimals,TotalSupply
4. 另外还定义了冻结、销毁等功能。

> 尽管`solidity`是图灵完备的语言，但是智能合约往往都非常简洁。这样一方面是为了减少操作带来的gas消耗，另一方面也是为了减少bug。

## 问题

### ERC20与ETH的区别是什么？

两者都是以太坊上的token，且都能够进行交易。但两者的价值来源不同。

Either(ETH)是以太坊的原生token，通过共识协议(POW/POS)产生，它的价格在一定程度上代表了以太坊的价值。

`ERC20`是通过智能合约发行的token，它代表的是其发行平台的价值。就像上市公司的股票一样，token对应的是公司股票，平台可以通过发行自己的token来“融资”。

### 可以定义相同Symbol的token吗？

可以，但是不推荐。交易时通过合约地址（而不是Symbol）来定位token，因此相同Symbol的token只会加重拥有者的心智负担。

## 相关阅读

- [What Are ERC-20 Tokens on the Ethereum Network?](https://www.investopedia.com/news/what-erc20-and-what-does-it-mean-ethereum/)
