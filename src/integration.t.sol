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

interface Proposal {
    function execute() external returns (bytes memory);
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

    function executeProposal(Proposal proposal) public returns (bytes32) {
        bytes memory response = proposal.execute();

        bytes32 id;
        assembly {
            id := mload(add(response, 32))
        }
        return id;
    }

    function executeAction(DSPause pause, bytes32 id) external {
        pause.execute(id);
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

contract GovFactory {
    Hevm hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function create(DSToken gov, uint delay)
        public
        returns (DSProxy proxy, DSChief chief, DSPause pause)
    {
        // constants
        uint256 maxSlate = 1;

        // init chief and iou tokens
        DSChiefFab fab = new DSChiefFab();
        chief = fab.newChief(gov, maxSlate);

        // init gov proxy and set chief as authority
        DSProxyCache cache = new DSProxyCache();
        proxy = new DSProxy(address(cache));
        proxy.setAuthority(chief);
        proxy.setOwner(address(0));

        // create pause
        pause = new DSPause(delay);

        // schedule pause ownership change
        Ownership ownership = new Ownership();
        bytes32 id = pause.schedule(
            address(ownership),
            abi.encodeWithSignature(
                "swap(address,address,address)",
                address(pause),
                address(this),
                address(proxy)
            )
        );

        // execute pause ownership change
        hevm.warp(now + delay + 1);
        pause.execute(id);
    }
}

// ------------------------------------------------------------------
// Proxy Scripts
// ------------------------------------------------------------------

contract Ownership {
    function rely(DSPause pause, address who) public {
        pause.rely(who);
        require(pause.wards(who) == 1);
    }

    function deny(DSPause pause, address who) public {
        pause.deny(who);
        require(pause.wards(who) == 0);
    }

    function swap(DSPause pause, address prev, address next) public {
        rely(pause, next);
        deny(pause, prev);
    }
}

contract Scheduler {
    function schedule(DSPause pause, address guy, bytes memory data) public returns (bytes32) {
        return pause.schedule(guy, data);
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

    // proxy scripts
    Scheduler scheduler;
    Ownership ownership;

    // pause timings
    uint256 start = 0;
    uint256 delay = 1;
    uint256 step = delay + 1;

    // gov constants
    uint initialBalance = 100;

    // gov system
    DSToken gov;
    DSProxy proxy;
    DSChief chief;
    DSPause pause;

    function setUp() public {
        // init hevm
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(start);

        // create test harness
        govFactory = new GovFactory();
        target = new Target();
        user = new User();

        // create proxy scripts
        ownership = new Ownership();
        scheduler = new Scheduler();

        // create gov token
        gov = new DSToken("GOV");
        gov.mint(address(user), initialBalance);
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

contract SimpleProposal is Proposal {
    bool done = false;
    SimpleAction action = new SimpleAction();

    DSProxy proxy;
    Scheduler scheduler;
    DSPause pause;
    Target target;

    constructor(DSProxy proxy_, Scheduler scheduler_, DSPause pause_, Target target_) public {
        proxy = proxy_;
        scheduler = scheduler_;
        pause = pause_;
        target = target_;
    }

    function execute() public returns (bytes memory) {
        require(!done);
        done = true;

        bytes memory scheduleBytes = abi.encodeWithSignature(
            "schedule(address,address,bytes)",
            pause,
            address(action),
            abi.encodeWithSignature("execute(address)", target)
        );
        return proxy.execute(address(scheduler), scheduleBytes);
    }
}

contract Voting is Test {

    function test_simple_proposal() public {
        // create gov system
        (proxy, chief, pause) = govFactory.create(gov, delay);
        user.lock(chief, initialBalance);
        target.rely(address(pause));
        target.deny(address(this));

        // create proposal
        SimpleProposal proposal = new SimpleProposal(proxy, scheduler, pause, target);

        // make proposal the hat
        user.vote(chief, address(proposal));
        user.lift(chief, address(proposal));

        // execute proposal (schedule action)
        bytes32 id = user.executeProposal(proposal);

        // wait until delay is passed
        hevm.warp(now + step);

        // execute action
        assertEq(target.val(), 0);
        user.executeAction(pause, id);
        assertEq(target.val(), 1);
    }

}

// ------------------------------------------------------------------
// Test Chief Upgrades
// ------------------------------------------------------------------

contract AddGuardProposal is Proposal {
    bool done = false;

    Scheduler scheduler;
    Guard guard;
    DSPause pause;
    DSProxy oldChiefProxy;

    constructor(Scheduler scheduler_, DSPause pause_, DSProxy oldChiefProxy_, Guard guard_) public {
        scheduler = scheduler_;
        guard = guard_;
        pause = pause_;
        oldChiefProxy = oldChiefProxy_;
    }

    function execute() public returns (bytes memory) {
        require(!done);
        done = true;

        Ownership ownership = new Ownership();
        bytes memory scheduleBytes = abi.encodeWithSignature(
            "schedule(address,address,bytes)",
            pause,
            address(ownership),
            abi.encodeWithSignature(
                "swap(address,address,address)",
                pause, oldChiefProxy, guard
            )
        );
        return oldChiefProxy.execute(address(scheduler), scheduleBytes);
    }
}

contract Guard {
    DSPause pause;
    address newOwner;

    Ownership ownership;
    uint lockUntil;

    constructor(uint delay, DSPause pause_, address newOwner_) public {
        lockUntil = now + delay;

        pause = pause_;
        newOwner = newOwner_;
        ownership = new Ownership();
    }

    function unlock() public returns (bytes32) {
        require(now > lockUntil);

        return pause.schedule(
            address(ownership),
            abi.encodeWithSignature(
                "swap(address,address,address)",
                pause, this, newOwner
            )
        );
    }
}

contract UpgradeChief is Test {

    function test_chief_upgrade() public {
        // create old gov system
        (DSProxy oldProxy, DSChief oldChief, DSPause pause) = govFactory.create(gov, delay);
        user.lock(oldChief, initialBalance);

        // target is owned by pause
        target.rely(address(pause));
        target.deny(address(this));

        // create new gov system
        (DSProxy newProxy, DSChief newChief, DSPause _) = govFactory.create(gov, delay);
        _; // silence compiler warning

        // add guard proposal
        Guard guard = new Guard(delay * 2, pause, address(newProxy));
        AddGuardProposal proposal = new AddGuardProposal(scheduler, pause, oldProxy, guard);

        // vote for proposal
        user.vote(oldChief, address(proposal));
        user.lift(oldChief, address(proposal));

        // schedule proposal
        bytes32 id = user.executeProposal(proposal);

        // wait until delay is passed
        hevm.warp(now + step);

        // set guard as owner
        pause.execute(id);

        // check that the guard is the owner
        assertEq(pause.wards(address(oldProxy)), 0);
        assertEq(pause.wards(address(newProxy)), 0);
        assertEq(pause.wards(address(guard)), 1);

        // move MKR from old chief to new chief
        user.free(oldChief, initialBalance);
        user.lock(newChief, initialBalance);

        // wait until unlock period has passed
        hevm.warp(now + step);

        // schedule ownership transfer from guard to newChief
        id = guard.unlock();

        // wait until delay has passed
        hevm.warp(now + step);

        // schedule ownership transfer from guard to newChief
        pause.execute(id);

        // check that the new chief is the owner
        assertEq(pause.wards(address(oldProxy)), 0);
        assertEq(pause.wards(address(guard)), 0);
        assertEq(pause.wards(address(newProxy)), 1);
    }

}
