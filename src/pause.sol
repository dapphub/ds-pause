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

import "ds-auth/auth.sol";
import "ds-note/note.sol";

contract DSPause is DSAuth, DSNote {
    // --- auth ---
    function setOwner(address owner_) public {
        require(msg.sender == address(proxy), "ds-pause-undelayed-ownership-change");
        owner = owner_;
        emit LogSetOwner(owner);
    }
    function setAuthority(DSAuthority authority_) public {
        require(msg.sender == address(proxy), "ds-pause-undelayed-authority-change");
        authority = authority_;
        emit LogSetAuthority(address(authority));
    }

    // --- math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require(z >= x, "ds-pause-addition-overflow");
    }

    // --- data ---
    mapping (bytes32 => bool) public plans;
    DSPauseProxy public proxy;
    uint         public delay;

    // --- init ---
    constructor(uint delay_, address owner_, DSAuthority authority_) public {
        delay = delay_;
        owner = owner_;
        authority = authority_;
        proxy = new DSPauseProxy(address(this));
    }

    // --- util ---
    function hash(address usr, bytes memory fax, uint eta)
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(usr, fax, eta));
    }

    // --- executions ---
    function plot(address usr, bytes memory fax, uint eta)
        public note auth
    {
        require(eta >= add(now, delay), "ds-pause-delay-not-respected");
        plans[hash(usr, fax, eta)] = true;
    }

    function drop(address usr, bytes memory fax, uint eta)
        public note auth
    {
        plans[hash(usr, fax, eta)] = false;
    }

    function exec(address usr, bytes memory fax, uint eta)
        public note
        returns (bytes memory out)
    {
        require(now >= eta,                 "ds-pause-premature-exec");
        require(plans[hash(usr, fax, eta)], "ds-pause-unplotted-plan");

        plans[hash(usr, fax, eta)] = false;

        out = proxy.exec(usr, fax);
        require(proxy.owner() == address(this), "ds-pause-illegal-storage-change");
    }
}

// plans are executed in an isolated storage context to protect the storage on
// the pause from malicious plans
contract DSPauseProxy {
    address public owner;
    constructor(address owner_) public {
        owner = owner_;
    }

    function exec(address usr, bytes memory fax)
        public
        returns (bytes memory out)
    {
        require(msg.sender == owner, "ds-pause-proxy-unauthorized");

        bool ok;
        (ok, out) = usr.delegatecall(fax);
        require(ok, "ds-pause-delegatecall-error");
    }
}
