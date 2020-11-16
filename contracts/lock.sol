pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract LockMapping is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    event NewReceipt(uint256 receiptId, address asset, address owner, uint256 endTime);

    address public asset;
	ERC20 token;
    uint256 public saveTime = 86400 * 15; //15 days;
    uint256 public receiptCount = 0;

    struct Receipt {
        address asset;
        address owner;
        string targetAddress;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        bool finished;
    }

    Receipt[] public receipts;

    mapping(uint256 => address) private receiptToOwner;
    mapping(address => uint256[]) private ownerToReceipts;


    modifier exceedEndtime(uint256 _id) {

        require(receipts[_id].endTime != 0 && receipts[_id].endTime <= now);
        _;
    }

    modifier notFinished(uint256 _id) {

        require(receipts[_id].finished == false);
        _;
    }

	constructor (ERC20 _token) public{
		asset = address(_token);
		token = _token;
	}

	function _createReceipt(
        address _asset,
        address _owner,
        string calldata _targetAddress,
        uint256 _amount,
        uint256 _startTime,
        uint256 _endTime,
        bool _finished
    ) internal {

        receipts.push(Receipt(_asset, _owner, _targetAddress, _amount, _startTime, _endTime, _finished));
        receiptCount = receipts.length;
        uint256 id = receiptCount - 1;
        receiptToOwner[id] = msg.sender;
        ownerToReceipts[msg.sender].push(id);
        emit NewReceipt(id, _asset, _owner, _endTime);
    }


    //create new receipt
    function createReceipt(uint256 _amount, string calldata _targetAddress) external {
        //deposit token to this contract
        token.safeTransferFrom(msg.sender, address(this), _amount);
        _createReceipt(asset, msg.sender, _targetAddress, _amount, now, now + saveTime, false);
    }

    //finish the receipt and withdraw bonus and token
    function finishReceipt(uint256 _id) external notFinished(_id) exceedEndtime(_id) {
        // only receipt owner can finish receipt
        require(msg.sender == receipts[_id].owner);
        token.safeTransfer(receipts[_id].owner, receipts[_id].amount);
        receipts[_id].finished = true;
    }

    function getMyReceipts(address _address) external view returns (uint256[] memory){
        uint256[] memory receipt_ids = ownerToReceipts[_address];
        return receipt_ids;
    }

    function getLockTokens(address _address) external view returns (uint256){
        uint256[] memory myReceipts = ownerToReceipts[_address != address(0) ? _address : msg.sender];
        uint256 amount = 0;

        for (uint256 i = 0; i < myReceipts.length; i++) {
            if (receipts[myReceipts[i]].finished == false) {
                amount += receipts[myReceipts[i]].amount;
            }
        }

        return amount;
    }

    function fixSaveTime(uint256 _period) external onlyOwner {
        saveTime = _period;
    }

    function getReceiptInfo(uint256 index) public view returns (bytes32, string memory, uint256, bool){
        string memory targetAddress = receipts[index].targetAddress;
        return (sha256(abi.encode(index)), targetAddress, receipts[index].amount, receipts[index].finished);
    }
}