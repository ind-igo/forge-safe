#!/bin/bash

source .env

forge script ./script/TestOnchainBatch.s.sol:TestOnchainBatch --rpc-url $RPC_URL -vvvv