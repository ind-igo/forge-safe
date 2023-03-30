// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

// 💬 ABOUT
// Standard Library's Gnosis Safe transaction batching script.

// 🧩 MODULES
import {console} from "./console.sol";
import {console2} from "./console2.sol";
import {StdChains} from "./StdChains.sol";
import {stdJson} from "./StdJson.sol";
import {stdMath} from "./StdMath.sol";
import {StdStorage, stdStorageSafe} from "./StdStorage.sol";
import {VmSafe} from "./Vm.sol";

import {Surl} from "lib/surl/src/Surl.sol";
import {RLPEncode} from "./RLPEncode.sol";

// 📦 BOILERPLATE
import {Script} from "./Script.sol";

// ⭐️ SCRIPT
abstract contract BatchScript is Script {
    using StdJson for string;
    using RLPEncode for *;
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

    // Deterministic deployment address of the Gnosis Safe Multisend contract.
    address internal constant SAFE_MULTISEND_ADDRESS_PRI = 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761; // TODO mainnet, goerli, most others
    address internal constant SAFE_MULTISEND_ADDRESS_SEC = 0x998739BFdAAdde7C933B942a68053933098f9EDa; // TODO optimism, some others

    string internal constant SAFE_API_BASE_URL = "https://safe-transaction-mainnet.safe.global/api/v1/safes/";
    string internal constant SAFE_API_MULTISIG_SEND = "/multisig-transactions";
    string internal constant SAFE_API_MULTISIG_ESTIMATE = "/estimations/";
    string internal constant ETHERSCAN_GAS_API_URL = "https://api.etherscan.io/api?module=gastracker&action=gasoracle&apikey=";

    enum Operation {
        CALL,
        DELEGATECALL
    }

    // Stages
    // 1. encodeWithSelector transactions into bytes
    // 2. encodePacked to packed structure
    struct Batch {
        Operation operation;
        address to;
        uint256 value;
        bytes encodedTx;
    }

    bytes[] public encodedTxns;
    Batch public batch;

    // Adds an encoded transaction to the batch.
    // Encodes the transaction as packed bytes of:
    // - `operation` as a `uint8` with `0` for a `call` or `1` for a `delegatecall` (=> 1 byte),
    // - `to` as an `address` (=> 20 bytes),
    // - `value` as a `uint256` (=> 32 bytes),
    // -  length of `data` as a `uint256` (=> 32 bytes),
    // - `data` as `bytes`.
    function addToBatch(address to_, uint256 value_, bytes memory data_) public {
        encodedTxns.push(abi.encodePacked(Operation.CALL, to_, value_, data_.length, data_));
    }


    // Encodes the stored encoded transactions into a single Multisend transaction
    function createBatch() internal {
        bytes memory data = abi.encodeWithSignature("multiSend(bytes)", abi.encode(encodedTxns));
        batch = Batch(Operation.DELEGATECALL, SAFE_MULTISEND_ADDRESS_PRI, 0, data);
    }

    function estimateBatchGas(address safe_) internal returns (uint256) {
        // Get endpoint
        string memory endpoint = getEstimateGasEndpoint(safe_);

        // Create json payload for send API call to Gnosis transaction service
        string memory payload = "";
        payload = payload.serialize("to", Batch.to);
        payload = payload.serialize("value", Batch.value);
        payload = payload.serialize("data", Batch.data);
        payload = payload.serialize("operation", uint256(Batch.operation));

        // Get gas estimate for batch
        (uint256 status, bytes memory data) = endpoint.post(getHeaders(), payload);

        if (status == 200) {
            string memory result = abi.decode(data, (string));
            return result.readUint("safeTxGas");
        } else {
            revert(); // TODO
        }
    }

    function getGasPrice() internal returns (uint256 baseFee, uint256 gasPrice) {
        string memory endpoint = string.concat(ETHERSCAN_GAS_API_URL, vm.envString("ETHERSCAN_API_KEY"));
        (uint256 status, bytes memory data) = endpoint.get();
        if (status == 200) {
            string memory result = abi.decode(data, (string));
            return (result.readUint("suggestBaseFee"), result.readUint("FastGasPrice"));
        } else {
            revert(); // TODO
        }
    }
    
    function getNonce(address safe_) internal returns (uint256) {
        string memory endpoint = string.concat(SAFE_API_BASE_URL, vm.toString(safe_));
        (uint256 status, bytes memory data) = endpoint.get();
        if(status == 200) {
            string memory result = abi.decode(data, (string));
            return result.readUint("nonce");
        } else {
            revert(); // TODO
        }
    }

    // Transaction data to be hashed
    // 0. nonce
    // 1. gasPrice (base or priority?)
    // 2. gasLimit
    // 3. to
    // 4. value
    // 5. data 
    // 6. chainId
    // Two zeros at the end?
    // 0
    // 0
    // Look at https://ethereum.org/en/developers/docs/transactions/
    function getTransactionHash() internal returns (string memory) {

    }

    function sendBatch(address safe_) internal {

        uint256 safeTxGas = estimateBatchGas(safe_);
        (uint256 baseFee, uint256 gasPrice) = getGasPrice();
        uint256 nonce = getNonce(safe_);
        
        // Get endpoint
        string memory endpoint = getSendEndpoint(safe_);


        // Create json payload for send API call to Gnosis transaction service
        string memory payload = "";
        payload = payload.serialize("safe", safe_);
        payload = payload.serialize("to", Batch.to);
        payload = payload.serialize("value", Batch.value);
        payload = payload.serialize("data", Batch.data);
        payload = payload.serialize("operation", uint256(Batch.operation));
        payload = payload.serialize("safeTxGas", safeTxGas);
        payload = payload.serialize("baseGas", baseFee);
        payload = payload.serialize("gasPrice", priorityFee);
        payload = payload.serialize("nonce", nonce);
        payload = payload.serialize("contractTransactionHash", ""); // TODO
        payload = payload.serialize("sender", msg.sender);

        // Send batch
        (uint256 status, bytes memory data) = endpoint.post(getHeaders(), payload);

        if (status == 201) {
            console2.log("Batch sent successfully");
        } else {
            revert(); // TODO
        }
        
        
    }

    function executeBatch() internal {
        createBatch();
        estimateBatchGas();
        sendBatch();
    }

    function getSendEndpoint(address safe_) public returns(string memory) {
        return string.concat(SAFE_API_BASE_URL, vm.toString(safe_), SAFE_API_MULTISIG_SEND);
    }

    function getEstimateGasEndpoint(address safe_) public returns (string memory) {
        return string.concat(getSafeAPIEndpoint(safe_), SAFE_API_MULTISIG_ESTIMATE);
    }

    function getHeaders() public returns (string[] memory) {
        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";
        return headers;
    }

}


