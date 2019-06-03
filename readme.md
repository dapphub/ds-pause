<h1 align="center">
ds-pause
</h1>

<p align="center">
<i><code>delegatecall</code> based proxy with an enforced delay</i>
</p>

`ds-pause` allows authorized users to schedule function calls that can only be executed once some
predetermined waiting period has elapsed. The configurable `delay` attribute sets the minimum wait
time.

`ds-pause` is designed to be used as a component in a governance system, to give affected parties
time to respond to decisions. If those affected by governance decisions have e.g. exit or veto
rights, then the pause can serve as an effective check on governance power.

## Plans

A `plan` describes a single `delegatecall` operation and a unix timestamp `eta` before which it
cannot be executed.

A `plan` consists of:

- `usr`: address to `delegatecall` into
- `tag`: the expected codehash of `usr`
- `fax`: `calldata` to use
- `eta`: first possible (unix) time of execution

Each plan has a unique id, defined as `keccack256(abi.encode(usr, fax, eta))`

## Operations

Plans can be manipulated in the following ways:

- **`plot`**: schedule a `plan`
- **`exec`**: execute a `plan`
- **`drop`**: cancel a `plan`

## Invariants

A break of any of the following would be classified as a critical issue. Please submit bug reports
to security@dapp.org.

**high level**
- There is no way to bypass the delay
- The code executed by the `delegatecall` cannot directly modify storage on the pause
- The pause will always retain ownership of it's `proxy`

**admin**
- `authority`, `owner`, and `delay` can only be changed if an authorized user plots a `plan` to do so

**`plot`**
- A `plan` can only be plotted if its `eta` is after `block.timestamp + delay`
- A `plan` can only be plotted by authorized users

**`exec`**
- A `plan` can only be executed if it has previously been plotted
- A `plan` can only be executed once it's `eta` has passed
- A `plan` can only be executed if its `tag` matches `extcodehash(usr)`
- A `plan` can only be executed once
- A `plan` can be executed by anyone

**`drop`**
- A `plan` can only be dropped by authorized users

## Identity & Trust

In order to protect the internal storage of the pause from malicious writes during `plan` execution,
we perform the actual `delegatecall` operation in a seperate contract with an isolated storage
context (`DSPauseProxy`). Each pause has it's own individual `proxy`.

This means that `plan`'s are executed with the identity of the `proxy`, and when integrating the
pause into some auth scheme, you probably want to trust the pause's `proxy` and not the pause
itself.

## Example Usage

```solidity
// construct the pause

uint delay            = 2 days;
address owner         = address(0);
DSAuthority authority = new DSAuthority();

DSPause pause = new DSPause(delay, owner, authority);

// plot the plan

address      usr = address(0x0);
bytes32      tag;  assembly { tag := extcodehash(usr) }
bytes memory fax = abi.encodeWithSignature("sig()");
uint         eta = now + delay;

pause.plot(usr, tag, fax, eta);
```

```solidity
// wait until block.timestamp is at least now + delay...
// and then execute the plan

bytes memory out = pause.exec(usr, tag, fax, eta);
```

## Tests

- [`pause.t.sol`](./pause.t.sol): unit tests
- [`integration.t.sol`](./integration.t.sol): usage examples / integation tests

