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
contract fsToken is IERC20 {
    string name = 'FS-token';
    string symbol = 'FST';
    uint8 decimal = 18;
    uint totalSupply = 1000000;

    mapping(address => uint) public holdersRecord;
    mapping(address => mapping(address => uint)) public allowances;

    address protocol;
    constructor() {
        holdersRecord[msg.sender] = totalSupply;
        protocol = msg.sender;
    }

    function getSupply() external override view returns(uint) {
        return totalSupply;
    }

    function balanceOf(address holder) external override view returns(uint) {
        return holdersRecord[holder];
    }

    function transfer(address recipent, uint amountToSend) external override returns(bool)  {
        require(holdersRecord[msg.sender] >= amountToSend);
        holdersRecord[recipent] =  holdersRecord[recipent] + amountToSend;
        holdersRecord[msg.sender] =  holdersRecord[msg.sender] - amountToSend;
        return true;
    }
    function getBal() external view returns(uint) {
        return holdersRecord[msg.sender];
    }

    function approve(address spender, uint allowanceAmount) external override returns(bool) {
        address owner = msg.sender;
        allowances[owner][spender] = allowanceAmount;
        return true;
    }

    function returnAllowance(address owner, address spender) external override view returns(uint) {
        return allowances[owner][spender];
    }

    function transferFrom(address from, address to, uint transferAmount) external override returns(bool) {
        address spender = msg.sender;
        spendAllowance(from, spender, transferAmount);
        holdersRecord[to] = holdersRecord[to] + transferAmount;
        holdersRecord[from] =  holdersRecord[from] - transferAmount;
        return true;
    }

    function spendAllowance(address owner, address spender, uint allowanceAmount) internal view {
        uint allowanceBalance = allowances[owner][spender];
        require(allowanceBalance >= allowanceAmount);
        allowanceBalance = allowanceBalance - allowanceAmount;
    }

}
contract fungibleSwap {
    address payable dexVault;

    constructor() {
        dexVault = payable(msg.sender);        
    }

    fsToken public _token = fsToken(0xddaAd340b0f1Ef65169Ae5E41A8b10776a75482d);

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
        amountProvidedByProvider[msg.sender] = amountProvidedByProvider[msg.sender] + amount;
        providersStat[msg.sender][poolOptions.WETH] = providersStat[msg.sender][poolOptions.WETH] + amount;
        _token.transferFrom(dexVault, liquidtyProvider, amount);
    } 

    function provideWmaticLiquidity(uint amount, address payable liquidtyProvider) external payable {
        require(liquidtyProvider == payable(msg.sender));
        require(amount == msg.value);
        amount = msg.value;
        dexVault.transfer(amount); 
        WMATICProviders.push(liquidtyProvider);      
        tokenLiquidityPool[poolOptions.WMATIC] =  tokenLiquidityPool[poolOptions.WMATIC] + amount;
        amountProvidedByProvider[msg.sender] = amountProvidedByProvider[msg.sender] + amount;
        providersStat[msg.sender][poolOptions.WMATIC] = providersStat[msg.sender][poolOptions.WMATIC] + amount;
        _token.transferFrom(dexVault, liquidtyProvider, amount);
    } 

    function provideFstokenLiquidity(uint amount, address payable liquidtyProvider) external {
        require(liquidtyProvider == payable(msg.sender));
        _token.transferFrom(liquidtyProvider, dexVault, amount);
        fsTOKENProviders.push(liquidtyProvider);
        tokenLiquidityPool[poolOptions.fsTOKEN] =  tokenLiquidityPool[poolOptions.fsTOKEN] + amount;
        amountProvidedByProvider[msg.sender] =  amountProvidedByProvider[msg.sender] +  amount;
        providersStat[msg.sender][poolOptions.fsTOKEN] = providersStat[msg.sender][poolOptions.fsTOKEN] + amount;
    }

    event swaplogs(uint, poolOptions, address);
    mapping(address => mapping(uint => bool)) public swapDetails;
    mapping(address => poolOptions) public swapInfo;

   
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
                _amountToShr = _amountToShr / WETHProviders.length;
                rewardToken.transferFrom(dexVault, WETHProviders[i], _amountToShr);
            }
        } else if(reward == poolOptions.WMATIC) {
            for(uint i = 0; i < WMATICProviders.length; i++) {
                uint _amountToShr;
                _amountToShr = amount / 2;
                _amountToShr = _amountToShr / WMATICProviders.length;
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
        require(swapInfo[recipent] != poolOptions.NONE);
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
// user get token when they provide liquidity same ratio = done
// create fs token = done