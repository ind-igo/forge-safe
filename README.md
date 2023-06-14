# forge-safe: Gnosis Safe batch builder

Forge Safe lets Forge users build Gnosis Safe batch transactions using Forge scripting in Solidity. Forge Safe builds a collection of encoded transactions, then sends them to the Gnosis [Safe Transaction Service](https://github.com/safe-global/safe-transaction-service) uses [surl](https://github.com/memester-xyz/surl).

The goal of this tool is to allow users to quickly build, validate and version control complex Safe batches as code.

## Installation

```forge install ind-igo/forge-safe```

## Usage

Steps:

1. Import `BatchScript.sol` into your Forge script
2. Call `addToBatch()` for each encoded call
3. After all encoded txs have been added, call `executeBatch()` and pass in Safe address and whether to send the transaction
4. ???
5. Profit

```js
import {BatchScript} from "forge-safe/BatchScript.sol";

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