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
  pub let TraderListStoragePath: StoragePath
  pub let TraderListPublicPath: PublicPath

  // Type Definitions
  // 
  // SwapAttribute
  // Detailed swap-pair attribute
  pub struct SwapAttribute {
    // resourceType - which type of NFT resource is required
    pub let resourceType: Type
    // minId - minimium id of the NFT
    pub let minId: UInt64
    // maxId - maximium id of the NFT
    pub let maxId: UInt64
    // amount - required amount of this type NFT
    pub let amount: UInt64

    init(
      resourceType: Type,
      minId: UInt64,
      maxId: UInt64,
      amount: UInt64
    ) {
      self.resourceType = resourceType
      self.minId = minId
      self.maxId = maxId
      self.amount = amount
    }
  }

  // SwapPair - Registering defination
  pub struct SwapPair {
    // capabilities
    // targetCollection - check for target existance
    pub let targetCollection: Capability<&{NonFungibleToken.CollectionPublic}>
    // targetProvider - withdraw from target capability
    pub let targetProvider: Capability<&{NonFungibleToken.Provider}>
    // sourceAttributes - required source attributes
    pub let sourceAttributes: [SwapAttribute]
    // targetAttributes - swap target attributes
    pub let targetAttributes: [SwapAttribute]

    // paused: is swappair working currently
    access(contract) var paused: Bool

    init(
      tarColl: Capability<&{NonFungibleToken.CollectionPublic}>,
      tarProv: Capability<&{NonFungibleToken.Provider}>,
      srcAttrs: [SwapAttribute],
      tarAttrs: [SwapAttribute],
      paused: Bool
    ) {
      self.sourceAttributes = srcAttrs
      self.targetAttributes = tarAttrs
      self.targetCollection = tarColl
      self.targetProvider = tarProv
      self.paused = paused
    }

    // setState
    // Set state of the swap pair
    access(contract) fun setState(_ paused: Bool) {
      self.paused = paused
    }
  }

  // TraderList
  // Interface for listing swap pair and handle swaping action
  pub resource interface TraderListPublic {
    // isTradable
    // 1. Does the swap-pair pause?
    // 2. Has enough target to swap?
    pub fun isTradable (typeID: UInt64): Bool;
    // swapNFT - execute swap
    pub fun swapNFT (
      typeID: UInt64,
      sourceIDs: [UInt64],
      sourceProvider: Capability<&{NonFungibleToken.Provider}>,
      targetReceiver: Capability<&{NonFungibleToken.Receiver}>
    );
  }

  // TraderList
  // Resource that an trader list or something similar would own to be
  // able to define new SwapPairs
  //
  pub resource TraderList {
    // pre-registered swap pairs
    // 
    access(contract) var registeredPairs: {UInt64: SwapPair}

    // init
    init() {
      self.registeredPairs = {}
    }

    // registerSwapPair
    // Registers SwapPair for a typeID
    pub fun registerSwapPair(index: UInt64, pair: SwapPair) {
      pre {
        self.registeredPairs[index] != nil: "Cannot register: The index is occupied"
      }
      self.registeredPairs[index] = pair

      // emit Event
      emit SwapPairRegistered(pairID: index)
    }

    // setSwapPairState
    // Set state of the swap pair 
    pub fun setSwapPairState(index: UInt64, paused: Bool) {
      pre {
        self.registeredPairs[index] == nil:
          "Cannot set state: The swap-pair of index does not exist."
        self.registeredPairs[index]!.paused == paused:
          "Cannot set state: The swap-pair of index has same state."
      }
      self.registeredPairs[index]?.setState(paused)

      // emit Event
      emit SwapPairStateChanged(pairID: index, paused: paused)
    }
  }

  // initializer
  //
  init() {
    // Set our named paths
    self.TraderListStoragePath = /storage/swapTraderAdmin
    self.TraderListPublicPath = /public/swapTraderList

    // Create a trader list resource and save it to storage
    let list <- create TraderList()
    self.account.save(<-list, to: self.TraderListStoragePath)

    emit ContractInitialized()
  }
}