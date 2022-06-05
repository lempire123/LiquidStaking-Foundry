pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface main {
    function burnStAurora(address _account, uint256 _amount) external;
    function balanceOf(address _account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract Distributor  {

    address public admin;

    main public stAurora;

    IERC20[] public tokens;

    constructor(address _admin, address _stAurora) {
        admin = _admin;
        stAurora = main(_stAurora);
    }

    function setTokens(address[] memory _tokens) external {
        require(msg.sender == admin, "ONLY ADMIN CAN CALL");
        uint256 length = _tokens.length;
        for(uint256 i; i < length; ++i) {
            tokens.push(IERC20(_tokens[i]));
        }
    }

    function getMyShare() external {
        uint256 bal = stAurora.balanceOf(msg.sender);
        uint256 share = bal / stAurora.totalSupply();
        uint256 length = tokens.length;
        for(uint256 i; i < length; ++i) {
            uint256 tokenBal = tokens[i].balanceOf(address(this));
            tokens[i].transfer(msg.sender, tokenBal * share);
            stAurora.burnStAurora(msg.sender, bal);
        }
    }




}