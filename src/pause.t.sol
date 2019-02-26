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
    function warp(uint256) public;
}

contract Target {
    function getBytes32() public pure returns (bytes32) {
        return bytes32("Hello");
    }
}

contract Stranger {
    function call(address target, bytes memory data) public returns (bytes memory) {
        (bool success, bytes memory result) = target.call(data);

        require(success);
        return result;
    }
}

contract AuthLike {
    function rely(address) public;
    function deny(address) public;
    function wards(address) public returns (uint);
}

contract Ownership {
    function rely(AuthLike target, address who) public {
        target.rely(who);
        require(target.wards(who) == 1);
    }

    function deny(AuthLike target, address who) public {
        target.deny(who);
        require(target.wards(who) == 0);
    }
}

// ------------------------------------------------------------------
// Common Setup
// ------------------------------------------------------------------

contract Test is DSTest {
    DSPause pause;
    Target target;
    Hevm hevm;
    Stranger stranger;
    Ownership ownership;

    uint256 start = 1;
    uint256 delay = 1;
    uint256 step = delay + 1;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(start);

        target = new Target();
        pause = new DSPause(delay);
        stranger = new Stranger();
        ownership = new Ownership();
    }
}

// ------------------------------------------------------------------
// Tests
// ------------------------------------------------------------------

contract Constructor is DSTest {

    function test_delay_set() public {
        DSPause pause = new DSPause(100);
        assertEq(pause.delay(), 100);
    }

    function test_creator_is_owner() public {
        DSPause pause = new DSPause(100);
        assertEq(pause.wards(address(this)), 1);
    }

}

contract Auth is Test {

    function testFail_call_rely_from_non_owner() public {
        bytes memory data = abi.encodeWithSignature("rely(address)", address(stranger));
        stranger.call(address(pause), data);
    }

    function testFail_call_rely_from_owner() public {
        pause.rely(address(this));
    }

    function testFail_call_deny_from_non_owner() public {
        bytes memory data = abi.encodeWithSignature("deny(address)", address(stranger));
        stranger.call(address(pause), data);
    }

    function testFail_call_deny_from_owner() public {
        pause.deny(address(this));
    }

    function test_rely() public {
        assertEq(pause.wards(address(stranger)), 0);

        bytes32 id = pause.schedule(
            address(ownership),
            abi.encodeWithSignature(
                "rely(address,address)",
                address(pause),
                address(stranger)
            )
        );
        hevm.warp(now + step);
        pause.execute(id);

        assertEq(pause.wards(address(stranger)), 1);
    }

    function test_deny() public {
        assertEq(pause.wards(address(this)), 1);

        bytes32 id = pause.schedule(
            address(ownership),
            abi.encodeWithSignature(
                "deny(address,address)",
                address(pause),
                address(this)
            )
        );
        hevm.warp(now + step);
        pause.execute(id);

        assertEq(pause.wards(address(this)), 0);
    }

    function test_call_wards_from_non_owner() public {
        bytes memory data = abi.encodeWithSignature("wards(address)", address(this));
        bytes memory response = stranger.call(address(pause), data);

        uint256 responseUint;
        assembly {
            responseUint := mload(add(response, 32))
        }
        assertEq(responseUint, 1);
    }


}

contract Schedule is Test {

    function testFail_cannot_schedule_zero_address() public {
        pause.schedule(address(0), abi.encode(0));
    }

    function testFail_call_from_non_owner() public {
        bytes memory data = abi.encodeWithSignature("schedule(address,bytes)", address(target), abi.encode(0));
        stranger.call(address(pause), data);
    }

    function test_insertion() public {
        bytes memory dataIn = abi.encodeWithSignature("getBytes32()");

        bytes32 id = pause.schedule(address(target), dataIn);
        (address guy, bytes memory dataOut, uint256 timestamp) = pause.queue(id);

        assertEq0(dataIn, dataOut);
        assertEq(guy, address(target));
        assertEq(timestamp, now);
    }

}

contract Execute is Test {

    function testFail_delay_not_passed() public {
        bytes32 id = pause.schedule(address(target), abi.encode(0));
        pause.execute(id);
    }

    function testFail_double_execution() public {
        bytes32 id = pause.schedule(address(target), abi.encodeWithSignature("getBytes32()"));
        hevm.warp(now + step);

        pause.execute(id);
        pause.execute(id);
    }

    function test_execute_delay_passed() public {
        bytes32 id = pause.schedule(address(target), abi.encodeWithSignature("getBytes32()"));
        hevm.warp(now + step);

        bytes memory response = pause.execute(id);

        bytes32 response32;
        assembly {
            response32 := mload(add(response, 32))
        }
        assertEq(response32, bytes32("Hello"));
    }

    function test_call_from_non_owner() public {
        bytes32 id = pause.schedule(address(target), abi.encodeWithSignature("getBytes32()"));
        hevm.warp(now + step);

        stranger.call(address(pause), abi.encodeWithSignature("execute(bytes32)", id));
    }

}

contract Cancel is Test {

    function testFail_call_from_non_owner() public {
        bytes32 id = pause.schedule(address(target), abi.encodeWithSignature("getBytes32()"));
        hevm.warp(now + step);

        bytes memory data = abi.encodeWithSignature("cancel(bytes32)", id);
        stranger.call(address(pause), data);
    }

    function test_cancel_scheduled_execution() public {
        bytes32 id = pause.schedule(address(target), abi.encodeWithSignature("getBytes32()"));
        hevm.warp(now + step);

        pause.cancel(id);

        (address guy, bytes memory data, uint256 timestamp) = pause.queue(id);
        assertEq(guy, address(0));
        assertEq0(data, new bytes(0));
        assertEq(timestamp, 0);
    }

}
