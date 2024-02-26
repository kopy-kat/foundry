// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.18;

import "ds-test/test.sol";
import "./Vm.sol";

contract Target {
    function read(bytes32 key) public view returns (bytes32) {
        return bytes32(uint256(key) + 1);
    }
}

/// @notice Test that the cheatcode correctly records account accesses
contract RecordAccountAccessOpcodesTest is DSTest {
    Vm constant cheats = Vm(HEVM_ADDRESS);

    Target target;

    function setUp() public {
        target = new Target();
    }

    function testStorageAccessDelegateCall() public {
        cheats.startStateDiffRecording();
        address(target).call(abi.encodeCall(Target.read, bytes32(uint256(1234))));
        cheats.stopAndReturnStateDiff();

        Vm.OpcodeAccess[] memory opcodeAccess = cheats.getStateDiffOpcodes(0);

        assertGt(opcodeAccess.length, 0);
    }
}
