# DSPause

_schedule function calls that can only be executed after some predetermined delay has passed_

This can be useful as a security component within a governance system, to ensure that those affected by governance decisions have time to react in the case of an attack.

## Workflow

The workflow consists of three steps:

* Creation of an action contract that performs the intended change
* Creation of a proposal contract that schedules the change
* When the `delay` has elapsed, anybody can call `execute` on the `ds-pause` to trigger execution of the action

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

**`wards(address guy) returns (uint)`**

- Returns `1` if `guy` is an owner, `0` otherwise.

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
- [`integration.t.sol`](./integration.t.sol): basic usage example / integation tests
