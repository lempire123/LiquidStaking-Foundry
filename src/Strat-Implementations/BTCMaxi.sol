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
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
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

interface cToken {
    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);
    function balanceOf(address account) external view returns (uint256);
    function approve(address account, uint256 amount) external;
}

interface Comptroller {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function exitMarket(address cToken) external returns (uint);
}

contract BTCMaxi is Strategy {

    address public admin;

    IERC20 public constant aurora = IERC20(0x8BEc47865aDe3B172A928df8f990Bc7f2A3b9f79);
    IERC20 public constant wnear = IERC20(0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d);
    IERC20 public constant USN = IERC20(0x5183e1B1091804BC2602586919E6880ac1cf2896);
    IERC20 public constant USDC = IERC20(0xB12BFcA5A55806AaF64E99521918A4bf0fC40802);
    IERC20 public constant BTC = IERC20(0xF4eB217Ba2454613b15dBdea6e5f22276410e89e);

    // Trisolaris routers
    TriRouter public router = TriRouter(0x2CB45Edb4517d5947aFdE3BEAbF95A582506858B);
    TriFlashSwap public flashSwap = TriFlashSwap(0x458459E48dbAC0C8Ca83F8D0b7b29FEfE60c3970);

    // Bastion contracts
    cToken cBTC = cToken(0xfa786baC375D8806185555149235AcDb182C033b);
    cToken cETH = cToken(0x4E8fE8fd314cFC09BDb0942c5adCC37431abDCD0);
    cToken cUSDC = cToken(0xe5308dc623101508952948b141fD9eaBd3337D99);
    Comptroller bTroller = Comptroller(0x6De54724e128274520606f038591A00C5E94a1F6);

    
    constructor(address _stAurora) Strategy(_stAurora) {
        admin = msg.sender;

        uint256 length = rewardTokens.length;
        for(uint256 i; i < length; i++) {
            rewardTokens[i].approve(address(router), 2**256 - 1);
        }
        USN.approve(address(flashSwap), 2**256 - 1);
        USDC.approve(address(router), 2**256 - 1);
    }

    function putFundsToWork() external override {
        for(uint256 i; i < 3; ++i) {
            uint256 balance = rewardTokens[i].balanceOf(address(this));
            swapTokens(address(rewardTokens[i]), address(BTC), balance);
        }
    }

    function swapUSNforBTC() external {
        uint256 USNbal = USN.balanceOf(address(this));
        flashSwap.swap(
            2,
            0,
            USNbal,
            0,
            block.timestamp + 60
        );
        uint256 balance = USDC.balanceOf(address(this));
        swapTokens(address(USDC), address(BTC), balance);
    }

    function swapTokens(address token0, address token1, uint256 amount) public {
        // uint256 balance = IERC20(token0).balanceOf(address(this));
        IERC20(token0).approve(address(router), 2**256 - 1);
        address[] memory path = new address[](3);
        path[0] = token0;
        path[1] = address(wnear);
        path[2] = token1;
        router.swapExactTokensForTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp + 60
        );
    }

    function lendBTC() external {
        uint256 balance = BTC.balanceOf(address(this));
        BTC.approve(address(cBTC), balance);
        cBTC.mint(balance);

        address[] memory cTokens = new address[](1);
        cTokens[0] = (address(cBTC));
        bTroller.enterMarkets(cTokens);
    }

    function borrowUSDC(uint256 amount) external {
        cUSDC.borrow(amount);
    }

    function repayUSDC() external {
        uint256 balance = USDC.balanceOf(address(this));
        USDC.approve(address(cUSDC), balance);
        cUSDC.repayBorrow(balance);
    }

    function redeemBTC() external {
        uint256 balance = cBTC.balanceOf(address(this));
        cBTC.redeem(balance);
    }

    function Compound() public {
        uint256 auroraBal = aurora.balanceOf(address(this));
        aurora.transfer(address(stAurora), auroraBal);
        stAurora.stakeAurora();
    }

    function addLiquidityPair(address token0, address token1) external {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        IERC20(token0).approve(address(router), balance0);
        IERC20(token1).approve(address(router), balance1);
        router.addLiquidity(
            token0, 
            token1, 
            balance0, 
            balance1, 
            0, 
            0, 
            address(this), 
            block.timestamp + 10
            );
    }
}