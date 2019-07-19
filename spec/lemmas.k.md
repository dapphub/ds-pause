# Storage

Syntax for storage access.

```k
syntax Int ::= "#DSPause.wards" "[" Int "]" [function]
rule #DSPause.wards[A] => #hashedLocation("Solidity", 0, A)

syntax Int ::= "#DSPause.plans" "[" Int "]" [function]
rule #DSPause.plans[A] => #hashedLocation("Solidity", 1, A)

syntax Int ::= "#DSPause.proxy" [function]
rule #DSPause.proxy => 2

syntax Int ::= "#DSPause.delay" [function]
rule #DSPause.delay => 3
```

Syntax for computing `plan` ids.

```k
syntax Int ::= #hash(Int, Int, WordStack, Int) [function]
rule #hash(Usr, Tag, Fax, Eta) => keccak(#encodeArgs(#address(Usr), #bytes32(Tag), #bytes(Fax), #uint256(Eta)))
```

Assume that keccack will never output an `Int` between 0 and 10.

```k
rule keccak(A) ==K B => false
     requires B <=Int 10
```
