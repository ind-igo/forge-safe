// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BatchScript} from "src/BatchScript.sol";

interface IRolesAdmin {
    function grantRole(bytes32 role_, address wallet_) external;
}

/// @notice A test for Gnosis Safe batching script
/// @dev    GOERLI
contract TestAuthBatch is BatchScript {
    address safe = 0x84C0C005cF574D0e5C602EA7b366aE9c707381E0;
    address deployer = 0x1A5309F208f161a393E8b5A253de8Ab894A67188;

    /// @notice The main script entrypoint
    function run(bool send_) external {
        IRolesAdmin rolesAdmin = IRolesAdmin(0x54FfCA586cD1B01E96a5682DF93a55d7Ef91EFF0);

        // Start batch
        // Give deployer minter admin role
        addToBatch(address(rolesAdmin), 0, abi.encodeWithSelector(
            IRolesAdmin.grantRole.selector,
            bytes32("minter_admin"),
            deployer
        ));

        // Give deployer burner admin role
        addToBatch(address(rolesAdmin), 0, abi.encodeWithSelector(
            IRolesAdmin.grantRole.selector,
            bytes32("burner_admin"),
            deployer
        ));

        // Execute batch
        executeBatch(safe, send_);
    }
}
