// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ISafe - A multisignature wallet interface with support for confirmations using signed messages based on EIP-712.
 * @author @safe-global/safe-protocol
 */
interface ISafe {

  enum Operation {
    CALL,
    DELEGATECALL
  }

  function getTransactionHash(
    address to,
    uint256 value,
    bytes calldata data,
    Operation operation,
    uint256 safeTxGas,
    uint256 baseGas,
    uint256 gasPrice,
    address gasToken,
    address refundReceiver,
    uint256 _nonce
  ) external view returns (bytes32);

  function execTransaction(
      address to,
      uint256 value,
      bytes calldata data,
      Operation operation,
      uint256 safeTxGas,
      uint256 baseGas,
      uint256 gasPrice,
      address gasToken,
      address payable refundReceiver,
      bytes memory signatures
  ) external payable returns (bool success);


  function nonce() external view returns (uint256);

  function getThreshold() external view returns (uint256);

  function getOwners() external view returns (address[] memory);

  function approvedHashes(address owner, bytes32 hash) external view returns (uint256);
}