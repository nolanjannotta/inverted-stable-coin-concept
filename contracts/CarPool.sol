// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract PriceConsumerV3 {

    AggregatorV3Interface internal priceFeed;

    constructor() {
        priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
    }


    function getLatestPrice() internal view returns (int) {
        (,int price,,,) = priceFeed.latestRoundData();
        return price;
    }
}



contract CarPool is ERC20, Ownable, PriceConsumerV3 {

    using SafeCast for int;

    mapping(address => uint) public addressToDeposited; 
    mapping(address => mapping(address => uint256)) private _allowances; //dollar amount in wei!!

    string private _name;
    string private _symbol;

    constructor() ERC20("CarPool", "CRPL") {}

    // UTILITY FUNCTIONS

    function ethToDollar(uint ethInWei) internal view returns(uint) {
        uint ethPriceInUsd = getEthPrice().toUint256() * 10**10;
        uint dollarAmount = (ethPriceInUsd * ethInWei) / 10**18;
        return dollarAmount;
    }

    function dollarToEth(uint dollarAmount) internal view returns(uint) { // dollar amount in wei!!!!
        uint ethPrice = getEthPrice().toUint256() * 10**10;
        uint ethAmount = (dollarAmount * 1 ether) / ethPrice;
        return ethAmount;


    }
    function empty() public {
        Address.sendValue(payable(_msgSender()), address(this).balance);
    }

    function exchangeForEth(uint dollarAmount) public { //dollarAmount represented in wei
        require(dollarAmount > 0 && dollarAmount <= balanceOf(msg.sender));
        uint ethAmount = dollarToEth(dollarAmount);
        Address.sendValue(payable(_msgSender()), ethAmount);
        addressToDeposited[_msgSender()] -= ethAmount;

    }
    function getEthPrice() public view returns(int) {
        return getLatestPrice();

    }




    function buyToken() public payable returns(uint) {
        require(msg.value > 0, "Deposit non zero amount");
        uint buyAmount = ethToDollar(msg.value);
        addressToDeposited[_msgSender()] += msg.value;
        return buyAmount;
        // _mint(_msgSender(), mintAmount);
    }


    // ERC20 FUNCTIONS
    function decimals() public pure override returns (uint8) {
        return 18;
    }
    function symbol() public view override returns (string memory) {
        return _symbol;
    }
    function name() public view override returns (string memory) {
        return _name;
    }

    function balanceOf(address account) public view override returns(uint) {
        require(account != address(0));
        uint depositedEth = addressToDeposited[account];
        uint ethPrice = getEthPrice().toUint256() * 10**10;
        uint balance = (ethPrice * depositedEth) / 1 ether;
        return balance;
    }



    function totalSupply() public view override returns(uint) {
        uint ethPrice = getEthPrice().toUint256() * 10**10;
        uint contractBalance = address(this).balance;
        uint _totalSupply = (ethPrice * contractBalance) / 10**18;
        return _totalSupply;
    }

    

    function transfer(address recipient, uint256 amount) public override returns(bool) { // amount is dollars represented in wei!!!
        _transfer(_msgSender(), recipient, amount);
        return true;

    }

    function transferFrom(
        address sender, 
        address recipient, 
        uint256 amount
        ) public virtual override returns (bool) {

        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];

        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;


            
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        uint senderDeposited = addressToDeposited[sender];

        require(senderDeposited >= dollarToEth(amount), "insufficient balance");
        unchecked {
            addressToDeposited[sender] = senderDeposited - dollarToEth(amount);
        }
        addressToDeposited[recipient] += dollarToEth(amount);

        emit Transfer(sender, recipient, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal override { // amount is dollars represented in wei
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }



    


    

     


}

