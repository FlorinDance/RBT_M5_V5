RBT_M5 Hybrid v5.10.18

Based on v5.10.17. Existing recovery modes are preserved:
0 RECOVERY_NORMAL
1 RECOVERY_ONLY
2 RECOVERY_WITH_TRAIL

Added runtime-selectable modes:
3 RECOVERY_GLOBAL_LOCK
  Watches every EA trade from entry.
  Default: when floating profit reaches +10, protect +5.

4 RECOVERY_GLOBAL_STEP_TRAIL
  Watches every EA trade from entry.
  Default:
    +10 -> protect +5
    +15 -> protect +10
    +20 -> protect +15

All thresholds are Inputs; no recompile is needed between tests:
InpGlobalLockTriggerMoney
InpGlobalLockFloorMoney
InpGlobalStep1TriggerMoney / FloorMoney
InpGlobalStep2TriggerMoney / FloorMoney
InpGlobalStep3TriggerMoney / FloorMoney

Lot scaling:
The new modes reuse InpRecoveryScaleWithLot and InpRecoveryReferenceLot.
At the default reference lot 0.50, the default values are exactly +10/+5,
+15/+10, +20/+15. Set InpRecoveryScaleWithLot=false to keep the same money
thresholds for every lot size.

Recommended comparison:
- RECOVERY_ONLY
- RECOVERY_GLOBAL_LOCK
- RECOVERY_GLOBAL_STEP_TRAIL
with identical date range, lot, TP and other settings.
