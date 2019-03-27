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
    // --- auth ---
    function setOwner(address owner_) public {
        require(msg.sender == address(this), "ds-pause-unplanned-ownership-change");
        super.setOwner(owner_);
    }
    function setAuthority(DSAuthority authority_) public {
        require(msg.sender == address(this), "ds-delay-unplanned-authority-change");
        super.setAuthority(authority_);
    }

    // --- math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require(z >= x, "ds-pause-addition-overflow");
    }

    // --- logs ---
    event Plan(address usr, bytes fax, uint val, uint gas, uint era);
    event Drop(address usr, bytes fax, uint val, uint gas, uint era);
    event Exec(address usr, bytes fax, uint val, uint gas, uint era);

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
    function hash(address usr, bytes memory fax, uint val, uint gas, uint era)
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(usr, fax, val, gas, era));
    }

    // --- planning ---
    function plan(address usr, bytes memory fax, uint val, uint gas, uint era)
        public auth
    {
        require(era >= add(now, delay), "ds-pause-plan-too-soon");
        plans[hash(usr, fax, val, gas, era)] = true;
        emit Plan(usr, fax, val, gas, era);
    }

    function drop(address usr, bytes memory fax, uint val, uint gas, uint era)
        public auth
    {
        plans[hash(usr, fax, val, gas, era)] = false;
        emit Drop(usr, fax, val, gas, era);
    }

    // --- execution ---
    function exec(address usr, bytes memory fax, uint val, uint sag, uint era)
        public payable
        returns (bytes memory response)
    {
        // A CALL or CREATE can consume at most 63/64 of the gas remaining at
        // the time the CALL is made; if a CALL asks for more than this
        // prescribed maximum, then the inner call will only have the
        // prescribed maximum gas regardless of how much gas was asked for.
        require(plans[hash(usr, fax, val, sag, era)], "ds-pause-unplanned-exec");
        //require(gasleft() > add((64 / 63) * sag, 5000),   "ds-pause-not-enough-gas");
        require(msg.value == val,                     "ds-pause-value-mismatch");
        require(now >= era,                           "ds-pause-premature-exec");

        plans[hash(usr, fax, val, sag, era)] = false;

        // delegatecall implementation from ds-proxy
        assembly {
            let succeeded := delegatecall(sag, usr, add(fax, 0x20), mload(fax), 0, 0)
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

        emit Exec(usr, fax, val, sag, era);
    }
}
