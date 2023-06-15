// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BatchScript} from "src/BatchScript.sol";

interface ICrossChainBridge {
    /// @dev path_ = abi.encodePacked(remoteAddress, localAddress)
    function setTrustedRemote(
        uint16 srcChainId_,
        bytes calldata path_
    ) external;
}

interface IKernel {
    function executeAction(uint8 action_, address target_) external;
}

/// @notice A test for Gnosis Safe batching script
/// @dev    GOERLI
contract TestBatch is BatchScript {
    address localBridgeAddr = 0xefffab0Aa61828c4af926E039ee754e3edE10dAc; // Goerli bridge
    address remoteBridgeAddr = 0xB01432c01A9128e3d1d70583eA873477B2a1f5e1; // Arb goerli bridge
    address safe = 0x84C0C005cF574D0e5C602EA7b366aE9c707381E0;
    uint16 lzChainId = 10143;

    /// @notice The main script entrypoint
    function run(bool send_) external {
        // vm.startBroadcast();

        IKernel kernel = IKernel(0xDb7cf68154bd422dF5196D90285ceA057786b4c3);
        ICrossChainBridge bridge = ICrossChainBridge(localBridgeAddr);

        // Start batch
        // Install on kernel
        // kernel.executeAction(kernel.Action.ActivatePolicy, policy)
        bytes memory txn1 = abi.encodeWithSelector(
            IKernel.executeAction.selector,
            2,
            address(bridge)
        );
        addToBatch(address(kernel), 0, txn1);

        // Call some initialize function on the contract
        // bridge.setTrustedRemote(vm.envUint("CHAIN_ID"), abi.encodePacked(remoteBridgeAddr, localBridgeAddr));
        bytes memory txn2 = abi.encodeWithSignature(
            "setTrustedRemote(uint16,bytes)",
            lzChainId,
            abi.encodePacked(remoteBridgeAddr, localBridgeAddr)
        );
        addToBatch(address(bridge), txn2);

        // Execute batch
        executeBatch(safe, send_);

        // vm.stopBroadcast();
    }
}
