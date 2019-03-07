# DSPause

_schedule function calls that can only be executed after some predetermined delay has passed_

This can be useful as a security component within a governance system, to ensure that those affected by governance decisions have time to react in the case of an attack.

## Auth

`ds-pause` uses a slightly modified form of the `ds-auth` scheme. Both `setOwner` and `setAuthority`
can only be called by the pause itself. This means that they can only be called by using `schedule` /
`execute` on the pause, and changes to auth are therefore also subject to a delay.

## Interface

**`constructor(uint256 delay)`**

- Initializes a new instance of the contract with a delay in ms

**`schedule(address guy, bytes memory data) auth returns (address, bytes memory, uint256)`**

- Schedule a call with `data` calldata to address `guy`.
- Returns all data needed to execute or cancel the scheduled call

**`cancel(address guy, bytes memory data, uint256 when) auth`**

- Cancels a scheduled execution.

**`execute(address guy, bytes memory data, uint256 when) returns (bytes memory response)`**

- Executes the given function call (using `delegatecall`) as long as the delay period has passed.
- Returns the `delegatecall` output

## Tests

- [`pause.t.sol`](./pause.t.sol): unit tests
- [`integration.t.sol`](./integration.t.sol): usage examples / integation tests
