---
date: 2024-08-06T01:43:00+08:00
title: 'NFT'
url: '/web3/nft'
toc: true
draft: false
description: 'nft研究'
slug: 'nft'
tags: ['web3', 'blockchain', 'nft', 'ethereum']
showDateUpdated: true
---

## 什么是NFT

`NFT`的全称是`Non-Fungible Token`，中文翻译为`非同质化代币`，是一种基于区块链技术的数字资产，它是一种独特的数字资产，不可替代，不可分割，具有独特性和稀缺性。NFT是一种数字资产，它可以代表任何具体的实物或虚拟物品，如艺术品、音乐、视频、游戏道具等，`NFT`可以用来证明数字资产的所有权和真实性。

## NFT的原理

### ERC721

我们在上一篇博客[ERC20](./ERC20.md)中介绍了`ERC20`, 实现了`ERC20`的token是**同质化**的——也就是说——就像你手中的百元钞票一样——它们具有等同的价值，因此可以进行自由互换。

实现了`ERC721`的token是**非同质化**的，这代表每个token都有自己的身份标识和价值，于是我们可以将一些资产信息记录到token上，通过将token放置到区块链上来实现资产的持有声明。

## 代码解析

[代码来源](https://eips.ethereum.org/EIPS/eip-721)

### 协议

```solidity
pragma solidity ^0.4.20;

/// @title ERC-721 Non-Fungible Token Standard
/// @dev See https://eips.ethereum.org/EIPS/eip-721
///  Note: the ERC-165 identifier for this interface is 0x80ac58cd.
interface ERC721 /* is ERC165 */ {
    /// @dev This emits when ownership of any NFT changes by any mechanism.
    ///  This event emits when NFTs are created (`from` == 0) and destroyed
    ///  (`to` == 0). Exception: during contract creation, any number of NFTs
    ///  may be created and assigned without emitting Transfer. At the time of
    ///  any transfer, the approved address for that NFT (if any) is reset to none.
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /// @dev This emits when the approved address for an NFT is changed or
    ///  reaffirmed. The zero address indicates there is no approved address.
    ///  When a Transfer event emits, this also indicates that the approved
    ///  address for that NFT (if any) is reset to none.
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    /// @dev This emits when an operator is enabled or disabled for an owner.
    ///  The operator can manage all NFTs of the owner.
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /// @notice Count all NFTs assigned to an owner
    /// @dev NFTs assigned to the zero address are considered invalid, and this
    ///  function throws for queries about the zero address.
    /// @param _owner An address for whom to query the balance
    /// @return The number of NFTs owned by `_owner`, possibly zero
    function balanceOf(address _owner) external view returns (uint256);

    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return The address of the owner of the NFT
    function ownerOf(uint256 _tokenId) external view returns (address);

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
    ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data) external payable;

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to "".
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;

    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;

    /// @notice Change or reaffirm the approved address for an NFT
    /// @dev The zero address indicates there is no approved address.
    ///  Throws unless `msg.sender` is the current NFT owner, or an authorized
    ///  operator of the current owner.
    /// @param _approved The new approved NFT controller
    /// @param _tokenId The NFT to approve
    function approve(address _approved, uint256 _tokenId) external payable;

    /// @notice Enable or disable approval for a third party ("operator") to manage
    ///  all of `msg.sender`'s assets
    /// @dev Emits the ApprovalForAll event. The contract MUST allow
    ///  multiple operators per owner.
    /// @param _operator Address to add to the set of authorized operators
    /// @param _approved True if the operator is approved, false to revoke approval
    function setApprovalForAll(address _operator, bool _approved) external;

    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `_tokenId` is not a valid NFT.
    /// @param _tokenId The NFT to find the approved address for
    /// @return The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 _tokenId) external view returns (address);

    /// @notice Query if an address is an authorized operator for another address
    /// @param _owner The address that owns the NFTs
    /// @param _operator The address that acts on behalf of the owner
    /// @return True if `_operator` is an approved operator for `_owner`, false otherwise
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

interface ERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceID The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}
```

整体上看，和`ERC20`的实现类似，只是`ERC721`是非同质化的，所以在`ERC721`中，我们需要定义一些新的方法，比如`ownerOf`、`getApproved`等。

数据存储方式也有了一些变化，在`ERC20`中，我们使用地址和余额构成的字典来存储余额；在`ERC721`中，我们使用地址和`tokenID`构成的字典来存储用户所持有的NFT(当然，这取决于具体的实现)。

## 问题

### NFT的应用场景有哪些

加密猫、无聊猿以及杰伦熊等等，这些都是NFT的应用。除了这些，其应用场景还包括：

1. 摄影：摄影师可以将自己的作品转化为NFT，确保作品的版权和所有权，并进行交易。
2. 元宇宙：虚拟世界的资产NFT化，确保所有权以及交易。
3. 音乐、电影等, 其应用方式与摄影类似。
4. 股权设计：将公司股权NFT化，确保股权的所有权以及交易。

### NFT的好处有哪些

1. 将资产NFT化，可以使交易更加透明、安全，以及极大的效率提升。

   比如将房屋合同NFT化，可以随时进行房屋交易，而不需要再进行繁琐的手续。

2. 股权NFT化，借助智能合约，实现利益的自动分配。让公司不再有“大饼”。

3. 游戏资产NFT化，可以使游戏资产的所有权更加透明，所有权不再属于游戏平台，也能够减小资产风险（游戏平台控制所有权，一旦被黑或者出现故障，所有人的游戏资产都会出现问题）。

### NFT的资产如何存储

如果数据少，可以直接存储在区块链上，如果数据大，则需要将其转换为一个可访问的地址，然后将地址存到区块链上。

### NFT中的地址失效后怎么办

区块链的“不变性”只能保存区块链上的数据不被篡改，但NFT中的地址是依赖于外部环境的。可以考虑如下方案：

1. **使用去中心化存储**：

   - 使用去中心化存储系统如IPFS（InterPlanetary File System）或Arweave来存储NFT的元数据和资产。这些系统通过分布式网络存储数据，减少了单点故障的风险。

2. **元数据更新机制**：

   - 在智能合约中设计一个元数据更新机制，允许NFT的拥有者或授权方在地址失效时更新元数据的存储地址。这需要在智能合约中实现一个更新函数，并确保只有授权方可以调用。

3. **链上存储**：

   - 对于小型数据，可以直接将数据存储在区块链上，避免外部地址失效的问题。然而，这种方法成本较高，不适用于大规模数据。

4. **多重备份**：

   - 将NFT的元数据和资产存储在多个备份地址上。如果一个地址失效，可以从其他备份地址中恢复数据。

5. **社区治理**：
   - 通过社区治理机制，允许社区成员投票决定如何处理失效的地址，确保NFT的长期可用性和可靠性。

### NFT中的地址对应的内容更改后怎么办

这应该属于NFT的元数据的问题，如果元数据发生了变化，可以通过智能合约中的更新函数来更新元数据。只有NFT的拥有者或授权方才能调用更新函数，确保数据的安全性和可靠性。

### 如何防止同一个资产在多条链上重复发行

防止同一个资产在多条链上重复发行是一个复杂的问题，涉及到跨链资产管理和验证。以下是一些可能的解决方案：

1. **跨链桥（Cross-Chain Bridge）**：

   - 使用跨链桥技术，将资产从一条链锁定，然后在另一条链上铸造等值的资产。这种方法确保了资产在不同链上的唯一性，因为跨链桥会管理和验证资产的转移。

2. **去中心化身份（Decentralized Identity, DID）**：

   - 使用去中心化身份系统来标识和验证资产的唯一性。通过DID，可以确保每个资产在不同链上都有唯一的标识符，从而防止重复发行。

3. **链上注册（On-Chain Registry）**：

   - 创建一个链上注册系统，记录所有已发行的资产及其对应的链。每次发行新资产时，先查询注册系统，确保该资产未在其他链上发行过。

4. **跨链协议（Cross-Chain Protocols）**：

   - 使用跨链协议，如Polkadot、Cosmos等，这些协议提供了跨链通信和资产管理的功能，可以帮助防止资产在多条链上重复发行。

5. **智能合约验证**：

   - 在智能合约中实现验证逻辑，确保每次发行新资产时，先检查其他链上的记录，防止重复发行。

6. **多签名机制（Multisig Mechanism）**：
   - 使用多签名机制来管理资产的发行和转移。只有在多个签名者（如不同链的验证者）达成一致后，才能发行新资产，从而防止重复发行。

通过这些方法，可以有效防止同一个资产在多条链上重复发行，确保资产的唯一性和安全性。

### 哪些链支持NFT

除了以太坊外，比特币、Solana等链也支持NFT。

## 相关阅读

- [ERC-721: Non-Fungible Token Standard](https://eips.ethereum.org/EIPS/eip-721)
- [Non-Fungible Token (NFT): What It Means and How It Works](https://www.investopedia.com/non-fungible-tokens-nft-5115211)
- [Erc721-OpenZeppelin](https://docs.openzeppelin.com/contracts/3.x/erc721)
