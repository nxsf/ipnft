# Interplanetary Non-fungible File Token (IPNFT)

An IPNFT is an on-chain, digital proof of authorship for an IPFS CID, tailored to existing NFT standards.

In IPNFT, a token ID is also the 32-byte CID multihash digest.

## Deployment

1. Run `npm run deploy -- --network <network>`.

### Known deployments

#### Polygon Mumbai

```
LibIPNFT deployed to 0x5CA8bAEc0b929E7667E0c39F6440Dca5f69f72fC
Transaction hash: 0xb2b2923941c306ea85e2ee9ad8d5b6fb0b8cd66f41df5d168dd5b700f32a3485
```

## Development

1. Run `npm run build`, then `npm run test`.
1. Run Hardhat node with `npm run node`.
1. Deploy contracts with `npm run deploy -- --network localhost`.
   Copy the contracts' addresses into the application.
