// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./Blake3Sol.sol";

contract Blake3SolTest is DSTest {
    Blake3Sol sol;

    function setUp() public {
        sol = new Blake3Sol();
    }

    function test_hash() public {
        Hasher memory hasher = sol.new_hasher();

        Hasher memory hasher1 = sol.update_hasher(hasher, unicode"hellohello?");
        /*
        bytes memory input = new bytes(2);
        input[0] = 0x01;
        input[1] = 0x02;
        */
        //bytes memory input = 0x00000000000000000000000000000000000000000000000000000000102;
        //Hasher memory hasher1 = sol.update_hasher(hasher, input);
        //Hasher memory hasher1 = sol.update_hasher(hasher, unicode"hiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiya");
        //assertEq(bytes32(hasher1.chunk_state.block_bytes), bytes32("oye"));
        /*
        uint32[16] memory perm = [uint32(0),1,2,3,4,5,6,7,8,9,10,11,12,13,14,15];
        uint32[16] memory perm_output = sol.shanes_permute(perm);
        for (uint8 i = 0; i < 16; i++) {
            assertEq(perm_output[i], i);
        }
        */


        Output memory self = sol.output(hasher1.chunk_state);
        /*
        for (uint8 i = 0; i < 16; i++) {
            assertEq(self.block_words[i], 1);
        }
        */

        // Compression test
        /*
        uint32 ROOT = 1 << 3;
        uint32[16] memory words_test = sol.compress(
            [uint32(1),1,1,1,1,1,1,1],
            [uint32(1),1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
            0,
            2,
            3
        );
        for (uint8 i = 0; i < 16; i++) {
            assertEq(words_test[i], 1);
        }
        */

       //assertEq(sol.rotr(1, 1), 2);

        // Compression value
        uint32[16] memory words = sol.compress(
            //[uint32(1),1,1,1,1,1,1,1],
            //[uint32(1),1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
            self.input_chaining_value,
            self.block_words,
            0,
            2,
            3
            //self.block_len,
            //self.flags | ROOT
        );
        /*
        for (uint8 i = 0; i < 16; i++) {
            //assertEq(words[i], 2234768957);
            assertEq(words[i], 1);
        }
        */
       bytes memory buf = sol.shanes_le(999999);
       //for (uint8 i = 0; i < 4; i++) {
       /*
           assertEq(bytes32(buf),
                    bytes32(new bytes(32)));
                    */
                    //bytes32([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]));
       //}

        // Ok the Output which is fed to root_output_bytes is the same value as
        // in the reference implementation
        //
        // The compress function produces the same output as the ref impl on
        // the above inputs dummy inputs (vectors of 1).
        // However it produces different outputs from the ref impl on the chunk
        // state "self" inputs, even though the input values are exactly the
        // same.

        /*
        assertEq(self.input_chaining_value[0], 300);
        for (uint8 i = 0; i < 1; i++) {
            assertEq(words[i], 74504119);
        }
        */

       /*
        uint32[16] memory state = sol.round_ext(
                      [uint32(0),3,2,0,0,0,0,0,0,0,0,0,0,0,0,1],
                      [uint32(1),3,1,1,1,1,1,1,1,1,1,1,1,1,1,2]);
        for (uint8 i = 0; i < 16; i++) {
            assertEq(state[i], 58);
        }
        */

        bytes memory output = sol.finalize(hasher1);
        assertEq(bytes32(output),
                 //0xb7d770040f780e9deff6bc038abea66e108b88d098d16d24cd7486eb671060b2);
                 0x10e6acb2cfcc4bb07588ad5b8e85f6a13f19e24f3302826effd93ce1ebbece6e);
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
