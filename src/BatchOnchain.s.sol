// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IMultiSend} from "dep/IMultiSend.sol";
import {ISafe} from "dep/ISafe.sol";

/// @title BatchScript - A script for creating and executing Gnosis Safe batch transactions
/// @notice This contract provides utilities for building batch transactions with on-chain approvals
contract BatchOnchainScript is Script {
    // NOTE: This is the MultiSend v1.4.1 contract address for most chains. Modify if using a custom deployment.
    address constant SAFE_MULTISEND_ADDRESS = 0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526;

    /// @notice Array to store encoded transactions for the batch
    bytes[] internal encodedTxns;

    /// @notice Struct representing a Safe batch transaction
    struct Batch {
        address to;
        uint256 value;
        bytes data;
        ISafe.Operation operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address payable refundReceiver;
        uint256 nonce;
    }

    /// @notice Add a standard call operation to the batch
    /// @param safe The address of the Gnosis Safe
    /// @param to The target address for the transaction
    /// @param value The amount of ETH to send
    /// @param data The calldata for the transaction
    /// @return returnData The data returned from the local execution of the call
    function addToBatch(
        address safe,
        address to, 
        uint256 value, 
        bytes memory data
    ) public returns (bytes memory returnData) {
        if (safe == address(0)) revert("Safe address cannot be zero");

        // Encode the transaction for the batch
        bytes memory encodedTxn = abi.encodePacked(
            uint8(0), // operation (0 for CALL)
            to,
            value,
            data.length,
            data
        );
        encodedTxns.push(encodedTxn);
        
        // Execute locally to verify the transaction would succeed
        console2.log("=== Testing transaction locally from Safe ===");
        console2.log("Safe:", safe);
        console2.log("Target:", to);
        console2.log("Value:", value);
        
        // Impersonate the Safe address during the call
        vm.prank(safe);
            
        // Execute the call and capture both success status and returned data
        bool success;
        (success, returnData) = to.call{value: value}(data);
            
        // If call failed, revert with failure message
        if (!success) {
            console2.log("Local execution FAILED");
            revert("Transaction would fail when executed from the Safe");
        }
            
        console2.log("Local execution: SUCCESS");
        console2.log("============================");
        
        return returnData;
    }

    /// @notice Add a delegate call operation to the batch
    /// @param to The target address for the delegate call
    /// @param data The calldata for the transaction
    /// @return returnData The data returned from the local execution of the delegatecall
    function addDelegateCallToBatch(
        address safeAddress,
        address to, 
        bytes memory data
    ) public returns (bytes memory returnData) {
        if (safeAddress == address(0)) revert("Safe address cannot be zero");

        // Encode the transaction for the batch
        bytes memory encodedTxn = abi.encodePacked(
            uint8(1), // operation (1 for DELEGATECALL)
            to,
            uint256(0), // value must be 0 for delegatecall
            data.length,
            data
        );
        encodedTxns.push(encodedTxn);
        
        // Execute locally to verify the transaction would succeed
        console2.log("=== Testing delegatecall locally from Safe ===");
        console2.log("Safe:", safeAddress);
        console2.log("Target:", to);
            
        // Impersonate the Safe address during the delegatecall
        vm.prank(safeAddress);
            
        // Execute the delegatecall and capture both success status and returned data
        bool success;
        (success, returnData) = to.delegatecall(data);
            
        // If call failed, revert with failure message
        if (!success) {
            console2.log("Local execution FAILED");
            revert("Delegatecall would fail when executed from the Safe");
        }
            
        console2.log("Local execution: SUCCESS");
        console2.log("============================");
        
        return returnData;
    }

    /// @notice Build the batch transaction and save to JSON
    /// @param safe_ The address of the Gnosis Safe
    function buildBatch(address safe_) internal {
        require(safe_ != address(0), "Safe address cannot be zero");
        
        ISafe SAFE = ISafe(payable(safe_));
        uint256 nonce = SAFE.nonce();
        Batch memory batch = _createBatch(nonce);

        // Serialize batch to JSON
        string memory json = "";
        json = vm.serializeAddress("batch", "to", batch.to);
        json = vm.serializeUint("batch", "value", batch.value);
        json = vm.serializeBytes("batch", "data", batch.data);
        json = vm.serializeUint("batch", "operation", uint8(batch.operation));
        json = vm.serializeUint("batch", "safeTxGas", batch.safeTxGas);
        json = vm.serializeUint("batch", "baseGas", batch.baseGas);
        json = vm.serializeUint("batch", "gasPrice", batch.gasPrice);
        json = vm.serializeAddress("batch", "gasToken", batch.gasToken);
        json = vm.serializeAddress("batch", "refundReceiver", batch.refundReceiver);
        json = vm.serializeUint("batch", "nonce", batch.nonce);
        vm.writeJson(json, "./data/batch.json");

        // Compute and output transaction hash
        bytes32 txHash = SAFE.getTransactionHash(
            batch.to, batch.value, batch.data, batch.operation,
            batch.safeTxGas, batch.baseGas, batch.gasPrice,
            batch.gasToken, batch.refundReceiver, batch.nonce
        );
        console2.log("Transaction hash to approve:", vm.toString(txHash));
    }

    /// @notice Create a batch transaction from collected transactions
    /// @param nonce The Safe's current nonce
    /// @return batch The constructed batch transaction
    function _createBatch(uint256 nonce) private view returns (Batch memory batch) {
        batch.to = SAFE_MULTISEND_ADDRESS;
        batch.value = 0;
        batch.operation = ISafe.Operation.DELEGATECALL;
        bytes memory data;
        for (uint256 i; i < encodedTxns.length; ++i) {
            data = bytes.concat(data, encodedTxns[i]);
        }
        batch.data = abi.encodeWithSelector(IMultiSend.multiSend.selector, data);
        batch.safeTxGas = 0;
        batch.baseGas = 0;
        batch.gasPrice = 0;
        batch.gasToken = address(0);
        batch.refundReceiver = payable(address(0));
        batch.nonce = nonce;
    }

    /// @notice Convenience function to encode a batch transaction from a JSON file
    ///         and return the transaction hash
    /// @param safe_ The address of the Gnosis Safe
    /// @param batchFilePath Path to the JSON batch file
    /// @return txHash The hash of the transaction
    function encodeBatchFromFile(address safe_, string memory batchFilePath) public view returns (bytes32 txHash) {
        require(safe_ != address(0), "Safe address cannot be zero");
        
        ISafe SAFE = ISafe(payable(safe_));
        
        // Read and parse the batch JSON file
        string memory json = vm.readFile(batchFilePath);
        
        // Parse batch data from JSON
        address to = abi.decode(vm.parseJson(json, ".to"), (address));
        uint256 value = abi.decode(vm.parseJson(json, ".value"), (uint256));
        bytes memory data = abi.decode(vm.parseJson(json, ".data"), (bytes));
        ISafe.Operation operation = ISafe.Operation(abi.decode(vm.parseJson(json, ".operation"), (uint8)));
        uint256 safeTxGas = abi.decode(vm.parseJson(json, ".safeTxGas"), (uint256));
        uint256 baseGas = abi.decode(vm.parseJson(json, ".baseGas"), (uint256));
        uint256 gasPrice = abi.decode(vm.parseJson(json, ".gasPrice"), (uint256));
        address gasToken = abi.decode(vm.parseJson(json, ".gasToken"), (address));
        address payable refundReceiver = payable(abi.decode(vm.parseJson(json, ".refundReceiver"), (address)));
        uint256 nonce = abi.decode(vm.parseJson(json, ".nonce"), (uint256));
        
        // Compute transaction hash
        txHash = SAFE.getTransactionHash(
            to, value, data, operation,
            safeTxGas, baseGas, gasPrice,
            gasToken, refundReceiver, nonce
        );
        
        console2.log("Transaction hash from file:", vm.toString(txHash));
        return txHash;
    }
}
