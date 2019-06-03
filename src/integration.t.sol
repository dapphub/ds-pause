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

import {DSTest} from "ds-test/test.sol";
import {DSToken} from "ds-token/token.sol";
import {DSProxy} from "ds-proxy/proxy.sol";
import {DSChief, DSChiefFab} from "ds-chief/chief.sol";

import "./pause.sol";

// ------------------------------------------------------------------
// Test Harness
// ------------------------------------------------------------------

contract Hevm {
    function warp(uint) public;
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
    bool public plotted  = false;

    DSPause public pause;
    address public usr;
    bytes32 public tag;
    bytes   public fax;
    uint    public eta;

    constructor(DSPause pause_, address usr_, bytes32 tag_, bytes memory fax_) public {
        pause = pause_;
        tag = tag_;
        usr = usr_;
        fax = fax_;
        eta = 0;
    }

    function plot() external {
        require(!plotted);
        plotted = true;

        eta = now + pause.delay();
        pause.plot(usr, tag, fax, eta);
    }

    function exec() external returns (bytes memory) {
        require(plotted);
        return pause.exec(usr, tag, fax, eta);
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
    uint delay = 1 days;

    // gov constants
    uint votes = 100;
    uint maxSlateSize = 1;

    // gov token
    DSToken gov;

    function setUp() public {
        // init hevm
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(0);

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

    function extcodehash(address usr) internal view returns (bytes32 tag) {
        assembly { tag := extcodehash(usr) }
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
        target.rely(address(pause.proxy()));
        target.deny(address(this));

        // create proposal
        address      usr = address(new SimpleAction());
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("exec(address)", target);

        Proposal proposal = new Proposal(pause, usr, tag, fax);

        // make proposal the hat
        voter.lock(chief, votes);
        voter.vote(chief, address(proposal));
        voter.lift(chief, address(proposal));

        // schedule proposal
        proposal.plot();

        // wait until eta
        hevm.warp(proposal.eta());

        // execute proposal
        assertEq(target.val(), 0);
        proposal.exec();
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

// Temporary DSAuthority that will give a DSChief authority over a pause only
// when a prespecified amount of MKR has been locked in the new chief
contract Guard is DSAuthority {
    // --- data ---
    DSPause public pause;
    DSChief public scion; // new chief
    uint    public limit; // min locked MKR in new chief

    bool public thawed = false;

    address public usr;
    bytes32 public tag;
    bytes   public fax;
    uint    public eta;

    // --- init ---

    constructor(DSPause pause_, DSChief scion_, uint limit_) public {
        pause = pause_;
        scion = scion_;
        limit = limit_;

        usr = address(new SetAuthority());
        tag = extcodehash(usr);
        fax = abi.encodeWithSignature( "set(address,address)", pause, scion);
    }

    // --- auth ---

    function canCall(address src, address dst, bytes4 sig) public view returns (bool) {
        require(src == address(this));
        require(dst == address(pause));
        require(sig == bytes4(keccak256("plot(address,bytes32,bytes,uint256)")));
        return true;
    }

    // --- unlock ---

    function thaw() external {
        require(scion.GOV().balanceOf(address(scion)) >= limit);
        require(!thawed);
        thawed = true;

        eta = now + pause.delay();
        pause.plot(usr, tag, fax, eta);
    }

    function free() external returns (bytes memory) {
        require(thawed);
        return pause.exec(usr, tag, fax, eta);
    }

    // --- util ---

    function extcodehash(address who) internal view returns (bytes32 soul) {
        assembly { soul := extcodehash(who) }
    }
}


contract UpgradeChief is Test {

    function test_chief_upgrade() public {
        // create gov system
        DSChief oldChief = chiefFab.newChief(gov, maxSlateSize);
        DSPause pause = new DSPause(delay, address(0x0), oldChief);

        // make pause the only owner of the target
        target.rely(address(pause.proxy()));
        target.deny(address(this));

        // create new chief
        DSChief newChief = chiefFab.newChief(gov, maxSlateSize);

        // create guard
        Guard guard = new Guard(pause, newChief, votes);

        // create gov proposal to transfer ownership from the old chief to the guard
        address      usr = address(new SetAuthority());
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("set(address,address)", pause, guard);

        Proposal proposal = new Proposal(pause, usr, tag, fax);

        // check that the old chief is the authority
        assertEq(address(pause.authority()), address(oldChief));

        // vote for proposal
        voter.lock(oldChief, votes);
        voter.vote(oldChief, address(proposal));
        voter.lift(oldChief, address(proposal));

        // transfer ownership from old chief to guard
        proposal.plot();
        hevm.warp(proposal.eta());
        proposal.exec();

        // check that the guard is the authority
        assertEq(address(pause.authority()), address(guard));

        // move MKR from old chief to new chief
        voter.free(oldChief, votes);
        voter.lock(newChief, votes);

        // plot plan to transfer ownership from guard to newChief
        guard.thaw();
        hevm.warp(guard.eta());
        guard.free();

        // check that the new chief is the authority
        assertEq(address(pause.authority()), address(newChief));
    }

}
