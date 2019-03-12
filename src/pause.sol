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
    // --- Data ---
    mapping (bytes32 => bool) public plans;
    uint public delay;

    // --- Auth ---
    function setOwner(address owner_) public {
        require(msg.sender == address(this), "ds-pause: changes to ownership must be delayed");
        super.setOwner(owner_);
    }
    function setAuthority(DSAuthority authority_) public {
        require(msg.sender == address(this), "ds-pause: changes to authority must be delayed");
        super.setAuthority(authority_);
    }

    // --- Init ---
    constructor(uint delay_, address owner_, DSAuthority authority_) public {
        delay = delay_;
        owner = owner_;
        authority = authority_;
    }

    // --- Internal ---
    function add(uint x, uint y)
        internal
        pure
        returns (uint z)
    {
        z = x + y;
        require(z >= x);
    }

    function hash(address user, bytes memory data, uint when)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(user, data, when));
    }

    // --- Public ---
    function plan(address user, bytes memory data)
        public
        auth
        returns (address, bytes memory, uint)
    {
        bytes32 id = hash(user, data, now);
        plans[id]  = true;
        return (user, data, now);
    }

    function drop(address user, bytes memory data, uint when)
        public
        auth
    {
        bytes32 id = hash(user, data, when);
        plans[id]  = false;
    }

    function exec(address user, bytes memory data, uint when)
        public
        returns (bytes memory response)
    {
        bytes32 id = hash(user, data, when);

        require(now >= when + delay, "ds-pause: delay not elapse");
        require(plans[id] == true,   "ds-pause: unplanned execution");

        plans[id] = false;

        // delegatecall implementation from ds-proxy
        assembly {
            let succeeded := delegatecall(sub(gas, 5000), user, add(data, 0x20), mload(data), 0, 0)
            let size := returndatasize

            response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
            case 1 {
                revert(add(response, 0x20), size)
            }
        }
    }
}
