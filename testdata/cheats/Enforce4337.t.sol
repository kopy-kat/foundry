// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.18;

import "ds-test/test.sol";
import "./Vm.sol";

struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}

interface IAccount {
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds) external;
}

contract Account {
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds) public {
        address(this).call(hex"");
    }
}

contract AccountFactory {
    function createAccount(bytes32 salt) public returns (address) {
        return address(new Account{salt: salt}());
    }

    function getAccountAddress(bytes32 salt) public view returns (address) {
        bytes32 hash =
            keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(type(Account).creationCode)));

        return address(uint160(uint256(hash)));
    }
}

contract EntryPoint {
    struct ReturnInfo {
        uint256 preOpGas;
        uint256 prefund;
        bool sigFailed;
        uint48 validAfter;
        uint48 validUntil;
        bytes paymasterContext;
    }

    struct StakeInfo {
        uint256 stake;
        uint256 unstakeDelaySec;
    }

    error ValidationResult(ReturnInfo returnInfo, StakeInfo senderInfo, StakeInfo factoryInfo, StakeInfo paymasterInfo);

    function simulateValidation(UserOperation calldata userOp) external {
        // If initCode is present, create the account.
        if (userOp.initCode.length > 0) {
            address factory = address(bytes20(userOp.initCode[:20]));
            factory.call(userOp.initCode[20:]);
        }

        // Call account.validateUserOp.
        bytes32 userOpHash = keccak256(abi.encode(userOp));
        IAccount(userOp.sender).validateUserOp(userOp, userOpHash, 0);

        // If specified a paymaster: paymaster.validatePaymasterUserOp.

        ReturnInfo memory returnInfo = ReturnInfo(0, 0, false, 0, 0, hex"");
        StakeInfo memory senderInfo = StakeInfo(0, 0);
        StakeInfo memory factoryInfo = StakeInfo(0, 0);
        StakeInfo memory paymasterInfo = StakeInfo(0, 0);
        // revert ValidationResult(returnInfo, senderInfo, factoryInfo, paymasterInfo);
    }
}

contract Enforce4337Test is DSTest {
    Vm constant vm = Vm(HEVM_ADDRESS);

    function fillUserOp() internal returns (UserOperation memory userOp) {
        userOp.sender = address(0);
        userOp.nonce = 0;
        userOp.initCode = hex"";
        userOp.callData = hex"";
        userOp.callGasLimit = 0;
        userOp.verificationGasLimit = 0;
        userOp.preVerificationGas = 0;
        userOp.maxFeePerGas = 0;
        userOp.maxPriorityFeePerGas = 0;
        userOp.paymasterAndData = hex"";
        userOp.signature = hex"";
    }

    function testEnforce4337() public {
        EntryPoint entryPoint = new EntryPoint();
        AccountFactory accountFactory = new AccountFactory();

        bytes32 salt = bytes32(0);
        address account = accountFactory.getAccountAddress(salt);
        bytes memory initCode = abi.encodePacked(
            address(accountFactory), abi.encodeWithSelector(accountFactory.createAccount.selector, salt)
        );

        UserOperation memory userOp = fillUserOp();
        userOp.sender = address(account);
        userOp.initCode = initCode;

        // vm.expectRevert(EntryPoint.ValidationResult.selector);
        vm.enforce4337();
        entryPoint.simulateValidation(userOp);
    }
}
