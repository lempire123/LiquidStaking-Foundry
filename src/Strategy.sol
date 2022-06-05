// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Strategy {
    
    address public stAurora;

    IERC20[] public rewardTokens;

    IERC20[] public returnTokens;

    modifier onlyStAurora() {
        require(msg.sender == stAurora, "ONLY STAURORA CAN CALL");
        _;
    }

    function putFundsToWork() external virtual onlyStAurora {
        // Every unique strat will implement its own strategies
    }

    function sendTokensBack() external onlyStAurora {
        uint256 length = returnTokens.length;
        for(uint256 i; i < length; ++i) {
            uint256 bal = returnTokens[i].balanceOf(address(this));
            returnTokens[i].transfer(stAurora, bal);
        }
    }
}
