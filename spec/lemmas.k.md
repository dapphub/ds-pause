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

# Calldata

## Layout

calldata for `plot` / `drop` / `exec` is layed out as follows:

1. `04 bytes` : `function selector`
1. `32 bytes` : `usr`
1. `32 bytes` : `tag`
1. `32 bytes` : `pointer to fax`
1. `32 bytes` : `eta`
1. `32 bytes` : `size of fax`
1. `symbolic` : `fax`
1. `symbolic` : `padding for fax (to word boundry, max 31 bytes)`
1. `symbolic` : `excess calldata (CD)`

## Size

These lemmas help `K` simplify terms that make calculations about calldata size. They are required as
both `chop` and `#ceil32` are `[concrete]` and so cannot be rewritten if they have symbolic values
as their arguments.

```k
rule ((164 <=Int chop((4 +Int (sizeWordStackAux((F ++ (#padToWidth((#ceil32(sizeWordStackAux(F, 0)) -Int sizeWordStackAux(F, 0)), .WordStack) ++ C)), 0) +Int 160))))) => true
  requires #sizeWordStack(F) <Int 64
  andBool #sizeWordStack(C) <Int 64

rule (((164 +Int sizeWordStackAux(F, 0)) <=Int chop((4 +Int (sizeWordStackAux((F ++ (#padToWidth((#ceil32(sizeWordStackAux(F, 0)) -Int sizeWordStackAux(F, 0)), .WordStack) ++ C)), 0) +Int 160))))) => true
  requires #sizeWordStack(F) <Int 64
  andBool #sizeWordStack(C) <Int 64
```





