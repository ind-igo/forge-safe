// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

// 💬 ABOUT
// Gnosis Safe transaction batching script

// 🧩 MODULES
import {
    Script,
    console,
    console2,
    StdChains,
    stdJson,
    stdMath,
    StdStorage,
    stdStorageSafe,
    VmSafe
} from "forge-std/Script.sol";

import {Surl} from "lib/surl/src/Surl.sol";

// ⭐️ SCRIPT
abstract contract BatchScript is Script {
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
    }

    bytes[] public encodedTxns;

    // Public functions

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

    function executeBatch(address safe_) public {
        Batch memory batch = _createBatch(safe_);
        _sendBatch(safe_, batch);
    }

    // Encodes the stored encoded transactions into a single Multisend transaction
    function _createBatch(address safe_) internal returns (Batch memory batch) {
        // Set initial batch fields
        batch.to = SAFE_MULTISEND_ADDRESS_PRI;
        batch.value = 0;
        batch.operation = Operation.DELEGATECALL;

        // Encode the batch calldata
        batch.data = abi.encodeWithSignature("multiSend(bytes)", abi.encode(encodedTxns));

        // Get the gas estimate for the batch
        batch.safeTxGas = _estimateBatchGas(safe_, batch);

        // Get the gas price
        (batch.baseGas, batch.gasPrice) = _getGasPrice();

        // Get the safe nonce
        batch.nonce = _getNonce(safe_);

        // Get the transaction hash
        batch.txHash = _getTransactionHash(safe_, batch);        
    }

    function _sendBatch(address safe_, Batch memory batch_) internal {
        string memory endpoint = _getSafeAPIEndpoint(safe_);

        // Create json payload for API call to Gnosis transaction service
        string memory payload = "";
        payload = payload.serialize("safe", safe_);
        payload = payload.serialize("to", batch_.to);
        payload = payload.serialize("value", batch_.value);
        payload = payload.serialize("data", batch_.data);
        payload = payload.serialize("operation", uint256(batch_.operation));
        payload = payload.serialize("safeTxGas", batch_.safeTxGas);
        payload = payload.serialize("baseGas", batch_.baseGas);
        payload = payload.serialize("gasPrice", batch_.gasPrice);
        payload = payload.serialize("nonce", batch_.nonce);
        payload = payload.serialize("contractTransactionHash", batch_.txHash);
        payload = payload.serialize("sender", msg.sender);

        // Send batch
        (uint256 status, bytes memory data) = endpoint.post(_getHeaders(), payload);

        if (status == 201) console2.log("Batch sent successfully");
        else revert("Send batch failed!"); // TODO
    }


    // Computes the EIP712 hash of a Safe transaction.
    // Look at https://github.com/safe-global/safe-eth-py/blob/174053920e0717cc9924405e524012c5f953cd8f/gnosis/safe/safe_tx.py#L186
    // and https://github.com/safe-global/safe-eth-py/blob/master/gnosis/eth/eip712/__init__.py
    function _getTransactionHash(address safe_, Batch memory batch_) internal view returns (bytes32) {
        // // Create EIP712 structured data for the batch transaction

        // // EIP712Domain Types
        // string[] memory domainTypes = new string[](2);
        // domainTypes[0] = "";
        // domainTypes[0] = domainTypes[0].serialize("name", "verifyingContract");
        // domainTypes[0] = domainTypes[0].serialize("type", "address");
        // domainTypes[1] = "";
        // domainTypes[1] = domainTypes[1].serialize("name", "chainId");
        // domainTypes[1] = domainTypes[1].serialize("type", "uint256");

        // // SafeTx Field Types
        // string[] memory txnTypes = new string[](10);
        // txnTypes[0] = "";
        // txnTypes[0] = txnTypes[0].serialize("name", "to");
        // txnTypes[0] = txnTypes[0].serialize("type", "address");
        // txnTypes[1] = "";
        // txnTypes[1] = txnTypes[1].serialize("name", "value");
        // txnTypes[1] = txnTypes[1].serialize("type", "uint256");
        // txnTypes[2] = "";
        // txnTypes[2] = txnTypes[2].serialize("name", "data");
        // txnTypes[2] = txnTypes[2].serialize("type", "bytes");
        // txnTypes[3] = "";
        // txnTypes[3] = txnTypes[3].serialize("name", "operation");
        // txnTypes[3] = txnTypes[3].serialize("type", "uint8");
        // txnTypes[4] = "";
        // txnTypes[4] = txnTypes[4].serialize("name", "safeTxGas");
        // txnTypes[4] = txnTypes[4].serialize("type", "uint256");
        // txnTypes[5] = "";
        // txnTypes[5] = txnTypes[5].serialize("name", "baseGas");
        // txnTypes[5] = txnTypes[5].serialize("type", "uint256");
        // txnTypes[6] = "";
        // txnTypes[6] = txnTypes[6].serialize("name", "gasPrice");
        // txnTypes[6] = txnTypes[6].serialize("type", "uint256");
        // txnTypes[7] = "";
        // txnTypes[7] = txnTypes[7].serialize("name", "gasToken");
        // txnTypes[7] = txnTypes[7].serialize("type", "address");
        // txnTypes[8] = "";
        // txnTypes[8] = txnTypes[8].serialize("name", "refundReceiver");
        // txnTypes[8] = txnTypes[8].serialize("type", "address");
        // txnTypes[9] = "";
        // txnTypes[9] = txnTypes[9].serialize("name", "nonce");
        // txnTypes[9] = txnTypes[9].serialize("type", "uint256");

        // // Create the top level types object
        // string memory types = "";
        // types = types.serialize("EIP712Domain", domainTypes);
        // types = types.serialize("SafeTx", txnTypes);

        // // Create the message object
        // string memory message = "";
        // message = message.serialize("to", Batch.to);
        // message = message.serialize("value", Batch.value);
        // message = message.serialize("data", Batch.data);
        // message = message.serialize("operation", uint256(Batch.operation));
        // message = message.serialize("safeTxGas", Batch.safeTxGas);
        // message = message.serialize("baseGas", Batch.baseGas);
        // message = message.serialize("gasPrice", Batch.gasPrice);
        // message = message.serialize("gasToken", address(0));
        // message = message.serialize("refundReceiver", address(0));
        // message = message.serialize("nonce", Batch.nonce);

        // // Create the domain object
        // string memory domain = "";
        // domain = domain.serialize("verifyingContract", Batch.safe);
        // domain = domain.serialize("chainId", vm.envUint("CHAIN_ID"));

        // // Create the payload object
        // string memory payload = "";
        // payload = payload.serialize("types", types);
        // payload = payload.serialize("primaryType", "SafeTx");
        // payload = payload.serialize("domain", domain);
        // payload = payload.serialize("message", message);

        // ABI-encoding version

        // Create hash of the transaction with EIP712
    
        return keccak256(abi.encodePacked(
                hex"1901",
                keccak256(
                    abi.encode(
                        keccak256("EIP712Domain(address verifyingContract, uint256 chainId)"),
                        safe_,
                        vm.envUint("CHAIN_ID")
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256("SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"),
                        batch_.to,
                        batch_.value,
                        batch_.data,
                        uint256(batch_.operation),
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

    function _estimateBatchGas(address safe_, Batch memory batch_) internal returns (uint256) {
        // Get endpoint
        string memory endpoint = _getEstimateGasEndpoint(safe_);

        // Create json payload for send API call to Gnosis transaction service
        string memory payload = "";
        payload = payload.serialize("to", batch_.to);
        payload = payload.serialize("value", batch_.value);
        payload = payload.serialize("data", batch_.data);
        payload = payload.serialize("operation", uint256(batch_.operation));

        // Get gas estimate for batch
        (uint256 status, bytes memory data) = endpoint.post(_getHeaders(), payload);

        if (status == 200) {
            string memory result = abi.decode(data, (string));
            return result.readUint("safeTxGas");
        } else {
            revert(); // TODO
        }
    }

    function _getGasPrice() internal returns (uint256 baseFee, uint256 gasPrice) {
        string memory endpoint = string.concat(ETHERSCAN_GAS_API_URL, vm.envString("ETHERSCAN_API_KEY"));
        (uint256 status, bytes memory data) = endpoint.get();
        if (status == 200) {
            string memory result = abi.decode(data, (string));
            return (result.readUint("suggestBaseFee"), result.readUint("FastGasPrice"));
        } else {
            revert(); // TODO
        }
    }

    function _getNonce(address safe_) internal returns (uint256) {
        string memory endpoint = string.concat(SAFE_API_BASE_URL, vm.toString(safe_));
        (uint256 status, bytes memory data) = endpoint.get();
        if(status == 200) {
            string memory result = abi.decode(data, (string));
            return result.readUint("nonce");
        } else {
            revert(); // TODO
        }
    }



    // Internal functions

    function _getSafeAPIEndpoint(address safe_) internal returns(string memory) {
        return string.concat(SAFE_API_BASE_URL, vm.toString(safe_), SAFE_API_MULTISIG_SEND);
    }

    function _getEstimateGasEndpoint(address safe_) internal returns (string memory) {
        return string.concat(_getSafeAPIEndpoint(safe_), SAFE_API_MULTISIG_ESTIMATE);
    }

    function _getHeaders() internal returns (string[] memory) {
        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";
        return headers;
    }

}


