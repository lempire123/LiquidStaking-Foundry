// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Strategy.sol";

interface TriRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface TriFlashSwap {
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    )
        external
        returns (uint256);
}

contract AuroraMaxi is Strategy {

    IERC20 public constant aurora = IERC20(0x8BEc47865aDe3B172A928df8f990Bc7f2A3b9f79);
    IERC20 public constant wnear = IERC20(0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d);

    // Trisolaris routers
    TriRouter public router = TriRouter(0x2CB45Edb4517d5947aFdE3BEAbF95A582506858B);
    TriFlashSwap public flashSwap = TriFlashSwap(0x458459E48dbAC0C8Ca83F8D0b7b29FEfE60c3970);

    
    constructor(address _stAurora, address[] memory _tokens) Strategy(_stAurora, _tokens) {
        uint256 length = rewardTokens.length;
        for(uint256 i; i < length; i++) {
            rewardTokens[i].approve(address(router), 2**256 - 1);
        }
    }

    function putFundsToWork() external override {
        for(uint256 i; i < 3; ++i) {
            swapTokenForAurora(rewardTokens[i]);
        }
    }

    function Compound() public {
        uint256 auroraBal = aurora.balanceOf(address(this));
        aurora.transfer(address(stAurora), auroraBal);
        stAurora.stakeAurora();
    }

    function swapTokenForAurora(IERC20 _token) internal {
        uint256 balance = _token.balanceOf(address(this));
        address[] memory path = new address[](3);
        path[0] = address(_token);
        path[1] = address(wnear);
        path[2] = address(aurora);

        router.swapExactTokensForTokens(
            balance,
            0,
            path,
            address(this),
            block.timestamp + 60
        );
    }
}