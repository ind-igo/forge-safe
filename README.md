# forge-safe: Gnosis Safe batch builder using Forge scripts 

Forge Safe lets Forge users build Gnosis Safe batch transactions using Forge scripting in Solidity. Forge Safe builds a collection of encoded transactions, then sends them to the Gnosis [Safe Transaction Service](https://github.com/safe-global/safe-transaction-service) uses [surl](https://github.com/memester-xyz/surl).

The goal of this tool is to allow users to quickly build, validate and version control complex Safe batches as code.

## Usage

Steps:

1. Import `BatchScript.sol` into your Forge script
2. Initialize your Safe address
3. Encode each function call you want to add into your batch
4. Call `addToBatch()` for each encoded call
5. After all encoded txs have been added, call `executeBatch()` and pass in Safe address.
6. ???
7. Profit
