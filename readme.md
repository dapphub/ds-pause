# DSPause

_schedule function calls that can only be executed after some predetermined delay has passed_

This can be useful as a security component within a governance system, to ensure that those affected by governance decisions have time to react in the case of an attack.

## Auth

This contract makes use of a simple multi-owner auth scheme. Owners can add (`rely`) or remove (`deny`) other owners. Methods marked with the `auth` modifier can only be called by owners.

## Interface

**`schedule(address guy, bytes memory data)`**

- Schedule a call with `data` calldata to address `guy`.
- Returns the id needed to execute or cancel the call.
- Can only be called by owners.

**`cancel(bytes32 id)`**

- Cancels an execution.
- Can only be called by owners.

**`execute(bytes32 id)`**

- Delegatecalls into the target contract with the given calldata.
- Can be called by anyone.

**`freeze(uint256 timestamp)`**

- Nothing can be scheduled, canceled or executed until `timestamp`.
- Auth can still be changed. This is intended to allow graceful ownership migrations.
