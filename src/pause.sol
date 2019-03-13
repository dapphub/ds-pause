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

contract DSPause {
    // --- auth ---
    address public owner;
    function give(address usr) public {
        require(msg.sender == address(this), "ds-pause-undelayed-ownership-update");
        owner = usr;
    }
    modifier auth() {
        require(msg.sender == owner);
        _;
    }

    // --- math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require(z >= x);
    }

    // --- logs ---
    event Plan(address usr, bytes arg, uint era);
    event Drop(address usr, bytes arg, uint era);
    event Exec(address usr, bytes arg, uint era);

    // --- data ---
    mapping (bytes32 => bool) public planned;
    uint public delay;

    // --- init ---
    constructor(uint delay_, address owner_, DSAuthority authority_) public {
        delay = delay_;
        owner = owner_;
        authority = authority_;
    }

    // --- util ---
    function hash(address usr, bytes memory arg, uint era)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(usr, arg, era));
    }

    // --- executions ---
    function plan(address usr, bytes memory arg, uint era)
        public
        auth
    {
        require(era > add(block.timestamp, delay), "ds-pause-must-respect-delay")

        bytes32 id  = hash(usr, arg, era);
        planned[id] = true;

        emit Plan(usr, arg, era);
    }

    function drop(address usr, bytes memory arg, uint era)
        public
        auth
    {
        bytes32 id  = hash(usr, arg, era);
        planned[id] = false;

        emit Drop(usr, arg, era);
    }

    function exec(address usr, bytes memory arg, uint era)
        public
        returns (bytes memory)
    {
        bytes32 id = hash(usr, arg, era);

        require(planned[id] == true,    "ds-pause-unplanned-execution");
        require(block.timestamp >= era, "ds-pause-execution-too-soon");

        planned[id] = false;

        (bool ok, bytes memory res) = usr.delegatecall(arg);
        require(ok, "ds-pause-delegatecall-failed");

        emit Exec(usr, arg, era);
        return res;
    }
}
