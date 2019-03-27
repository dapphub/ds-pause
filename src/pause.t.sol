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
    Bytecode:
    ---
    0x5a GAS
    0x60 PUSH1
    0x02 2
    0x01 ADD
    0x60 PUSH1
    0x00 0
    0x52 MSTORE
    0x60 PUSH1
    0x20 32
    0x60 PUSH1
    0x00 0
    0xf3 RETURN

    Initcode:
    ---
    0x68 PUSH12
    0x5a
    0x60
    0x02
    0x01
    0x60
    0x00
    0x52
    0x60
    0x20
    0x60
    0x00
    0xf3
    0x60 PUSH1
    0x00 0
    0x52 MSTORE
    0x60 PUSH1
    0x20 32
    0x60 PUSH1
    0x14 20
    0xf3 RETURN
    */

    function build() public returns (address out) {
      assembly {
        mstore(mload(0x40), 0x685a60020160005260206000f360005260206014f3)
        out := create(0, add(11, mload(0x40)), 21)
      }
    }
}

contract Target {
    function text() public pure returns (bytes32) {
        return bytes32("Hello");
    }

    function val() public payable returns (uint) {
        return msg.value;
    }
}

contract Stranger {
    function plan(DSPause pause, address usr, bytes memory fax, uint val, uint gas, uint era)
        public
    {
        pause.plan(usr, fax, val, gas, era);
    }
    function drop(DSPause pause, address usr, bytes memory fax, uint val, uint gas, uint era)
        public
    {
        pause.drop(usr, fax, val, gas, era);
    }
    function exec(DSPause pause, address usr, bytes memory fax, uint val, uint gas, uint era)
        public payable
        returns (bytes memory)
    {
        return pause.exec.value(msg.value)(usr, fax, val, gas, era);
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
    address gasMeter;

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

    // returns the 1st 32 bytes of some dynamic data
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

    function test_delay() public {
        DSPause pause = new DSPause(100, address(0x0), new Authority());
        assertEq(pause.delay(), 100);
    }

    function test_owner() public {
        DSPause pause = new DSPause(100, address(0xdeadbeef), new Authority());
        assertEq(address(pause.owner()), address(0xdeadbeef));
    }

    function test_authority() public {
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
        uint         val = 0;
        uint         gas = 50000;
        uint         era = now + pause.delay();

        pause.plan(usr, fax, val, gas, era);
        hevm.warp(era);
        pause.exec(usr, fax, val, gas, era);

        assertEq(address(pause.owner()), address(0xdeadbeef));
    }

    function testFail_cannot_set_authority_without_delay() public {
        pause.setAuthority(new Authority());
    }

    function test_set_authority_with_delay() public {
        DSAuthority newAuthority = new Authority();

        address      usr = address(new SetAuthority());
        bytes memory fax = abi.encodeWithSignature("set(address,address)", pause, newAuthority);
        uint         val = 0;
        uint         gas = 50000;
        uint         era = now + pause.delay();

        pause.plan(usr, fax, val, gas, era);
        hevm.warp(era);
        pause.exec(usr, fax, val, gas, era);

        assertEq(address(pause.authority()), address(newAuthority));
    }
}

contract Plan is Test {

    function testFail_call_from_unauthorized() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         val = 0;
        uint         gas = 50000;
        uint         era = now + pause.delay();

        stranger.plan(pause, usr, fax, val, gas, era);
    }

    function testFail_era_too_soon() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         val = 0;
        uint         gas = 50000;
        uint         era = now + pause.delay() - 1;

        stranger.plan(pause, usr, fax, val, gas, era);
    }

    function test_plan() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         val = 0;
        uint         gas = 50000;
        uint         era = now + pause.delay();

        pause.plan(usr, fax, val, gas, era);

        bytes32 id = keccak256(abi.encode(usr, fax, val, gas, era));
        assertTrue(pause.plans(id));
    }

}

contract Exec is Test {

    function testFail_too_soon() public {
        address      usr = target;
        bytes memory fax = abi.encode(0);
        uint         val = 0;
        uint         gas = 50000;
        uint         era = now + pause.delay();

        pause.plan(usr, fax, val, gas, era);
        pause.exec(usr, fax, val, gas, era);
    }

    function testFail_unplanned() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         val = 0;
        uint         gas = 50000;
        uint         era = now + pause.delay();

        pause.exec(usr, fax, val, gas, era);
    }

    function testFail_double_execution() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         val = 0;
        uint         gas = 50000;
        uint         era = now + pause.delay();

        pause.plan(usr, fax, val, gas, era);
        hevm.warp(era);

        pause.exec(usr, fax, val, gas, era);
        pause.exec(usr, fax, val, gas, era);
    }

    function testFail_value_mismatch() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         val = 10 ether;
        uint         gas = 50000;
        uint         era = now + pause.delay();

        pause.plan(usr, fax, val, gas, era);
        hevm.warp(era);

        pause.exec.value(1 ether)(usr, fax, val, gas, era);
    }

    function test_gas_propogation() public {
        address      usr = gasMeter;
        bytes memory fax = "hi";
        uint         val = 0;
        uint         gas = 50000;
        uint         era = now + pause.delay();

        pause.plan(usr, fax, val, gas, era);
        hevm.warp(era);
        bytes memory out = stranger.exec(pause, usr, fax, val, gas, era);

        assertEq(num(out), gas);
    }

    function test_value_propogation() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("val()");
        uint         val = 1 ether;
        uint         gas = 50000;
        uint         era = now + pause.delay();

        pause.plan(usr, fax, val, gas, era);
        hevm.warp(era);
        bytes memory out = stranger.exec.value(val)(pause, usr, fax, val, gas, era);

        assertEq(num(out), val);
    }

}

contract Drop is Test {

    function testFail_call_from_unauthorized() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         val = 0;
        uint         gas = 50000;
        uint         era = now + pause.delay();

        pause.plan(usr, fax, val, gas, era);
        hevm.warp(era);

        stranger.drop(pause, usr, fax, val, gas, era);
    }

    function test_drop_planned_execution() public {
        address      usr = target;
        bytes memory fax = abi.encodeWithSignature("get()");
        uint         val = 0;
        uint         gas = 50000;
        uint         era = now + pause.delay();

        pause.plan(usr, fax, val, gas, era);

        hevm.warp(era);
        pause.drop(usr, fax, val, gas, era);

        bytes32 id = keccak256(abi.encode(usr, fax, val, gas, era));
        assertTrue(!pause.plans(id));
    }

}



