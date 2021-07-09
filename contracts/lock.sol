pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Receipts.sol";
import "../interfaces/ITakeToken.sol";

contract LockMapping is Ownable, Receipts, ITakeToken {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    event NewReceipt(uint256 receiptId, address asset, address owner, uint256 amount);
    event TokenTaken(address receiverAddress, uint256 amount);

    address public asset;
    address public controller;// Should be the TokenSwap Contract address
    ERC20 token;
    uint256 takeAmount;

    mapping(address => uint256[]) public ownerToReceipts;

    constructor (ERC20 _token, address _controller) public{
        asset = address(_token);
        token = _token;
        controller = _controller;
    }

    function _createReceipt(
        address _asset,
        address _owner,
        string calldata _targetAddress,
        uint256 _amount
    ) internal {
        receipts.push(Receipt(_asset, _owner, _targetAddress, _amount));
        totalAmountInReceipts = totalAmountInReceipts.add(_amount);
        receiptCount = receipts.length;
        uint256 id = receiptCount.sub(1);
        ownerToReceipts[msg.sender].push(id);
        emit NewReceipt(id, _asset, _owner, _amount);
    }

    // Create new receipt and deposit erc20 token
    function createReceipt(uint256 _amount, string calldata _targetAddress) external {
        // Deposit token to this contract
        token.safeTransferFrom(msg.sender, address(this), _amount);
        _createReceipt(asset, msg.sender, _targetAddress, _amount);
    }

    function getMyReceipts(address _address) external view returns (uint256[] memory){
        uint256[] memory receipt_ids = ownerToReceipts[_address];
        return receipt_ids;
    }

    function getLockTokens(address _ownerAddress) external view returns (uint256){
        uint256[] memory myReceipts = ownerToReceipts[_ownerAddress];
        uint256 amount = 0;

        for (uint256 i = 0; i < myReceipts.length; i++) {
            amount = amount.add(receipts[myReceipts[i]].amount);
        }

        return amount;
    }

    function getReceiptInfo(uint256 index) public view returns (bytes32, string memory, uint256){
        string memory targetAddress = receipts[index].targetAddress;
        return (sha256(abi.encode(index)), targetAddress, receipts[index].amount);
    }

    function takeToken(uint256 _amount) external override {
        require(msg.sender == controller, "unauthorized");
        takeAmount = takeAmount.add(_amount);
        token.safeTransfer(msg.sender, _amount);
        emit TokenTaken(msg.sender, _amount);
    }
}