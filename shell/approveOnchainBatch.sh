#!/bin/bash

source .env

# Check if transaction hash is provided as an argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <transaction_hash>"
    echo "Example: $0 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    exit 1
fi

# Use the provided transaction hash instead of reading from .env
TX_HASH=$1

cast send --private-key $PRIVATE_KEY $SAFE_ADDRESS "approveHash(bytes32)" $TX_HASH --rpc-url $RPC_URL