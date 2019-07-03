```k
syntax Int ::= "#DSToken._supply" [function]
rule #DSToken._supply => 0

syntax Int ::= "#DSToken._balances" "[" Int "]" [function]
rule #DSToken._balances[A] => #hashedLocation("Solidity", 1, A)

syntax Int ::= "#DSToken._approvals" "[" Int "]" "[" Int "]" [function]
rule #DSToken._approvals[A][B] => #hashedLocation("Solidity", 2, A B)

syntax Int ::= "#DSToken.owner_stopped" [function]
rule #DSToken.owner_stopped => 4

syntax Int ::= "#WordPackAddrUInt8" "(" Int "," Int ")" [function]
rule #WordPackAddrUInt8(X, Y) => Y *Int pow160 +Int X
  requires #rangeAddress(X)
  andBool #rangeUInt(8, Y)
```
