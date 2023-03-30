// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BatchScript} from 'src/BatchScript.sol';

interface ICrossChainBridge {
    /// @dev path_ = abi.encodePacked(remoteAddress, localAddress)
    function setTrustedRemote(uint16 srcChainId_, bytes calldata path_) external;
}

interface IKernel {
    function executeAction(uint8 action_, address target_) external;
}

/// @notice A test for Gnosis Safe batching script
/// @dev    GOERLI
contract Deploy is BatchScript {

  address localAddr = 0xefffab0Aa61828c4af926E039ee754e3edE10dAc; // Goerli bridge
  address remoteAddr = 0xB01432c01A9128e3d1d70583eA873477B2a1f5e1; // Arb goerli bridge
  
  /// @notice The main script entrypoint
  /// @return greeter The deployed contract
  function run() external returns (Greeter greeter) {
    vm.startBroadcast();
    greeter = new Greeter("GM");
    vm.stopBroadcast();

    address safe = vm.envAddress("MULTISIG");
    IKernel kernel = IKernel(vm.envAddress("GOERLI_KERNEL"));
    ICrossChainBridge bridge = ICrossChainBridge(localAddr);

    // Start batch
    // Install on kernel
    // kernel.executeAction(kernel.Action.ActivatePolicy, policy)
    bytes memory txn1 = abi.encodeWithSelector(IKernel.executeAction.selector, 2, address(bridge));
    addToBatch(address(kernel), 0, txn1);  

    // Call some initialize function on the contract
    // bridge.setTrustedRemote(vm.envUint("CHAIN_ID"), abi.encodePacked(remoteAddr, localAddr));
    bytes memory txn2 = abi.encodeWithSignature("setTrustedRemote(uint16,bytes)", vm.envUint("CHAIN_ID"), abi.encodePacked(remoteAddr, localAddr));
    addToBatch(address(bridge), 0, txn2);    


    // Execute batch
    executeBatch(safe);
  }
}