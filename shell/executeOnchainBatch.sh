#!/bin/bash

source .env

# Check if a batch file path was provided as a parameter
if [ -n "$1" ]; then
  # Use the provided batch file path
  export BATCH_FILE_PATH=$1
  echo "Using custom batch file: $BATCH_FILE_PATH"
  
  # Execute with the --sig parameter to call the overloaded run function
  forge script ./src/ExecBatchOnchain.s.sol:ExecBatchOnchain --sig "run(string)" "$BATCH_FILE_PATH" --broadcast --private-key $PRIVATE_KEY --rpc-url $RPC_URL -vvvv
else
  # Use the default batch file path
  echo "Using default batch file: ./data/batch.json"
  forge script ./src/ExecBatchOnchain.s.sol:ExecBatchOnchain --broadcast --private-key $PRIVATE_KEY --rpc-url $RPC_URL -vvvv
fi