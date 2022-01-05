# CAA-NFT

NFT for Chinese Academy of Art

## How to use SwapTrader（Testnet）

### Register SwapPair

```sh
flow transactions send ./transactions/swapTrader_registerSwapPair.cdc 0 "[[0,10,1],[10,20,1]]" "[[20,30,1]]" \
  --network testnet \
  --signer admin-testnet
```

Parameters:

1. PairID
2. Source array of CaaPass:
   1. MinID
   2. MaxID
   3. Amount
3. Target array of CaaPass:
   1. MinID
   2. MaxID
   3. Amount

### Execute Swap

```sh
flow transactions send ./transactions/swapTrader_swapNFT.cdc 0xf8d6....20c7 0 "[0, 10]" \
  --network testnet \
  --signer user-testnet
```

Parameters:

1. Contract Address
2. PairID
3. Array of CaaPass IDs

### Query SwapPair info

```sh
flow scripts execute ./scripts/swapTrader_getSwapPair.cdc 0xf8d6....20c7 0 \
  --network testnet
```

Parameters:

1. Contract Address
2. PairID

### Query SwapPair swapped times

```sh
flow scripts execute ./scripts/swapTrader_getSwappedAmount.cdc 0xf8d6....20c7 0 \
  --network testnet
```

Parameters:

1. Contract Address
2. PairID

### Query SwapPair how many pairs remained

```sh
flow scripts execute ./scripts/swapTrader_getTradableAmount.cdc 0xf8d6....20c7 0 \
  --network testnet
```

Parameters:

1. Contract Address
2. PairID

### Other

- Change SwapPair state: `./transactions/swapTrader_setSwapPairState.cdc`
- Check if tradable `./scripts/swapTrader_isTradable.cdc`
