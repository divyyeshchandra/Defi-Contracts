// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenFarm is ChainlinkClient, Ownable{

    string public name = "Dapp Token Farm";
    
    IERC20 public dappToken;

    //stakers is a public array for storing total numbers of stakers in the entire contract.
    address[] public  stakers;

    //stakingBalance is for mapping the token addres with user wallet address(msg.sender) with the amount they staked.
    mapping(address=>mapping (address=>uint256)) public stakingBalance;

    //uniqueTokensStaked is for calculating how much unique tokens per address is staked.
    mapping(address=>uint256) public uniqueTokensStaked;

    //tokenPricedFeedMapping is for mapping the token contract address with the Datafeed(Aggregator address) for the token.
    //Search What is Datafeed in chainlinks? to get better understanding.
    mapping(address=>address) public  tokenPricedFeedMapping;

    //allowedTokens is a array of tokens contract address which are allowed to be staked in this contract.
    address[] allowedTokens;

    //Initilizing a empty token IERC20 types address in dappToken
    constructor(address _dappTokenAddress) {
        dappToken=IERC20(_dappTokenAddress);
    }

    //onlyOwner type Function
    function addAllowedTokens(address token) public onlyOwner{
        allowedTokens.push(token);
    }

    //onlyOwner type Function
    function setPriceFeedContract(address token, address priceFeed) public onlyOwner{
        tokenPricedFeedMapping[token]=priceFeed;
    }

    //For staking allowed tokens in the contract
    function stakeTokens(uint256 _amount, address token) public {
        require(_amount>0,"amount cannot be 0");
        if(tokenIsAllowed(token)){
            updateUniqueTokensStaked(msg.sender,token);
            IERC20(token).transferFrom(msg.sender,address(this),_amount);
            stakingBalance[token][msg.sender]=stakingBalance[token][msg.sender]+_amount;
            if(uniqueTokensStaked[msg.sender]==1){
                stakers.push(msg.sender);
            }
        }
    }

    //For unstaking allowed tokens in the contract
    function unStakeTokens(address token) public {
        uint256 balance=stakingBalance[token][msg.sender];
        require(balance>0,"Staking balance cannot be 0");
        IERC20(token).transfer(msg.sender,balance);
        stakingBalance[token][msg.sender]=0;
        uniqueTokensStaked[msg.sender]=uniqueTokensStaked[msg.sender]-1;
    }

    //Fetching total value a user address have in terms of ETH using Chainlink Aggregator 
    function getUserTotalValue(address user) public  view returns (uint256){
        uint256 totalValue=0;
        if(uniqueTokensStaked[user]>0){
            for(uint256 allowedTokensIndex=0;allowedTokensIndex<allowedTokens.length;allowedTokensIndex++){
                totalValue=totalValue+getUserStakingBalanceEthValue(user,allowedTokens[allowedTokensIndex]);
            }
        }
        return totalValue;
    }

    function tokenIsAllowed(address token) public view returns(bool){
        for(uint256 allowedTokensIndex=0;allowedTokensIndex<allowedTokens.length;allowedTokensIndex++){
            if(allowedTokens[allowedTokensIndex]==token){
                return true;
            }
        }
        return false;
    }

    function updateUniqueTokensStaked(address user, address token) internal {
        if(stakingBalance[token][user]<=0){
            uniqueTokensStaked[user]=uniqueTokensStaked[user]+1;
        }
    }

    function getUserStakingBalanceEthValue(address user,address token) public view returns(uint256){
        if(uniqueTokensStaked[user]<=0) return 0;
        return (stakingBalance[token][user]*getTokenEthPrice(token))/(10**18);
    }

    //Simple issueToken function to transfer tokens from dappToken address to the recipient(It is not compulsory to add)
    function issueTokens() public onlyOwner{
        for(uint256 stakersIndex=0;stakersIndex<stakers.length;stakersIndex++){
            address recipient = stakers[stakersIndex];
            dappToken.transfer(recipient,getUserTotalValue(recipient));
        }
    }

    //The function where we are using Chainlink aggregator to return the value of ETH
       function getTokenEthPrice(address token) public view returns (uint256) {
        address priceFeedAddress = tokenPricedFeedMapping[token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return uint256(price);
    }
}


