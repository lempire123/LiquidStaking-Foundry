// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/LiquidStaking.sol";
import "../src/Strat-Implementations/BTCMaxi.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";

contract BTCMaxiTest is Test {
    AuroraLiquidStaking liquidStaking;
    BTCMaxi farmer;
    address admin = address(1);
    address harvester = address(2);
    address bob = address(4);
    address sam = address(5);
    address kate = address(6);
    IERC20 aurora = IERC20(0x8BEc47865aDe3B172A928df8f990Bc7f2A3b9f79);
    IERC20 bstn = IERC20(0x9f1F933C660a1DC856F0E0Fe058435879c5CCEf0);
    IERC20 ply = IERC20(0x09C9D464b58d96837f8d8b6f4d9fE4aD408d3A4f);
    IERC20 tri = IERC20(0xFa94348467f64D5A457F75F8bc40495D33c65aBB);
    IERC20 usn = IERC20(0x5183e1B1091804BC2602586919E6880ac1cf2896);
    IERC20 btc = IERC20(0xF4eB217Ba2454613b15dBdea6e5f22276410e89e);
    IERC20 usdc = IERC20(0xB12BFcA5A55806AaF64E99521918A4bf0fC40802);
    address[] tokens = [address(bstn), address(ply), address(tri), address(usn)];
    

    function setUp() public {
        liquidStaking = new AuroraLiquidStaking(admin, tokens);
        farmer = new BTCMaxi(address(liquidStaking));

        deal(address(aurora), bob, 100000 ether);
        deal(address(aurora), sam, 10 ether);
        deal(address(aurora), kate, 10 ether);
        vm.startPrank(admin);
        liquidStaking.setHarvester(harvester);
        liquidStaking.setFarmer(address(farmer));
        vm.stopPrank();
    }

    function depositFor(address user, uint256 amount) public {
        vm.startPrank(user);
        aurora.approve(address(liquidStaking), amount);
        liquidStaking.deposit(amount);
        vm.stopPrank();
    }

    // ============================
    //         SHOULD PASS
    // ============================

    function testFarming() public {
        depositFor(bob, 100000 ether);
        vm.warp(block.timestamp + 10 weeks);
        vm.startPrank(harvester);
        liquidStaking.moveRewardsToPending();
        vm.warp(block.timestamp + 3 days);
        liquidStaking.harvest();
        liquidStaking.sendRewardTokensToFarmer();
        console.log(btc.balanceOf(address(farmer)));
        farmer.putFundsToWork();
        farmer.swapUSNforBTC();
        console.log(btc.balanceOf(address(farmer)) / 10**6);
        farmer.lendBTC();
        console.log(btc.balanceOf(address(farmer)) / 10**6);
        farmer.borrowUSDC(10000*10**6);
        console.log(usdc.balanceOf(address(farmer)) / 10**6);
        farmer.repayUSDC();
        console.log(usdc.balanceOf(address(farmer)) / 10**6);
        farmer.redeemBTC();
        console.log(btc.balanceOf(address(farmer)) / 10**6);
    }

    function testCompound() public {
        // deal(address(aurora), address(farmer), 100 ether);
        // deal(address(usdc), address(farmer), 150 * 10**6);
        deal(address(btc), address(farmer), 15 * 10**8);
        console.log(btc.balanceOf(address(farmer)) / 10**6);
        farmer.lendBTC();
        console.log(btc.balanceOf(address(farmer)) / 10**6);
        farmer.borrowUSDC(10000*10**6);
        console.log(usdc.balanceOf(address(farmer)) / 10**6);
        farmer.swapTokens(address(usdc), address(aurora));
        console.log(liquidStaking.staking().getUserShares(address(liquidStaking)));
        farmer.Compound();
        console.log(liquidStaking.staking().getUserShares(address(liquidStaking)));
    }
}
