```k
syntax Int ::= #hash(Int, Int, WordStack, Int) [function]
rule #hash(Usr, Tag, Fax, Eta) => keccak(#encodeArgs(#address(Usr), #bytes32(Tag), #bytes(Fax), #uint256(Eta)))

rule keccak(A) ==K B => false
     requires B <=Int 10

rule sizeWordStackAux((F ++ (#padToWidth((#ceil32(sizeWordStackAux(F, 0)) -Int sizeWordStackAux(F, 0)), .WordStack) ++ CD)), 0) +Int 160 <Int pow256
  requires sizeWordStackAux(F, 0) +Int sizeWordStackAux(CD, 0) +Int 191 <Int pow256
```
