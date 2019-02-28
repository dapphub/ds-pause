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

contract DSPause is DSAuth {
    // --- Auth ---
    function setOwner(address owner_) public {
        require(msg.sender == address(this));
        owner = owner_;
        emit LogSetOwner(owner);
    }
    function setAuthority(DSAuthority guy) public {
        require(msg.sender == address(this));
        authority = guy;
        emit LogSetAuthority(address(authority));
    }

    // --- Data ---
    mapping (bytes32 => bool) public scheduled;
    uint public delay;

    // --- Init ---
    constructor(uint delay_, address owner_, DSAuthority authority_) public {
        delay = delay_;
        owner = owner_;
        authority = authority_;
    }

    // --- Internal ---
    function tag(address guy, bytes memory data, uint when)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(guy, data, when));
    }

    // --- Public ---
    function schedule(address guy, bytes memory data)
        public
        auth
        returns (address, bytes memory, uint)
    {
        bytes32 id = tag(guy, data, now);
        scheduled[id] = true;
        return (guy, data, now);
    }

    function cancel(address guy, bytes memory data, uint when)
        public
        auth
    {
        bytes32 id = tag(guy, data, when);
        scheduled[id] = false;
    }

    function execute(address guy, bytes memory data, uint when)
        public
        returns (bytes memory response)
    {
        bytes32 id = tag(guy, data, when);

        require(now >= when + delay, "ds-pause: delay not passed");
        require(scheduled[id] == true, "ds-pause: unscheduled execution");

        scheduled[id] = false;

        // delegatecall implementation from ds-proxy
        assembly {
            let succeeded := delegatecall(sub(gas, 5000), guy, add(data, 0x20), mload(data), 0, 0)
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
