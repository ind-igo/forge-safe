// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Interface for the MultiSend contract
interface IMultiSend {
    function multiSend(bytes memory transactions) external payable;
}

