pragma solidity 0.6.12;

contract Receipts {
    struct Receipt {
        address asset;// ERC20 Token Address
        address owner;// Sender
        string targetAddress;// User address in aelf
        uint256 amount;// Locking amount
    }

    uint256 public receiptCount = 0;
    Receipt[] public receipts;
    uint256 public totalAmountInReceipts = 0;
}
