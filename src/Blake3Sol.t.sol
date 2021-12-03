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
        sol.update_hasher(hasher, "hellohello?");
        assertEq(string(hasher.chunk_state.block_bytes), "oye");

        bytes memory output;
        sol.finalize(hasher, output);
        assertEq(string(output), "hi");
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
