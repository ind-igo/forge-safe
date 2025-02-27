// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ISafe} from "dep/ISafe.sol";

import {LibSort} from "lib/solady/src/utils/LibSort.sol";

/// @title ExecBatchOnchain
/// @notice A script for executing approved Gnosis Safe batch transactions onchain
contract ExecBatchOnchain is Script {
    using stdJson for string;

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

    address[] private approvingOwners;
    
    // Script accepts a batch file path as a CLI argument
    function run(string memory batchFilePath) public {
        console2.log("Using batch file:", batchFilePath);

        string memory json = vm.readFile(batchFilePath);
        Batch memory batch;
        batch.to = json.readAddress(".to");
        batch.value = json.readUint(".value");
        batch.data = json.readBytes(".data");
        batch.operation = ISafe.Operation(json.readUint(".operation"));
        batch.safeTxGas = json.readUint(".safeTxGas");
        batch.baseGas = json.readUint(".baseGas");
        batch.gasPrice = json.readUint(".gasPrice");
        batch.gasToken = json.readAddress(".gasToken");
        batch.refundReceiver = payable(json.readAddress(".refundReceiver"));
        batch.nonce = json.readUint(".nonce");

        ISafe SAFE = ISafe(payable(vm.envAddress("SAFE_ADDRESS")));

        // Compute transaction hash
        bytes32 txHash = SAFE.getTransactionHash(
            batch.to, batch.value, batch.data, batch.operation,
            batch.safeTxGas, batch.baseGas, batch.gasPrice,
            batch.gasToken, batch.refundReceiver, batch.nonce
        );

        {
        // Check if the transaction has enough approvals
        uint256 threshold = SAFE.getThreshold();
        uint256 approvalCount = 0;
        
        // Count approvals by checking each owner
        address[] memory owners = SAFE.getOwners();
        for (uint256 i = 0; i < owners.length; i++) {
            if (SAFE.approvedHashes(owners[i], txHash) == 1) {
                approvingOwners.push(owners[i]);
                approvalCount++;
            }
        }
            
        require(approvalCount >= threshold, "Not enough approvals");

        console2.log("Executing transaction with hash:", vm.toString(txHash));
        console2.log("Approvals:", approvalCount, "Threshold:", threshold);
        }

        // Encode a signature based on the approving owners
        
        // Sort the addresses in ascending order
        address[] memory sortedApprovingOwners = approvingOwners;
        LibSort.sort(sortedApprovingOwners);

        // Construct the signature using the sorted addresses
        bytes memory signatures = new bytes(0);
        for (uint256 i = 0; i < sortedApprovingOwners.length; i++) {
            signatures = abi.encodePacked(
                signatures,
                uint256(uint160(sortedApprovingOwners[i])),
                bytes32(0),
                uint8(1)
            );
        }

        // Execute the transaction
        vm.startBroadcast();
        bool success = SAFE.execTransaction(
            batch.to, batch.value, batch.data, batch.operation,
            batch.safeTxGas, batch.baseGas, batch.gasPrice,
            batch.gasToken, batch.refundReceiver, signatures
        );
        vm.stopBroadcast();

        require(success, "Transaction execution failed");
        console2.log("Transaction executed successfully");
    }
} 