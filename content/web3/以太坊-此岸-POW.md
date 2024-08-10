---
title: '以太坊-此岸-POW'
date: 2023-06-04T14:35:00+08:00
url: '/web3/eth_pow'
isCJKLanguage: true
draft: false
toc: true
keywords:
  - eth
authors:
  - stong
tags: ['web3', 'blockchain', 'ethereum']
---

以太坊区别于比特币的一大特点是使用权益证明（POS）替代了工作量证明（POW）。

但是以太坊在初始阶段仍旧使用的POW，之所以用POW过渡是因为POW已经被比特币证明了是可行的，而POS则需要进一步的探索和完善。

### 与比特币中的不同

以太坊使用的POW和比特币的有很大不同。

#### 增加了内存要求的puzzle

在比特币和以太坊中，工作量证明的过程都是找nonce：

1. 通过随机数获得一个nonce
2. 进行一系列的计算判断是否小于目标值
3. 如果不小于，换个nonce重复上一个步骤
4. 一旦找到合格的nonce值，就可以发布区块

两者的区别就在于第二个步骤中的计算过程。

比特币的计算过程比较简单，就是对区块信息和nonce值进行哈希，这使得后期出现了专用芯片——ASIC——不再适用通用计算机，专门用于挖矿的芯片。ASIC芯片的诞生打破了中本聪`one cpu one vote`的愿景。

以太坊为了避免重蹈覆辙，**增加了对内存的要求**。

##### 1. 生成cache

在以太坊的源码中，`generateCache`函数用于生成cache，

```go
// Create a hasher to reuse between invocations
	keccak512 := makeHasher(sha3.NewLegacyKeccak512())

	// Sequentially produce the initial dataset
	keccak512(cache, seed)
	for offset := uint64(hashBytes); offset < size; offset += hashBytes {
		keccak512(cache[offset:], cache[offset-hashBytes:offset])
	}
	// Use a low-round version of randmemohash
	temp := make([]byte, hashBytes)

	for i := 0; i < cacheRounds; i++ {
		for j := 0; j < rows; j++ {
			var (
				srcOff = ((j - 1 + rows) % rows) * hashBytes
				dstOff = j * hashBytes
				xorOff = (binary.LittleEndian.Uint32(cache[dstOff:]) % uint32(rows)) * hashBytes
			)
			bitutil.XORBytes(temp, cache[srcOff:srcOff+hashBytes], cache[xorOff:xorOff+hashBytes])
			keccak512(cache[dstOff:], temp)
		}
	}
	// Swap the byte order on big endian systems and return
	if !isLittleEndian() {
		swap(cache)
	}
```

大体逻辑就是：

1. 使用seed哈希后的数据填充cache前64位
2. 再填充cache的后续64位，输入为cache的前64位
3. 重复这个步骤，直到填充满cache
4. 最后给cache再做一些异或操作

最终，我们得到了cache。

cache的大小初始为16M，后续会根据块的数量增多而增大。

##### 2. 生成dataset

在以太坊源码中，`generateDataset`函数用于生成dataset。

```go
// 使用多线程生成
for i := 0; i < threads; i++ {
		go func(id int) {
			defer pend.Done()

			// Create a hasher to reuse between invocations
			keccak512 := makeHasher(sha3.NewLegacyKeccak512())

			// Calculate the data segment this thread should generate
			batch := (size + hashBytes*uint64(threads) - 1) / (hashBytes * uint64(threads))
			first := uint64(id) * batch
			limit := first + batch
			if limit > size/hashBytes {
				limit = size / hashBytes
			}
			// Calculate the dataset segment
			percent := size / hashBytes / 100
			for index := first; index < limit; index++ {
				item := generateDatasetItem(cache, uint32(index), keccak512)
				if swapped {
					swap(item)
				}
				copy(dataset[index*hashBytes:], item)

				if status := atomic.AddUint64(&progress, 1); status%percent == 0 {
					logger.Info("Generating DAG in progress", "percentage", (status*100)/(size/hashBytes), "elapsed", common.PrettyDuration(time.Since(start)))
				}
			}
		}(i)
	}
```

这个函数中调用了`generateDatasetItem`函数：

```go
// generateDatasetItem combines data from 256 pseudorandomly selected cache nodes,
// and hashes that to compute a single dataset node.
func generateDatasetItem(cache []uint32, index uint32, keccak512 hasher) []byte {
	// Calculate the number of theoretical rows (we use one buffer nonetheless)
	rows := uint32(len(cache) / hashWords)

	// Initialize the mix
	mix := make([]byte, hashBytes)

	binary.LittleEndian.PutUint32(mix, cache[(index%rows)*hashWords]^index)
	for i := 1; i < hashWords; i++ {
		binary.LittleEndian.PutUint32(mix[i*4:], cache[(index%rows)*hashWords+uint32(i)])
	}
	keccak512(mix, mix)

	// Convert the mix to uint32s to avoid constant bit shifting
	intMix := make([]uint32, hashWords)
	for i := 0; i < len(intMix); i++ {
		intMix[i] = binary.LittleEndian.Uint32(mix[i*4:])
	}
	// fnv it with a lot of random cache nodes based on index
	for i := uint32(0); i < datasetParents; i++ {
		parent := fnv(index^i, intMix[i%16]) % rows
		fnvHash(intMix, cache[parent*hashWords:])
	}
	// Flatten the uint32 mix into a binary one and return
	for i, val := range intMix {
		binary.LittleEndian.PutUint32(mix[i*4:], val)
	}
	keccak512(mix, mix)
	return mix
}
```

可以看到dataset是根据cache来生成的。

dataset的初始大小为1G，后续根据区块的增多而增大。

##### 3. 计算nonce

```go
// hashimotoFull aggregates data from the full dataset (using the full in-memory
// dataset) in order to produce our final value for a particular header hash and
// nonce.
func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte) {
	lookup := func(index uint32) []uint32 {
		offset := index * hashWords
		return dataset[offset : offset+hashWords]
	}
	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
}

// hashimoto aggregates data from the full dataset in order to produce our final
// value for a particular header hash and nonce.
func hashimoto(hash []byte, nonce uint64, size uint64, lookup func(index uint32) []uint32) ([]byte, []byte) {
	// Calculate the number of theoretical rows (we use one buffer nonetheless)
	rows := uint32(size / mixBytes)

	// Combine header+nonce into a 40 byte seed
	seed := make([]byte, 40)
	copy(seed, hash)
	binary.LittleEndian.PutUint64(seed[32:], nonce)

	seed = crypto.Keccak512(seed)
	seedHead := binary.LittleEndian.Uint32(seed)

	// Start the mix with replicated seed
	mix := make([]uint32, mixBytes/4)
	for i := 0; i < len(mix); i++ {
		mix[i] = binary.LittleEndian.Uint32(seed[i%16*4:])
	}
	// Mix in random dataset nodes
	temp := make([]uint32, len(mix))

  // loopAccesses=64，即循环64次
	for i := 0; i < loopAccesses; i++ {
    // 通过计算获得索引值
		parent := fnv(uint32(i)^seedHead, mix[i%len(mix)]) % rows
    // mixBytes/hashBytes = 2,即循环两次
		for j := uint32(0); j < mixBytes/hashBytes; j++ {
			copy(temp[j*hashWords:], lookup(2*parent+j)) // 填充temp
		}
		fnvHash(mix, temp) // 根据temp填充mix
	}
	// Compress mix
	for i := 0; i < len(mix); i += 4 {
		mix[i/4] = fnv(fnv(fnv(mix[i], mix[i+1]), mix[i+2]), mix[i+3])
	}
	mix = mix[:len(mix)/4]

	digest := make([]byte, common.HashLength)
	for i, val := range mix {
		binary.LittleEndian.PutUint32(digest[i*4:], val)
	}
	return digest, crypto.Keccak256(append(seed, digest...))
}
```

计算nonce时会通过一系列的计算来得到dataset的一个索引值，然后通过索引来获得对应的值，循环这个步骤，最终填充满mix，再对mix进行压缩，最终得到了一个值。

将得到的值与目标值进行比较，如果小于目标值，这个nonce就是一个合格的nonce！

#### 难度调整

> 以Homestead阶段的算法为准

计算公式为：`block_diff = pdiff - pdiff / 2048 * max((time - ptime) / 10 - 1, 99) + 2 ^ int((num / 100000) - 2))`

其中：

- pdiff: 父区块的难度
- ptime：父区块的时间
- time：当前区块的时间
- num：当前区块的高度

整个公式可以分为三部分：

- 父区块的难度
- 根据出块时间得到的需要调整的难度值
- 难度炸弹：指数型上升的难度，目的是为未来转POS做准备

#### 更快的出块时间

由于以太坊期待的出块时间是15秒一个，因此区块链出现**短暂分叉的可能性大大增加**（相比比特币10分钟一个块，以太坊确定区块的时间更短）。

以太坊做了以下几点优化：

1. 使用更高效的传输协议gossip。比特币中是挑选完全随机的节点进行传播。
2. 将分叉的块作为叔块“融入”主链中，叔块的矿工也能得到部分出块奖励。通过这种方式鼓励分叉的链进行“合并”，避免分散算力导致被攻击成功。

## 代码

代码可在[github](https://github.com/ethereum/go-ethereum)上查看，POW的共识算法名为`ethash`，当前POW相关的代码已被删除，需要`checkout`到历史版本才能看到。

在版本hash为`dde2da0efb8e9a1812f470bc43254134cd1f8cc0`的提交备注中写道：

```shell
all: remove ethash pow. only retain shims needed for consensus and tests (#27178)
```

因此查看代码需要`checkout`其前一个版本：

```shell
git checkout 2b44ef5f93cc7479a77890917a29684b56e9167a
```

## 总结

由于区块链的“不可变”的特性，**如何维护、升级程序成了开发者的一大难题**。

以太坊团队给出的解决办法是**先通过已被验证可靠的方式进行开发，然后通过一些机制保证未来能够平稳过渡**。而在这期间，团队就有了大量时间能够进行宣传、探索。

## 相关阅读

- [挖矿算法 | ethereum.org](https://ethereum.org/zh/developers/docs/consensus-mechanisms/pow/mining-algorithms/)
