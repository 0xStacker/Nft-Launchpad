// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
import {Drop} from "../contracts/Drop.sol";

// File name has to end with '_test.sol', this file can contain more than one testSuite contracts
contract testSuite {
    Drop public newDrop;
    address acc0;
    address acc1;
    address acc2;
    address drop;
    uint public mintedCount;

    /// 'beforeAll' runs before all other tests
    /// More special functions are: 'beforeEach', 'beforeAll', 'afterEach' & 'afterAll'
    /// #sender: account-0
    function beforeAll() public payable{
        acc0 = TestsAccounts.getAccount(0); 
        acc1 = TestsAccounts.getAccount(1);
        acc2 = TestsAccounts.getAccount(2);

        Drop _newDrop = new Drop("TEST", "TST",
     21, 0, acc0,
       acc0, 0, 100, 2);
       newDrop = _newDrop;
       drop = address(_newDrop);
       Assert.equal(acc0, newDrop.creatorAddress(), "Owner doesn't match");
    }

    /// #sender: account-1
    /// #value: 200
    function testMint() public payable{
        // Use 'Assert' methods: https://remix-ide.readthedocs.io/en/latest/assert_library.html
        uint currentBal = newDrop.balanceOf(msg.sender);
        uint creatorBalance = newDrop.creatorAddress().balance;
        newDrop.mintPublic{value: 200}(2, msg.sender);
        Assert.equal(newDrop.balanceOf(msg.sender), currentBal + 2, "Balance should increase by 2");
        Assert.equal(newDrop.creatorAddress().balance, creatorBalance + 200, "Creator Balance should increase by 200");
    }

    /// #sender: account-2
    /// #value: 200
    function testControlledMint() public payable{
        uint creatorBalance = newDrop.creatorAddress().balance;
        uint currentBal = newDrop.balanceOf(msg.sender);
        newDrop.controlledMint{value: 200}(5, msg.sender);
        Assert.equal(newDrop.balanceOf(msg.sender), currentBal + 2, "Balance should increase by 2");
        Assert.equal(newDrop.creatorAddress().balance, creatorBalance + 200, "Creator Balance should increase by 200");
    }

    /// #sender: account-1
    function testAirdrop() external{
        uint initialBal = newDrop.balanceOf(acc1);
        newDrop.airdrop(acc1, 2);
        Assert.equal(newDrop.balanceOf(acc1), initialBal + 2, "Airdrop should transfer 2 tokens from account->account-3");

    }

    /// # sender: account-3
    /// #value: 100
    function testMintAfterResume() public payable{
        uint initialBal = newDrop.balanceOf(msg.sender);
        newDrop.mintPublic{value: 100}(1, msg.sender); 
        Assert.equal(newDrop.balanceOf(msg.sender), initialBal + 1, "Balance should increase by 1");
    }
}
    