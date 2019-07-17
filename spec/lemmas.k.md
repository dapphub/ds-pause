# Hashing

Helper to compute the id of a `plan`

```k
syntax Int ::= #hash(Int, Int, WordStack, Int) [function]
rule #hash(Usr, Tag, Fax, Eta) => keccak(#encodeArgs(#address(Usr), #bytes32(Tag), #bytes(Fax), #uint256(Eta)))
```

Assume that keccack will never output an `Int` between 0 and 10.

```k
rule keccak(A) ==K B => false
     requires B <=Int 10
```

# Dynamic Data

The following lemmas give K a helping hand when dealing with dynamic data. They mostly exist to help
`K` figure out what to do with `chop` (which cannot operate on symbolic values).

```k
rule sizeWordStackAux((F ++ (#padToWidth((#ceil32(sizeWordStackAux(F, 0)) -Int sizeWordStackAux(F, 0)), .WordStack) ++ CD)), 0) +Int 160 <Int pow256 => true
  requires sizeWordStackAux(F, 0) +Int 31 +Int sizeWordStackAux(CD, 0) +Int 160 <Int pow256
```

