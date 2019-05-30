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
import {DSAuth, DSAuthority} from "ds-auth/auth.sol";

import {DSPause} from "./pause.sol";

// ------------------------------------------------------------------
// Test Harness
// ------------------------------------------------------------------

contract Hevm {
    function warp(uint) public;
}

contract Target {
    address owner;
    function give(address usr) public {
        owner = usr;
    }

    function get() public pure returns (bytes32) {
        return bytes32("Hello");
    }
}

contract Stranger {
    function plot(DSPause pause, address usr, bytes32 tag, bytes memory fax, uint eta) public {
        pause.plot(usr, tag, fax, eta);
    }
    function drop(DSPause pause, address usr, bytes32 tag, bytes memory fax, uint eta) public {
        pause.drop(usr, tag, fax, eta);
    }
    function exec(DSPause pause, address usr, bytes32 tag, bytes memory fax, uint eta)
        public returns (bytes memory)
    {
        return pause.exec(usr, tag, fax, eta);
    }
}

contract Authority is DSAuthority {
    address owner;

    constructor() public {
        owner = msg.sender;
    }

    function canCall(address src, address, bytes4)
        public
        view
        returns (bool)
    {
        require(src == owner);
        return true;
    }
}

// ------------------------------------------------------------------
// Common Setup & Test Utils
// ------------------------------------------------------------------

contract Test is DSTest {
    Hevm hevm;
    DSPause pause;
    Stranger stranger;
    address target;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(0);

        target = address(new Target());
        stranger = new Stranger();

        uint delay = 1 days;
        pause = new DSPause(delay, address(0x0), new Authority());


    }

    // returns the 1st 32 bytes of data from a bytes array
    function b32(bytes memory data) public pure returns (bytes32 data32) {
        assembly {
            data32 := mload(add(data, 32))
        }
    }

    function extcodehash(address usr) internal view returns (bytes32 tag) {
        assembly { tag := extcodehash(usr) }
    }
}

// ------------------------------------------------------------------
// Proxy Scripts
// ------------------------------------------------------------------

contract AdminScripts {
    function setDelay(DSPause pause, uint delay) public {
        pause.setDelay(delay);
    }
    function setOwner(DSPause pause, address owner) public {
        pause.setOwner(owner);
    }
    function setAuthority(DSPause pause, DSAuthority authority) public {
        pause.setAuthority(authority);
    }
}

// ------------------------------------------------------------------
// Tests
// ------------------------------------------------------------------

contract Constructor is DSTest {

    function test_delay_set() public {
        DSPause pause = new DSPause(100, address(0x0), new Authority());
        assertEq(pause.delay(), 100);
    }

    function test_owner_set() public {
        DSPause pause = new DSPause(100, address(0xdeadbeef), new Authority());
        assertEq(address(pause.owner()), address(0xdeadbeef));
    }

    function test_authority_set() public {
        Authority authority = new Authority();
        DSPause pause = new DSPause(100, address(0x0), authority);
        assertEq(address(pause.authority()), address(authority));
    }

}

contract Admin is Test {

    // --- owner ---

    function testFail_cannot_set_owner_without_delay() public {
        pause.setOwner(address(this));
    }

    function test_set_owner_with_delay() public {
        address      usr = address(new AdminScripts());
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("setOwner(address,address)", pause, 0xdeadbeef);
        uint         eta = now + pause.delay();

        pause.plot(usr, tag, fax, eta);
        hevm.warp(eta);
        pause.exec(usr, tag, fax, eta);

        assertEq(address(pause.owner()), address(0xdeadbeef));
    }

    // --- authority ---

    function testFail_cannot_set_authority_without_delay() public {
        pause.setAuthority(new Authority());
    }

    function test_set_authority_with_delay() public {
        DSAuthority newAuthority = new Authority();

        address      usr = address(new AdminScripts());
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("setAuthority(address,address)", pause, newAuthority);
        uint         eta = now + pause.delay();

        pause.plot(usr, tag, fax, eta);
        hevm.warp(eta);
        pause.exec(usr, tag, fax, eta);

        assertEq(address(pause.authority()), address(newAuthority));
    }

    // --- delay ---

    function testFail_cannot_set_delay_without_delay() public {
        pause.setDelay(0);
    }

    function test_set_delay_with_delay() public {
        address      usr = address(new AdminScripts());
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("setDelay(address,uint256)", pause, 0);
        uint         eta = now + pause.delay();

        pause.plot(usr, tag, fax, eta);
        hevm.warp(eta);
        pause.exec(usr, tag, fax, eta);

        assertEq(pause.delay(), 0);
    }
}

contract Plot is Test {

    function testFail_call_from_unauthorized() public {
        address      usr = target;
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         eta = now + pause.delay();

        stranger.plot(pause, usr, tag, fax, eta);
    }

    function testFail_plot_eta_too_soon() public {
        address      usr = target;
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         eta = now;

        pause.plot(usr, tag, fax, eta);
    }

    function test_plot_populates_plans_mapping() public {
        address      usr = target;
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         eta = now + pause.delay();

        pause.plot(usr, tag, fax, eta);

        bytes32 id = keccak256(abi.encode(usr, tag, fax, eta));
        assertTrue(pause.plans(id));
    }

}

contract Exec is Test {

    function testFail_delay_not_passed() public {
        address      usr = target;
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encode(0);
        uint         eta = now + pause.delay();

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function testFail_double_execution() public {
        address      usr = target;
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         eta = now + pause.delay();

        pause.plot(usr, tag, fax, eta);
        hevm.warp(eta);
        pause.exec(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function testFail_tag_mismatch() public {
        address      usr = target;
        bytes32      tag = bytes32("INCORRECT_CODEHASH");
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         eta = now + pause.delay();

        pause.plot(usr, tag, fax, eta);
        hevm.warp(eta);
        pause.exec(usr, tag, fax, eta);
    }

    function testFail_exec_plan_with_proxy_ownership_change() public {
        address      usr = target;
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("give(address)", address(this));
        uint         eta = now + pause.delay();

        pause.plot(usr, tag, fax, eta);
        hevm.warp(eta);
        pause.exec(usr, tag, fax, eta);
    }

    function test_suceeds_when_delay_passed() public {
        address      usr = target;
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         eta = now + pause.delay();

        pause.plot(usr, tag, fax, eta);
        hevm.warp(eta);
        bytes memory out = pause.exec(usr, tag, fax, eta);

        assertEq(b32(out), bytes32("Hello"));
    }

    function test_suceeds_when_called_from_unauthorized() public {
        address      usr = target;
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         eta = now + pause.delay();

        pause.plot(usr, tag, fax, eta);
        hevm.warp(eta);

        bytes memory out = stranger.exec(pause, usr, tag, fax, eta);
        assertEq(b32(out), bytes32("Hello"));
    }

    function test_suceeds_when_called_from_authorized() public {
        address      usr = target;
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         eta = now + pause.delay();

        pause.plot(usr, tag, fax, eta);
        hevm.warp(eta);

        bytes memory out = pause.exec(usr, tag, fax, eta);
        assertEq(b32(out), bytes32("Hello"));
    }

}

contract Drop is Test {

    function testFail_call_from_unauthorized() public {
        address      usr = target;
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         eta = now + pause.delay();

        pause.plot(usr, tag, fax, eta);
        hevm.warp(eta);

        stranger.drop(pause, usr, tag, fax, eta);
    }

    function test_drop_plotted_plan() public {
        address      usr = target;
        bytes32      tag = extcodehash(usr);
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         eta = now + pause.delay();

        pause.plot(usr, tag, fax, eta);

        hevm.warp(eta);
        pause.drop(usr, tag, fax, eta);

        bytes32 id = keccak256(abi.encode(usr, tag, fax, eta));
        assertTrue(!pause.plans(id));
    }

}
