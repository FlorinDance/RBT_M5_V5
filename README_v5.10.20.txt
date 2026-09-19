RBT M5 v5.10.20
================

New mode 6:
RECOVERY_GLOBAL_LOCK_RECOVERY_ONLY_TIME_STOP

It keeps mode 5 behavior intact and runs all three protections together:
1) Global profit lock: +10 EUR -> protect about +5 EUR (defaults, scaled by lot if enabled).
2) Recovery Only: trigger at -20 EUR, recovery handling to +10 EUR, including the existing 30-minute logic.
3) Failure protection: evaluated after 60 minutes from the -20 Recovery trigger, with the existing filters and -160 EUR protection defaults.
4) NEW hard time-stop: close any trade still open after InpCombinedTimeStopMinutes from ORIGINAL TRADE ENTRY.

Default InpCombinedTimeStopMinutes = 245.0 = 4 hours 5 minutes.
Change this input in Strategy Tester without recompiling (e.g. 240, 245, 270, 360).

Modes 0..5 remain available for clean A/B comparison.
Compile RBT_M5_Hybrid_v5.10.20.mq5.
