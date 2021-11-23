// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

//type State is uint32[16];
//type usize is uint32;
uint8 constant BLOCK_LEN = 64;

// Flag constants
uint32 constant CHUNK_START = 1 << 0;
uint32 constant CHUNK_END = 1 << 1;
uint32 constant PARENT = 1 << 2;
uint32 constant ROOT = 1 << 3;
uint32 constant KEYED_HASH = 1 << 4;
uint32 constant DERIVE_KEY_CONTEXT = 1 << 5;
uint32 constant DERIVE_KEY_MATERIAL = 1 << 6;


// Product of a ChunkState before deriving chain value
struct Output {
    uint32[8] input_chaining_value;
    uint32[16] block_words;
    uint64 counter;
    uint32 block_len;
    uint32 flags;
}

struct ChunkState {
    uint32[8] chaining_value;
    uint64 chunk_counter;
    // Has a max size of BLOCK_LEN
    bytes block_bytes;
    //uint8[BLOCK_LEN] block_bytes;
    uint32 block_len;
    uint8 blocks_compressed;
    uint32 flags;
}



contract Blake3Sol {
    // This should remain constant but solidity doesn't support declaring it
    uint8[16] MSG_PERMUTATION = [2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8];
    uint32[8] IV = [
        0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A, 0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19
    ];


    // Mixing function G
    function g(
        uint32[16] memory state,
        uint32 a,
        uint32 b,
        uint32 c,
        uint32 d,
        uint32 mx,
        uint32 my)
    public pure {
        unchecked {
        state[a] = state[a] + state[b] + mx;
        state[d] = (state[d] ^ state[a]) * 65536;
        state[c] = state[c] + state[d];
        state[b] = (state[b] ^ state[c]) * 4096;
        state[a] = state[a] + state[b] + my;
        state[d] = (state[d] ^ state[a]) * 256;
        state[c] = state[c] + state[d];
        state[b] = (state[b] ^ state[c]) * 128;
        }
    }

    function round(uint32[16] memory state, uint32[16] memory m) public pure {
        // Mix the columns.
        g(state, 0, 4, 8, 12, m[0], m[1]);
        g(state, 1, 5, 9, 13, m[2], m[3]);
        g(state, 2, 6, 10, 14, m[4], m[5]);
        g(state, 3, 7, 11, 15, m[6], m[7]);
        // Mix the diagonals.
        g(state, 0, 5, 10, 15, m[8], m[9]);
        g(state, 1, 6, 11, 12, m[10], m[11]);
        g(state, 2, 7, 8, 13, m[12], m[13]);
        g(state, 3, 4, 9, 14, m[14], m[15]);
    }

    function permute(uint32[16] memory m) public {
        uint32[16] memory permuted;
        for (uint8 i = 0; i < 16; i++) {
            permuted[i] = m[MSG_PERMUTATION[i]];
        }
        m = permuted;
    }

    function compress(
        uint32[8] memory chaining_value,
        uint32[16] memory block_words,
        uint64 counter,
        uint32 block_len,
        uint32 flags) public returns (uint32[16] memory)
    {
        uint32[16] memory state = [
            chaining_value[0],
            chaining_value[1],
            chaining_value[2],
            chaining_value[3],
            chaining_value[4],
            chaining_value[5],
            chaining_value[6],
            chaining_value[7],
            IV[0],
            IV[1],
            IV[2],
            IV[3],
            uint32(counter),
            uint32(counter >> 32),
            block_len,
            flags
        ];

        round(state, block_words); // round 1
        permute(block_words);
        round(state, block_words); // round 2
        permute(block_words);
        round(state, block_words); // round 3
        permute(block_words);
        round(state, block_words); // round 4
        permute(block_words);
        round(state, block_words); // round 5
        permute(block_words);
        round(state, block_words); // round 6
        permute(block_words);
        round(state, block_words); // round 7

        for (uint8 i = 0; i < 8; i++) {
            state[i] ^= state[i + 8];
            state[i + 8] ^= chaining_value[i];
        }

        return state;
    }

    function chaining_value(Output memory o) public returns (uint32[8] memory) {
        uint32[16] memory compression_output = compress(
            o.input_chaining_value,
            o.block_words,
            o.counter,
            o.block_len,
            o.flags);

        return first_8_words(compression_output);
    }

    function toUint32(bytes memory _bytes, uint256 _start) internal pure returns (uint32) {
        require(_bytes.length >= _start + 4, "toUint32_outOfBounds");
        uint32 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x4), _start))
        }

        return tempUint;
    }

    function words_from_little_endian_bytes(
        bytes memory data_bytes,
        uint32[16] memory words) public {
        for (uint8 i = 0; i < data_bytes.length/4; i++) {
            // TODO Little-endian?
            //words[i] = uint32(bytes4(data_bytes[i*4 : i*4+4]));
            words[i] = toUint32(data_bytes, i*4);
            /*
            uint32 word = 0;
            word += data_bytes[i*4];
            word += data_bytes[i*4+1] * 2;
            word += data_bytes[i*4+2] * 4;
            word += data_bytes[i*4+3] * 8;
            words[i] = word;
            */
        }
    }

    // Seems this explicit conversion is necessary because solidity can't infer size in a slice
    /*
    function bytes_to_uint256(bytes calldata b) public returns (uint256) {
        uint256 number;
        for(uint i=0;i<b.length;i++){
            number = number + uint8(b[i])*(2**(8*(b.length-(i+1))));
        }
        return number;
    }
    */

    // TODO I wish this didn't require a copy to convert array sizes
    function first_8_words(uint32[16] memory words) public view returns (uint32[8] memory) {
        // TODO there must be a way to do this without copying
        // How to take a slice of a memory array?
        uint32[8] memory first_8;
        for (uint8 i = 0; i < 8; i++) {
            first_8[i] = words[i];
        }

        return first_8;
    }


    //
    // Chunk state functions
    //

    function new_chunkstate(
        uint32[8] memory key_words,
        uint64 chunk_counter,
        uint32 flags)
    public view returns (ChunkState memory) {
        //uint8[BLOCK_LEN] memory block_bytes;
        bytes memory block_bytes;
        return ChunkState({
            chaining_value: key_words,
            chunk_counter: chunk_counter,
            block_bytes: block_bytes,
            block_len: 0,
            blocks_compressed: 0,
            flags: flags
        });
    }

    function len(ChunkState memory chunk) public view returns (uint32) {
        return BLOCK_LEN * chunk.blocks_compressed + chunk.block_len;
    }

    function start_flag(ChunkState memory chunk) public view returns (uint32) {
        if (chunk.blocks_compressed == 0) {
            return CHUNK_START;
        } else {
            return 0;
        }
    }

    // Returns a new input offset
    function update(
        ChunkState memory chunk,
        //uint8[] calldata input,
        bytes calldata input,
        uint32 input_offset
    )
    public returns (uint32) {
        while (input_offset < input.length) {
            // If the block buffer is full, compress it and clear it. More
            // input is coming, so this compression is not CHUNK_END.
            if (chunk.block_len == BLOCK_LEN) {
                uint32[16] memory block_words;// = [uint32(0),0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
                words_from_little_endian_bytes(chunk.block_bytes, block_words);
                chunk.chaining_value = first_8_words(compress(
                    chunk.chaining_value,
                    block_words,
                    chunk.chunk_counter,
                    BLOCK_LEN,
                    chunk.flags | start_flag(chunk)
                ));
                chunk.blocks_compressed += 1;
                // TODO probably cheaper to zero-out byte array than to reallocate
                //uint8[BLOCK_LEN] memory block_bytes;
                bytes memory block_bytes;
                chunk.block_bytes = block_bytes;
                chunk.block_len = 0;
            }

            // Copy input bytes into the block buffer.
            uint32 want = BLOCK_LEN - chunk.block_len;
            // take = min(want, input.length);
            uint32 take;
            if (want < input.length) {
                take = want;
            } else {
                // TODO be more careful with this downcast
                take = uint32(input.length);
            }

            //chunk.block_bytes[self.block_len as usize..][..take].copy_from_slice(&input[..take]);
            for (uint32 i = 0; i < take; i++) {
                // TODO recheck this logic
                //bytes1 b = input[input_offset+i];
                chunk.block_bytes[i+chunk.block_len] = input[input_offset+i];
            }

            chunk.block_len += take;
            return input_offset + take;
        }
    }

}
