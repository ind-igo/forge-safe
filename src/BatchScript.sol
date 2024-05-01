// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

// 💬 ABOUT
// Gnosis Safe transaction batching script

// 🧩 MODULES
import {Script, console2, StdChains, stdJson, stdMath, StdStorage, stdStorageSafe, VmSafe} from "forge-std/Script.sol";

import {Surl} from "../lib/surl/src/Surl.sol";
import {DelegatePrank} from "./lib/DelegatePrank.sol";

// ⭐️ SCRIPT
abstract contract BatchScript is Script, DelegatePrank {
    using stdJson for string;
    using Surl for *;

    //     "to": "<checksummed address>",
    //     "value": 0, // Value in wei
    //     "data": "<0x prefixed hex string>",
    //     "operation": 0,  // 0 CALL, 1 DELEGATE_CALL
    //     "safeTxGas": 0,  // Max gas to use in the transaction

    // Used by refund mechanism, not needed here
    //     "gasToken": "<checksummed address>", // Token address (hold by the Safe) to be used as a refund to the sender, if `null` is Ether
    //     "baseGas": 0,  // Gast costs not related to the transaction execution (signature check, refund payment...)
    //     "gasPrice": 0,  // Gas price used for the refund calculation
    //     "refundReceiver": "<checksummed address>", //Address of receiver of gas payment (or `null` if tx.origin)

    //     "nonce": 0,  // Nonce of the Safe, transaction cannot be executed until Safe's nonce is not equal to this nonce
    //     "contractTransactionHash": "string",  // Contract transaction hash calculated from all the field
    //     "sender": "<checksummed address>",  // Owner of the Safe proposing the transaction. Must match one of the signatures
    //     "signature": "<0x prefixed hex string>",  // One or more ethereum ECDSA signatures of the `contractTransactionHash` as an hex string

    // Not required
    //     "origin": "string"  // Give more information about the transaction, e.g. "My Custom Safe app"

    // Hash constants
    // Safe version for this script, hashes below depend on this
    string private constant VERSION = "1.3.0";

    // keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    // keccak256(
    //     "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
    // );
    bytes32 private constant SAFE_TX_TYPEHASH =
        0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8;

    // Deterministic deployment address of the Gnosis Safe Multisend contract, configured by chain.
    address private SAFE_MULTISEND_ADDRESS;

    // Chain ID, configured by chain.
    uint256 private chainId;

    // Safe API base URL, configured by chain.
    string private SAFE_API_BASE_URL;
    string private constant SAFE_API_MULTISIG_SEND = "/multisig-transactions/";

    enum Operation {
        CALL,
        DELEGATECALL
    }

    struct Batch {
        address to;
        uint256 value;
        bytes data;
        Operation operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address refundReceiver;
        uint256 nonce;
        bytes32 txHash;
        bytes signature;
    }

    bytes[] public encodedTxns;

    // Public functions

    // Adds an encoded transaction to the batch.
    // Encodes the transaction as packed bytes of:
    // - `operation` as a `uint8` with `0` for a `call` or `1` for a `delegatecall` (=> 1 byte),
    // - `to` as an `address` (=> 20 bytes),
    // - `value` as in msg.value, sent as a `uint256` (=> 32 bytes),
    // -  length of `data` as a `uint256` (=> 32 bytes),
    // - `data` as `bytes`.
    function addToBatch(
        address to_,
        uint256 value_,
        bytes memory data_
    ) public {
        encodedTxns.push(
            abi.encodePacked(Operation.CALL, to_, value_, data_.length, data_)
        );
    }

    // Convenience funtion to add an encoded transaction to the batch, but passes
    // 0 as the `value` (equivalent to msg.value) field.
    function addToBatch(address to_, bytes memory data_) public {
        encodedTxns.push(
            abi.encodePacked(
                Operation.CALL,
                to_,
                uint256(0),
                data_.length,
                data_
            )
        );
    }

    // Simulate then send the batch to the Safe API. If `send_` is `false`, the
    // batch will only be simulated.
    function executeBatch(address safe_, bool send_) public {
        _initialize();
        Batch memory batch = _createBatch(safe_);
        _simulateBatch(safe_, batch);
        if (send_) {
            batch = _signBatch(batch);
            _sendBatch(safe_, batch);
        }
    }

    // Internal functions
    function _initialize() private {
        // Set the chain ID
        chainId = block.chainid;
        // Set the Safe API base URL and multisend address based on chain
        if (chainId == 1) {
            SAFE_API_BASE_URL = "https://safe-transaction-mainnet.safe.global/api/v1/safes/";
            SAFE_MULTISEND_ADDRESS = 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761;
        } else if (chainId == 5) {
            SAFE_API_BASE_URL = "https://safe-transaction-goerli.safe.global/api/v1/safes/";
            SAFE_MULTISEND_ADDRESS = 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761;
        } else if (chainId == 42161) {
            SAFE_API_BASE_URL = "https://safe-transaction-arbitrum.safe.global/api/v1/safes/";
            SAFE_MULTISEND_ADDRESS = 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761;
        } else if (chainId == 43114) {
            SAFE_API_BASE_URL = "https://safe-transaction-avalanche.safe.global/api/v1/safes/";
            SAFE_MULTISEND_ADDRESS = 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761;
        } else {
            revert("Unsupported chain");
        }
        console2.log("Using Signer:", msg.sender);
    }

    // Encodes the stored encoded transactions into a single Multisend transaction
    function _createBatch(address safe_) internal returns (Batch memory batch) {
        // Set initial batch fields
        batch.to = SAFE_MULTISEND_ADDRESS;
        batch.value = 0;
        batch.operation = Operation.DELEGATECALL;

        // Encode the batch calldata. The list of transactions is tightly packed.
        bytes memory data;
        uint256 len = encodedTxns.length;
        for (uint256 i; i < len; ++i) {
            data = bytes.concat(data, encodedTxns[i]);
        }
        batch.data = abi.encodeWithSignature("multiSend(bytes)", data);

        // Batch gas parameters can all be zero and don't need to be set

        // Get the safe nonce
        batch.nonce = _getNonce(safe_);

        // Get the transaction hash
        batch.txHash = _getTransactionHash(safe_, batch);
    }

    function _signBatch(
        Batch memory batch_
    ) internal pure returns (Batch memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(batch_.txHash);
        // Set the signature on the batch
        bytes memory signature = abi.encodePacked(r, s, v);
        batch_.signature = signature;
        return batch_;
    }

    function _simulateBatch(address safe_, Batch memory batch_) internal {
        require(batch_.to.code.length > 0, "No code at address");
        vm.allowCheatcodes(safe_);
        (bool success, bytes memory data) = delegatePrank(
            safe_,
            batch_.to,
            batch_.data
        );
        if (success) {
            console2.log("Batch simulated successfully");
        } else {
            revert(string(data));
        }
    }

    function _sendBatch(address safe_, Batch memory batch_) internal {
        string memory endpoint = _getSafeAPIEndpoint(safe_);

        // Create json payload for API call to Gnosis transaction service
        string memory placeholder = "";
        placeholder.serialize("safe", safe_);
        placeholder.serialize("to", batch_.to);
        placeholder.serialize("value", batch_.value);
        placeholder.serialize("data", batch_.data);
        placeholder.serialize("operation", uint256(batch_.operation));
        placeholder.serialize("safeTxGas", batch_.safeTxGas);
        placeholder.serialize("baseGas", batch_.baseGas);
        placeholder.serialize("gasPrice", batch_.gasPrice);
        placeholder.serialize("nonce", batch_.nonce);
        placeholder.serialize("gasToken", address(0));
        placeholder.serialize("refundReceiver", address(0));
        placeholder.serialize("contractTransactionHash", batch_.txHash);
        placeholder.serialize("signature", batch_.signature);
        string memory payload = placeholder.serialize("sender", msg.sender);

        // Send batch
        (uint256 status, bytes memory data) = endpoint.post(
            _getHeaders(),
            payload
        );

        if (status == 201) {
            console2.log("Batch sent successfully");
        } else {
            console2.log(string(data));
            revert("Send batch failed!");
        }
    }

    // Computes the EIP712 hash of a Safe transaction.
    // Look at https://github.com/safe-global/safe-eth-py/blob/174053920e0717cc9924405e524012c5f953cd8f/gnosis/safe/safe_tx.py#L186
    // and https://github.com/safe-global/safe-eth-py/blob/master/gnosis/eth/eip712/__init__.py
    function _getTransactionHash(
        address safe_,
        Batch memory batch_
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    hex"1901",
                    keccak256(
                        abi.encode(DOMAIN_SEPARATOR_TYPEHASH, chainId, safe_)
                    ),
                    keccak256(
                        abi.encode(
                            SAFE_TX_TYPEHASH,
                            batch_.to,
                            batch_.value,
                            keccak256(batch_.data),
                            batch_.operation,
                            batch_.safeTxGas,
                            batch_.baseGas,
                            batch_.gasPrice,
                            address(0),
                            address(0),
                            batch_.nonce
                        )
                    )
                )
            );
    }

    function _getNonce(address safe_) internal returns (uint256) {
        string memory endpoint = string.concat(
            SAFE_API_BASE_URL,
            vm.toString(safe_),
            "/"
        );
        (uint256 status, bytes memory data) = endpoint.get();
        if (status == 200) {
            string memory result = string(data);
            return result.readUint(".nonce");
        } else {
            revert("Get nonce failed!");
        }
    }

    function _getSafeAPIEndpoint(
        address safe_
    ) internal view returns (string memory) {
        return
            string.concat(
                SAFE_API_BASE_URL,
                vm.toString(safe_),
                SAFE_API_MULTISIG_SEND
            );
    }

    function _getHeaders() internal pure returns (string[] memory) {
        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";
        return headers;
    }
}
