// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

//type State is uint32[16];
//type usize is uint32;

library Blake3 {
    /*
    uint32[8] constant IV = [
        0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A, 0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19
    ];

    uint8[16] constant MSG_PERMUTATION = [2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8];
    */


    // Mixing function G
    function g(
        uint32[16] memory state,
        uint32 a,
        uint32 b,
        uint32 c,
        uint32 d,
        uint32 mx,
        uint32 my)
    public {
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

    function round(uint32[16] memory state, uint32[16] memory m) public {
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
        uint8[16] memory MSG_PERMUTATION = [2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8];

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
        uint32[8] memory IV = [
            0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A, 0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19
        ];

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


}


contract Blake3Sol {
}
