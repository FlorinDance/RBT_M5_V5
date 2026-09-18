RBT M5 v5.10.19 - combined mode test

New InpRecoveryMode option:
RECOVERY_GLOBAL_LOCK_PLUS_RECOVERY_ONLY

It combines the global +10 -> +5 lock with the existing RECOVERY_ONLY logic.
No compiler switch is required. Compile v5.10.19 once, then select the mode from Strategy Tester -> Inputs.

Defaults at reference lot 0.50 with InpRecoveryScaleWithLot=true:
- Global: +10 -> SL +5
- Recovery trigger: -20
- Recovery arm: +10 (existing Recovery Only behavior, including InpRecoveryMinMinutes)
- Failure evaluation delay: 60 minutes AFTER the Recovery trigger (-20), not 60 minutes from trade entry.
- Failure activation: -40
- Failure stop: -160
- Failure negative ratio/window/slope: unchanged from current Inputs.

Existing modes 0..4 remain available for A/B tests.
