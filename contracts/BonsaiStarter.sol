// Copyright 2023 RISC Zero, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.17;

import {IBonsaiRelay} from "../lib/bonsai-lib-sol/src/IBonsaiRelay.sol";
import {BonsaiCallbackReceiver} from "../lib/bonsai-lib-sol/src/BonsaiCallbackReceiver.sol";

/// @title A starter application using Bonsai through the on-chain relay.
/// @dev This contract demonstrates one pattern for offloading the computation of an expensive
//       or difficult to implement function to a RISC Zero guest running on Bonsai.
contract BonsaiStarter is BonsaiCallbackReceiver {
    /// @notice Cache of the results calculated by our guest program in Bonsai.
    /// @dev Using a cache is one way to handle the callback from Bonsai. Upon callback, the
    ///      information from the journal is stored in the cache for later use by the contract.
    /// Because only elementary types can be used as keys,
    /// We hash 2 factors and use it as a key in cache
    mapping(bytes32 => uint256) public factorsCache;


    /// @notice Image ID of the only zkVM binary to accept callbacks from.
    bytes32 public immutable facImageId;

    /// @notice Gas limit set on the callback from Bonsai.
    /// @dev Should be set to the maximum amount of gas your callback might reasonably consume.
    uint64 private constant BONSAI_CALLBACK_GAS_LIMIT = 100000;

    /// @notice Initialize the contract, binding it to a specified Bonsai relay and RISC Zero guest image.
    constructor(IBonsaiRelay bonsaiRelay, bytes32 _facImageId) BonsaiCallbackReceiver(bonsaiRelay) {
        facImageId = _facImageId;
    }

    event CalculateFactorsCallback(uint256 a, uint256 b, uint256 result);

    /// @notice Returns muptiplication of two input numbers.
    /// @dev The input values have to be > 1.
    function factors(uint256 a, uint256 b) external view returns (uint256) {
        uint256 result = factorsCache[keccak256(abi.encodePacked(a,b))];
        require(a > 1 && b > 1, "Values have to be larger than 1");
        return result;
    }

    /// @notice Callback function logic for processing verified journals from Bonsai.
    function storeResult(uint256 a, uint256 b, uint256 result) external onlyBonsaiCallback(facImageId) {
        emit CalculateFactorsCallback(a, b, result);
        factorsCache[keccak256(abi.encodePacked(a,b))] = result;
    }

    /// @notice Sends a request to Bonsai to multiply Factors.
    /// @dev This function sends the request to Bonsai through the on-chain relay.
    ///      The request will trigger Bonsai to run the specified RISC Zero guest program with
    ///      the given input and asynchronously return the verified results via the callback below.
    function calculateFactors(uint256 a, uint256 b) external {
        bonsaiRelay.requestCallback(
          facImageId, abi.encode(a, b), address(this), this.storeResult.selector, BONSAI_CALLBACK_GAS_LIMIT
        );
    }
}
