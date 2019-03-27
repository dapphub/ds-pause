# DSPause

_schedule function calls that can only be executed after some predetermined delay has passed_

This can be useful as a security component within a governance system, to ensure that those affected by governance decisions have time to react in the case of an attack.

## Auth

`ds-pause` uses a slightly modified form of the `ds-auth` scheme. Both `setOwner` and `setAuthority`
can only be called by the pause itself. This means that they can only be called by using `schedule` /
`execute` on the pause, and changes to auth are therefore also subject to a delay.

## Interface

**`constructor(uint delay)`**

- Initializes a new instance of the contract with a delay in ms

**`plan(address usr, bytes memory fax, uint val, uint era) public auth`**

- Plan a call to address `usr` with `fax` calldata and `val` value that cannot be executed until
  `block.timestamp >= era`
- Fails if `block.timestamp + delay > era`
- Returns all data needed to execute or cancel the scheduled call

**`drop(address usr, bytes memory fax, uint val, uint era) public auth`**

- Cancels a planned execution

**`exec(address usr, bytes memory fax, uint val, uint era) public returns (bytes memory response)`**

- `delegatecall` into `usr` with `fax` calldata
- Fails if the call has not been planned beforehand
- Fails if `msg.value` does not match `val`
- Fails if `era > block.timestamp`
- Returns the `delegatecall` output

## Tests

- [`pause.t.sol`](./pause.t.sol): unit tests
- [`integration.t.sol`](./integration.t.sol): usage examples / integation tests
