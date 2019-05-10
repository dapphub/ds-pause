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

import "./pause.sol";

// ------------------------------------------------------------------
// Test Harness
// ------------------------------------------------------------------

contract Hevm {
    function warp(uint) public;
}

contract GasMeterFactory {
    /*
    A GasMeter is a contract that returns the exact value of the gas provided
    in any call to it. It must be writtten in bytecode directly as the solidity
    function dispatch code already consumes gas, so any solidity implementation
    will always return an incorrect result.

    Bytecode:
    ---
    0x5a  0x60   0x02  0x01  0x60   0x00  0x52    0x60   0x20  0x60   0x00  0xf3
    GAS   PUSH1  2     ADD   PUSH1  0     MSTORE  PUSH1  32    PUSH1  0     RETURN

    Initcode:
    ---
    0x6b    0x5a  0x60  0x02  0x01  0x60  0x00  0x52  0x60  0x20  0x60  0x20  0x60  0x00  0xf3
    PUSH12

    0x60   0x00  0x52    0x60   0x20  0x60   0x14  0xf3
    PUSH1  0     MSTORE  PUSH1  32    PUSH1  20    RETURN
    */

    function build() public returns (address out) {
      assembly {
        mstore(mload(0x40), 0x6b5a60020160005260206000f360005260206014f3)
        out := create(0, add(11, mload(0x40)), 21)
      }
    }
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
    function plot(DSPause pause, address usr, bytes memory fax, uint gas, uint eta)
        public
    {
        pause.plot(usr, fax, gas, eta);
    }
    function drop(DSPause pause, address usr, bytes memory fax, uint gas, uint eta)
        public
    {
        pause.drop(usr, fax, gas, eta);
    }
    function exec(DSPause pause, address usr, bytes memory fax, uint gas, uint eta)
        public
        returns (bytes memory)
    {
        return pause.exec(usr, fax, gas, eta);
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
    address gasMeter;
    address target;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(0);

        target = address(new Target());
        stranger = new Stranger();

        GasMeterFactory gasMeterFactory = new GasMeterFactory();
        gasMeter = gasMeterFactory.build();

        uint delay = 1 days;
        pause = new DSPause(delay, address(0x0), new Authority());
    }

    // returns the 1st word of some dynamic data
    function b32(bytes memory data) public pure returns (bytes32 out) {
        assembly {
            out := mload(add(data, 32))
        }
    }

    // parses the 1st word of some dynamic data as a uint
    function num(bytes memory data) public pure returns (uint out) {
        assembly {
            out := mload(add(data, 32))
        }
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

contract SetAuthority {
    function set(DSAuth usr, DSAuthority authority) public {
        usr.setAuthority(authority);
    }
}

contract SetOwner {
    function set(DSAuth usr, address owner) public {
        usr.setOwner(owner);
    }
}

contract Auth is Test {

    function testFail_cannot_set_owner_without_delay() public {
        pause.setOwner(address(this));
    }

    function test_set_owner_with_delay() public {
        address      usr = address(new SetOwner());
        bytes memory fax = abi.encodeWithSignature("set(address,address)", pause, 0xdeadbeef);
        uint         gas = 50000;
        uint         eta = now + pause.delay();

        pause.plot(usr, fax, gas, eta);
        hevm.warp(eta);
        pause.exec(usr, fax, gas, eta);

        assertEq(address(pause.owner()), address(0xdeadbeef));
    }

    function testFail_cannot_set_authority_without_delay() public {
        pause.setAuthority(new Authority());
    }

    function test_set_authority_with_delay() public {
        DSAuthority newAuthority = new Authority();

        address      usr = address(new SetAuthority());
        bytes memory fax = abi.encodeWithSignature("set(address,address)", pause, newAuthority);
        uint         gas = 50000;
        uint         eta = now + pause.delay();

        pause.plot(usr, fax, gas, eta);
        hevm.warp(eta);
        pause.exec(usr, fax, gas, eta);

        assertEq(address(pause.authority()), address(newAuthority));
    }
}

contract Plot is Test {

    function testFail_call_from_unauthorized() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         gas = 50000;
        uint         eta = now + pause.delay();

        stranger.plot(pause, usr, fax, gas, eta);
    }

    function testFail_plot_eta_too_soon() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         gas = 50000;
        uint         eta = now;

        pause.plot(usr, fax, gas, eta);
    }

    function test_plot_populates_plans_mapping() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         gas = 50000;
        uint         eta = now + pause.delay();

        pause.plot(usr, fax, gas, eta);

        bytes32 id = keccak256(abi.encode(usr, fax, gas, eta));
        assertTrue(pause.plans(id));
    }

}

contract Exec is Test {

    function testFail_delay_not_passed() public {
        address      usr = target;
        bytes memory fax = abi.encode(0);
        uint         gas = 50000;
        uint         eta = now + pause.delay();

        pause.plot(usr, fax, gas, eta);
        pause.exec(usr, fax, gas, eta);
    }

    function testFail_double_execution() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         gas = 50000;
        uint         eta = now + pause.delay();

        pause.plot(usr, fax, gas, eta);
        hevm.warp(eta);
        pause.exec(usr, fax, gas, eta);
        pause.exec(usr, fax, gas, eta);
    }

    function testFail_exec_plan_with_proxy_ownership_change() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("give(address)", address(this));
        uint         gas = 50000;
        uint         eta = now + pause.delay();

        pause.plot(usr, fax, gas, eta);
        hevm.warp(eta);
        pause.exec(usr, fax, gas, eta);
    }

    function testFail_exec_plan_with_non_existent_usr() public {
        address      usr = address(0xdeadbeef);
        bytes memory fax = abi.encodeWithSignature("");
        uint         gas = 50000;
        uint         eta = now + pause.delay();

        pause.plot(usr, fax, gas, eta);
        hevm.warp(eta);
        pause.exec(usr, fax, gas, eta);
    }

    function testFail_insufficient_gas() public {
        address      usr = gasMeter;
        bytes memory fax = abi.encodeWithSignature("");
        uint         gas = 50000;
        uint         eta = now + pause.delay();

        pause.plot(usr, fax, gas, eta);
        hevm.warp(eta);
        pause.exec.gas(gas)(usr, fax, gas, eta);
    }

    function test_gas_propogation() public {
        address      usr = gasMeter;
        bytes memory fax = abi.encodeWithSignature("");
        uint         gas = 50000;
        uint         eta = now + pause.delay();

        pause.plot(usr, fax, gas, eta);
        hevm.warp(eta);
        bytes memory out = pause.exec(usr, fax, gas, eta);

        assertEq(num(out), gas);
    }

    function test_successful_exec_from_authorized() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         gas = 50000;
        uint         eta = now + pause.delay();

        pause.plot(usr, fax, gas, eta);
        hevm.warp(eta);
        bytes memory out = pause.exec(usr, fax, gas, eta);

        assertEq(b32(out), bytes32("Hello"));
    }

    function test_successful_exec_from_unauthorized() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         gas = 50000;
        uint         eta = now + pause.delay();

        pause.plot(usr, fax, gas, eta);
        hevm.warp(eta);

        bytes memory out = stranger.exec(pause, usr, fax, gas, eta);
        assertEq(b32(out), bytes32("Hello"));
    }

}

contract Drop is Test {

    function testFail_call_from_unauthorized() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         gas = 50000;
        uint         eta = now + pause.delay();

        pause.plot(usr, fax, gas, eta);
        hevm.warp(eta);

        stranger.drop(pause, usr, fax, gas, eta);
    }

    function test_drop_plotted_plan() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         gas = 50000;
        uint         eta = now + pause.delay();

        pause.plot(usr, fax, gas, eta);

        hevm.warp(eta);
        pause.drop(usr, fax, gas, eta);

        bytes32 id = keccak256(abi.encode(usr, fax, gas, eta));
        assertTrue(!pause.plans(id));
    }

}
