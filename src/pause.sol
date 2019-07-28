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

import {DSNote} from "ds-note/note.sol";
import {DSAuth, DSAuthority} from "ds-auth/auth.sol";

contract DSPause is DSAuth, DSNote {

    // --- admin ---

    modifier wait { require(msg.sender == address(this), "ds-pause-undelayed-call"); _; }

    function setOwner(address owner_) public wait {
        owner = owner_;
        emit LogSetOwner(owner);
    }
    function setAuthority(DSAuthority authority_) public wait {
        authority = authority_;
        emit LogSetAuthority(address(authority));
    }
    function setDelay(uint delay_) public note wait {
        delay = delay_;
    }

    // --- math ---

    function add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require(z >= x, "ds-pause-addition-overflow");
    }

    // --- data ---

    uint public delay;
    mapping (bytes32 => bool) public plans;

    // --- init ---

    constructor(uint delay_, address owner_, DSAuthority authority_) public {
        delay = delay_;
        owner = owner_;
        authority = authority_;
    }

    // --- util ---

    function hash(address usr, bytes32 tag, bytes memory fax, uint eta)
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(usr, tag, fax, eta));
    }

    function soul(address usr)
        internal view
        returns (bytes32 tag)
    {
        assembly { tag := extcodehash(usr) }
    }

    // --- operations ---

    function plot(address usr, bytes32 tag, bytes memory fax, uint eta)
        public note auth
    {
        require(eta >= add(now, delay), "ds-pause-delay-not-respected");
        plans[hash(usr, tag, fax, eta)] = true;
    }

    function drop(address usr, bytes32 tag, bytes memory fax, uint eta)
        public note auth
    {
        plans[hash(usr, tag, fax, eta)] = false;
    }

    function exec(address usr, bytes32 tag, bytes memory fax, uint eta)
        public note
        returns (bytes memory out)
    {
        require(plans[hash(usr, tag, fax, eta)], "ds-pause-unplotted-plan");
        require(soul(usr) == tag,                "ds-pause-wrong-codehash");
        require(now >= eta,                      "ds-pause-premature-exec");

        plans[hash(usr, tag, fax, eta)] = false;

        bool ok;
        (ok, out) = usr.delegatecall(fax);
        require(ok, "ds-pause-delegatecall-error");
    }
}
