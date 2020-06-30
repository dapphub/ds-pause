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

import {DSNote} from "./lib.sol";

contract DSPause is DSNote {

    // --- auth ---

    mapping (address => uint) public wards;
    function rely(address usr) public note wait { wards[usr] = 1; }
    function deny(address usr) public note wait { wards[usr] = 0; }

    modifier auth { require(wards[msg.sender] == 1,       "ds-pause-not-authorized"); _; }
    modifier wait { require(msg.sender == address(proxy), "ds-pause-undelayed-call"); _; }

    // --- admin ---

    function file(uint data) external note wait {
        delay = data;
    }

    // --- logs ---

    event Plot(address usr, bytes32 tag, bytes fax, uint eta);
    event Drop(address usr, bytes32 tag, bytes fax, uint eta);
    event Exec(address usr, bytes32 tag, bytes fax, uint eta);

    // --- math ---

    function add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require(z >= x, "ds-pause-overflow");
    }

    // --- util ---

    function soul(address usr) internal view returns (bytes32 tag) {
        assembly { tag := extcodehash(usr) }
    }

    // --- data ---

    mapping (bytes32 => uint) public plans;
    DSPauseProxy public proxy;
    uint         public delay;

    // --- init ---

    constructor(uint delay_) public {
        delay = delay_;
        wards[msg.sender] = 1;
        proxy = new DSPauseProxy();
    }

    // --- operations ---

    function plot(address usr, bytes32 tag, bytes calldata fax, uint eta)
        external note auth
    {
        require(eta >= add(now, delay), "ds-pause-delay-not-respected");
        plans[keccak256(abi.encode(usr, tag, fax, eta))] = 1;
        emit Plot(usr, tag, fax, eta);
    }

    function drop(address usr, bytes32 tag, bytes calldata fax, uint eta)
        external note auth
    {
        plans[keccak256(abi.encode(usr, tag, fax, eta))] = 0;
        emit Drop(usr, tag, fax, eta);
    }

    function exec(address usr, bytes32 tag, bytes calldata fax, uint eta)
        external note
        returns (bytes memory out)
    {
        bytes32 id = keccak256(abi.encode(usr, tag, fax, eta));

        require(now >= eta,       "ds-pause-premature-exec");
        require(plans[id] == 1,   "ds-pause-unplotted-plan");
        require(soul(usr) == tag, "ds-pause-wrong-codehash");

        plans[id] = 0;
        out = proxy.exec(usr, fax);

        require(proxy.owner() == address(this), "ds-pause-proxy-stolen");
        emit Exec(usr, tag, fax, eta);
    }
}

// plans are executed in an isolated storage context to protect the pause from
// malicious storage modification during plan execution
contract DSPauseProxy {
    address public owner;
    modifier auth { require(msg.sender == owner, "ds-pause-proxy-not-authorized"); _; }
    constructor() public { owner = msg.sender; }

    function exec(address usr, bytes calldata fax)
        external auth
        returns (bytes memory out)
    {
        bool ok;
        (ok, out) = usr.delegatecall(fax);
        require(ok, "ds-pause-delegatecall-error");
    }
}
