pragma solidity ^0.4.24;

import "ds-test/test.sol";

import "./DsDelay.sol";

contract DsDelayTest is DSTest {
    DsDelay delay;

    function setUp() public {
        delay = new DsDelay();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
