// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/BatchOnchain.s.sol";

// A simple ERC20 interface for testing token approvals
interface IERC20Test {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

/**
 * @title TestOnchainBatch
 * @dev A simple script to test the Gnosis Safe batch functionality with a basic test transaction.
 * To run: forge script ./script/TestOnchainBatch.s.sol:TestOnchainBatch --rpc-url $RPC_URL -vvvv
 */
contract TestOnchainBatch is BatchOnchainScript {
    
    function run() external {
        // Use a test Safe address (replace with your actual Safe for real testing)
        address safeAddress = vm.envAddress("SAFE_ADDRESS");
        
        console2.log("Building test batch for Safe:", safeAddress);
        console2.log("----------------------------------------");
        
        // Example 1: Simple ETH transfer
        // Sends a small amount of ETH (0.001 ETH) to a test address
        address testRecipient = vm.envAddress("TEST_RECIPIENT");
        uint256 testAmount = 0.0001 ether; // 0.0001 ETH in wei
        
        console2.log("Adding ETH transfer:");
        console2.log("  To:", testRecipient);
        console2.log("  Amount:", testAmount);
        
        addToBatch(
            safeAddress,
            testRecipient,
            testAmount,
            "" // Empty call data for a simple ETH transfer
        );
        
        // Example 2: Token approval (using DAI as an example)
        // Note: This is just for demonstration, replace with real token addresses
        address wethToken = 0x4200000000000000000000000000000000000006; // WETH on Base
        address testSpender = testRecipient;
        uint256 approvalAmount = 1 wei; // 1 wei WETH (with 18 decimals)
        
        console2.log("Adding token approval:");
        console2.log("  Token:", wethToken);
        console2.log("  Spender:", testSpender);
        console2.log("  Amount:", approvalAmount);
        
        addToBatch(
            safeAddress,
            wethToken,
            0,
            abi.encodeWithSelector(
                IERC20Test.approve.selector,
                testSpender,
                approvalAmount
            )
        );
        
        // Build the batch with the Safe address
        console2.log("----------------------------------------");
        console2.log("Building batch transaction...");
        buildBatch(safeAddress);
    }
}
