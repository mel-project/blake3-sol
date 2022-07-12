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

    function test_keyed_hash_thirty_times() public pure {
        Blake3Sol.Hasher memory hasher  = Blake3Sol.new_keyed(unicode"hellohello!");
        bytes memory output;

        bytes memory encodedStakeDoc = abi.encodePacked(
            bytes32(0x5dc57fc274b1235e28352d67b8ee4a30b74b5d0b070dc4400f30714cda80b280),
            bytes32(0xfd5fdd4268ccf9ed06fd481be5231b037e8efe905ff5aae270ee660c7240fe32),
            bytes3(0x05b030)
        );

        for (uint256 i = 0; i < 30; ++i) {
            hasher = hasher.update_hasher(encodedStakeDoc);
            output = hasher.finalize();
        }
    }

    /**
    * This test works by levaraging the FFI provided by Foundry tools, but it also requires the
    * bridge-differential-tests project to exist in the same folder as Blake3Sol and it must
    * be compiled using `cargo build` before running the Solidity test. This test currently passes
    * hashing ~50kb of data.
    */
    function test_big_hash_ffi() public {
        string[] memory cmds = new string[](2);
        cmds[0] = '../bridge-differential-tests/target/debug/bridge_differential_tests';
        cmds[1] = '--big-hash';

        bytes memory packedData = vm.ffi(cmds);
        (bytes memory data, bytes32 dataHash) = abi.decode(packedData, (bytes, bytes32));

        Blake3Sol.Hasher memory hasher = Blake3Sol.new_keyed(
            abi.encodePacked(
                bytes32(0xc811f2ef6eb6bd09fb973c747cbf349e682393ca4d8df88e5f0bcd564c10a84b)
            )
        );
        hasher = hasher.update_hasher(data);
        bytes memory bigHash = hasher.finalize();

        assertEq(bytes32(bigHash), dataHash);
    }
}