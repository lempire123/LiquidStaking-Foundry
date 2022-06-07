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

contract DeltaNeutral is Strategy {

    IERC20 public constant aurora = IERC20(0x8BEc47865aDe3B172A928df8f990Bc7f2A3b9f79);
    IERC20 public constant wnear = IERC20(0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d);
    IERC20 public constant USN = IERC20(0x5183e1B1091804BC2602586919E6880ac1cf2896);
    IERC20 public constant USDC = IERC20(0xB12BFcA5A55806AaF64E99521918A4bf0fC40802);

    // Trisolaris routers
    TriRouter public router = TriRouter(0x2CB45Edb4517d5947aFdE3BEAbF95A582506858B);
    TriFlashSwap public flashSwap = TriFlashSwap(0x458459E48dbAC0C8Ca83F8D0b7b29FEfE60c3970);

    address[] public usdcToAurora;

    
    constructor(address _stAurora, address[] memory _tokens) Strategy(_stAurora, _tokens) {
        uint256 length = rewardTokens.length;
        for(uint256 i; i < length; i++) {
            rewardTokens[i].approve(address(router), 2**256 - 1);
        }
       
}