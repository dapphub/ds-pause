// Copyright (C) 2019 David Terry <me@xwvvvvwx.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.5.0 <0.6.0;

import "ds-test/test.sol";
import "ds-chief/chief.sol";
import "ds-token/token.sol";
import "ds-proxy/proxy.sol";

import "./pause.sol";

// ------------------------------------------------------------------
// Test Harness
// ------------------------------------------------------------------

contract Hevm {
    function warp(uint) public;
}

contract ProposalLike {
    function plan() public returns (bytes memory);
}

contract Voter {
    function vote(DSChief chief, address proposal) public {
        address[] memory votes = new address[](1);
        votes[0] = address(proposal);
        chief.vote(votes);
    }

    function lift(DSChief chief, address proposal) external {
        chief.lift(proposal);
    }

    function lock(DSChief chief, uint amount) public {
        DSToken gov = chief.GOV();
        gov.approve(address(chief));
        chief.lock(amount);
    }

    function free(DSChief chief, uint amount) public {
        DSToken iou = chief.IOU();
        iou.approve(address(chief));
        chief.free(amount);
    }
}

contract Target {
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    constructor() public {
        wards[msg.sender] = 1;
    }

    uint public val = 0;
    function set(uint val_) public auth {
        val = val_;
    }
}

// ------------------------------------------------------------------
// Gov Proposal Template
// ------------------------------------------------------------------

contract Proposal {
    bool done = false;

    DSPause pause;
    address usr;
    bytes   fax;
    uint    val;

    constructor(DSPause pause_, address usr_, bytes memory fax_, uint val_) public {
        pause = pause_;
        usr = usr_;
        fax = fax_;
        val = val_;
    }

    function plan() public returns (address, bytes memory, uint, uint) {
        require(!done);
        done = true;

        uint era = now + pause.delay();
        pause.plan(usr, fax, val, era);
        return (usr, fax, val, era);
    }
}

// ------------------------------------------------------------------
// Shared Test Setup
// ------------------------------------------------------------------

contract Test is DSTest {
    // test harness
    Hevm hevm;
    DSChiefFab chiefFab;
    Target target;
    Voter voter;

    // pause timings
    uint start = 0;
    uint delay = 1 days;

    // gov constants
    uint votes = 100;
    uint maxSlateSize = 1;

    // gov token
    DSToken gov;

    function setUp() public {
        // init hevm
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(start);

        // create test harness
        target = new Target();
        voter = new Voter();

        // create gov token
        gov = new DSToken("GOV");
        gov.mint(address(voter), votes);
        gov.setOwner(address(0));

        // chief fab
        chiefFab = new DSChiefFab();
    }
}

// ------------------------------------------------------------------
// Test Simple Voting
// ------------------------------------------------------------------

contract SimpleAction {
    function exec(Target target) public {
        target.set(1);
    }
}

contract Voting is Test {

    function test_simple_proposal() public {
        // create gov system
        DSChief chief = chiefFab.newChief(gov, maxSlateSize);
        DSPause pause = new DSPause(delay, address(0x0), chief);
        target.rely(address(pause));
        target.deny(address(this));

        // create proposal
        address      usr = address(new SimpleAction());
        bytes memory fax = abi.encodeWithSignature("exec(address)", target);
        uint         val = 0;

        Proposal proposal = new Proposal(pause, usr, fax, val);

        // make proposal the hat
        voter.lock(chief, votes);
        voter.vote(chief, address(proposal));
        voter.lift(chief, address(proposal));

        // make plan
        uint era;
        (usr, fax, val, era) = proposal.plan();

        // wait until delay is passed
        hevm.warp(era);

        // execute plan
        assertEq(target.val(), 0);
        pause.exec(usr, fax, val, era);
        assertEq(target.val(), 1);
    }

}

// ------------------------------------------------------------------
// Test Chief Upgrades
// ------------------------------------------------------------------

contract SetAuthority {
    function set(DSAuth usr, DSAuthority authority) public {
        usr.setAuthority(authority);
    }
}

contract Guard is DSAuthority {
    uint lockUntil;
    address newAuthority;
    DSPause pause;

    constructor(uint lockUntil_, DSPause pause_, address newAuthority_) public {
        lockUntil = lockUntil_;
        newAuthority = newAuthority_;
        pause = pause_;
    }

    function canCall(address src, address dst, bytes4 sig) public view returns (bool) {
        require(src == address(this));
        require(dst == address(pause));
        require(sig == bytes4(keccak256("plan(address,bytes,uint256,uint256)")));
        return true;
    }

    function unlock() public returns (address, bytes memory, uint, uint) {
        require(now >= lockUntil);

        address      usr = address(new SetAuthority());
        bytes memory fax = abi.encodeWithSignature( "set(address,address)", pause, newAuthority);
        uint         val = 0;
        uint         era = now + pause.delay();

        pause.plan(usr, fax, val, era);
        return (usr, fax, val, era);
    }
}


contract UpgradeChief is Test {

    function test_chief_upgrade() public {
        // create gov system
        DSChief oldChief = chiefFab.newChief(gov, maxSlateSize);
        DSPause pause = new DSPause(delay, address(0x0), oldChief);

        // make pause the only owner of the target
        target.rely(address(pause));
        target.deny(address(this));

        // create new chief
        DSChief newChief = chiefFab.newChief(gov, maxSlateSize);

        // create guard
        uint lockGuardUntil = now + pause.delay() + 100 days;
        Guard guard = new Guard(lockGuardUntil, pause, address(newChief));

        // create proposal to transfer ownership from the old chief to the guard
        address      usr = address(new SetAuthority());
        bytes memory fax = abi.encodeWithSignature("set(address,address)", pause, guard);
        uint         val = 0;

        Proposal proposal = new Proposal(pause, usr, fax, val);

        // check that the old chief is the authority
        assertEq(address(pause.authority()), address(oldChief));

        // vote for proposal
        voter.lock(oldChief, votes);
        voter.vote(oldChief, address(proposal));
        voter.lift(oldChief, address(proposal));

        // plan ownership transfer from old chief to guard
        uint era;
        (usr, fax, val, era) = proposal.plan();

        // wait until delay is passed
        hevm.warp(era);

        // execute ownership transfer from old chief to guard
        pause.exec(usr, fax, val, era);

        // check that the guard is the authority
        assertEq(address(pause.authority()), address(guard));

        // move MKR from old chief to new chief
        voter.free(oldChief, votes);
        voter.lock(newChief, votes);

        // wait until unlock period has passed
        hevm.warp(lockGuardUntil);

        // plan ownership transfer from guard to newChief
        (usr, fax, val, era) = guard.unlock();

        // wait until delay has passed
        hevm.warp(era);

        // execute ownership transfer from guard to newChief
        pause.exec(usr, fax, val, era);

        // check that the new chief is the authority
        assertEq(address(pause.authority()), address(newChief));
    }

}
