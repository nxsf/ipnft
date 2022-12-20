# Interplanetary Non-fungible File Token (IPNFT)

An IPNFT is an on-chain, digital proof of authorship for an IPFS CID, tailored to existing NFT standards.

In IPNFT, a token ID is also the 32-byte CID multihash digest.

## Deployment

1. Run `npm run deploy -- --network <network>`.

## Development

1. Run `npm run build`, then `npm run test`.
1. Run Hardhat node with `npm run node`.
1. Deploy contracts with `npm run deploy -- --network localhost`.
   Copy the contracts' addresses into the application.
