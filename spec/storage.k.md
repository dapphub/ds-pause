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
