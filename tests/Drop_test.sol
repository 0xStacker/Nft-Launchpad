// SPDX-License-Identifier: MIT
        
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 
import {PresaleLib} from "../contracts/Drop.sol";
// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
import {Drop} from "../contracts/Drop.sol";

// File name has to end with '_test.sol', this file can contain more than one testSuite contracts
contract testSuite{
    Drop public newDrop;
    address acc0;
    address acc1;
    address acc2;
    address drop;
    uint public mintedCount;

    /*
        uint8 maxPerAddress;
        string name;
        uint price;
        uint startTime;
        uint endTime;
        bytes32 merkleRoot;
    */
    
    PresaleLib.PresalePhase[] phases;
    /// 'beforeAll' runs before all other tests
    /// More special functions are: 'beforeEach', 'beforeAll', 'afterEach' & 'afterAll'
    function beforeAll() public payable{
        acc0 = TestsAccounts.getAccount(0); 
        acc1 = TestsAccounts.getAccount(1);
        acc2 = TestsAccounts.getAccount(2);
        PresaleLib.PresalePhase memory newPhase = phases.push();
        newPhase.maxPerAddress = 2;
        newPhase.name = "testPhase";
        newPhase.price = 50;
        newPhase.startTime = 0;
        newPhase.endTime = 200;
        newPhase.merkleRoot = 0x85c99f9ed408529a8e32d19f1606c0783273722f7a42ae71ef5f7345b0e62870;
        phases.push(newPhase);
        Drop _newDrop = new Drop("TEST",
         "TST",
         10,
         0,
         300,
         acc0,
         0,
         100,
         2,
         true,
         phases
         );

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

    /// #sender: account-1
    function testAirdrop() external{
        uint initialBal = newDrop.balanceOf(acc1);
        newDrop.airdrop(acc1, 2);
        Assert.equal(newDrop.balanceOf(acc1), initialBal + 2, "Airdrop should transfer 2 tokens from account->account-3");
    }

}
    