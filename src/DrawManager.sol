// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "owner-manager/Ownable.sol";
import { PrizePool } from "v5-prize-pool/PrizePool.sol";

import { Phase } from "../abstract/PhaseManager.sol";
import { RewardLib } from "../libraries/RewardLib.sol";

/**
 * @title PoolTogether V5 DrawManager
 * @author Generation Software Team
 * @notice The DrawManager completes the pending draw with the given random number
 * and awards the auction phase recipients with rewards from the prize pool reserve.
 */
contract DrawManager is Ownable {

  /* ============ Constants ============ */

  /// @notice The prize pool to manage draws for
  address public immutable prizePool;

  /* ============ Variables ============ */

  /// @notice The address allowed to close draws
  address internal _drawCloser;

  /* ============ Custom Errors ============ */

  /// @notice Thrown if the prize pool address is the zero address.
  error PrizePoolZeroAddress();

  /// @notice Thrown if the draw closer address is the zero address.
  error DrawCloserZeroAddress();

  /**
   * @notice Thrown if the caller is not the draw closer.
   * @param caller The caller address
   * @param drawCloser The draw closer address
   */
  error CallerNotDrawCloser(address caller, address drawCloser);

  /* ============ Events ============ */

  /**
   * @notice Emitted when a reward for an auction is distributed to a recipient
   * @param recipient The recipient address of the reward
   * @param phaseId The ID of the auction phase completed for the reward
   * @param reward The reward amount
   */
  event AuctionRewardDistributed(address indexed recipient, uint8 indexed phaseId, uint104 reward);

  /* ============ Constructor ============ */

  /**
   * @notice Deploy the DrawManager smart contract.
   * @param prizePool_ The prize pool to manage draws for
   * @param drawCloser_ Address allowed to close draws
   * @param owner_ Owner of this contract
   */
  constructor(
    PrizePool prizePool_,
    address drawCloser_,
    address owner_
  ) Ownable(owner_) {
    if (address(prizePool_) == address(0)) revert PrizePoolZeroAddress();
    _setDrawCloser(drawCloser_);
    prizePool = prizePool_;
  }

  /* ============ External Functions ============ */

  /**
   * @notice Called to close a draw and award the completers of each auction phase.
   * @param _auctionPhases Array of auction phases
   * @param _randomNumber Random number generated by the RNG service
   * @dev This function can only be called by the draw closer.
   */
  function closeDraw(uint256 _randomNumber, Phase[] memory _auctionPhases) external {
    if (msg.sender != _drawCloser) {
      revert CallerNotDrawCloser(msg.sender, _drawCloser);
    }

    prizePool.closeDraw(_randomNumber);

    uint256[] memory _rewards = RewardLib.rewards(_auctionPhases, prizePool.reserve());

    for (uint i = 0; i < _rewards.length; i++) {
      uint104 _reward = uint104(_rewards[i]);
      prizePool.withdrawReserve(_auctionPhases[i].recipient, _reward);
      emit AuctionRewardDistributed(_auctionPhases[i].recipient, i, _reward)
    }
  }

  /**
   * @notice Getter for the draw closer address.
   * @return The draw closer address
   */
  function drawCloser() external returns (address) {
    return _drawCloser;
  }

  /**
   * @notice Setter for the draw closer address.
   * @param drawCloser_ The new draw closer address
   * @dev Only callable by the owner.
   */
  function setDrawCloser(address drawCloser_) external onlyOwner {
    _setDrawCloser(drawCloser_);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Sets the draw closer address
   * @param drawCloser_ The new draw closer address
   */
  function _setDrawCloser(address drawCloser_) internal {
    if (address(drawCloser_) == address(0)) revert DrawCloserZeroAddresss();
    _drawCloser = drawCloser_;
  }
}
