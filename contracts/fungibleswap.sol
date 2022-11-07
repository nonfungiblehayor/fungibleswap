// SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0 <= 0.9.0;

interface IERC20 {

    function getSupply() external  view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function returnAllowance(address owner, address spender) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);


    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract fungibleSwap {
    address payable dexVault;

    constructor() {
        dexVault = payable(msg.sender);        
    }

    FSToken public _token = FSToken(0xddaAd340b0f1Ef65169Ae5E41A8b10776a75482d);

    // IERC20 WETH;
    // IERC20 WMATIC;
    // IERC20 fsTOKEN;

    address[] WETHProviders;
    address[] WMATICProviders;
    address[] fsTOKENProviders;

    enum poolOptions {
        WETH,
        WMATIC,
        fsTOKEN,
        NONE
    }

    mapping(poolOptions => uint) public  tokenLiquidityPool;
    mapping(address => uint) public amountProvidedByProvider;
    mapping(address => mapping(poolOptions => uint)) public providersStat;

    function provideWethLiquidity(uint amount, address payable liquidtyProvider) external payable {
        require(liquidtyProvider == payable(msg.sender));
        require(amount == msg.value);
        amount = msg.value;
        dexVault.transfer(amount); 
        WETHProviders.push(liquidtyProvider);      
        tokenLiquidityPool[poolOptions.WETH] =  tokenLiquidityPool[poolOptions.WETH] + amount;
        amountProvidedByProvider[msg.sender] = amount;
        providersStat[msg.sender][poolOptions.WETH] = providersStat[msg.sender][poolOptions.WETH] + amount;
    } 

    function provideWmaticLiquidity(uint amount, address payable liquidtyProvider) external payable {
        require(liquidtyProvider == payable(msg.sender));
        require(amount == msg.value);
        amount = msg.value;
        dexVault.transfer(amount); 
        WMATICProviders.push(liquidtyProvider);      
        tokenLiquidityPool[poolOptions.WMATIC] =  tokenLiquidityPool[poolOptions.WMATIC] + amount;
        amountProvidedByProvider[msg.sender] = amount;
        providersStat[msg.sender][poolOptions.WMATIC] = providersStat[msg.sender][poolOptions.WMATIC] + amount;
    } 

    function provideFstokenLiquidity(uint amount, address payable liquidtyProvider) external {
        require(liquidtyProvider == payable(msg.sender));
        IERC20 token;
        token.transferFrom(liquidtyProvider, dexVault, amount);
        fsTOKENProviders.push(liquidtyProvider);
        tokenLiquidityPool[poolOptions.fsTOKEN] =  tokenLiquidityPool[poolOptions.fsTOKEN] + amount;
        amountProvidedByProvider[msg.sender] = amount;
        providersStat[msg.sender][poolOptions.fsTOKEN] = providersStat[msg.sender][poolOptions.fsTOKEN] + amount;
    }

    event swaplogs(uint, poolOptions, address);
    mapping(address => mapping(uint => bool)) swapDetails;
    mapping(address => poolOptions) swapInfo;

   
    function swap(uint amount, address payable swapper, IERC20 swappingToken, poolOptions swappingFor)
    external returns(bool)  {
        require(swapper == payable(msg.sender));
        if(swappingFor == poolOptions.fsTOKEN) {
        swappingToken.transferFrom(swapper, dexVault, amount);
        _token.transferFrom(dexVault, swapper, amount);    
         return true;       
        } else {
        swappingToken.transferFrom(swapper, dexVault, amount);
        rewardLiquidityProvider(amount, swappingToken, swappingFor);
        swapDetails[swapper][amount] = true;
        swapInfo[swapper] = swappingFor;
        emit swaplogs(amount, swappingFor, swapper);
        return true;
        }
    }

    function rewardLiquidityProvider(uint amount, IERC20 rewardToken, poolOptions reward) internal {
        if(reward == poolOptions.WETH) {
            for(uint i = 0; i < WETHProviders.length; i++) {
                uint _amountToShr;
                _amountToShr = amount / 2;
                _amountToShr = _amountToShr / WETHProviders[i].length;
                rewardToken.transferFrom(dexVault, WETHProviders[i], _amountToShr);
            }
        } else if(reward == poolOptions.WMATIC) {
            for(uint i = 0; i < WMATICProviders.length; i++) {
                uint _amountToShr;
                _amountToShr = amount / 2;
                _amountToShr = _amountToShr / WMATICProviders[i].length;
                rewardToken.transferFrom(dexVault, WMATICProviders[i], _amountToShr);
            }
        }
    }

    modifier vault() {
       require(msg.sender == dexVault);
       _;
    }

    function getSwap(uint amount, address payable recipent, poolOptions tokenOut) external payable vault returns(bool) {
        require(amount == msg.value);
        require(swapInfo[recipent] == tokenOut);
        require(swapDetails[recipent][amount] == true);
        recipent.transfer(amount);
        swapDetails[recipent][amount] = false;
        swapInfo[recipent] = poolOptions.NONE;
        return true;
    }


               

       
   
    
}

// create function to add liquidity = done
// swap function = done
// check if token exist in the above before swapping
// reward function for liquidity provider = done
// function to loan from liquidity pool
// user get token when they provide liquidity same ratio