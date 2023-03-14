// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EIVToken is ERC20, ERC20Burnable, Ownable {
    uint256 public constant INITIAL_SUPPLY = 10 * 10**9 * 10**18;
    uint256 public constant TEAM_TOKENS = 1 * 10**9 * 10**18;
    uint256 public constant ADVISOR_TOKENS = 0.9 * 10**9 * 10**18;
    uint256 public constant COMMUNITY_TOKENS = 3 * 10**9 * 10**18;
    uint256 public constant UNLOCKED_TOKENS = 5.1 * 10**9 * 10**18;

    uint256 public constant TGE_TIMESTAMP = 1646035200; // 28th Feb 2022

    uint256 public constant LOCK_PERIOD_TEAM = 18 * 30 days;
    uint256 public constant RELEASE_PERIOD_TEAM = 3 * 365 days;
    uint256 public constant LOCK_PERIOD_ADVISOR = 12 * 30 days;
    uint256 public constant RELEASE_PERIOD_ADVISOR = 1.5 * 365 days;
    uint256 public constant LOCK_PERIOD_COMMUNITY = 6 * 30 days;
    uint256 public constant RELEASE_PERIOD_COMMUNITY = 1 * 365 days;

    uint256 private _teamLockedBalance;
    uint256 private _advisorLockedBalance;
    uint256 private _communityLockedBalance;
    uint256 private immutable _teamLockEndTime;
    uint256 private immutable _advisorLockEndTime;
    uint256 private immutable _communityLockEndTime;
    uint256 private _unlockedBalance;

    event ClaimTokens(address indexed claimer, uint256 price);
    event UnlockTeamTokens(address indexed claimer, uint256 price);
    event UnlockAdvisorTokens(address indexed claimer, uint256 price);
    event UnlockCommunityTokens(address indexed claimer, uint256 price);

    constructor() ERC20("EIV Token", "EIV") {
        // _mint(msg.sender, INITIAL_SUPPLY);
        _teamLockedBalance = TEAM_TOKENS;
        _advisorLockedBalance = ADVISOR_TOKENS;
        _communityLockedBalance = COMMUNITY_TOKENS;
        _teamLockEndTime = TGE_TIMESTAMP + LOCK_PERIOD_TEAM;
        _advisorLockEndTime = TGE_TIMESTAMP + LOCK_PERIOD_ADVISOR;
        _communityLockEndTime = TGE_TIMESTAMP + LOCK_PERIOD_COMMUNITY;
        _unlockedBalance = UNLOCKED_TOKENS;
    }

    function _calculateUnlockedAmount(uint256 lockedBalance, uint256 lockEndTime, uint256 releasePeriod) internal view returns (uint256) {
        if (block.timestamp < lockEndTime) {
            return 0;
        }
        uint256 elapsedTime = block.timestamp - lockEndTime;
        uint256 numReleases = elapsedTime - releasePeriod;
        uint256 unlockedAmount = lockedBalance * numReleases;
        return unlockedAmount;
    }

    function claimTokens() external onlyOwner {
        uint256 teamUnlockedAmount = _calculateUnlockedAmount(_teamLockedBalance, _teamLockEndTime, RELEASE_PERIOD_TEAM);
        uint256 advisorUnlockedAmount = _calculateUnlockedAmount(_advisorLockedBalance, _advisorLockEndTime, RELEASE_PERIOD_ADVISOR);
        uint256 communityUnlockedAmount = _calculateUnlockedAmount(_communityLockedBalance, _communityLockEndTime, RELEASE_PERIOD_COMMUNITY);
        uint256 totalUnlockedAmount = teamUnlockedAmount + advisorUnlockedAmount + communityUnlockedAmount + _unlockedBalance;
        require(totalUnlockedAmount > 0, "No tokens to claim");
        _teamLockedBalance = _teamLockedBalance - teamUnlockedAmount;
        _advisorLockedBalance = _advisorLockedBalance - advisorUnlockedAmount;
        _communityLockedBalance = _communityLockedBalance - communityUnlockedAmount;
        _unlockedBalance = 0;
        _mint(msg.sender, totalUnlockedAmount);
        emit ClaimTokens(msg.sender, totalUnlockedAmount);
    }

    function lockedTeamBalance() external view returns (uint256) {
        return _teamLockedBalance;
    }

    function lockedAdvisorBalance() external view returns (uint256) {
        return _advisorLockedBalance;
    }

    function lockedCommunityBalance() external view returns (uint256) {
        return _communityLockedBalance;
    }

    function unlockTeamTokens() external onlyOwner {
        require(block.timestamp >= _teamLockEndTime, "Team tokens are still locked");
        uint256 teamUnlockedAmount = _calculateUnlockedAmount(_teamLockedBalance, _teamLockEndTime, RELEASE_PERIOD_TEAM);
        require(teamUnlockedAmount > 0, "No team tokens to unlock");
        _teamLockedBalance = _teamLockedBalance - teamUnlockedAmount;
        _mint(owner(), teamUnlockedAmount);
        emit UnlockTeamTokens(msg.sender, teamUnlockedAmount);
    }

    function unlockAdvisorTokens() external onlyOwner {
        require(block.timestamp >= _advisorLockEndTime, "Advisor tokens are still locked");
        uint256 advisorUnlockedAmount = _calculateUnlockedAmount(_advisorLockedBalance, _advisorLockEndTime, RELEASE_PERIOD_ADVISOR);
        require(advisorUnlockedAmount > 0, "No advisor tokens to unlock");
        _advisorLockedBalance = _advisorLockedBalance - advisorUnlockedAmount;
        _mint(owner(), advisorUnlockedAmount);
        emit UnlockAdvisorTokens(msg.sender, advisorUnlockedAmount);
    }

    function unlockCommunityTokens() external onlyOwner {
        require(block.timestamp >= _communityLockEndTime, "Community tokens are still locked");
        uint256 communityUnlockedAmount = _calculateUnlockedAmount(_communityLockedBalance, _communityLockEndTime, RELEASE_PERIOD_COMMUNITY);
        require(communityUnlockedAmount > 0, "No community tokens to unlock");
        _communityLockedBalance = _communityLockedBalance - communityUnlockedAmount;
        _mint(owner(), communityUnlockedAmount);
        emit UnlockCommunityTokens(msg.sender, communityUnlockedAmount);
    }
}
