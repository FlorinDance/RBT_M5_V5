RBT M5 Hybrid v5.10.22
======================

Main file:
  RBT_M5_Hybrid_v5.10.22.mq5

Default live recovery mode:
  7 = RECOVERY_GLOBAL_LOCK_RECOVERY_DEGRADATION_TIME_STOP

Default live protection stack (0.50 lot reference):
  - Global lock: +10 account-currency profit -> physical SL near +5.
  - Recovery trigger: -20.
  - Recovery arm: +10, floor +5.
  - Failure evaluation: 60 minutes after the -20 Recovery trigger.
  - Failure activation default changed from 40 to 35.
  - Failure hard loss target remains 160.
  - Hard time-stop: 605 minutes = 10h05 from original trade entry.

LIVE degradation protection (mode 7):
  A) Continuous collapse M5: warning/log only; never closes by itself.
  B1) Fast shock: arms when the current degradation segment reaches <= -70
      within the first 3 minutes; after 60..120 seconds, if still <= -90,
      the EA closes the real position at market.
  B2) Sustained 60-second collapse: 5 consecutive adverse sampled price moves,
      >=10 pips on the first segment or >=15 pips after C re-arm, current P/L
      <= -50, then after 60..120 seconds still <= -70 -> real market close.
  C) Failed recovery re-arm: after a -20 trigger, a recovery to at least -15
      followed by a new break <= -20 resets/re-arms B1/B2. C never closes alone.
  D2) Confirmed deterioration: after the existing 1h failure filter arms, if
      P/L deteriorates another 30 within the next 20 minutes -> real market close.

All monetary thresholds scale with lot size when InpRecoveryScaleWithLot=true.
All thresholds are public Inputs and can be changed without recompilation.

GUI chart-structure fix:
  The checkbox now owns the entire structure overlay. With it OFF, HH/HL/LH/LL,
  connecting swing lines and BOS/CHOCH are all hidden/deleted. With it ON, they
  all appear together. The checkbox label is now "Chart structure".

Logging:
  Recovery CSV events include:
    DEGRADATION_A_WARNING
    DEGRADATION_B1_ARMED
    B1_FAST_SHOCK_CLOSE_EXECUTED / _CLOSE_RETRY
    DEGRADATION_B2_ARMED
    B2_SUSTAINED_COLLAPSE_CLOSE_EXECUTED / _CLOSE_RETRY
    DEGRADATION_C_REARM
    DEGRADATION_D2_ARMED / _EXPIRED
    D2_CONFIRMED_DETERIORATION_CLOSE_EXECUTED / _CLOSE_RETRY

Notes:
  - B1/B2/D2 are LIVE actions in mode 7; this is not shadow behavior.
  - A and C are supporting states only.
  - A latched degradation close is retried if the broker temporarily refuses it.
  - No EX5 is included for v5.10.22 because MetaEditor is not available in this build environment.


v5.10.22 additions
-------------------
- B2 recovery/invalidation now follows InpDegradationSampleSeconds (default 60 s), matching the offline replay. Brief intra-sample ticks above the -20 boundary no longer permanently disable B2.
- After a successful B1/B2/D2 live close, new entries are blocked for InpDegradationPostCloseCooldownMinutes (default 5 min).
- The cooldown is persisted in a terminal Global Variable in live/demo mode and restored after EA/terminal restart.
- All v5.10.21 thresholds and the 605-minute hard timeout are unchanged.
