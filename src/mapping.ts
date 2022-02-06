import { BigInt } from "@graphprotocol/graph-ts"
import {
  Marketplace,
  MarketItemCreated
} from "../generated/Marketplace/Marketplace"
import { MarketItemEntity } from "../generated/schema"

export function handleMarketItemCreated(event: MarketItemCreated): void {
    // Entities can be loaded from the store using a string ID; this ID
    let id = event.params.itemId
    // needs to be unique across all entities of the same type
    let entity = MarketItemEntity.load(id.toString())

    // Entities only exist after they have been saved to the store;
    // `null` checks allow to create entities on demand
    if (entity == null) {
      entity = new MarketItemEntity(id.toString())
    }

    entity.itemId = event.params.itemId
    entity.nftContract = event.params.nftContract
    entity.tokenId = event.params.tokenId
    entity.seller = event.params.seller
    entity.owner = event.params.owner
    entity.price = event.params.price
    entity.sold = event.params.sold
    entity.save()
}
