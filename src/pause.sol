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
        require(msg.sender == address(this), "ds-pause-undelayed-ownership-change");
        super.setOwner(owner_);
    }
    function setAuthority(DSAuthority authority_) public {
        require(msg.sender == address(this), "ds-pause-undelayed-authority-change");
        super.setAuthority(authority_);
    }

    // --- math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require(z >= x, "ds-pause-addition-overflow");
    }

    // --- data ---
    mapping (bytes32 => bool) public plans;
    uint public delay;

    // --- init ---
    constructor(uint delay_, address owner_, DSAuthority authority_) public {
        delay = delay_;
        owner = owner_;
        authority = authority_;
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
        returns (bytes memory response)
    {
        require(now >= eta,                 "ds-pause-premature-execution");
        require(plans[hash(usr, fax, eta)], "ds-pause-unplotted-execution");

        plans[hash(usr, fax, eta)] = false;

        // delegatecall implementation from ds-proxy
        assembly {
            let succeeded := delegatecall(sub(gas, 5000), usr, add(fax, 0x20), mload(fax), 0, 0)
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
