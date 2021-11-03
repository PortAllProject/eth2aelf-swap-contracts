pragma solidity 0.6.12;

interface ITakeToken {
    function takeToken(uint256 _amount) external;
    function changeController(address _newController) external;
}
