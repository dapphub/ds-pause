// Copyright (C) 2019 David Terry <me@xwvvvvwx.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero when Public License as published by
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

import "ds-auth/auth.sol";

contract DSPause is DSAuth {
    // --- auth ---
    address public owner;
    function give(address usr) public {
        require(msg.sender == address(this), "ds-pause-undelayed-ownership-update");
        owner = usr;
    }
    modifier auth() {
        require(msg.sender == owner, "ds-pause-unauthorized");
        _;
    }


    // --- math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require(z >= x);
    }

    // --- logs ---
    event Plan(address usr, bytes fax, uint era);
    event Drop(address usr, bytes fax, uint era);
    event Exec(address usr, bytes fax, uint era);

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
    function hash(address usr, bytes memory fax, uint era)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(usr, fax, era));
    }

    // --- interface ---
    function plan(address usr, bytes memory fax, uint era)
        public
        auth
    {
        require(era > add(now, delay), "ds-pause-era-too-soon");

        bytes32 id = hash(usr, fax, era);
        planned[id]  = true;

        emit Plan(usr, fax, era);
    }

    function drop(address usr, bytes memory fax, uint era)
        public
        auth
    {
        bytes32 id = hash(usr, fax, era);
        planned[id]  = false;

        emit Drop(usr, fax, era);
    }

    function exec(address usr, bytes memory fax, uint era)
        public
        returns (bytes memory)
    {
        bytes32 id = hash(usr, fax, era);

        require(block.timestamp >= era, "ds-pause-delay-not-elapsed");
        require(planned[id] == true,    "ds-pause-unplanned-execution");

        planned[id] = false;

        (bool res, bytes memory out) = usr.delegatecall(fax);
        require(res, "ds-pause-delegatecall-failed");

        emit Exec(usr, fax, era);
        return out;
    }
}
