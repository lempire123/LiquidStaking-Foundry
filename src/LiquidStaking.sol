// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IFarmer {
    function putFundsToWork() external;
    function sendTokensBack() external;
}

interface AuroraStaking {
    function stake(uint256 amount) external;
    function unstakeAll() external;
    function withdraw(uint256 streamId) external;
    function moveAllRewardsToPending() external;
    function withdrawAll() external;
    function getUserTotalDeposit(address account) external view  returns (uint256);
    function getUserShares(address account) external view returns (uint256);
    function getTotalAmountOfStakedAurora() external view returns (uint256);
    function totalAuroraShares() external view returns (uint256);
}

/// @title Aurora Liquid Staking Contract
/// @author Lance Henderson
/// 
/// @notice Contract allows user to stake their aurora tokens.
/// In return they receive an ERC20 receipt (stAurora)
/// The reason for this is so users can gain immediate liquidity 
/// from their staked aurora (by selling on the open market) rather 
/// than having to wait 2 days
/// 
/// @dev Important things to note:
/// - The user is not able to redeem their stAurora (only sell it)
/// - The rewards generated from streams are sent to a separate contract
/// - This separate contract will earn a yield on these tokens
/// - Only the admin can withdraw the aurora tokens
/// - The stAurora will become redeemable for aurora/rewards once/6 months
/// Reasoning behind this is that rewards will be put in complex strategies,
/// hence we don't want to be unwinding complex positions constantly.

contract AuroraLiquidStaking is ERC20 {

    // Admin of the contract
    address public admin;
    // Address in charge of harvesting rewards
    address public harvester;
    // Distribution happense every 6 months
    uint256 public distributionPeriod = 24 weeks;
    // Next time distribution will take place
    uint256 public distributionDate;
    // Allows functions to be paused
    bool public paused;
    // Aurora Token
    IERC20 public constant aurora = IERC20(0x8BEc47865aDe3B172A928df8f990Bc7f2A3b9f79);
    // Array of reward tokens
    IERC20[] public rewardStreamTokens;
    // Aurora Staking Contract
    AuroraStaking public staking = AuroraStaking(0xccc2b1aD21666A5847A804a73a41F904C4a4A0Ec);
    // Contract which will handle farming with harvested rewards
    IFarmer public farmer;
    // Distributor contract
    address public distributor;


    // Only admin can access
    modifier onlyAdmin {
        require(msg.sender == admin, "ONLY ADMIN CAN CALL");
        _;
    }

    // Only harvester can access
    modifier onlyHarvester {
        require(msg.sender == harvester, "ONLY HARVESTER CAN HARVEST");
        _;
    }

    // Only distributor can access
    modifier onlyDistributor {
        require(msg.sender == distributor, "ONLY DISTRIBUTOR CAN CALL");
        _;
    }
    // Make sure distribution date is reached
    modifier DistributionDatePast() {
        require(block.timestamp > distributionDate, "DISTRIBUTION DATE NOT REACHED");
        _;
    }

    // Function must not be paused
    modifier notPaused() {
        require(paused == false, "FUNCTION PAUSED");
        _;
    }

    // =====================================
    //            CONSTRUCTOR
    // =====================================

    // @param _admin Admin address
    // @param _tokens Array of reward tokens
    // @param _treasury Address of treasury
    constructor(address _admin, address[] memory _tokens) ERC20("Staked Aurora", "stAurora") {
        admin = _admin;
        distributionDate = block.timestamp + distributionPeriod;
        aurora.approve(address(staking), 2**256 - 1);

        uint256 length = _tokens.length;
        for(uint256 i; i < length; ++i) {
            rewardStreamTokens.push(IERC20(_tokens[i]));
        }
    }

    // =====================================
    //            PUBLIC/EXTERNAL 
    // =====================================

    // @notice Allows user to stake their aurora 
    // User must approve contract to spend their aurora first
    // @dev User receives an ERC20 token receipt (stAurora)
    // @param _amount Amount of aurora to stake
     function deposit(uint256 _amount) public notPaused {
        aurora.transferFrom(msg.sender, address(this), _amount);
        uint256 totalAurora = (staking.getTotalAmountOfStakedAurora() *
            staking.getUserShares(address(this))) / staking.totalAuroraShares();
        if (totalSupply() == 0 || totalAurora == 0) {
            _mint(msg.sender, _amount);
        } else {
            uint256 mintAmount = (_amount * totalSupply()) / totalAurora;
            _mint(msg.sender, mintAmount);
        }
        stakeAurora();

    }

    // @notice Helper function to stake all of user's aurora balance
    function depositAll() external notPaused {
        uint256 auroraBalance = aurora.balanceOf(msg.sender);
        deposit(auroraBalance);
    }

    function stakeAurora() public notPaused{
        uint256 balance = aurora.balanceOf(address(this));
        staking.stake(balance);
    }

    // =====================================
    //             HARVESTER
    // =====================================

    // @notice Moves rewards to pending (become accessible after 2 days)
    function moveRewardsToPending() external onlyHarvester {
        staking.moveAllRewardsToPending();
    }

    // @notice Harvest rewards and puts them to work (ie staking)
    // @dev Farming with received rewards will be delegated to a separate contract
    function harvest() external onlyHarvester {
        staking.withdrawAll();
    }

    function sendTokensToFarmer() external onlyHarvester {
        uint256 length = rewardStreamTokens.length;
        for(uint i; i < length; ++i) {
            uint256 tokenBalance = rewardStreamTokens[i].balanceOf(address(this));
            rewardStreamTokens[i].transfer(address(farmer), tokenBalance);
        }
    }

    // @notice Put funds to work
    function earn() external onlyHarvester {
        farmer.putFundsToWork();
    }

    // ====================================
    //              DISTRIBUTION
    // ====================================

    
    // @notice In the edge case that something goes wrong, 
    // the admin is able to recover funds.
    function Unstake() external onlyAdmin DistributionDatePast {
        staking.unstakeAll();
        distributionDate = block.timestamp + distributionPeriod;
        paused = true;
    }

    // @notice Funds can only be withdrawn after a 2 day wait.
    function Withdraw() external onlyAdmin {
        staking.withdraw(0);
    }

    // @notice Withdraw rewards from farmer contract
    function withdrawFarmer() external onlyAdmin {
        farmer.sendTokensBack();
    }

    // @notice Sends tokens to distributor
    function sendTokensToDistributor(address[] memory tokens) external onlyAdmin {
        uint256 length = tokens.length;
        for(uint256 i; i < length; ++i) {
            uint256 bal = IERC20(tokens[i]).balanceOf(address(this));
            IERC20(tokens[i]).transfer(address(distributor), bal);
        }
    }

    function burnStAurora(address _account, uint256 _amount) external onlyDistributor {
        _burn(_account, _amount);
    }

    // ====================================
    //              EDIT REWARDS
    // ====================================

    // @notice Allows admin to add reward token
    // @param _reward Address of reward token
    function addRewardToken(address _token) external onlyAdmin {
        rewardStreamTokens.push(IERC20(_token));
    } 
     
    // @notice Allows admin to remove reward token
    // @param _index Index of reward token to remove
    function removeRewardToken(uint256 _index) external onlyAdmin {
        rewardStreamTokens[_index] = rewardStreamTokens[rewardStreamTokens.length - 1];
        rewardStreamTokens.pop();
    }

    // ====================================
    //           SAFETY MEASURES
    // ====================================

    // @notice Allows admin to withdraw a token
    // @param _token Token to withdraw
    function sweepTokens(address _token) external onlyAdmin {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(msg.sender, balance);
    }

    // ====================================
    //      CONNECT EXTERNAL CONTRACTS
    // ====================================

    // @notice Allows admin to change farmer contract
    // @param _farmer Address of new farmer
    function setFarmer(address _farmer) external onlyAdmin {
        farmer = IFarmer(_farmer);
    }

    function setHarvester(address _harvester) external onlyAdmin {
        harvester = _harvester;
    }

    function setDistributer(address _distributor) external onlyAdmin {
        distributor = _distributor;
    }

    // ====================================
    //               HELPERS
    // ====================================

    function getRewardTokens() external view returns (IERC20[] memory) {
        return rewardStreamTokens;
    }

}