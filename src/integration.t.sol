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
import "ds-spell/spell.sol";
import "ds-token/token.sol";
import "ds-proxy/proxy.sol";

import "./pause.sol";

// ------------------------------------------------------------------
// Test Harness
// ------------------------------------------------------------------

contract Hevm {
    function warp(uint256) public;
}

contract ProposalLike {
    function execute() public returns (bytes memory);
}

contract User {
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
    mapping (address => uint256) public wards;
    function rely(address guy) public auth { wards[guy] = 1; }
    function deny(address guy) public auth { wards[guy] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    constructor() public {
        wards[msg.sender] = 1;
    }

    uint256 public val = 0;
    function set(uint256 val_) public auth {
        val = val_;
    }
}

// Proxy script for changing ownership
contract AuthLike {
    function rely(address) public;
    function deny(address) public;
}

contract OwnershipActions {
    function rely(address auth, address guy) public {
        AuthLike(auth).rely(guy);
    }

    function deny(address auth, address guy) public {
        AuthLike(auth).deny(guy);
    }

    function swap(address auth, address prev, address next) public {
        rely(auth, next);
        deny(auth, prev);
    }
}

contract GovFactory {
    Hevm hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function create(DSToken gov, uint delay) public returns (DSChief, Scheduler, DSPause)
    {
        // constants
        uint256 maxSlateSize = 1;
        uint256 step = delay + 1;

        // init chief and iou tokens
        DSChiefFab fab = new DSChiefFab();
        DSChief chief = fab.newChief(gov, maxSlateSize);

        // create pause
        DSPause pause = new DSPause(delay);

        // create scheduler
        Scheduler scheduler = new Scheduler(pause);
        scheduler.setAuthority(chief);
        scheduler.setOwner(address(0x0));

        // create proxy scripts
        OwnershipActions ownershipActions = new OwnershipActions();

        // add scheduler as an owner
        bytes memory callData = abi.encodeWithSignature("rely(address,address)", pause, scheduler);
        bytes32 id = pause.schedule(address(ownershipActions), callData);

        hevm.warp(now + step);
        pause.execute(id);

        // remove govFactory as an owner
        callData = abi.encodeWithSignature("deny(address,address)", pause, this);
        id = pause.schedule(address(ownershipActions), callData);

        hevm.warp(now + step);
        pause.execute(id);

        return (chief, scheduler, pause);
    }
}

// ------------------------------------------------------------------
// Shared Test Setup
// ------------------------------------------------------------------

contract Test is DSTest {
    // test harness
    Hevm hevm;
    GovFactory govFactory;
    Target target;
    User user;

    // pause timings
    uint256 start = 0;
    uint256 delay = 1 days;
    uint256 step = delay + 1;

    // gov constants
    uint votes = 100;

    // gov system
    DSToken gov;

    function setUp() public {
        // init hevm
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(start);

        // create test harness
        govFactory = new GovFactory();
        target = new Target();
        user = new User();

        // create gov token
        gov = new DSToken("GOV");
        gov.mint(address(user), votes);
        gov.setOwner(address(0));
    }
}

// ------------------------------------------------------------------
// Test Simple Voting
// ------------------------------------------------------------------

contract SimpleAction {
    function execute(Target target) public {
        target.set(1);
    }
}

contract SimpleProposal {
    bool done = false;
    SimpleAction action = new SimpleAction();

    Scheduler scheduler;
    Target target;

    constructor(Scheduler scheduler_, Target target_) public {
        scheduler = scheduler_;
        target = target_;
    }

    function execute() public returns (bytes32) {
        require(!done);
        done = true;

        bytes memory callData = abi.encodeWithSignature("execute(address)", target);
        return scheduler.schedule(address(action), callData);
    }
}

contract Voting is Test {

    function test_simple_proposal() public {
        // create gov system
        (DSChief chief, Scheduler scheduler, DSPause pause) = govFactory.create(gov, delay);
        target.rely(address(pause));
        target.deny(address(this));

        // create proposal
        SimpleProposal proposal = new SimpleProposal(scheduler, target);

        // make proposal the hat
        user.lock(chief, votes);
        user.vote(chief, address(proposal));
        user.lift(chief, address(proposal));

        // execute proposal (schedule action)
        bytes32 id = proposal.execute();

        // wait until delay is passed
        hevm.warp(now + step);

        // execute action
        assertEq(target.val(), 0);
        pause.execute(id);
        assertEq(target.val(), 1);
    }

}

// ------------------------------------------------------------------
// Test Chief Upgrades
// ------------------------------------------------------------------

contract Guard {
    uint lockUntil;
    address newOwner;
    DSPause pause;

    constructor(uint lockUntil_, DSPause pause_, address newOwner_) public {
        lockUntil = lockUntil_;
        newOwner = newOwner_;
        pause = pause_;
    }

    function unlock() public returns (bytes32) {
        require(now >= lockUntil);

        OwnershipActions ownershipActions = new OwnershipActions();
        return pause.schedule(
            address(ownershipActions),
            abi.encodeWithSignature(
                "swap(address,address,address)",
                pause, this, newOwner
            )
        );
    }
}

contract AddGuardProposal {
    bool done = false;

    DSPause pause;
    Scheduler scheduler;
    Guard guard;

    constructor(DSPause pause_, Scheduler scheduler_, Guard guard_) public {
        pause = pause_;
        scheduler = scheduler_;
        guard = guard_;
    }

    function execute() public returns (bytes32) {
        require(!done);
        done = true;

        OwnershipActions ownershipActions = new OwnershipActions();
        return scheduler.schedule(
            address(ownershipActions),
            abi.encodeWithSignature(
                "swap(address,address,address)",
                pause, scheduler, guard
            )
        );
    }
}

contract UpgradeChief is Test {

    function test_chief_upgrade() public {
        // create old gov system
        (DSChief oldChief, Scheduler oldScheduler, DSPause pause) = govFactory.create(gov, delay);

        // target is owned by pause
        target.rely(address(pause));
        target.deny(address(this));

        // create new gov system
        (DSChief newChief, Scheduler newScheduler, ) = govFactory.create(gov, delay);

        // create guard
        uint lockGuardUntil = now + 1000;
        Guard guard = new Guard(lockGuardUntil, pause, address(newScheduler));

        // create gov proposal to transfer ownership from oldScheduler to guard
        AddGuardProposal proposal = new AddGuardProposal(pause, oldScheduler, guard);

        // check that the oldScheduler is the owner
        assertEq(pause.wards(address(oldScheduler)), 1);
        assertEq(pause.wards(address(guard)), 0);
        assertEq(pause.wards(address(newScheduler)), 0);

        // vote for proposal
        user.lock(oldChief, votes);
        user.vote(oldChief, address(proposal));
        user.lift(oldChief, address(proposal));

        // schedule ownership transfer from oldScheduler to guard
        bytes32 id = proposal.execute();

        // wait until delay is passed
        hevm.warp(now + step);

        // execute ownership transfer from oldScheduler to guard
        pause.execute(id);

        // check that the guard is the owner
        assertEq(pause.wards(address(oldScheduler)), 0);
        assertEq(pause.wards(address(guard)), 1);
        assertEq(pause.wards(address(newScheduler)), 0);

        // move MKR from old chief to new chief
        user.free(oldChief, votes);
        user.lock(newChief, votes);

        // wait until unlock period has passed
        hevm.warp(lockGuardUntil);

        // schedule ownership transfer from guard to newChief
        id = guard.unlock();

        // wait until delay has passed
        hevm.warp(now + step);

        // execute ownership transfer from guard to newChief
        pause.execute(id);

        // check that the new chief is the owner
        assertEq(pause.wards(address(oldScheduler)), 0);
        assertEq(pause.wards(address(guard)), 0);
        assertEq(pause.wards(address(newScheduler)), 1);
    }

}
