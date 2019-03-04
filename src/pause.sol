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
    // --- Auth ---
    address public owner;
    function give(address guy) {
        require(msg.sender == address(this), "ds-pause: changes to ownership are subject to delay");
        owner = guy;
    }
    modifier auth() {
        require(msg.sender == owner, "ds-pause: unauthorized");
        _;
    }

    // --- Data ---
    mapping (bytes32 => bool) public wires;
    uint public pause;

    // --- Init ---
    constructor(uint pause_, address owner_) public {
        pause = pause_;
        owner = owner_;
    }

    // --- Internal ---
    function hash(address guy, bytes memory fax, uint era)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(guy, fax, era));
    }

    // --- Public ---
    function wire(address guy, bytes memory fax, uint era)
        public
        auth
    {
        bytes32 id = hash(guy, fax, era);
        wired[id]  = true;
    }

    function clip(address guy, bytes memory fax, uint era)
        public
        auth
    {
        bytes32 id = hash(guy, fax, era);
        wired[id]  = false;
    }

    function fire(address guy, bytes memory fax, uint era)
        public
        returns (bytes memory resp)
    {
        bytes32 id = hash(guy, fax, era);

        // checks
        require(now >= era + pause, "ds-pause: delay not elapsed");
        require(wired[id] == true,  "ds-pause: unscheduled execution");

        // effects
        wired[id] = false;

        // interactions
        (bool succ, bytes memory resp) = address(guy).delegatecall(fax);
        require(succ, "ds-pause: delegatecall failed");
        return resp;
    }
}
