import { IPFT } from "../../src/IPFT";
import { encode } from "multiformats/block";
import { BlockView } from "multiformats/block/interface";
import * as DagCbor from "@ipld/dag-cbor";
import { keccak256 } from "@multiformats/sha3";
import { CID } from "multiformats";

export async function contentBlock(
  chainId: number,
  contractAddress: string,
  authorAddress: string,
  metadataCID: CID = CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4")
): Promise<{
  block: BlockView;
  ipftOffset: number;
}> {
  const ipft = new IPFT(chainId, contractAddress, authorAddress).toBytes();

  const block = await encode({
    value: {
      ["metadata.json"]: metadataCID,
      ipft,
    },
    codec: DagCbor,
    hasher: keccak256,
  });

  const ipftOffset = indexOfMulti(block.bytes, ipft);

  return {
    block,
    ipftOffset,
  };
}

/**
 * Search for a multi-byte `pattern` in `bytes`.
 */
export function indexOfMulti(bytes: Uint8Array, pattern: Uint8Array): number {
  const patternLength = pattern.length;
  const bytesLength = bytes.length;

  for (let i = 0; i < bytesLength; i++) {
    if (bytes[i] === pattern[0]) {
      let found = true;

      for (let j = 1; j < patternLength; j++) {
        if (bytes[i + j] !== pattern[j]) {
          found = false;
          break;
        }
      }

      if (found) {
        return i;
      }
    }
  }

  return -1;
}
