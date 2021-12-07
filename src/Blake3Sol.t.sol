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

        //Hasher memory hasher1 = sol.update_hasher(hasher, unicode"hellohello?");
        bytes memory input = new bytes(4);
        input[0] = 0x01;
        input[1] = 0x02;
        //input[3] = 0x01;
        //input[2] = 0x02;
        //bytes memory input = 0x00000000000000000000000000000000000000000000000000000000102;
        //Hasher memory hasher1 = sol.update_hasher(hasher, input);
        Hasher memory hasher1 = sol.update_hasher(hasher, input);
        //Hasher memory hasher1 = sol.update_hasher(hasher, unicode"hiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiyahiya");
        assertEq(bytes32(hasher1.chunk_state.block_bytes), bytes32("oye"));


        Output memory out = sol.output(hasher1.chunk_state);
        for (uint8 i = 0; i < 1; i++) {
            assertEq(out.block_words[i], 1);
        }

        bytes memory output = sol.finalize(hasher1);
        assertEq(bytes32(output),
                 0x10e6acb2cfcc4bb07588ad5b8e85f6a13f19e24f3302826effd93ce1ebbece6e);
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
