pragma solidity >=0.5.0 <0.6.0;

import "ds-test/test.sol";

import "./delay.sol";

contract Hevm {
    function warp(uint256) public;
}

contract Target {
    function getBytes32() public pure returns (bytes32) {
        return bytes32("Hello");
    }
}

contract DsDelayTest is DSTest {
    DSDelay delay;
    Target target;
    Hevm hevm;

    uint256 start = 1;
    uint256 wait  = 1;
    uint256 ready = 3;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(start);

        target = new Target();
        delay = new DSDelay(wait);
    }

    function testFail_execute_delay_not_passed() public {
        bytes32 id = delay.enqueue(address(target), abi.encode(0));
        delay.execute(id);
    }

    function test_execute_delay_passed() public {
        bytes32 id = delay.enqueue(address(target), abi.encodeWithSignature("getBytes32()"));
        hevm.warp(ready);

        bytes memory response = delay.execute(id);

        bytes32 response32;
        assembly {
            response32 := mload(add(response, 32))
        }
        assertEq(response32, bytes32("Hello"));
    }
}
