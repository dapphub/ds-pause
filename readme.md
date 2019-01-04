# DSPause

_schedule function calls that can only be executed after some predetermined delay has passed_

This can be useful as a security component within a governance system, to ensure that those affected by governance decisions have time to react in the case of an attack.

## Auth

This contract makes use of a simple multi-owner auth scheme. Owners can add (`rely`) or remove (`deny`) other owners. Methods marked with the `auth` modifier can only be called by owners.

## Interface

**`constructor(uint256 delay)`**

- Initializes a new instance of the contract with a delay in ms

**`schedule(address guy, bytes memory data) auth returns (bytes32 id)`**

- Schedule a call with `data` calldata to address `guy`.
- Returns the id needed to execute or cancel the call.

**`cancel(bytes32 id) auth`**

- Cancels a scheduled execution.

**`execute(bytes32 id) returns (bytes memory response)`**

- Executes the given function call as long as the delay period has passed.

**`freeze(uint256 timestamp) auth`**

- Nothing can be scheduled, canceled or executed until `timestamp`.
- Owners can still be added and removed. This is to allow graceful ownership migrations.
