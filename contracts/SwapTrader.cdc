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
  pub let SwapPairListStoragePath: StoragePath
  pub let SwapPairListPublicPath: PublicPath

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
      targetCollection: Capability<&{NonFungibleToken.CollectionPublic}>,
      targetProvider: Capability<&{NonFungibleToken.Provider}>,
      sourceAttrs: [SwapAttribute],
      targetAttrs: [SwapAttribute],
      paused: Bool
    ) {
      pre {
        sourceAttrs.length > 0: "Length should be greator then 0: source swap attributes"
        targetAttrs.length > 0: "Length should be greator then 0: target swap attributes"
      }
      let collection = targetCollection.borrow() ?? panic("Failed to borrow collection")
      let ids = collection.getIDs()
      if ids.length > 0 {
        let firstNFT = collection.borrowNFT(id: ids[0])
        for one in targetAttrs {
          if !firstNFT.isInstance(one.resourceType) {
            panic("Target resource type mis-match")
          }
        } // end for
      } else {
        panic("Empty target collection.")
      }
      // initialize struct data
      self.sourceAttributes = sourceAttrs
      self.targetAttributes = targetAttrs
      self.targetCollection = targetCollection
      self.targetProvider = targetProvider
      self.paused = paused
    }

    // setState
    // Set state of the swap pair
    access(contract) fun setState(_ paused: Bool) {
      self.paused = paused
    }
  }

  // SwapPairList
  // Interface for listing swap pair and handle swaping action
  //
  pub resource interface SwapPairListPublic {
    // isTradable
    // 1. Does the swap-pair pause?
    // 2. Has enough target to swap?
    pub fun isTradable (_ pairID: UInt64): Bool;

    // swapNFT - execute swap
    pub fun swapNFT (
      pairID: UInt64,
      sourceIDs: [UInt64],
      sourceProvider: Capability<&{NonFungibleToken.Provider}>,
      targetReceiver: Capability<&{NonFungibleToken.Receiver}>
    );
  }

  // SwapPairList
  // Resource that an trader list or something similar would own to be
  // able to define new SwapPairs
  //
  pub resource SwapPairList: SwapPairListPublic {
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
        self.registeredPairs[index] == nil: "Cannot register: The index is occupied"
      }
      self.registeredPairs[index] = pair

      // emit Event
      emit SwapPairRegistered(pairID: index)
    }

    // setSwapPairState
    // Set state of the swap pair 
    pub fun setSwapPairState(pairID: UInt64, paused: Bool) {
      pre {
        self.registeredPairs[pairID] != nil:
          "Cannot set state: The swap-pair of pairID does not exist."
        self.registeredPairs[pairID]!.paused != paused:
          "Cannot set state: The swap-pair of pairID has same state."
      }
      self.registeredPairs[pairID]?.setState(paused)

      // emit Event
      emit SwapPairStateChanged(pairID: pairID, paused: paused)
    }

    // ------ Interface implement ------
    // isTradable
    // 1. Does the swap-pair pause?
    // 2. Has enough target to swap?
    pub fun isTradable (_ pairID: UInt64): Bool {
      if let swapPair = self.registeredPairs[pairID] {
        // check pause state
        if swapPair.paused {
          return false
        }
        // check target
        let collection = swapPair.targetCollection.borrow() ?? panic("Failed to borrow target collection")
        // exist ids
        let existIDs = collection.getIDs()
        // required attributes
        let requiredAttributes = swapPair.targetAttributes
        for attr in requiredAttributes {
          var matched: UInt64 = 0
          // check all existIDs
          for currentID in existIDs {
            if currentID >= attr.minId && currentID < attr.maxId {
              matched = matched + 1
              // when matched id reach the attr amount, end check
              if matched >= attr.amount {
                break
              }
            }
          }
          // if not matched, return false immediately
          if matched < attr.amount {
            return false
          }
        } // end for requiredAttributes
        return true
      } else {
        return false
      }
    }
    // swapNFT - execute swap
    pub fun swapNFT (
      pairID: UInt64,
      sourceIDs: [UInt64],
      sourceProvider: Capability<&{NonFungibleToken.Provider}>,
      targetReceiver: Capability<&{NonFungibleToken.Receiver}>
    ) {
      pre {
        self.isTradable(pairID): "The swap pair is not tradable."
      }
      // TODO
    }
  }

  // initializer
  //
  init() {
    // Set our named paths
    self.SwapPairListStoragePath = /storage/swapTraderAdmin
    self.SwapPairListPublicPath = /public/swapPairListPublic

    // Create a swap pair list resource and save it to storage
    let list <- create SwapPairList()
    self.account.save(<-list, to: self.SwapPairListStoragePath)

    // Create a swap pair list public link
    self.account.link<&{SwapPairListPublic}>(
      self.SwapPairListPublicPath,
      target: self.SwapPairListStoragePath
    )

    emit ContractInitialized()
  }
}