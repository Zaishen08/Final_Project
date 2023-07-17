// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "../contracts/Lottery.sol";

contract LotteryTest is Test {

    Lottery public lottery;
    address public cTokenAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public player1;
    address public player2;

    function setUp() public {
        lottery = new Lottery();
        player1 = address(0x123);
        player2 = address(0x456);
    }

    function testDrawTicket() public {
        uint256 ticketPrice = lottery.ticketPrice();
        // Player 1 enters the lottery
        vm.startPrank(player1);
        uint256 initialBalancePlayer1 = address(player1).balance;
        lottery.enter{value: ticketPrice}();
        assertEq(address(player1).balance, initialBalancePlayer1 - lottery.ticketPrice());
        vm.stopPrank();

        // Player 2 enters the lottery by sending less than the ticket price
        vm.startPrank(player2);
        uint256 initialBalancePlayer2 = address(player2).balance;
        lottery.enter{value: 0.001 ether}();
        vm.stopPrank();
    }

    function testPickWinner() public {
        uint256 ticketPrice = lottery.ticketPrice();

        vm.startPrank(player1);
        lottery.enter{value: ticketPrice}();
        vm.stopPrank();

        vm.startPrank(player2);
        lottery.enter{value: ticketPrice}();
        vm.stopPrank();

        // Pick the winner
        address winner = lottery.pickWinner();
//        assert(winner == player1 || winner == player2, "Invalid winner");

        // Check the winner received the prize
        uint256 expectedPrize = address(this).balance;
        assertEq(address(winner).balance, expectedPrize);
    }

    function testCompoundIntegration() public {
        vm.startPrank(player1);
        uint256 ticketPrice = lottery.ticketPrice();
        lottery.enter{value: ticketPrice}();

        // Deposit to Compound
        lottery.depositToCompound(ticketPrice);

        // Withdraw from Compound
        lottery.withdrawFromCompound(ticketPrice);
        vm.stopPrank();

        // Ensure that the deposited amount is back
        assertEq(CErc20(cTokenAddress).balanceOf(address(lottery)), 0);
    }
}