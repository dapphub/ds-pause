# DSPause

_schedule function calls that can only be executed after some predetermined delay has passed_

This can be useful as a security component within a governance system, to ensure that those affected by governance decisions have time to react in the case of an attack.

## Interface

**`constructor(uint256 delay)`**

- Initializes a new instance of the contract with a delay in ms

**`rely(address guy)`**

- Add `guy` as an owner
- `guy` can now call methods restricted with `auth`
- Subject to a delay (can only be called by using `schedule` and then `execute`)

**`deny(address guy)`**

- Remove `guy` from the owners list
- `guy` can no longer call methods restricted with `auth`
- Subject to a delay (can only be called by using `schedule` and then `execute`)

**`wards(address guy)`**

- Returns `1` if `guy` is an owner, `0` otherwise.

**`schedule(address guy, bytes memory data) auth returns (bytes32 id)`**

- Schedule a call with `data` calldata to address `guy`.
- Returns the id needed to execute or cancel the call.

**`cancel(bytes32 id) auth`**

- Cancels a scheduled execution.

**`execute(bytes32 id) returns (bytes memory response)`**

- Executes the given function call (using `delegatecall`) as long as the delay period has passed.
- Returns the `delegatecall` output

## Tests

- [`pause.t.sol`](./pause.t.sol): unit tests
- [`integration.t.sol`](./integration.t.sol): basic usage example / integation tests
