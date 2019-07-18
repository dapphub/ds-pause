# Specification

## Getters

### `wards`

```act
behaviour wards of DSPause
interface wards(address usr)

types

  Can: uint256

storage

  wards[usr] |-> Can

iff

  VCallValue == 0

returns Can
```

### `plans`

```act
behaviour plans of DSPause
interface plans(bytes32 id)

types

  Plan: uint256

storage

  plans[id] |-> Plan

iff

  VCallValue == 0

returns Plan
```

### `proxy`

```act
behaviour proxy of DSPause
interface proxy()

types

  Proxy: address

storage

  proxy |-> Proxy

iff

  VCallValue == 0

returns Proxy
```

### `delay`

```act
behaviour delay of DSPause
interface delay()

types

  Delay: uint256

storage

  delay |-> Delay

iff

  VCallValue == 0

returns Delay
```

## Admin

### `rely`

```act
behaviour rely of DSPause
interface rely(address usr)

types

  Can: uint256
  Proxy: address

storage

  wards[usr] |-> Can => 1
  proxy |-> Proxy

iff

  VCallValue == 0
  CALLER_ID == Proxy
```

### `deny`

```act
behaviour deny of DSPause
interface deny(address usr)

types

  Can: uint256
  Proxy: address

storage

  wards[usr] |-> Can => 0
  proxy |-> Proxy

iff

  VCallValue == 0
  CALLER_ID == Proxy
```

### `file`

```act
behaviour file of DSPause
interface file(uint data)

types

  Delay: uint256
  Proxy: address

storage

  delay |-> Delay => data
  proxy |-> Proxy

iff

  VCallValue == 0
  CALLER_ID == Proxy
```

## Operations

### `plot`

```act
behaviour plot of DSPause
interface plot(address usr, bytes32 tag, bytes fax, uint eta)

types

  Delay: uint256

storage

  delay |-> Delay
  wards[CALLER_ID] |-> Can
  plans[#hash(usr, tag, fax, eta)] |-> Plotted => 1

iff in range uint256

  TIME + Delay

iff

  Can == 1
  VCallValue == 0
  eta >= TIME + Delay

if

  #sizeWordStack(fax) < 64
  #sizeWordStack(CD) < 64
```

### `drop`

### `exec`
