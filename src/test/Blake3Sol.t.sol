// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "forge-std/Test.sol";
import "../Blake3Sol.sol";

contract Blake3SolTest is Test {
    using Blake3Sol for Blake3Sol.Hasher;

    function test_hash() public {
        Blake3Sol.Hasher memory hasher = Blake3Sol.new_hasher();

        hasher = hasher.update_hasher(unicode"hellohello?");
        bytes memory output = hasher.finalize();

        assertEq(
            bytes32(output),
            0x10e6acb2cfcc4bb07588ad5b8e85f6a13f19e24f3302826effd93ce1ebbece6e
        );
    }

    function test_keyed_hash() public {
        Blake3Sol.Hasher memory hasher  = Blake3Sol.new_keyed(unicode"hellohello!");

        hasher = hasher.update_hasher(unicode"hellohello?");
        bytes memory output = hasher.finalize();

        assertEq(
            bytes32(output),
            0x0edd7e645d2bc1bba1f323f6339a3d0448ec6b675991e8dc76d2396eb0dffca2
        );
    }
}
