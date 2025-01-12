// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentalizedStableCoin.sol";

contract TestDSC is Test {
    DecentralizedStableCoin dsc;
    address public OWNER = makeAddr("user1");
    address public USER = makeAddr("user2");

    function setUp() external {
        dsc = new DecentralizedStableCoin();
    }

    function testMintDsc() public {
        vm.prank(OWNER);
        bool result = dsc.mint(OWNER, 1 ether);
        assert(result == true);
    }
}
