# Load environment variables from .env file
set dotenv-load
# Show usage information
default:
    @echo "Available commands:"
    @echo "  just create-batch <script-path>    - Create a new onchain batch using the specified script"
    @echo "  just approve-batch <batch-json>    - Approve an onchain batch transaction using a batch file"
    @echo "  just execute-batch <batch-json>    - Execute an approved onchain batch"
    @echo ""
    @echo "Required environment variables (in .env file):"
    @echo "  - RPC_URL: The RPC endpoint URL for the target blockchain"
    @echo "  - PRIVATE_KEY: Your private key for signing transactions"
    @echo "  - SAFE_ADDRESS: The address of the Safe contract"
    @echo ""
    @echo "Examples:"
    @echo "  just create-batch ./script/TestOnchainBatch.s.sol:TestOnchainBatch"
    @echo "  just approve-batch ./data/batch.json"
    @echo "  just execute-batch ./data/batch.json"

# Create an onchain batch with a specified forge script
create-batch script-path:
    #!/usr/bin/env bash
    if [ ! -f "{{script-path}}" ]; then
        echo "Error: Script file not found: {{script-path}}"
        echo "Please provide a valid path to a Forge script"
        exit 1
    fi
    
    # Extract the contract name from the path (assuming format like path/to/Script.s.sol:ContractName)
    if [[ "{{script-path}}" == *":"* ]]; then
        # Path already includes contract name
        forge script {{script-path}} --rpc-url $RPC_URL -vvvv
    else
        echo "Error: Script path must include contract name (e.g., ./script/TestOnchainBatch.s.sol:TestOnchainBatch)"
        exit 1
    fi

# Approve an onchain batch transaction using a batch file
approve-batch batch-json:
    #!/usr/bin/env bash
    if [ ! -f "{{batch-json}}" ]; then
        echo "Error: Batch JSON file not found: {{batch-json}}"
        echo "Please provide a valid path to a batch JSON file"
        exit 1
    fi
    
    # Get the transaction hash from the batch file using the encodeBatchFromFile function
    TX_HASH=$(forge script ./src/BatchOnchain.s.sol:BatchOnchainScript --sig "encodeBatchFromFile(address,string)(bytes32)" $SAFE_ADDRESS "{{batch-json}}" --rpc-url $RPC_URL | grep "Transaction hash from file:" | awk '{print $NF}')
    
    if [[ ! "$TX_HASH" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        echo "Error: Failed to extract a valid transaction hash"
        exit 1
    fi
    
    echo "Approving transaction hash: $TX_HASH"
    cast send --private-key $PRIVATE_KEY $SAFE_ADDRESS "approveHash(bytes32)" $TX_HASH --rpc-url $RPC_URL

# Execute an onchain batch
execute-batch batch-json:
    #!/usr/bin/env bash
    if [ ! -f "{{batch-json}}" ]; then
        echo "Error: Batch JSON file not found: {{batch-json}}"
        echo "Please provide a valid path to a batch JSON file"
        exit 1
    fi
    
    forge script ./src/ExecBatchOnchain.s.sol:ExecBatchOnchain --sig "run(string)" "{{batch-json}}" --broadcast --private-key $PRIVATE_KEY --rpc-url $RPC_URL -vvvv

