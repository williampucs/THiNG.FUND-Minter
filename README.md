# CAA-NFT

NFT for Chinese Academy of Art

## How to use SwapTrader（测试网）

### 注册 SwapPair

```sh
flow transactions send ./transactions/swapTrader_registerSwapPair.cdc 0 "[[0,10,1],[10,20,1]]" "[[20,30,1]]" \
  --network testnet \
  --signer admin-testnet
```

参数说明：

1. PairID 序号
2. 被交换的CaaPass 数组，配置说明:
   1. 最小ID
   2. 最大ID
   3. 数量
3. 换出的CaaPass 数组，配置说明:
   1. 最小ID
   2. 最大ID
   3. 数量

### 执行 Swap

```sh
flow transactions send ./transactions/swapTrader_swapNFT.cdc 0xf8d6....20c7 0 "[0, 10]" \
  --network testnet \
  --signer user-testnet
```

参数说明：

1. 合约地址
2. PairID 序号
3. 被交换的CaaPass ID数组

### 查询 SwapPair 信息

```sh
flow scripts execute ./scripts/swapTrader_getSwapPair.cdc 0xf8d6....20c7 0 \
  --network testnet
```

参数说明：

1. 合约地址
2. PairID 序号

### 查询 SwapPair 已进行了多少次

```sh
flow scripts execute ./scripts/swapTrader_getSwappedAmount.cdc 0xf8d6....20c7 0 \
  --network testnet
```

参数说明：

1. 合约地址
2. PairID 序号

### 查询 SwapPair 目前还有多少可交易的

```sh
flow scripts execute ./scripts/swapTrader_getTradableAmount.cdc 0xf8d6....20c7 0 \
  --network testnet
```

参数说明：

1. 合约地址
2. PairID 序号

### 其他操作

- 修改SwapPair状态： `./transactions/swapTrader_setSwapPairState.cdc`
- 查询是否可交易 `./scripts/swapTrader_isTradable.cdc`
