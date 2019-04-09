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

import "ds-note/note.sol";

contract DSPause is DSNote {
    // --- auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public note rest { wards[usr] = 1; }
    function deny(address usr) public note rest { wards[usr] = 0; }

    modifier rest { require(msg.sender == cage,     "ds-pause-uncaged-call"); _; }
    modifier auth { require(wards[msg.sender] == 1, "ds-pause-unauthorized"); _; }

    // --- data ---
    mapping (bytes32 => bool) public plans;
    uint        public wait;
    DSPauseCage public cage;

    // --- init ---
    constructor(uint wait_) public {
        wait = wait_;
        cage = new DSPauseCage(address(this));
    }

    // --- util ---
    function hash(address usr, bytes memory fax, uint eta)
        internal pure
        returns (bytes32)
    {
        // is this safe?
        return keccak256(abi.encode(usr, fax, eta));
    }

    // --- executions ---
    function plan(address usr, bytes memory fax, uint eta)
        public note auth
    {
        require(eta >= now + wait,          "ds-pause-plan-too-early");
        plans[hash(usr, fax, eta)] = true;
    }

    function drop(address usr, bytes memory fax, uint eta)
        public note auth
    {
        require(plans[hash(usr, fax, eta)], "ds-pause-unplotted-plan");
        plans[hash(usr, fax, eta)] = false;
    }

    function exec(address usr, bytes memory fax, uint eta)
        public note
        returns (bytes memory out)
    {
        require(plans[hash(usr, fax, eta)], "ds-pause-unplotted-plan");
        require(now >= eta,                 "ds-pause-premature-exec");

        plans[hash(usr, fax, eta)] = false;

        out = cage.exec(usr, fax);
        require(cage.owner() == address(this), "ds-pause-cage-stolen");
    }
}

// isolated storage context for delegatecall.
// protects the internal storage of the pause from malicious plans
contract DSPauseCage {
    address public owner;
    constructor(address owner_) public {
        owner = owner_;
    }

    function exec(address usr, bytes memory fax)
        public payable
        returns (bytes memory out)
    {
        require(msg.sender == owner, "ds-pause-cage-unauthorized");

        bool ok;
        (ok, out) = usr.delegatecall(fax);
        require(ok, "ds-pause-delegatecall-failed");
    }
}
