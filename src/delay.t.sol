pragma solidity >=0.5.0 <0.6.0;

import "ds-test/test.sol";

import "./delay.sol";

contract DsDelayTest is DSTest {
    DSDelay delay;

    function setUp() public {
        delay = new DSDelay(1);
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
