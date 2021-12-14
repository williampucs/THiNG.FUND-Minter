# Token
### Get Metadata from CaaArts
```
flow scripts execute ./scripts/getCaaArtMetadata.cdc \
  --network testnet \
  --arg Address:0x56ac261eb0f67cf4
```

### Get All Metadata from CaaArts
```
flow scripts execute ./scripts/getAllCaaArtsMetadata.cdc \
  --network mainnet \
  --arg Address:0xdd718b0856a69974
```

### Get All Metadata from CaaPass
```
flow scripts execute ./scripts/getAllCaaPassMetadata.cdc \
  --network mainnet \
  --arg Address:0xdd718b0856a69974
```

### Get Metadata for a typeID from CaaPass
```
flow scripts execute ./scripts/getCaaPassTypeMetadata.cdc \
  --network mainnet \
  --arg UInt64:0
```
