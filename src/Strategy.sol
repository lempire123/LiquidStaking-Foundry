// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./LiquidStaking.sol";

// interface StakedAurora {
//     function rewardStreamTokens() external view returns (IERC20[] memory);
//     function stakeAurora() external;
// }

contract Strategy {
    
    // StakedAurora public stAurora;
    AuroraLiquidStaking public stAurora;

    IERC20[] public rewardTokens;

    IERC20[] public returnTokens;

    modifier onlyStAurora() {
        require(msg.sender == address(stAurora), "ONLY STAURORA CAN CALL");
        _;
    }

    constructor(address _stAurora, address[] memory _returnTokens) {
        stAurora = AuroraLiquidStaking(_stAurora);
        rewardTokens = stAurora.getRewardTokens();
        uint256 length = _returnTokens.length;
        for(uint256 i; i < length; ++i) {
            returnTokens.push(IERC20(_returnTokens[i]));
        }
    }

    function putFundsToWork() external virtual {
        // Every unique strat will implement its own strategies
    }

    function sendTokensBack() external onlyStAurora {
        uint256 length = returnTokens.length;
        for(uint256 i; i < length; ++i) {
            uint256 bal = returnTokens[i].balanceOf(address(this));
            returnTokens[i].transfer(address(stAurora), bal);
        }
    }
}
