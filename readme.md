# DSPause

_`delegatecall` based proxy with an enforced wait time for code execution_

`ds-pause` is designed to be used as a component in a governance system, to ensure that the governed
have time to respond to malicious actions. This can help to constrain the power wielded by the
governors.

## Plans

`ds-pause` allows authorized entities to make `plans`. A `plan` describes a single `delegatecall`
operation and a unix timestamp `eta` before which it cannot be executed.

Once the `eta` has passed, a `plan` can be executed by anyone.

A `plan` can only be made if its `eta` is after `block.timestamp + delay`. The `delay` is
configurable upon construction.

A `plan` consists of:

- `usr`: the address to `delegatecall` into
- `fax`: the `calldata` to use
- `eta`: the time from when the `plan` can be executed

## Auth

`ds-pause` uses a slightly modified form of the [`ds-auth`](https://github.com/dapphub/ds-auth)
scheme. Changes to auth are potentially highly impactful, and must also be subject to a delay.

`owner` and `authority` can therefore only be changed if an authorized user makes a `plan` to do so.

## Interface

**`constructor(uint delay)`**

- Initializes a new instance of the contract with a delay in ms

**`plan(address usr, bytes memory fax uint eta) public auth`**

- Plan a call to address `usr` with `fax` calldata that cannot be executed until `block.timestamp >=
  eta`
- Fails if `block.timestamp + delay > eta`
- Returns all data needed to execute or cancel the scheduled call

**`drop(address usr, bytes memory fax, uint eta) public auth`**

- Cancels a planned execution

**`exec(address usr, bytes memory fax, uint eta) public returns (bytes memory response)`**

- `delegatecall` into `usr` with `fax` calldata
- Fails if the call has not been planned beforehand
- Fails if `eta > block.timestamp`
- Returns the `delegatecall` output

## Tests

- [`pause.t.sol`](./pause.t.sol): unit tests
- [`integration.t.sol`](./integration.t.sol): usage examples / integation tests
