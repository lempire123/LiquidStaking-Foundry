// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/LiquidStaking.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";

contract ContractTest is Test {
    AuroraLiquidStaking staking;
    address admin = address(1);
    address harvester = address(2);
    address farmer = address(3);
    address bob = address(4);
    address sam = address(5);
    address kate = address(6);
    IERC20 aurora = IERC20(0x8BEc47865aDe3B172A928df8f990Bc7f2A3b9f79);
    IERC20 bstn = IERC20(0x9f1F933C660a1DC856F0E0Fe058435879c5CCEf0);
    IERC20 ply = IERC20(0x09C9D464b58d96837f8d8b6f4d9fE4aD408d3A4f);
    IERC20 tri = IERC20(0xFa94348467f64D5A457F75F8bc40495D33c65aBB);
    IERC20 usn = IERC20(0x5183e1B1091804BC2602586919E6880ac1cf2896);
    address[] tokens = [address(bstn), address(ply), address(tri), address(usn)];
    

    function setUp() public {
        staking = new AuroraLiquidStaking(admin, tokens);
        deal(address(aurora), bob, 100000 ether);
        deal(address(aurora), sam, 10 ether);
        deal(address(aurora), kate, 10 ether);
        vm.startPrank(admin);
        staking.setHarvester(harvester);
        staking.setFarmer(farmer);
        vm.stopPrank();
    }

    function depositFor(address user, uint256 amount) public {
        vm.startPrank(user);
        aurora.approve(address(staking), amount);
        staking.deposit(amount);
        vm.stopPrank();
    }

    // ============================
    //         SHOULD PASS
    // ============================

    function testDepositAurora() public {
        depositFor(bob, 10 ether);
        uint256 bal = staking.balanceOf(bob);
        assertEq(bal, 10 ether);
    }

    function testReturns() public {
        depositFor(bob, 10 ether);
        vm.warp(block.timestamp + 24 weeks + 1);
        vm.startPrank(admin);
        staking.Unstake();
        vm.warp(block.timestamp + 3 days);
        staking.Withdraw();
        uint256 bal = aurora.balanceOf(address(staking));
        assert(bal > 10 ether);
    }

    function testHarvest() public {
        depositFor(bob, 100000 ether);
        vm.warp(block.timestamp + 10 weeks);
        vm.startPrank(harvester);
        staking.moveRewardsToPending();
        vm.warp(block.timestamp + 3 days);
        staking.harvest();
        staking.sendTokensToFarmer();
    }

    function testStAuroraAmounts() public {
        depositFor(bob, 10 ether);
        vm.warp(block.timestamp + 1 weeks);
        depositFor(sam, 10 ether);
        vm.warp(block.timestamp + 1 weeks);
        depositFor(kate, 10 ether);
        uint256 bobBal = staking.balanceOf(bob);
        uint256 samBal = staking.balanceOf(sam);
        uint256 kateBal = staking.balanceOf(kate);
        assert(bobBal > samBal && samBal > kateBal);
    }

    // ============================
    //         SHOULD FAIL
    // ============================

    function testCannotMoveRewardsToPending() public {
        depositFor(bob, 10 ether);
        vm.expectRevert("ONLY HARVESTER CAN HARVEST");
        staking.moveRewardsToPending();
    }

    function testCannotUnstakeEarly() public {
        depositFor(bob, 10 ether);
        vm.startPrank(admin);
        vm.expectRevert("DISTRIBUTION DATE NOT REACHED");
        staking.Unstake();
    }
}
