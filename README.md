# forge-safe: Gnosis Safe batch builder

Forge Safe lets Forge users build Gnosis Safe batch transactions using Forge scripting in Solidity. Forge Safe builds a collection of encoded transactions, then sends them to the Gnosis [Safe Transaction Service](https://github.com/safe-global/safe-transaction-service) uses [surl](https://github.com/memester-xyz/surl).

The goal of this tool is to allow users to quickly build, validate and version control complex Safe batches as code.

Inspired by [ape-safe](https://github.com/banteg/ape-safe) and Olymsig

## Supported Chains

Only supports Mainnet, Goerli and Arbitrum currently. If you'd like more to be supported, please make a PR.

The only chains supported by Gnosis Safe API can be found [here](https://docs.safe.global/learn/safe-core/safe-core-api/available-services#safe-transaction-service).

## Installation

```forge install ind-igo/forge-safe```

## Usage

Steps:

1. In your .env file
    - Set `CHAIN` to the name of the chain your Safe is on
    - Set `WALLET_TYPE` with `LOCAL` or `LEDGER` depending on your wallet
2. Import `BatchScript.sol` into your Forge script
3. Call `addToBatch()` for each encoded call
4. After all encoded txs have been added, call `executeBatch()` with your Safe address and whether to send the transaction
5. Sign the batch data
6. ???
7. Profit

```js
import {BatchScript} from "forge-safe/BatchScript.sol";

...

function run(bool send_) public {
        string memory gm = "gm";
        address greeter = 0x1111;

        bytes memory txn = abi.encodeWithSelector(
            Greeter.greet.selector,
            gm
        );
        addToBatch(greeter, 0, txn);

        executeBatch(safe, send_);
}
```