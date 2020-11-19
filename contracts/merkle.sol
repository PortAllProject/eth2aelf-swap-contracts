import "@openzeppelin/contracts/access/Ownable.sol";
import "./Receipts.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

pragma solidity 0.6.12;

contract MerkleTreeGenerator is Ownable {

    using SafeMath for uint256;

    uint256 constant pathMaximalLength = 7;
    uint256 constant public MerkleTreeMaximalLeafCount = 1 << pathMaximalLength;
    uint256 constant treeMaximalSize = MerkleTreeMaximalLeafCount * 2;
    uint256 public receiptCollectionCount = 0;
    uint256 public receiptCountInTree = 0;

    mapping(uint256 => ReceiptCollection) receiptCollections;

    Receipts receiptProvider;
    address public receiptProviderAddress;

    struct MerkleTree {
        bytes32 root;
        uint256 leaf_count;
        uint256 first_receipt_id;
        uint256 size;
    }

    struct ReceiptCollection {
        uint256 first_receipt_id;
        uint256 receipt_count;
    }

    constructor (Receipts _lock) public {
        receiptProviderAddress = address(_lock);
        receiptProvider = _lock;
    }

    //fetch receipts
    function _receiptsToLeaves(uint256 _start, uint256 _leafCount) private view returns (bytes32[] memory){
        bytes32[] memory leaves = new bytes32[](_leafCount);

        for (uint256 i = _start; i < _start + _leafCount; i++) {
            (
            ,
            ,
            string memory targetAddress,
            uint256 amount,
            ,
            ,
            ) = receiptProvider.receipts(i);

            bytes32 amountHash = sha256(abi.encode(amount));
            bytes32 targetAddressHash = sha256(abi.encode(targetAddress));
            bytes32 receiptIdHash = sha256(abi.encode(i));

            leaves[i - _start] = (sha256(abi.encode(amountHash, targetAddressHash, receiptIdHash)));
        }

        return leaves;
    }

    //create new receipt
    function recordReceipts() external onlyOwner {
        uint256 receiptCount = receiptProvider.receiptCount().sub(receiptCountInTree);
        require(receiptCount > 0, "[MERKLE]No receipts.");
        uint256 leafCount = receiptCount < MerkleTreeMaximalLeafCount ? receiptCount : MerkleTreeMaximalLeafCount;
        ReceiptCollection memory receiptCollection = ReceiptCollection(receiptCountInTree, leafCount);
        receiptCollections[receiptCollectionCount] = receiptCollection;
        receiptCountInTree = receiptCountInTree.add(leafCount);
        receiptCollectionCount = receiptCollectionCount.add(1);
    }

    function getMerkleTree(uint256 _treeIndex) public view returns (bytes32, uint256, uint256, uint256, bytes32[] memory){
        ReceiptCollection memory receiptCollection = receiptCollections[_treeIndex];
        MerkleTree memory merkleTree;
        bytes32[] memory treeNodes;
        (merkleTree, treeNodes) = _generateMerkleTree(receiptCollection.first_receipt_id, receiptCollection.receipt_count);
        return (merkleTree.root, merkleTree.first_receipt_id, merkleTree.leaf_count, merkleTree.size, treeNodes);
    }

    //get users merkle tree path
    function generateMerklePath(uint256 _receiptId) public view returns (uint256, uint256, bytes32[pathMaximalLength] memory, bool[pathMaximalLength] memory) {
        require(_receiptId < receiptCountInTree);
        uint256 treeIndex = receiptCollectionCount - 1;
        for (; treeIndex >= 0; treeIndex--) {
            if (_receiptId >= receiptCollections[treeIndex].first_receipt_id)
                break;
        }

        bytes32[pathMaximalLength] memory neighbors;
        bool[pathMaximalLength] memory isLeftNeighbors;
        uint256 pathLength;

        ReceiptCollection memory receiptCollection = receiptCollections[treeIndex];
        MerkleTree memory merkleTree;
        (merkleTree,) = _generateMerkleTree(receiptCollection.first_receipt_id, receiptCollection.receipt_count);
        uint256 index = _receiptId - merkleTree.first_receipt_id;
        (pathLength, neighbors, isLeftNeighbors) = _generatePath(merkleTree, index);
        return (treeIndex, pathLength, neighbors, isLeftNeighbors);
    }

    function _generateMerkleTree(uint256 _firstReceiptId, uint256 _leafCount) private view returns (MerkleTree memory, bytes32[] memory) {
        bytes32[] memory leafNodes = _receiptsToLeaves(_firstReceiptId, _leafCount);
        bytes32[] memory allNodes;
        uint256 nodeCount;

        (allNodes, nodeCount) = _leavesToTree(leafNodes);
        MerkleTree memory merkleTree = MerkleTree(allNodes[nodeCount - 1], _leafCount, _firstReceiptId, nodeCount);
        return (merkleTree, allNodes);
    }

    function _generatePath(MerkleTree memory _merkleTree, uint256 _index) private view returns (uint256, bytes32[pathMaximalLength] memory, bool[pathMaximalLength] memory){

        bytes32[] memory leaves = _receiptsToLeaves(_merkleTree.first_receipt_id, _merkleTree.leaf_count);
        bytes32[] memory allNodes;
        uint256 nodeCount;

        (allNodes, nodeCount) = _leavesToTree(leaves);
        require(nodeCount == _merkleTree.size);

        bytes32[] memory nodes = new bytes32[](_merkleTree.size);
        for (uint256 t = 0; t < _merkleTree.size; t++) {
            nodes[t] = allNodes[t];
        }

        return _generatePath(nodes, _merkleTree.leaf_count, _index);
    }

    function _generatePath(bytes32[] memory _nodes, uint256 _leafCount, uint256 _index) private pure returns (uint256, bytes32[pathMaximalLength] memory, bool[pathMaximalLength] memory){
        bytes32[pathMaximalLength] memory neighbors;
        bool[pathMaximalLength] memory isLeftNeighbors;
        uint256 indexOfFirstNodeInRow = 0;
        uint256 nodeCountInRow = _leafCount;
        bytes32 neighbor;
        bool isLeftNeighbor;
        uint256 shift;
        uint256 i = 0;

        while (_index < _nodes.length - 1) {

            if (_index % 2 == 0)
            {
                // add right neighbor node
                neighbor = _nodes[_index + 1];
                isLeftNeighbor = false;
            }
            else
            {
                // add left neighbor node
                neighbor = _nodes[_index - 1];
                isLeftNeighbor = true;
            }

            neighbors[i] = neighbor;
            isLeftNeighbors[i++] = isLeftNeighbor;

            nodeCountInRow = nodeCountInRow % 2 == 0 ? nodeCountInRow : nodeCountInRow + 1;
            shift = (_index - indexOfFirstNodeInRow) / 2;
            indexOfFirstNodeInRow += nodeCountInRow;
            _index = indexOfFirstNodeInRow + shift;
            nodeCountInRow /= 2;

        }

        return (i, neighbors, isLeftNeighbors);
    }

    function _leavesToTree(bytes32[] memory _leaves) private pure returns (bytes32[] memory, uint256){
        uint256 leafCount = _leaves.length;
        bytes32 left;
        bytes32 right;

        uint256 newAdded = 0;
        uint256 i = 0;

        bytes32[] memory nodes = new bytes32[](treeMaximalSize);

        for (uint256 t = 0; t < leafCount; t++)
        {
            nodes[t] = _leaves[t];
        }

        uint256 nodeCount = leafCount;
        if (_leaves.length % 2 == 1) {
            nodes[leafCount] = (_leaves[leafCount - 1]);
            nodeCount = nodeCount + 1;
        }


        // uint256 nodeToAdd = nodes.length / 2;
        uint256 nodeToAdd = nodeCount / 2;

        while (i < nodeCount - 1) {

            left = nodes[i++];
            right = nodes[i++];
            nodes[nodeCount++] = sha256(abi.encode(left, right));
            if (++newAdded != nodeToAdd)
                continue;

            if (nodeToAdd % 2 == 1 && nodeToAdd != 1)
            {
                nodeToAdd++;
                nodes[nodeCount] = nodes[nodeCount - 1];
                nodeCount++;
            }

            nodeToAdd /= 2;
            newAdded = 0;
        }

        return (nodes, nodeCount);
    }
}