// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
import {Drop} from "../contracts/Drop.sol";

// interface IERC721{
//     function mintPublic(uint _amount, address _to) external;
// }

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
    /// #value: 200
    function beforeAll() public payable{
        acc0 = TestsAccounts.getAccount(0); 
        acc1 = TestsAccounts.getAccount(1);
        acc2 = TestsAccounts.getAccount(2);

        Drop _newDrop = new Drop("TEST", "TST",
     21, 0, acc0,
       acc0, 0, 100, 2);
       newDrop = _newDrop;
       drop = address(_newDrop);
    }

    
    function preChecks() public{
        Assert.ok(!newDrop.paused(), "Paused should be false");
        Assert.ok(newDrop.checkStart(), "Sale not started");
        Assert.equal(newDrop.checkCost(1), 100, "Cost should be 100 wei");
    }

    /// #sender: account-1
    /// #value: 200
    function testMint() public{
        // Use 'Assert' methods: https://remix-ide.readthedocs.io/en/latest/assert_library.html
        uint currentBal = newDrop.balanceOf(msg.sender);
        newDrop.mintPublic{value: 200}(2, msg.sender);
        Assert.equal(newDrop.balanceOf(msg.sender), currentBal + 2, "Balance should increase by 2");
    }

    /// #sender: account-2
    /// #value: 200
    function testControlledMint() public payable{
        uint currentBal = newDrop.balanceOf(msg.sender);
        newDrop.controlledMint{value: 200}(5, msg.sender);
        Assert.equal(newDrop.balanceOf(msg.sender), currentBal + 2, "Balance should increase by 2");
    }

    function checkSupply() public {
        Assert.ok(newDrop.supply() == 21, "Supply does not match");
    }
    
}
    