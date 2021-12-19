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
    // sourceReceiver - capability for depositing source NFTs
    pub let sourceReceiver: Capability<&{NonFungibleToken.Receiver}>
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
      sourceReceiver: Capability<&{NonFungibleToken.Receiver}>,
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
      // check collection length
      assert(ids.length > 0, message: "Empty target collection.")
      // check resource type
      let firstNFT = collection.borrowNFT(id: ids[0])
      for one in targetAttrs {
        assert(firstNFT.isInstance(one.resourceType), message: "Target resource type mis-match")
      } // end for

      // initialize struct data
      self.sourceAttributes = sourceAttrs
      self.targetAttributes = targetAttrs
      self.sourceReceiver = sourceReceiver
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
        for attr in swapPair.targetAttributes {
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
        } // end for swapPair.targetAttributes
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
        // check if currently tradable
        self.isTradable(pairID): "The swap pair is not tradable."
        sourceProvider.address == targetReceiver.address: "The address of sourceProvider and targetReceiver should be same."
      }

      // Step.1 withdraw all source NFTs, and prepare swap pair
      // 
      // swap pair
      let swapPair = self.registeredPairs[pairID]!
      // source NFTs
      let sourceRefNFTs: {UInt64: &NonFungibleToken.NFT} = {}
      let sourceNFTs: @[NonFungibleToken.NFT] <- []
      for id in sourceIDs {
        let source = sourceProvider.borrow() ?? panic("Failed to borrow source provider")
        let nft <- source.withdraw(withdrawID: id)
        // add to dictionary
        let nftRef = &nft as &NonFungibleToken.NFT
        sourceRefNFTs[nftRef.uuid] = nftRef
        // append to array
        sourceNFTs.append(<- nft)
      }

      // Step.2 Check if all NFT matched
      // 
      // check in required source attributes
      for srcOneAttr in swapPair.sourceAttributes {
        // to find matched NFT
        var matchedAmount: UInt64 = 0
        for key in sourceRefNFTs.keys {
          let nftRef = sourceRefNFTs[key]!
          if matchedAmount < srcOneAttr.amount &&
            nftRef.isInstance(srcOneAttr.resourceType) &&
            nftRef.id >= srcOneAttr.minId &&
            nftRef.id < srcOneAttr.maxId {
            // record on matched
            matchedAmount = matchedAmount + 1
            // remove from refs
            sourceRefNFTs.remove(key: nftRef.uuid)
          } else if matchedAmount >= srcOneAttr.amount {
            break
          }
        }
        // check if all matched
        assert(matchedAmount >= srcOneAttr.amount, message: "produced NFTs not match swap pair source NFTs")
      }

      // Step.3 Pick target NFT from SwapPair capability
      // 
      let targetCollection = swapPair.targetCollection.borrow() ?? panic("Failed to borrow target collection")
      let targetNFTs: @[NonFungibleToken.NFT] <- []

      // get exist ids
      let existIDs = targetCollection.getIDs()
      let pickedIDs: [UInt64] = []
      // required attributes
      for attr in swapPair.targetAttributes {
        var matched: UInt64 = 0
        // check all existIDs
        for currentID in existIDs {
          if currentID >= attr.minId && currentID < attr.maxId {
            matched = matched + 1
            pickedIDs.append(currentID)
            // when matched id reach the attr amount, end check
            if matched >= attr.amount {
              break
            }
          }
        }
        // ensuore 
        assert(matched >= attr.amount, message: "target NFTs is not enough.")
      } // end for swapPair.targetAttributes
      // ensure picked IDs exists
      assert(pickedIDs.length > 0, message: "No picked IDs found.")
      // withdraw all target NFTs
      for id in pickedIDs {
        let target = swapPair.targetProvider.borrow() ?? panic("Failed to borrow target provider in SwapPair")
        targetNFTs.append(<- target.withdraw(withdrawID: id))
      }

      // Step.4 Deposit source NFTs to SwapPair source Receiver
      // 
      let sourceReceiverRef = swapPair.sourceReceiver.borrow() ?? panic("Failed to borrow source receiver.")
      while sourceNFTs.length > 0 {
        sourceReceiverRef.deposit(token: <- sourceNFTs.removeFirst())
      }
      destroy  sourceNFTs

      // Step.5 Deposit target NFTs to target Receiver
      // 
      let targetReceiverRef = targetReceiver.borrow() ?? panic("Failed to borrow target receiver.")
      while targetNFTs.length > 0 {
        targetReceiverRef.deposit(token: <- targetNFTs.removeFirst())
      }
      destroy  targetNFTs

      // emit Swap Event
      emit SwapNFT(
        pairID: pairID,
        swapper: targetReceiver.address,
        sourceIDs: sourceIDs,
        targetIDs: pickedIDs
      )
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