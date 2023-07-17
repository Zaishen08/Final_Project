pragma solidity ^0.8.13;


import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Comptroller} from "compound-protocol/contracts/Comptroller.sol";
import {CToken} from "compound-protocol/contracts/CToken.sol";
import {CErc20} from "compound-protocol/contracts/CErc20.sol";

contract Lottery {

    address public deployer;
    address[] public players;
    uint public ticketPrice;
    address private winner;
    uint private balance;
    uint256 public expiration;
    uint256 public constant duration = 10 minutes;

    CErc20 public cToken;
    Comptroller public comptroller;
    address public cTokenAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    modifier isDeployer() {
        require(msg.sender == deployer);
        _;
    }

    constructor() public {
        deployer = msg.sender;
        ticketPrice = 0.01 ether;
        expiration = block.timestamp + duration;
        cToken = CErc20(cTokenAddress);
        comptroller = new Comptroller();
    }

    function enter() public payable {
        //0.01 ether for drawing the ticket
        require(msg.value > 0.01 ether, "Less than 0.01 ether");
        require(winner == address(0), "Winner has already been picked");

        // Deposit the ticketPrice to Compound
        depositToCompound(ticketPrice);

        balance += msg.value - ticketPrice;
        players.push(msg.sender);
    }

    function getPlayers() public view isDeployer returns(address[] memory) {
        return players;
    }

    function getTotalPlayers() public view returns(uint) {
        return players.length;
    }

    function generateRandomNumber() private view returns (uint) {
        bytes32 hash = keccak256(abi.encode(block.prevrandao, block.timestamp, getTotalPlayers()));
        return uint256(hash);
    }

    function pickWinner() public isDeployer returns( address ) {
        require( getTotalPlayers() > 0 );
        require(block.timestamp >= expiration, "The lottery is not expired yet");

        uint prize = balance;

        // Charge 5% for winner
        uint handlingCharge = (prize * 5) / 100;
        uint prizeAfterHandlingCharge = prize - handlingCharge;

        // Withdraw the prize money from Compound
        withdrawFromCompound(prizeAfterHandlingCharge);

        if( winner == address(0) ) { // Pick one winner
            uint idx = generateRandomNumber() % players.length;
            winner = players[idx];
        }

        // Transfer the prize to the winner
        payable(winner).transfer(prizeAfterHandlingCharge);
        // Transfer the handlingCharge to contract deployer
        payable(deployer).transfer(handlingCharge);
        players = new address[](0);
        resetValue();

        return winner;
    }

    function resetValue() private {
        balance = 0;
        ticketPrice = 0;
    }

    // Deposit funds to Compound
    function depositToCompound(uint _amount) public isDeployer {
        require(_amount > 0, "Amount must be greater than zero");
        require(balance >= _amount, "Insufficient balance in the lottery");

        // Approve the transfer of ERC20 tokens to the Compound contract
        IERC20 underlyingToken = IERC20(cToken.underlying());
        underlyingToken.approve(address(cToken), _amount);

        // Mint cTokens
        require(cToken.mint(_amount) == 0, "Compound deposit failed");

        // Update the balance
        balance -= _amount;
    }

    // Withdraw funds from Compound
    function withdrawFromCompound(uint _amount) public isDeployer {
        require(_amount > 0, "Amount must be greater than zero");

        // Redeem cTokens to get back ERC20 tokens from Compound
        require(cToken.redeemUnderlying(_amount) == 0, "Compound withdrawal failed");

        // Redeemed ERC20 tokens to the lottery contract
        IERC20 underlyingToken = IERC20(cToken.underlying());
        underlyingToken.transfer(address(this), _amount);
        balance += _amount;
    }

}