// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./EIVToken.sol";

contract MultiSigWallet is Ownable {
    event SubmitTransaction(address indexed owner, uint256 indexed txIndex, address indexed from, bytes32 data);
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    address[] public approvers;
    mapping(address => bool) public isApprover;
    uint256 public numConfirmationsRequired;

    struct Transaction {
        address from;
        bytes32 data;
        bool executed;
        uint256 numConfirmations;
    }

    // mapping from tx index => owner => bool
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;

    EIVToken private _eivToken;

    bytes32 public constant CLAIM = keccak256("CLAIM");
    bytes32 public constant TEAM = keccak256("TEAM");
    bytes32 public constant ADVISORY = keccak256("ADVISORY");
    bytes32 public constant COMMUNITY = keccak256("COMMUNITY");

    modifier onlyApprover() {
        require(isApprover[msg.sender], "not approver");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    constructor(address[] memory _approvers, uint256 _numConfirmationsRequired, address eivAddress) {
        require(_approvers.length > 0, "approvers required");
        require(
            _numConfirmationsRequired > 0 &&
                _numConfirmationsRequired <= _approvers.length,
            "invalid number of required confirmations"
        );

        _eivToken = EIVToken(eivAddress);

        for (uint256 i = 0; i < _approvers.length; i++) {
            address owner = _approvers[i];

            require(owner != address(0), "invalid owner");
            require(!isApprover[owner], "owner not unique");

            isApprover[owner] = true;
            approvers.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    function submitTransaction(
        address _from,
        bytes32 _data
    ) public onlyApprover {
        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                from: _from,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _from, _data);
    }

    function confirmTransaction(
        uint256 _txIndex
    ) public onlyApprover txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(msg.sender != transaction.from, "invalid approver");
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(
        uint256 _txIndex
    ) public onlyApprover txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        if (bytes32(transaction.data) == CLAIM) {
            _eivToken.claimTokens();
        } else if (bytes32(transaction.data) == TEAM) {
            _eivToken.unlockTeamTokens();
        } else if (bytes32(transaction.data) == ADVISORY) {
            _eivToken.unlockAdvisorTokens();
        } else {
            _eivToken.unlockCommunityTokens();
        }

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(
        uint256 _txIndex
    ) public onlyApprover txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getapprovers() public view returns (address[] memory) {
        return approvers;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(
        uint256 _txIndex
    )
        public
        view
        returns (
            address from,
            bytes32 data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.from,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
