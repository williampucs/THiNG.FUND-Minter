import NonFungibleToken from "./NonFungibleToken.cdc"

pub contract SwapTrader {
  // Events
  //
  pub event ContractInitialized()
  pub event SwapPairRegistered(pairID: UInt64)
  pub event SwapPairStateChanged(pairID: UInt64, paused: Bool)
  pub event SwapNFT(pairID: UInt64, swapper: Address, sourceIDs: [UInt64], targetIDs: [UInt64])

  // Named Paths
  //
  pub let AdminStoragePath: StoragePath

  // pre-defined swap pairs
  // 
  access(contract) var registeredPairs: {UInt64: SwapPair}

  // Type Definitions
  // 
  pub struct SwapPair {

    // paused: is swappair working currently
    access(contract) var paused: Bool

    init(paused: Bool) {
      self.paused = paused
    }

    // setState
    // Set state of the swap pair
    access(contract) fun setState(_ paused: Bool) {
      self.paused = paused
    }
  }


  // Admin
  // Resource that an admin or something similar would own to be
  // able to define new SwapPairs
  //
  pub resource Admin {
    // registerSwapPair
    // Registers SwapPair for a typeID
    //
    pub fun registerSwapPair(index: UInt64, pair: SwapPair) {
      pre {
        SwapTrader.registeredPairs[index] != nil: "Cannot register: The index is occupied"
      }
      SwapTrader.registeredPairs[index] = pair

      // emit Event
      emit SwapPairRegistered(pairID: index)
    }

    // setSwapPairState
    // Set state of the swap pair 
    pub fun setSwapPairState(index: UInt64, paused: Bool) {
      pre {
        SwapTrader.registeredPairs[index] == nil:
          "Cannot set state: The swap-pair of index does not exist."
        SwapTrader.registeredPairs[index]!.paused == paused:
          "Cannot set state: The swap-pair of index has same state."
      }
      SwapTrader.registeredPairs[index]?.setState(paused)

      // emit Event
      emit SwapPairStateChanged(pairID: index, paused: paused)
    }
  }

  // initializer
  //
  init() {
    // Set our named paths
    self.AdminStoragePath = /storage/swapTraderAdmin

    // Initialize predefined swap pairs
    self.registeredPairs = {}

    // Create a Admin resource and save it to storage
    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}