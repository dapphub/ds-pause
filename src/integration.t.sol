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

contract User {
    DSChief chief;
    DSToken gov;
    DSPause pause;

    constructor(DSChief chief_, DSToken gov_, DSPause pause_) public {
        chief = chief_;
        gov = gov_;
        pause = pause_;
    }

    function vote(address[] memory votes) public {
        chief.vote(votes);
    }

    function lift(address who) external {
        chief.lift(who);
    }

    function executeProposal(Proposal proposal) public returns (bytes32) {
        bytes memory response = proposal.execute();

        bytes32 id;
        assembly {
            id := mload(add(response, 32))
        }
        return id;
    }

    function executeAction(bytes32 id) external {
        pause.execute(id);
    }

    function lock(uint amount) public {
        gov.approve(address(chief));
        chief.lock(amount);
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

// ------------------------------------------------------------------
// Interfaces
// ------------------------------------------------------------------

contract AuthLike {
    function rely(address) public;
    function deny(address) public;
    function wards(address) public;
}

// ------------------------------------------------------------------
// Proxy Scripts
// ------------------------------------------------------------------

contract Scheduler {
    function schedule(DSPause pause, address guy, bytes memory data) public returns (bytes32) {
        return pause.schedule(guy, data);
    }
}

contract Ownership {
    function swap(AuthLike target, address rely, address deny) public {
        target.rely(rely);
        target.deny(deny);
    }
}

// ------------------------------------------------------------------
// Governance Proposal
// ------------------------------------------------------------------

contract Action {
    function execute(Target target) public {
        require(target.val() == 0);
        target.set(1);
        require(target.val() == 1);
    }
}

contract Proposal {
    bool done = false;

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

        Action action = new Action();

        bytes memory scheduleBytes = abi.encodeWithSignature(
            "schedule(address,address,bytes)",
            pause,
            address(action),
            abi.encodeWithSignature("execute(address)", target)
        );
        return proxy.execute(address(scheduler), scheduleBytes);
    }
}

// ------------------------------------------------------------------
// Test
// ------------------------------------------------------------------

contract Integration is DSTest {
    Hevm hevm;
    User user;

    DSChief chief;
    DSToken gov;
    DSToken iou;

    DSProxyFactory factory;
    DSProxyCache cache;
    DSProxy proxy;

    Scheduler scheduler;

    DSPause pause;
    Target target;

    uint256 initialBalance = 100;
    uint256 electionSize = 3;

    // timings
    uint256 start = 1;
    uint256 delay = 1;
    uint256 step = delay + 1;

    function setUp() public {
        // init hevm
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(start);

        // init gov token
        gov = new DSToken("GOV");
        gov.mint(initialBalance);

        // init chief and iou tokens
        DSChiefFab fab = new DSChiefFab();
        chief = fab.newChief(gov, electionSize);
        iou = chief.IOU();

        // init gov proxy and set chief as authority
        factory = new DSProxyFactory();
        cache = new DSProxyCache();
        proxy = new DSProxy(address(cache));
        proxy.setAuthority(chief);
        proxy.setOwner(address(0));

        // proxy script for changing pause ownership
        Ownership ownership = new Ownership();

        // init pause and set gov proxy as owner
        pause = new DSPause(delay);
        bytes32 id = pause.schedule(
            address(ownership),
            abi.encodeWithSignature(
                "swap(address,address,address)",
                address(pause),
                address(proxy),
                address(this)
            )
        );

        hevm.warp(now + step);
        pause.execute(id);

        // init user and give them some gov tokens
        user = new User(chief, gov, pause);
        gov.transfer(address(user), initialBalance);

        // init scheduler
        scheduler = new Scheduler();

        // init target and set pause as owner
        target = new Target();
        target.rely(address(pause));
        target.deny(address(this));

        // user locks voting tokens
        assertEq(gov.balanceOf(address(user)), initialBalance);
        user.lock(initialBalance);
    }

    function test_simple_proposal() public {
        // create proposal
        Proposal proposal = new Proposal(proxy, scheduler, pause, target);

        // make proposal the hat
        address[] memory votes = new address[](1);
        votes[0] = address(proposal);

        user.vote(votes);
        user.lift(address(proposal));

        assertEq(chief.hat(), address(proposal));

        // execute proposal
        bytes32 id = user.executeProposal(proposal);

        // execute action
        hevm.warp(now + step);
        assertEq(target.val(), 0);

        user.executeAction(id);

        assertEq(target.val(), 1);
    }
}
