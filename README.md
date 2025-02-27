# forge-safe: Gnosis Safe Batch Builder (On-Chain Approvals)

This tool builds and executes Gnosis Safe batch transactions using on-chain approvals via the `approveHash` function.

## Prerequisites
- Foundry installed (`forge`)
- A deployed Gnosis Safe
- Network RPC URL and owner private keys

## Setup
1. Clone the repo and install dependencies:
   ```sh
   git clone <repo-url>
   cd forge-safe
   forge install
   ```

## Workflow

### Build the Batch:
1. Customize `script/BatchScript.sol`'s run function with your transactions.
2. Run the script:
   ```sh
   forge script script/BatchScript.sol:BatchScript --rpc-url $RPC_URL -vvvv
   ```
3. Note the transaction hash output and check `data/batch.json`.

### Approve the Hash:
Each Safe owner approves the hash:
```sh
cast send --private-key $OWNER_KEY $SAFE_ADDRESS "approveHash(bytes32)" $TX_HASH
```

### Execute the Transaction:
Once enough approvals are collected, execute:
```sh
SAFE=$SAFE_ADDRESS PRIVATE_KEY=$EXECUTOR_KEY forge script script/ExecBatchWithApprovals.s.sol:ExecBatchWithApprovals --rpc-url $RPC_URL --broadcast -vvvv
```

## Example Scripts

### Basic Test Script

For a quick test of the batch functionality, you can use the included test script:

1. Update the `TEST_SAFE_ADDRESS` in `script/testbatch.s.sol` with your Safe address.
2. Run the test script:
   ```sh
   forge script script/testbatch.s.sol:TestBatch --rpc-url $RPC_URL -vvvv
   ```

The test script includes two simple example transactions:
- A small ETH transfer (0.001 ETH)
- A token approval for 1000 DAI

This provides a ready-to-use example to verify your setup before customizing for your own needs.

### DeFi Example Script

For a more advanced example with real DeFi protocols, use the DeFi example script:

1. Update the `SAFE_ADDRESS` in `script/defi_example.s.sol` with your Safe address.
2. Run the DeFi example script:
   ```sh
   forge script script/defi_example.s.sol:DeFiExample --rpc-url $RPC_URL -vvvv
   ```

This script demonstrates a realistic DeFi workflow by:
1. Approving USDC for Uniswap V3
2. Swapping USDC to ETH using Uniswap V3
3. Approving DAI for Aave V3
4. Supplying DAI to Aave V3

All contract addresses used are real mainnet addresses, making this script ready for production use with minimal changes.

## Detailed Example

### Example Scenario
In this example, we'll create a batch transaction for a Gnosis Safe on Ethereum Mainnet that:
1. Sends 0.1 ETH to a recipient
2. Approves a token contract to spend 1000 USDC
3. Calls a custom contract function

### Step 1: Configure BatchScript.sol

```solidity
// Define interfaces for the contracts you'll interact with
interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
}

interface ICustomContract {
    function setConfig(string calldata name, uint256 value) external;
}

// In script/BatchScript.sol, modify the run function:
function run() external {
    address safeAddress = 0x1234567890123456789012345678901234567890; // Your Safe address
    
    // Example 1: Send 0.1 ETH to a recipient
    addToBatch(
        0xabcdef0123456789abcdef0123456789abcdef01, // Recipient address
        100000000000000000, // 0.1 ETH in wei
        ""
    );
    
    // Example 2: Approve USDC spending
    // USDC contract on Ethereum Mainnet: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    addToBatch(
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC contract
        0,
        abi.encodeWithSelector(
            IERC20.approve.selector,
            0x2222222222222222222222222222222222222222, // Spender address
            1000000000 // 1000 USDC (with 6 decimals)
        )
    );
    
    // Example 3: Call a custom contract function
    addToBatch(
        0x3333333333333333333333333333333333333333, // Contract address
        0,
        abi.encodeWithSelector(
            ICustomContract.setConfig.selector,
            "maxGasPrice",
            50000000000 // 50 gwei
        )
    );
    
    // Build the batch with your Safe address
    buildBatch(safeAddress);
}
```

### Step 2: Run the Script

```sh
# For Ethereum Mainnet
forge script script/BatchScript.sol:BatchScript --rpc-url https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY -vvvv
```

This will output something like:
```
Transaction hash to approve: 0xabc123def456789abc123def456789abc123def456789abc123def456789abcd
```

### Step 3: Approve the Transaction Hash

Each Safe owner needs to approve the transaction hash:

```sh
# Owner 1
cast send --rpc-url https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY --private-key 0xYOUR_PRIVATE_KEY_1 0x1234567890123456789012345678901234567890 "approveHash(bytes32)" 0xabc123def456789abc123def456789abc123def456789abc123def456789abcd

# Owner 2
cast send --rpc-url https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY --private-key 0xYOUR_PRIVATE_KEY_2 0x1234567890123456789012345678901234567890 "approveHash(bytes32)" 0xabc123def456789abc123def456789abc123def456789abc123def456789abcd
```

### Step 4: Execute the Transaction

Once enough owners have approved (meeting the Safe's threshold):

```sh
SAFE=0x1234567890123456789012345678901234567890 PRIVATE_KEY=0xYOUR_PRIVATE_KEY forge script script/ExecBatchWithApprovals.s.sol:ExecBatchWithApprovals --rpc-url https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY --broadcast -vvvv
```

## Network-Specific MultiSend Addresses

The MultiSend contract address varies by network. Here are the addresses for common networks:

| Network          | MultiSend Contract Address                   |
|------------------|---------------------------------------------|
| Ethereum Mainnet | 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761 |
| Polygon          | 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761 |
| Arbitrum One     | 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761 |
| Optimism         | 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761 |
| BSC              | 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761 |
| Avalanche        | 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761 |
| Gnosis Chain     | 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761 |
| Base             | 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761 |
| Sepolia (testnet)| 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761 |

Update the `SAFE_MULTISEND_ADDRESS` constant in `BatchScript.sol` to match your target network.

## Advanced Usage

### Local Testing of Transactions

The BatchScript now includes functionality to locally test transactions before adding them to the batch. This allows you to verify that transactions will work as expected in the current chain state:

```solidity
// Enable or disable local testing globally
setLocalTesting(true); // or false

// Add a transaction with default testing behavior (follows global setting)
bool success = addToBatch(
    tokenAddress,
    0,
    abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
);

// Check if the transaction succeeded
if (success) {
    console2.log("Transaction will succeed");
} else {
    console2.log("Transaction will fail");
}

// Override global setting for a specific transaction
addToBatch(
    contractAddress,
    0,
    callData,
    true // Force enable testing for this transaction
);
```

To run a comprehensive example that demonstrates local testing:

```sh
forge script script/LocalTestingExample.s.sol:LocalTestingExample --rpc-url $RPC_URL -vvvv
```

This feature is particularly useful for:
- Validating complex DeFi interactions before execution
- Ensuring that transactions are called in the correct order
- Testing that your contracts have sufficient balances for transfers
- Verifying permission settings before attempting operations

**Note:** Some transactions may fail in the local test but succeed in the actual execution or vice versa, depending on differences between your local fork state and the real chain state when the batch is executed.

### Custom Operations (DelegateCall)

By default, `addToBatch` creates CALL operations (operation type 0). If you need to use DELEGATECALL (operation type 1), you can modify the BatchScript.sol file to add this functionality:

```solidity
// Add this function to BatchScript.sol
function addDelegateCallToBatch(address to, bytes memory data) public {
    bytes memory encodedTxn = abi.encodePacked(
        uint8(1), // operation (1 for DELEGATECALL)
        to,
        uint256(0), // value must be 0 for delegatecall
        data.length,
        data
    );
    encodedTxns.push(encodedTxn);
}
```

Then use it in your run function:

```solidity
// Define an interface for the contract you want to delegate call
interface IExternalContract {
    function doSomething() external;
    function doSomethingElse(uint256 value) external;
}

function run() external {
    address safeAddress = 0x1234567890123456789012345678901234567890;
    
    // Regular call
    addToBatch(
        0xabcdef0123456789abcdef0123456789abcdef01,
        0,
        abi.encodeWithSelector(IExternalContract.doSomething.selector)
    );
    
    // Delegate call
    addDelegateCallToBatch(
        0xfedcba9876543210fedcba9876543210fedcba98,
        abi.encodeWithSelector(IExternalContract.doSomethingElse.selector, 123)
    );
    
    buildBatch(safeAddress);
}
```

### Working with ERC-20 Tokens

Here's how to include common ERC-20 token operations in your batch:

```solidity
// Define the ERC-20 interface
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

// Transfer tokens
addToBatch(
    0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // Token contract address (USDC)
    0,
    abi.encodeWithSelector(
        IERC20.transfer.selector,
        0xRecipientAddress, // Recipient
        1000000 // Amount (adjust for token decimals)
    )
);

// Approve tokens
addToBatch(
    0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // Token contract address (USDC)
    0,
    abi.encodeWithSelector(
        IERC20.approve.selector,
        0xSpenderAddress, // Spender (e.g., DEX contract)
        1000000 // Amount (adjust for token decimals)
    )
);
```

## Troubleshooting

### Common Issues

1. **Transaction Reverts During Execution**
   - Check that the nonce in the batch matches the current Safe nonce
   - Verify that enough owners have approved the transaction hash
   - Ensure the executor has enough ETH to pay for gas

2. **approveHash Transaction Fails**
   - Make sure you're using the exact transaction hash output by the BatchScript
   - Verify that the caller is an owner of the Safe

3. **Invalid MultiSend Address**
   - Verify that the MultiSend contract address is correct for your network
   - Check the address checksum (capitalization matters in Ethereum addresses)

4. **Batch Execution Fails with "Not Enough Approvals"**
   - Ensure that enough owners have called approveHash
   - Check that the Safe threshold hasn't changed since the batch was created

### Debugging Tips

- Use the `-vvvv` flag with forge script commands to see detailed output
- Check the Safe's on-chain state using:
  ```sh
  cast call $SAFE_ADDRESS "getThreshold()(uint256)" --rpc-url $RPC_URL
  cast call $SAFE_ADDRESS "nonce()(uint256)" --rpc-url $RPC_URL
  cast call $SAFE_ADDRESS "isOwner(address)(bool)" $OWNER_ADDRESS --rpc-url $RPC_URL
  ```
- Verify approval status for a transaction hash:
  ```sh
  cast call $SAFE_ADDRESS "approvedHashes(address,bytes32)(uint256)" $OWNER_ADDRESS $TX_HASH --rpc-url $RPC_URL
  ```

## Notes
- If the Safe nonce changes (e.g., another transaction executes), rebuild the batch with the new nonce.
- The execution script checks if enough approvals have been collected before executing the transaction.
- Make sure to replace the placeholder addresses in the scripts with your actual Safe address.
- Never share your private keys. The examples above are for illustration only.

## Using a Custom Batch File Path

By default, the script reads the batch transaction data from `./data/batch.json`. However, you can now specify a custom path to the batch JSON file in several ways:

### 1. Using the Shell Script

The `executeOnchainBatch.sh` script now accepts an optional file path parameter:

```bash
# Execute using the default batch file path (./data/batch.json)
./shell/executeOnchainBatch.sh

# Execute using a custom batch file path
./shell/executeOnchainBatch.sh /path/to/your/custom-batch.json
```

### 2. Using Forge Script Directly

You can also run the script directly using the Forge CLI with the `--sig` parameter:

```bash
# Using direct function argument
forge script ./src/ExecBatchOnchain.s.sol:ExecBatchOnchain --sig "run(string)" "/path/to/your/custom-batch.json" --broadcast --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### 3. Using Environment Variables

If you prefer using environment variables, you can set the `BATCH_FILE_PATH` variable:

```bash
# Set the batch file path as an environment variable
export BATCH_FILE_PATH="/path/to/your/custom-batch.json"

# Run the script (it will detect the environment variable)
forge script ./src/ExecBatchOnchain.s.sol:ExecBatchOnchain --broadcast --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

The script will log which batch file is being used to help you confirm the correct file path is being read.
