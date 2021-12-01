// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

//type State is uint32[16];
//type usize is uint32;
uint8 constant BLOCK_LEN = 64;
uint32 constant OUT_LEN = 32;
uint32 constant CHUNK_LEN = 1024;

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
    uint32 block_len;
    uint8 blocks_compressed;
    uint32 flags;
}

// An incremental hasher that can accept any number of writes.
struct Hasher {
    ChunkState chunk_state;
    uint32[8] key_words;
    uint32[8][54] cv_stack; // Space for 54 subtree chaining values:
    uint8 cv_stack_len;     // 2^54 * CHUNK_LEN = 2^64
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

    function root_output_bytes(
        Output memory self,
        bytes memory out_slice) private
    {
        uint32 output_block_counter = 0;
        for (uint32 i = 0; i < out_slice.length; i += 2 * OUT_LEN) {
            uint32[16] memory words = compress(
                self.input_chaining_value,
                self.block_words,
                output_block_counter,
                self.block_len,
                self.flags | ROOT
            );
            // The output length might not be a multiple of 4.
            for (uint32 j = 0; j < words.length && out_slice.length > j*4; j++) {
                // Load word at j into out_slice as little endian
                load_uint32_to_le_bytes(words[j], out_slice, j*4);
            }

            output_block_counter += 1;
        }
    }

    function load_uint32_to_le_bytes(
        uint32 n,
        bytes memory buf,
        uint32 offset
    ) private
    {
        for (int i = 0; i < 4; i++) {
            assembly {
                let cc := add(add(buf, 0x20), offset)
                let buf_idx := add(cc, sub(3, i))
                let n_idx := add(n, i)
                mstore8(buf_idx, n_idx)
            }
        }
    }

    function uint32_to_le_bytes(uint32 n) private pure returns (bytes4)
    {
        bytes4 buf;
        for (int i = 0; i < 4; i++) {
            assembly {
                let cc := add(buf, 0x20)
                let buf_idx := add(cc, sub(3, i))
                let n_idx := add(n, i)
                mstore8(buf_idx, n_idx)
            }
        }

        return buf;
    }


    function toUint32(bytes memory _bytes, uint256 _start) internal pure returns (uint32) {
        require(_bytes.length >= _start + 4, "toUint32_outOfBounds");
        uint32 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x4), _start))
        }

        return tempUint;
    }

    function words_from_little_endian_bytes8(
        bytes memory data_bytes,
        uint32[8] memory words) public {
        for (uint8 i = 0; i < data_bytes.length/4; i++) {
            // TODO Little-endian?
            words[i] = toUint32(data_bytes, i*4);
        }
    }

    function words_from_little_endian_bytes(
        bytes memory data_bytes,
        uint32[16] memory words) public {
        for (uint8 i = 0; i < data_bytes.length/4; i++) {
            // TODO Little-endian?
            words[i] = toUint32(data_bytes, i*4);
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
    function update_chunkstate(
        ChunkState memory chunk,
        bytes calldata input,
        uint32 input_offset
    )
    public returns (uint32) {
        while (input_offset <= input.length) {
            // If the block buffer is full, compress it and clear it. More
            // input is coming, so this compression is not CHUNK_END.
            if (chunk.block_len == BLOCK_LEN) {
                uint32[16] memory block_words;
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
                bytes memory block_bytes = new bytes(BLOCK_LEN);
                chunk.block_bytes = block_bytes;
                chunk.block_len = 0;
            }

            // Take enough to fill a block [min(want, input.length)]
            uint32 want = BLOCK_LEN - chunk.block_len;
            // TODO be more careful with this downcast
            uint32 take = min(want, uint32(input.length));

            // Copy bytes from input to chunk block
            //chunk.block_bytes[self.block_len as usize..][..take].copy_from_slice(&input[..take]);
            /*
            for (uint32 i = 0; i < take; i++) {
                // TODO recheck this logic
                chunk.block_bytes[i+chunk.block_len] = input[input_offset+i];
            }
            */
           bytes memory block_ref = chunk.block_bytes;
            assembly {
                let block_addr := add(block_ref, 0x20)
                let input_addr := add(add(input.offset, 0x20), input_offset)
                calldatacopy(block_addr, input_addr, take)
            }

            chunk.block_len += take;
            return input_offset + take;
        }
    }

    function min(uint32 x, uint32 y) private returns (uint32) {
        if (x < y) {
            return x;
        } else {
            return y;
        }
    }

    function output(ChunkState memory chunk) public returns (Output memory) {
        uint32[16] memory block_words;
        words_from_little_endian_bytes(chunk.block_bytes, block_words);

        return Output({
            input_chaining_value: chunk.chaining_value,
            block_words: block_words,
            counter: chunk.chunk_counter,
            block_len: chunk.block_len,
            flags: chunk.flags | start_flag(chunk) | CHUNK_END
        });
    }

    //
    // Parent functions
    //

    function parent_output(
        uint32[8] memory left_child_cv,
        uint32[8] memory right_child_cv,
        uint32[8] memory key_words,
        uint32 flags
    ) public returns (Output memory) {
        uint32[16] memory block_words;
        for (uint8 i = 0; i < 8; i++) {
            block_words[i] = left_child_cv[i];
        }
        for (uint8 i = 8; i < 16; i++) {
            block_words[i] = right_child_cv[i];
        }

        return Output({
            input_chaining_value: key_words,
            block_words: block_words,
            counter: 0,           // Always 0 for parent nodes.
            block_len: BLOCK_LEN, // Always BLOCK_LEN (64) for parent nodes.
            flags: PARENT | flags
        });
    }

    function parent_cv(
        uint32[8] memory left_child_cv,
        uint32[8] memory right_child_cv,
        uint32[8] memory key_words,
        uint32 flags
    ) public returns (uint32[8] memory) {
        return chaining_value(parent_output(left_child_cv, right_child_cv, key_words, flags));
    }


    //
    // Hasher functions
    //

    function new_hasher_internal(uint32[8] memory key_words, uint32 flags)
    private returns (Hasher memory) {
        uint32[8][54] memory cv_stack;
        return Hasher({
            chunk_state: new_chunkstate(key_words, 0, flags),
            key_words: key_words,
            cv_stack: cv_stack,
            cv_stack_len: 0,
            flags: flags
        });
    }

    /// Construct a new `Hasher` for the regular hash function.
    function new_hasher() public returns (Hasher memory) {
        return new_hasher_internal(IV, 0);
    }

    /// Construct a new `Hasher` for the keyed hash function.
    function new_keyed(bytes calldata key) public returns (Hasher memory) {
        uint32[8] memory key_words;
        bytes memory key_mem = key;
        words_from_little_endian_bytes8(key_mem, key_words);
        return new_hasher_internal(key_words, KEYED_HASH);
    }

    // Construct a new `Hasher` for the key derivation function. The context
    // string should be hardcoded, globally unique, and application-specific
    function new_derive_key(bytes calldata context) public returns (Hasher memory) {
        Hasher memory context_hasher = new_hasher_internal(IV, DERIVE_KEY_CONTEXT);
        update_hasher(context_hasher, context);

        bytes memory context_key;
        finalize(context_hasher, context_key);

        uint32[8] memory context_key_words;
        words_from_little_endian_bytes8(context_key, context_key_words);

        return new_hasher_internal(context_key_words, DERIVE_KEY_MATERIAL);
    }

    function push_stack(Hasher memory self, uint32[8] memory cv) private {
        self.cv_stack[self.cv_stack_len] = cv;
        self.cv_stack_len += 1;
    }

    function pop_stack(Hasher memory self) private returns (uint32[8] memory) {
        self.cv_stack_len -= 1;
        return self.cv_stack[self.cv_stack_len];
    }

    function add_chunk_chaining_value(
        Hasher memory self,
        uint32[8] memory new_cv,
        uint64 total_chunks) private
    {
        while (total_chunks & 1 == 0) {
            new_cv = parent_cv(pop_stack(self), new_cv, self.key_words, self.flags);
            total_chunks >>= 1;
        }
        push_stack(self, new_cv);
    }

    /// Add input to the hash state. This can be called any number of times.
    function update_hasher(Hasher memory self, bytes calldata input) public {
        //while !input.is_empty() {
        uint32 input_offset = 0;
        while (input_offset < input.length) {
            // If the current chunk is complete, finalize it and reset the
            // chunk state. More input is coming, so this chunk is not ROOT.
            if (len(self.chunk_state) == CHUNK_LEN) {
                uint32[8] memory chunk_cv  = chaining_value(output(self.chunk_state));
                uint64 total_chunks = self.chunk_state.chunk_counter + 1;
                add_chunk_chaining_value(self, chunk_cv, total_chunks);
                self.chunk_state = new_chunkstate(self.key_words, total_chunks, self.flags);
            }

            // Compress input bytes into the current chunk state.
            uint32 want = CHUNK_LEN - len(self.chunk_state);

            // take = min(want, input.length);
            uint32 take;
            if (want < input.length) {
                take = want;
            } else {
                // TODO be more careful with this downcast
                take = uint32(input.length);
            }

            // Update chunk state
            bytes calldata input_slice = input[input_offset:take+input_offset];
            input_offset = update_chunkstate(self.chunk_state, input_slice, input_offset);

            //input_offset += take;
        }
    }

    function finalize(Hasher memory self, bytes memory out_slice) public {
        // Starting with the Output from the current chunk, compute all the
        // parent chaining values along the right edge of the tree, until we
        // have the root Output.
        Output memory output = output(self.chunk_state);
        uint32 parent_nodes_remaining = self.cv_stack_len;
        while (parent_nodes_remaining > 0) {
            parent_nodes_remaining -= 1;
            output = parent_output(
                self.cv_stack[parent_nodes_remaining],
                chaining_value(output),
                self.key_words,
                self.flags
            );
        }
        root_output_bytes(output, out_slice);
    }


}
