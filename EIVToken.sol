// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract EIVToken is ERC20, ERC20Burnable, AccessControl, Ownable {
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

    address public companyWallet;
    address public teamWallet;
    address public advisoryWallet;
    address public communityWallet;

    uint256 private _unlockedBalance;
    uint256 private _teamLockedBalance;
    uint256 private _advisorLockedBalance;
    uint256 private _communityLockedBalance;
    uint256 private immutable _teamLockEndTime;
    uint256 private immutable _advisorLockEndTime;
    uint256 private immutable _communityLockEndTime;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event UnlockCompanyTokens(address indexed claimer, uint256 price);
    event UnlockTeamTokens(address indexed claimer, uint256 price);
    event UnlockAdvisorTokens(address indexed claimer, uint256 price);
    event UnlockCommunityTokens(address indexed claimer, uint256 price);

    constructor(address _companyWallet, address _teamWallet, address _advisoryWallet, address _communityWallet) ERC20("EIV Token", "EIV") {
        // _mint(msg.sender, INITIAL_SUPPLY);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);

        _unlockedBalance = UNLOCKED_TOKENS;
        _teamLockedBalance = TEAM_TOKENS;
        _advisorLockedBalance = ADVISOR_TOKENS;
        _communityLockedBalance = COMMUNITY_TOKENS;
        _teamLockEndTime = TGE_TIMESTAMP + LOCK_PERIOD_TEAM;
        _advisorLockEndTime = TGE_TIMESTAMP + LOCK_PERIOD_ADVISOR;
        _communityLockEndTime = TGE_TIMESTAMP + LOCK_PERIOD_COMMUNITY;

        companyWallet = _companyWallet;
        teamWallet = _teamWallet;
        advisoryWallet = _advisoryWallet;
        communityWallet = _communityWallet;
    }

    function _calculateUnlockedAmount(uint256 lockedBalance, uint256 lockEndTime, uint256 releasePeriod) internal view returns (uint256) {
        if (block.timestamp < lockEndTime) {
            return 0;
        }
        uint256 elapsedTime = block.timestamp - lockEndTime;

        if (elapsedTime >= releasePeriod) {
            return lockedBalance;
        } else {
            return lockedBalance * elapsedTime / releasePeriod;
        }
    }

    function claimTokens() external onlyRole(MINTER_ROLE) {
        uint256 teamAmount = _calculateUnlockedAmount(TEAM_TOKENS, _teamLockEndTime, RELEASE_PERIOD_TEAM);        
        uint256 advisorAmount = _calculateUnlockedAmount(ADVISOR_TOKENS, _advisorLockEndTime, RELEASE_PERIOD_ADVISOR);
        uint256 communityAmount = _calculateUnlockedAmount(COMMUNITY_TOKENS, _communityLockEndTime, RELEASE_PERIOD_COMMUNITY);
        uint256 unlockedBalance = _unlockedBalance;

        uint256 teamUnlockedAmount = teamAmount - (TEAM_TOKENS - _teamLockedBalance);
        uint256 advisorUnlockedAmount = advisorAmount - (ADVISOR_TOKENS - _advisorLockedBalance);
        uint256 communityUnlockedAmount = communityAmount - (COMMUNITY_TOKENS - _communityLockedBalance);

        uint256 totalUnlockedAmount = unlockedBalance + teamUnlockedAmount + advisorUnlockedAmount + communityUnlockedAmount;

        require(totalUnlockedAmount > 0, "No tokens to claim");
        _teamLockedBalance -= teamUnlockedAmount;
        _advisorLockedBalance -= advisorUnlockedAmount;
        _communityLockedBalance -= communityUnlockedAmount;
        _unlockedBalance = 0;

        _mint(address(this), totalUnlockedAmount);

        if (unlockedBalance > 0) {
            _transfer(address(this), companyWallet, unlockedBalance);
            emit UnlockCompanyTokens(companyWallet, unlockedBalance);
        }

        if (teamUnlockedAmount > 0) {
            _transfer(address(this), teamWallet, teamUnlockedAmount);
            emit UnlockTeamTokens(teamWallet, teamUnlockedAmount);
        }

        if (communityUnlockedAmount > 0) {
            _transfer(address(this), communityWallet, communityUnlockedAmount);
            emit UnlockCommunityTokens(communityWallet, communityUnlockedAmount);
        }

        if (advisorUnlockedAmount > 0) {
            _transfer(address(this), advisoryWallet, advisorUnlockedAmount);
            emit UnlockAdvisorTokens(advisoryWallet, advisorUnlockedAmount);
        }
    }

    function lockedCompanyBalance() external view returns (uint256) {
        return _unlockedBalance;
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

    function unlockTeamTokens() external onlyRole(MINTER_ROLE) {
        require(block.timestamp >= _teamLockEndTime, "Team tokens are still locked");
        uint256 teamAmount = _calculateUnlockedAmount(TEAM_TOKENS, _teamLockEndTime, RELEASE_PERIOD_TEAM);
        uint256 teamUnlockedAmount = teamAmount - (TEAM_TOKENS - _teamLockedBalance);
        require(teamUnlockedAmount > 0, "No team tokens to unlock");
        _teamLockedBalance -= teamUnlockedAmount;
        _mint(teamWallet, teamUnlockedAmount);
        emit UnlockTeamTokens(teamWallet, teamUnlockedAmount);
    }

    function unlockAdvisorTokens() external onlyRole(MINTER_ROLE) {
        require(block.timestamp >= _advisorLockEndTime, "Advisor tokens are still locked");
        uint256 advisorAmount = _calculateUnlockedAmount(ADVISOR_TOKENS, _advisorLockEndTime, RELEASE_PERIOD_ADVISOR);
        uint256 advisorUnlockedAmount = advisorAmount - (ADVISOR_TOKENS - _advisorLockedBalance);
        require(advisorUnlockedAmount > 0, "No advisor tokens to unlock");
        _advisorLockedBalance -= advisorUnlockedAmount;
        _mint(advisoryWallet, advisorUnlockedAmount);
        emit UnlockAdvisorTokens(advisoryWallet, advisorUnlockedAmount);
    }

    function unlockCommunityTokens() external onlyRole(MINTER_ROLE) {
        require(block.timestamp >= _communityLockEndTime, "Community tokens are still locked");
        uint256 communityAmount = _calculateUnlockedAmount(COMMUNITY_TOKENS, _communityLockEndTime, RELEASE_PERIOD_COMMUNITY);
        uint256 communityUnlockedAmount = communityAmount - (COMMUNITY_TOKENS - _communityLockedBalance);
        require(communityUnlockedAmount > 0, "No community tokens to unlock");
        _communityLockedBalance -= communityUnlockedAmount;
        _mint(communityWallet, communityUnlockedAmount);
        emit UnlockCommunityTokens(communityWallet, communityUnlockedAmount);
    }

    function setCompanyWallet(address _companyWallet) external onlyRole(MINTER_ROLE) {
        companyWallet = _companyWallet;
    }

     function setTeamWallet(address _teamWallet) external onlyRole(MINTER_ROLE) {
        teamWallet = _teamWallet;
    }

     function setAdvisoryWallet(address _advisoryWallet) external onlyRole(MINTER_ROLE) {
        advisoryWallet = _advisoryWallet;
    }

     function setCommunityWallet(address _communityWallet) external onlyRole(MINTER_ROLE) {
        communityWallet = _communityWallet;
    }
}
