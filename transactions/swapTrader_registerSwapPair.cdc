import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import SwapTrader from "../contracts/SwapTrader.cdc"

transaction(pairID: UInt64) {
  let swapTraderList: &SwapTrader.SwapPairList

  prepare(signer: AuthAccount) {
    self.swapTraderList = signer.borrow<&SwapTrader.SwapPairList>(from: SwapTrader.SwapPairListStoragePath)
      ?? panic("Could not borrow swap-pair list resource reference")
  }

  execute {
    // self.swapTraderList.registerSwapPair(index: pairID, pair: pair)
    // TODO
  }
}
 