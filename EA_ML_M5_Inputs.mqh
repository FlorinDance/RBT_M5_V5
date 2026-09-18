//+------------------------------------------------------------------+
//| EA_ML_M5_Inputs.mqh                                             |
//| Public release inputs plus internal EA settings.                 |
//| Operational money/risk values stay visible and configurable.     |
//| The rest are internal defaults used by the validated EA logic.   |
//+------------------------------------------------------------------+

#ifndef __EA_ML_M5_INPUTS_MQH__
#define __EA_ML_M5_INPUTS_MQH__

// Feature compatibility mode.
// LEGACY_COMPAT reproduces the historical V1 feature wiring exactly.
// TRAINING_ALIGNED fixes the known scale/order mismatches before XGBoost inference.
enum ENUM_M5_FEATURE_MODE
{
   M5_FEATURE_LEGACY_COMPAT   = 0,
   M5_FEATURE_TRAINING_ALIGNED = 1
};

ENUM_M5_FEATURE_MODE InpM5FeatureMode = M5_FEATURE_TRAINING_ALIGNED;

// Phase 5.6E temporal-model challenger.
// PRODUCTION is bit-for-bit the original Phase5.6D classifier path.
// A/B are research challengers and are hard-locked to Strategy Tester only.
enum ENUM_M5_TEMPORAL_MODEL
{
   M5_TEMPORAL_PRODUCTION   = 0,
   M5_TEMPORAL_A_2022_2024 = 1,
   M5_TEMPORAL_B_2020_2024 = 2
};

ENUM_M5_TEMPORAL_MODEL InpM5TemporalModel = M5_TEMPORAL_PRODUCTION;

bool InpM5FeatureShadowCompare = false;   // Log legacy vs aligned predictions; never changes the order itself.
bool InpM5FeatureSanityLog      = false;  // Log rejected/out-of-range aligned vectors.


//+------------------------------------------------------------------+
//| V3 PHASE 4.1 - MTF / CLEAN RISK EVENTS / ENTRY GATE SHADOW
//| Toate modulele de mai jos sunt observatoare: nu deschid, nu
//| modifica si nu inchid pozitii.
//+------------------------------------------------------------------+
bool   InpV3ShadowEnable                  = true;
int    InpV3ShadowHistoryBars             = 360;
bool   InpV3ShadowLogMTF                  = false;
int    InpV3ShadowInternalPivotBars       = 2;
double InpV3ShadowInternalMinSwingATR     = 0.30;
int    InpV3ShadowExternalPivotBars       = 5;
double InpV3ShadowExternalMinSwingATR     = 0.85;
double InpV3ShadowEqualSwingToleranceATR  = 0.08;
double InpV3ShadowBreakConfirmATR         = 0.05;
int    InpV3ShadowWeightedBiasThreshold   = 3;

bool   InpV3ShadowDatasetEnable           = false;
bool   InpV3ShadowDatasetUseCommon        = false;
string InpV3ShadowDatasetPrefix           = "RBT_M5_V3_P50_TRADE_SHADOW";

bool   InpV3ShadowRiskEnable              = true;
bool   InpV3ShadowLogRisk                 = false;
double InpV3ShadowMinInitialSLPips        = 25.0;
double InpV3ShadowMinLossMoney            = 50.0;
int    InpV3ShadowRiskScoreTrigger        = 6;
int    InpV3ShadowRecentBreakBars         = 2;
int    InpV3ShadowMinAdverseBars          = 2;
double InpV3ShadowAdverseRet3ATR          = 0.70;
double InpV3ShadowAdverseRet12ATR         = 1.20;
double InpV3ShadowOppositeMLProb          = 0.45;

// Phase 2 candidate rules are still shadow-only. They never close positions.
bool   InpV3ShadowP2CandidatesEnable            = true;
bool   InpV3ShadowP2SellM15BreakEnable          = true;
bool   InpV3ShadowP2SellM15BreakNoReclaimEnable = true;

// Phase 3 visual overlay. It only draws calculated structure on the chart.
input group "Chart structure - visual only"
input bool InpV3OverlayEnable                  = true;
input bool InpV3OverlayShowInternalSwings      = true;
input bool InpV3OverlayShowExternalSwings      = true;
input bool InpV3OverlayShowBOS                 = true;
input bool InpV3OverlayShowCHOCH               = true;
bool   InpV3OverlayShowMTFPanel            = true;
bool   InpV3OverlayConnectInternalSwings   = true;   // Connect internal pivots with a zig-zag path.
bool   InpV3OverlayConnectExternalSwings   = true;   // Connect external pivots with a thicker path.
int    InpV3OverlayInternalLineWidth       = 1;
int    InpV3OverlayExternalLineWidth       = 2;
int    InpV3OverlayMaxSwingLabels          = 40;
int    InpV3OverlayMaxSwingSegments        = 60;
int    InpV3OverlayRecentEventBars         = 30;
int    InpV3OverlayPanelX                  = 320;
int    InpV3OverlayPanelY                  = 20;

// Phase 3 selective risk candidates remain shadow-only.
bool   InpV3ShadowP3CandidatesEnable       = true;
bool   InpV3ShadowP3CandidateAEnable       = true;  // SELL + score + M15 break at trigger
bool   InpV3ShadowP3CandidateBEnable       = true;  // M5 adverse + H1/H4 adverse
bool   InpV3ShadowP3CandidateCEnable       = true;  // state machine: warning -> confirm -> no reclaim
bool   InpV3ShadowP3SellOnly               = true;
double InpV3ShadowP3WarningLossMoney       = 25.0;
int    InpV3ShadowP3NoReclaimM15Bars       = 2;
double InpV3ShadowP3ReclaimToleranceATR    = 0.05;
bool   InpV3ShadowP3RequireHTFAgainst      = true;
bool   InpV3ShadowP3RequireAdverseContinue = true;

// Phase 4: deterministic regime snapshot + labeled risk events.
// Still shadow-only; these inputs do not change order entry or close positions.
bool   InpV3P4Enable                       = true;
bool   InpV3P4LogRegime                    = false;
int    InpV3P4RegimeRecentBreakBars        = 3;
double InpV3P4RegimeHighVolM5Ret12ATR      = 2.20;
double InpV3P4RegimeHighVolM15Ret12ATR     = 1.80;
double InpV3P4RegimeHighVolImpulseATR      = 2.20;
int    InpV3P4RegimeRangeScoreGap          = 1;

// Phase 4.1 separates direction from volatility. The normalized score is
// built from the Phase 4 high-volatility thresholds above.
double InpV3P41VolLowRatio                 = 0.35;
double InpV3P41VolExtremeRatio             = 1.60;

bool   InpV3P4RiskEventDatasetEnable       = false;
string InpV3P4RiskEventDatasetPrefix       = "RBT_M5_V3_P50_RISK_EVENTS";
double InpV3P4EventMinLossMoney            = 20.0;
int    InpV3P4EventMinRiskScore             = 2;
int    InpV3P4MaxBufferedRiskEvents         = 5000;
bool   InpV3P4LogRiskEvents                 = false;
double InpV3P4RecoveredTPFraction           = 0.95;
bool   InpV3P41RiskBarEventsEnable          = true;
bool   InpV3P41RiskTransitionEventsEnable   = true;


// Phase 4.1 entry-gate candidates. They are evaluated only after the legacy
// confidence and V1 filters already passed. They NEVER block the real order.
bool   InpV3P41EntryGateEnable              = true;
bool   InpV3P41EntryGateLog                 = false;
bool   InpV3P41EntryGateG1Enable            = true;  // H4 + D1 hard conflict.
bool   InpV3P41EntryGateG2Enable            = true;  // M15 or H1 directional confirmation.
bool   InpV3P41EntryGateG3Enable            = true;  // Regime-adaptive confidence.
double InpV3P41EntryAgainstProbAdd          = 0.08;
double InpV3P41EntryReversalProbAdd         = 0.05;
double InpV3P41EntryHighVolProbAdd          = 0.02;
double InpV3P41EntryAgainstGapAdd           = 0.05;
double InpV3P41EntryReducedLotFactor        = 0.50;

// Phase 4 discovery candidates. They are logged only and never close a trade.
bool   InpV3P4CandidateDEnable             = true;  // P3-B + entry weighted_bias bearish.
bool   InpV3P4CandidateEEnable             = true;  // P3-C + entry M5 alignment neutral.
bool   InpV3P4CandidateFEnable             = true;  // P3-C + entry H4 alignment bearish.
bool   InpV3P42CandidateGEnable            = true;  // Shadow consensus: any 2 of D/E/F have appeared.

// Phase 4.4 ML4 competing-risk shadow.
// Four embedded XGBoost models compare LOSS-FIRST versus RECOVERY-FIRST
// over 12 and 24 closed M5 bars, only in the actionable loss zone.
// These settings only label CSV events; they never close or modify a trade.
bool   InpV3P44CompetingRiskEnable          = true;
bool   InpV3P44CompetingRiskLog             = false;
double InpV3P44ActionZoneMinLossMoney       = 30.0;
double InpV3P44ActionZoneMaxLossMoney       = 90.0;
double InpV3P44RecoveryTargetMoney          = -20.0; // Exact first-passage label target.
double InpV3P44LossTargetMoney              = -150.0; // Exact first-passage label target.
double InpV3P44Loss12WatchProbability       = 0.04;
double InpV3P44Loss12StrongProbability      = 0.05;
double InpV3P44Recovery12LowProbability     = 0.40;
double InpV3P44Recovery12WatchMaxProbability= 0.55;
double InpV3P44Recovery12HighProbability    = 0.72;
double InpV3P44Loss24WatchProbability       = 0.10;
double InpV3P44Loss24StrongProbability      = 0.15;
double InpV3P44Recovery24LowProbability     = 0.40;
double InpV3P44Recovery24WatchMaxProbability= 0.58;
double InpV3P44Recovery24HighProbability    = 0.78;
int    InpV3P44MinPersistenceBars           = 2;
int    InpV3P44MinNoReclaimBars             = 1;
bool   InpV3P44RequireStructureConfirm      = true;
bool   InpV3P44StrongRequireCandidateG      = true; // Conservative; still Shadow-only.

// Phase 4.5 Candidate H: after Candidate G appears inside the actionable
// zone, wait at most N M5 bars for a recovery to -20 EUR. If recovery
// arrives first, record a recovery-exit; otherwise record a timeout exit.
// Entirely Shadow-only: no real close, SL/TP or lot modification.
bool   InpV3P45CandidateHEnable              = false;
bool   InpV3P45CandidateHLog                 = false;
double InpV3P45ArmMinLossMoney               = 30.0;
double InpV3P45ArmMaxLossMoney               = 90.0;
double InpV3P45RecoveryExitMoney             = -20.0;
int    InpV3P45RecoveryWindowBars            = 3;
bool   InpV3P45RequireModelConfirm           = false;
double InpV3P45MaxRecovery12Probability      = 0.55;
double InpV3P45MaxRecovery24Probability      = 0.65;

// Phase 4.6 parallel Candidate I/J policies.
// I: Candidate G in action zone -> arm; recovery to -20 cancels invalidation;
//    no recovery within N closed M5 bars records a timeout exit.
// J: same as I, but arms only when the existing ML4 dual confirmation is present.
// All policies are Shadow-only and cannot close or modify real positions.
bool   InpV3P46CandidateIEnable              = false;
bool   InpV3P46CandidateJEnable              = false;
bool   InpV3P46CandidatePolicyLog            = false;
double InpV3P46ArmMinLossMoney               = 30.0;
double InpV3P46ArmMaxLossMoney               = 90.0;
double InpV3P46RecoveryCancelMoney           = -20.0;
int    InpV3P46RecoveryWindowBars            = 3;
double InpV3P46JMaxRecovery12Probability     = 0.55;
double InpV3P46JMaxRecovery24Probability     = 0.65;

// Phase 4.7 parallel model-confirmed Candidate J windows.
// J3/J6/J12 share the same Candidate-G arm and ML4 confirmation. A fast
// recovery to -20 EUR cancels only policies whose timeout has not already
// fired. Otherwise each policy records its own timeout at 3/6/12 closed M5
// bars. A separate first-recovery-after-G snapshot is always recorded for
// future healthy-recovery versus relapse research. Entirely Shadow-only.
bool   InpV3P47CandidateJ3Enable              = false;
bool   InpV3P47CandidateJ6Enable              = false;
bool   InpV3P47CandidateJ12Enable             = false;
bool   InpV3P47RecoverySnapshotEnable         = true;
bool   InpV3P47CandidatePolicyLog             = false;
double InpV3P47ArmMinLossMoney                = 30.0;
double InpV3P47ArmMaxLossMoney                = 90.0;
double InpV3P47RecoveryCancelMoney            = -20.0;
int    InpV3P47J3WindowBars                   = 3;
int    InpV3P47J6WindowBars                   = 6;
int    InpV3P47J12WindowBars                  = 12;
double InpV3P47MaxRecovery12Probability       = 0.55;
double InpV3P47MaxRecovery24Probability       = 0.65;

// Phase 4.8 adaptive timing policies, all Shadow-only.
// K1: at bar 3, exit early only if the current loss is already at or beyond
//     the emergency threshold; otherwise wait until bar 12.
// K2: K1 plus early exit when the position deteriorated strongly during the
//     first 3 bars and D1 is structurally against the trade.
// Both policies cancel and HOLD if the position recovers to -20 EUR before
// their chosen exit. They never close or modify a real position.
bool   InpV3P48CandidateK1Enable              = false;
bool   InpV3P48CandidateK2Enable              = true;
bool   InpV3P48CandidatePolicyLog             = false;
int    InpV3P48DecisionWindowBars             = 3;
int    InpV3P48FinalWindowBars                = 12;
double InpV3P48RecoveryCancelMoney            = -20.0;
double InpV3P48EmergencyLossMoney             = 85.0;
double InpV3P48StrongDeteriorationMoney       = 12.0;
bool   InpV3P48RequireD1AgainstForDeterioration = true;

// Phase 5.4 frozen integrated policy: SlowRisk entry control + K2 post-entry.
// The same policy may run in Strategy Tester and on live/demo charts.
// Strict deposit/leverage checks are applied only inside Strategy Tester.
// The validated rules remain frozen: HIGH=50%, EXTREME=BLOCK.
bool   InpV5P54IntegratedRealEnable          = true;
bool   InpV5P54TesterOnly                    = false; // Legacy compatibility; non-fatal in LiveSafe R1.
bool   InpV5P54StrictTesterConfig            = false; // Optional research-profile lock; false keeps tester account/leverage flexible.
string InpV5RequiredAccountCurrency          = "EUR";
long   InpV5P54RequiredLeverage              = 33;
double InpV5P54RequiredInitialDeposit        = 3000.0;
double InpV5P54DepositTolerance              = 1.0;
bool   InpV5P54MonetaryPipSanityCheck        = false; // Legacy research diagnostic; product runtime relies on broker + margin checks.
double InpV5P54MinMoneyPerPip                = 3.0;
double InpV5P54MaxMoneyPerPip                = 7.0;
double InpV5P54HighLotMultiplier             = 0.50;
bool   InpV5P54BlockExtreme                  = true;
bool   InpV5P54NormalizeK2ByInitialRisk      = true;
double InpV5P54ReferenceRiskMoney            = 200.0;
double InpV5P54K2RiskScaleMin                = 0.25;
double InpV5P54K2RiskScaleMax                = 100.00; // Lets K2 scale proportionally on larger GUI lots/accounts.
int    InpV5K2RealCloseMaxAttempts           = 3;
int    InpV5K2RealCloseRetrySeconds          = 2;
bool   InpV5K2RealCloseLog                   = false;
bool   InpV5P54IntegratedLog                 = false;
bool   InpV5P54UnifiedAuditEnable            = false;
string InpV5P54UnifiedAuditPrefix            = "RBT_M5_V3_P56D_INTEGRATED_AUDIT";
bool   InpV5P54KeepSeparateAudits            = false;
bool   InpV5K2AuditDatasetEnable             = false;
string InpV5K2AuditDatasetPrefix             = "RBT_M5_V3_P56D_K2_REAL_AUDIT";

// Phase 5.6A label foundation. It observes every raw non-HOLD M5 model
// signal and records the future 3/6/12/24/48/96-bar path. The 1R labels are
// price-path labels only: they do not depend on lot size, K2 or realized money.
// This module is Shadow-only and never changes the real entry policy.
bool   InpV5EntryResearchEnable               = true;
bool   InpV5EntryResearchUseCommon            = false;
string InpV5EntryResearchDatasetPrefix        = "RBT_M5_V3_P56D_ENTRY_CANDIDATES";
int    InpV5EntryResearchMaxActive            = 128;
int    InpV5EntryResearchFinalHorizonBars     = 96;
double InpV5EntryResearchCatastrophicPips     = 40.0;
double InpV5P56ARiskUnitPips                  = 40.0;
bool   InpV5EntryResearchLog                  = false;

// Phase 5.6B raw sequence research. A second, compact training CSV is written
// only after the 96-bar labels are complete. By default it contains SELL
// candidates that would reach order-send eligibility if SlowRisk were removed,
// including EXTREME candidates blocked only by SlowRisk.
bool   InpV5P56BRawSequenceEnable              = true;
bool   InpV5P56BRawSequenceUseCommon           = false;
string InpV5P56BRawSequenceDatasetPrefix       = "RBT_M5_V3_P56D_RAW_SEQUENCE";
bool   InpV5P56BRawSequenceSellOnly            = true;
bool   InpV5P56BRawOnlyWouldOpenWithoutSlowRisk= true;
bool   InpV5P56BRawSequenceLog                 = false;

// Phase 5.6C-R1 embedded Raw Risk model. Shadow-only by construction:
// there is no real-enable input and this module never changes p53Policy,
// order lots, TP, SL or entry decisions. It may run both in tester and live.
// A marked FULL position is simulated at 50%; an already REDUCED position
// is never reduced a second time, regardless of the GUI lot.
bool   InpV5P56CRawRiskShadowEnable            = true;
bool   InpV5P56CRawRiskShadowTesterOnly        = false; // Legacy compatibility; ignored on live in R1.
double InpV5P56CRawRiskThreshold               = 0.95;
double InpV5P56CShadowLotMultiplier            = 0.50;
bool   InpV5P56CRawRiskShadowAuditEnable       = false;
string InpV5P56CRawRiskShadowAuditPrefix       = "RBT_M5_V3_P56D_RAW_RISK_SHADOW";
bool   InpV5P56CRawRiskShadowLog               = false;


// Phase 5.6D controlled real execution of the validated Raw Risk signal.
// The model may only reduce a SELL that the frozen SlowRisk policy classified
// as FULL. It can never unblock EXTREME, never reduce an already REDUCED trade,
// never affect BUY, and never hard-block an entry. Lot and TP money are scaled
// together using the representable broker lot ratio, preserving TP price.
//
// Safe default behavior:
// - Strategy Tester: real reduction is active when RealEnable=true.
// - Live/demo: EA still runs normally, but real Raw Risk reduction remains
//   locked until AllowLiveRealReduction is explicitly set true.
bool   InpV5P56DRawRiskRealEnable              = true;
bool   InpV5P56DAllowLiveRealReduction         = true;  // Production parity with the validated tester path.
double InpV5P56DRealLotMultiplier              = 0.50;
bool   InpV5P56DRealAuditEnable                = false;
string InpV5P56DRealAuditPrefix                = "RBT_M5_V3_P56D_RAW_RISK_REAL";
bool   InpV5P56DRealLog                        = false;

// Phase 5.7B-R2 Trade Health / No-Recovery AI + Failed-Recovery branch. SHADOW ONLY.
// GUI lot and GUI TP are the runtime authority. Monetary model features are
// expressed as multiples of the trade's own effective TP target, so the model
// is not tied to 0.50/25 or 0.40/20. Example: ArmLossTP=3.60 means ARM only
// after the loss reaches 3.6 x that trade's TP-money target.
// Reduced SlowRisk / 5.6D entries are excluded; no real close is possible here.
bool   InpV5P57BTradeHealthShadowEnable        = false;
int    InpV5P57BArmBar                         = 12;
double InpV5P57BTrainingZoneLossTP             = 1.20; // Research-equivalent distress zone, in x effective TP.
double InpV5P57BArmLossTP                      = 3.60; // ARM depth, in x effective TP.
double InpV5P57BNoRecoveryProbability          = 0.60;
double InpV5P57BM5Ret3ATRMin                   = 0.0;
int    InpV5P57BConfirmBars                    = 3;
double InpV5P57BCancelRecoveryTP               = 1.00; // Required recovery from ARM, in x effective TP.

// R2 Failed-Recovery branch. It runs ONLY after the first ARM was cancelled
// by a genuine recovery. All money thresholds are relative to the effective
// TP captured at entry; nothing is tied to a specific lot or EUR amount.
// Conservative rule: a recovery is considered failed only if, within the watch
// window, the trade gives back >= 1.50xTP from CANCEL AND breaks below the
// original ARM loss by >= 0.25xTP while M5 momentum is adverse again.
// A second short confirmation then protects against one-bar spikes.
bool   InpV5P57BFailedRecoveryEnable            = true;
int    InpV5P57BRecoveryWatchBars               = 12;   // 60 minutes after CANCEL on M5.
double InpV5P57BRearmGivebackFromCancelTP       = 1.50;
double InpV5P57BRearmBelowOriginalArmTP         = 0.25;
double InpV5P57BRearmM5Ret3ATRMin               = 0.0;
int    InpV5P57BRearmConfirmBars                = 2;    // 10 minutes on M5.
double InpV5P57BRearmCancelRecoveryTP           = 0.50; // Recovery from REARM that cancels R2 exit.

bool   InpV5P57BRequireFullEntry               = true;
bool   InpV5P57BAuditEnable                    = false;
string InpV5P57BAuditPrefix                    = "RBT_M5_V3_P57B_TRADE_HEALTH_SHADOW";
bool   InpV5P57BLog                            = false;

// Phase 5.1: embedded ML1 context + ML2 setup/fast-risk scores. Shadow-only.
// The diagnostic states never block, resize, delay or open a real trade.
bool   InpV5MTFEntryShadowEnable              = true;
bool   InpV5MTFEntryShadowLog                 = false;
double InpV5MTFStrongQuality                  = 0.72;
double InpV5MTFStrongContext                  = 0.65;
double InpV5MTFWeakQuality                    = 0.40;
double InpV5MTFWeakContext                    = 0.48;
double InpV5MTFConflictMinQuality             = 0.70;
double InpV5MTFConflictFastRisk               = 0.35;
double InpV5MTFConflictScoreGap               = 0.25;

// Phase 5.2: dedicated slow-failure risk model for SELL entries. Shadow-only.
// It estimates final V1 trade loss <= -100 EUR from entry-time data.
// Thresholds are training-distribution quantiles, not live trade commands.
bool   InpV5MTFSlowRiskEnable                 = true;
double InpV5MTFSlowRiskElevated               = 0.47885162;
double InpV5MTFSlowRiskHigh                   = 0.51357067;
double InpV5MTFSlowRiskExtreme                = 0.54746944;
bool   InpV5MTFSlowRiskLog                    = false;


// Phase 5.4 entry component. Controlled by InpV5P54IntegratedRealEnable.
// Separate audit is optional; the unified P54 audit is the primary source.
bool   InpV5P54EntryPolicyLog                 = false;
bool   InpV5P54EntryPolicyAuditEnable         = false;
string InpV5P54EntryPolicyAuditPrefix         = "RBT_M5_V3_P56D_ENTRY_POLICY_AUDIT";

// Phase 5.5: exact pre-entry sequence dataset. These features describe how
// M5/M15/H1/H4 structure, momentum and volatility evolved before the signal.
// They are research-only in 5.5; the validated Phase 5.4 policy remains the
// only real entry authority.
bool   InpV5P55SequenceDatasetEnable          = false;
bool   InpV5P55SequenceLog                    = false;

// Phase 5.5: memory after an EXTREME SELL block. It groups immediate SELL
// re-entry attempts into the same dangerous episode. Shadow is ON by default;
// real blocking is OFF until the 2023/2024/2025-2026 audits are reviewed.
bool   InpV5P55EpisodeMemoryEnable            = false;
bool   InpV5P55EpisodeMemoryRealEnable        = false;
bool   InpV5P55EpisodeMemoryTesterOnly        = true;
int    InpV5P55EpisodeMinBars                 = 3;
int    InpV5P55EpisodeBaseBars                = 6;
int    InpV5P55EpisodeMaxBars                 = 12;
double InpV5P55EpisodeMaxPriceDistanceATR     = 1.00;
int    InpV5P55EpisodeLowConfirmations        = 2;
bool   InpV5P55EpisodeMemoryLog               = false;
bool   InpV5P55EpisodeAuditEnable             = false;
string InpV5P55EpisodeAuditPrefix             = "RBT_M5_V3_P56D_EPISODE_AUDIT";

// Counterfactual checkpoints recorded in the risk-event dataset.
double InpV3P4CounterfactualLoss40         = 40.0;
double InpV3P4CounterfactualLoss50         = 50.0;
double InpV3P4CounterfactualLoss60         = 60.0;


//+------------------------------------------------------------------+
//| GENERAL / TRADE SETTINGS
//| Setări generale pentru volum, TP/SL, magic number, direcție permisă și loguri de bază.
//+------------------------------------------------------------------+
input group "Trade settings"
input double InpLots                = 0.50;   // Initial lot; can also be changed from the chart panel.
input double InpTakeProfitMoney     = 25.0;   // Initial TP in account currency; panel-adjustable.

//+------------------------------------------------------------------+
//| NORMAL-RBT MOTIF POLICY LAB
//| The live/tested position keeps the original RBT management. Two
//| proportional profit protectors are evaluated in shadow on ticks.
//+------------------------------------------------------------------+
input group "Normal RBT Motif policy lab"
input bool   InpNormalPolicyLabEnable              = true;
input double InpNormalPrudentAgreeArmPctTP         = 30.0;
input double InpNormalPrudentAgreeFloorPctTP       = 15.0;
input double InpNormalPrudentOpposeArmPctTP        = 20.0;
input double InpNormalPrudentOpposeFloorPctTP      = 8.0;
input double InpNormalPermissiveAgreeArmPctTP      = 45.0;
input double InpNormalPermissiveAgreeFloorPctTP    = 22.0;
input double InpNormalPermissiveOpposeArmPctTP     = 30.0;
input double InpNormalPermissiveOpposeFloorPctTP   = 12.0;
input bool   InpNormalPolicyLabLog                  = true;


//+------------------------------------------------------------------+
//| PROP / EVALUATION ACCOUNT RISK GUARD
//| Optional account-level protection. It never changes the ML signal,
//| lot or TP. When enabled, it only blocks new entries and can close
//| positions opened by this EA before the configured internal limits
//| are exceeded. The operational stop is calculated as account value
//| * firm limit percentage - safety buffer in account currency.
//+------------------------------------------------------------------+
input group "Optional account risk guard"
input bool   InpPropRiskEnable                 = false;
input double InpPropAccountValue               = 10000.0; // Starting/evaluation account value.
input double InpPropFirmDailyLossLimitPct      = 5.00;    // Firm rule; e.g. 5%.
input double InpPropFirmTotalLossLimitPct      = 10.00;   // Firm rule; e.g. 10%.
input double InpPropDailySafetyBufferMoney     = 100.0;   // Stop before the firm's daily limit.
input double InpPropTotalSafetyBufferMoney     = 100.0;   // Stop before the firm's total limit.
input int    InpPropMaxConsecutiveLosses       = 2;      // 0 = disabled
input int    InpPropDayResetHourServer         = 0;      // Broker server hour, 0..23
input bool   InpPropEmergencyCloseEAPositions  = true;
bool         InpPropRiskLog                    = false;

// Dynamic lot/margin protection. GUI lot is authoritative: there is no implicit
// 40 -> 0.40 correction and no product-level hard cap by default. A large lot is
// accepted when it is within the broker volume range and passes the real margin
// checks below. OptionalMaxLots=0 disables the optional manual cap.
input group "Order safety"
input bool   InpLotSafetyEnable                 = true;
input double InpLotSafetyAbsoluteMaxLots        = 0.00; // Optional manual cap; 0 = disabled.
input double InpLotSafetyMaxMarginUsagePct      = 90.0;
input double InpLotSafetyMinFreeMarginAfterOpen = 150.0;
bool         InpLotSafetyLog                    = false;
input double InpStopLossPips  = 40.0;  // Fixed SL when Dynamic SL is disabled.
input long InpMagicNumber     = 55001;  // Unique identifier for this EA's positions.
bool   InpAllowBuy            = true;   // Allow BUY
bool   InpAllowSell           = true;   // Allow SELL
bool   InpUseRegressorLog     = false;   // Log regressor output
bool   InpOnlyOnePosition     = true;   // Only one open position on symbol
int    InpSRLookbackBars      = 20;     // Support/Resistance lookback

//+------------------------------------------------------------------+
//| SPREAD PROTECTION
//| Blochează deschiderea ordinelor când spread-ul este prea mare.
//| Pentru EUR/USD, 1.5 pips este un default rezonabil; în backtest poți testa și 1.0.
//+------------------------------------------------------------------+
bool   InpUseMaxSpreadFilter  = true;   // Activează filtrul de spread înainte de ordin
input group "Chart protection defaults"
input double InpMaxSpreadPips = 1.5;    // Maximum spread; panel-adjustable.

int    InpDeviationPoints     = 20;     // Slippage / deviation
bool   InpPrintFeatureLog     = false;  // Detailed diagnostics are disabled in production.


//+------------------------------------------------------------------+
//| CHART CONTROL PANEL
//| Panel grafic pentru ajustări runtime. Inputurile rămân baza pentru backtest.
//+------------------------------------------------------------------+
bool   InpShowControlPanel    = true;   // Afișează panelul grafic pe chart
int    InpPanelX              = 10;     // Poziția X a panelului
int    InpPanelY              = 20;     // Poziția Y a panelului


//+------------------------------------------------------------------+
//| ML CONFIDENCE FILTER
//| Praguri pentru probabilitățile modelului ML și diferența minimă dintre clase.
//+------------------------------------------------------------------+
input double InpMinBuyProb     = 0.49;   // XGBoost minimum pBuy.
input double InpMinSellProb    = 0.36;   // XGBoost minimum pSell.
input double InpMinDecisionGap = 0.10;   // XGBoost chosen-class gap.
input bool   InpUseConfidenceFilter  = true;
input bool   InpLogConfidenceDetails = false;

//+------------------------------------------------------------------+
//| HYBRID XGBOOST + MOTIF QUALITY RISK
//| XGBoost remains the only entry-direction authority. Motif never
//| reverses a signal. It grades quality, exposure and exit protection.
//+------------------------------------------------------------------+
input group "Hybrid XGBoost + Motif risk"
input bool   InpHybridMotifEnable              = true;
input bool   InpHybridMotifLog                 = true;
input int    InpHybridMotifMaximumAgeMinutes   = 75;
input double InpMotifDirectionConfidence       = 0.52; // HIGH minimum confidence.
input double InpMotifMinimumPredictedNetATR    = 0.60; // HIGH minimum expected net ATR.
input double InpMotifMinimumGrossToCostRatio   = 1.50; // HIGH minimum gross/cost ratio.
input double InpMotifMediumDirectionConfidence = 0.52;
input double InpMotifMediumPredictedNetATR      = 0.40;
input double InpMotifMediumGrossToCostRatio     = 1.00;
input bool   InpMotifQualityUseHardCostGates   = false;
input double InpMotifMaximumSelectionCostATR   = 0.15;
input double InpMotifMaximumSpreadPips         = 1.20;
input double InpMotifSpreadMultiplier          = 1.20;
input double InpMotifCommissionRoundTurnPips   = 0.70;
input double InpMotifSlippageRoundTurnPips     = 0.20;
input int    InpMotifLatestFridayEntryHour     = 12;

input group "Motif quality lot multipliers"
input double InpHybridHighQualityLotMultiplier = 1.00;
input double InpHybridMediumQualityLotMultiplier=0.00;
input double InpHybridLowQualityLotMultiplier  = 0.00;
input double InpHybridUnavailableLotMultiplier = 0.00;
input bool   InpHybridScaleTPWithLot            = true;

input group "Hybrid CSV logger"
input bool   InpHybridCSVEnable                 = true;
input bool   InpHybridCSVUseCommonFiles         = true;
input string InpHybridRunLabel                  = "2026_V5117";
input int    InpHybridCSVFlushEveryRows         = 1;

input group "Hybrid trajectory logger"
input bool   InpHybridTrajectoryEnable          = true;
input double InpHybridFirstProfitEpsilonMoney   = 0.01;

input group "Trade manager ML dataset"
input bool   InpManagerDatasetEnable             = true;
input int    InpManagerDatasetSampleSeconds      = 60;
input bool   InpManagerDatasetLog                = true;

input group "Entry Risk Manager ML — shadow only"
input bool   InpRiskManagerShadowEnable          = true;
input double InpRiskManagerThreshold             = 0.30; // Frozen validation value.
input double InpRiskManagerReducedLotMultiplier  = 0.25; // Recommended fraction of opened lot.



//+------------------------------------------------------------------+
//| OPTIONAL MARKET FILTERS
//| Filtre opționale peste decizia ML: trend puternic, epuizare și timing de intrare.
//+------------------------------------------------------------------+
input bool InpUseTrendStrengthFilter = false;
input bool InpUseExhaustionFilter    = false;
input bool InpUseEntryTimingFilter   = false;


//+------------------------------------------------------------------+
//| TREND STRENGTH LIMITS
//| Praguri pentru filtrul de trend: ADX și mișcarea pe 12 lumânări.
//+------------------------------------------------------------------+
double InpTrendADXMin              = 30.0;
double InpTrendRet12Min            = 0.00080;


//+------------------------------------------------------------------+
//| EXHAUSTION LIMITS
//| Praguri Williams %R și Stochastic pentru confirmarea zonelor extreme.
//+------------------------------------------------------------------+
double InpExhaustionMaxWPRSell     = -10.0;
double InpExhaustionMinWPRBuy      = -90.0;
double InpExhaustionMaxStochSell   = 85.0;
double InpExhaustionMinStochBuy    = 15.0;


//+------------------------------------------------------------------+
//| ENTRY TIMING / LOCATION LIMITS
//| Distanța față de suport/rezistență și mișcarea scurtă în ATR.
//+------------------------------------------------------------------+
double InpMaxDistResATRForSell     = 1.50;
double InpMaxDistSupATRForBuy      = 1.50;
double InpMaxATRMultiplierRet3     = 1.20;



//+------------------------------------------------------------------+
//| DYNAMIC SL - MAIN SWITCHES
//| Activare Dynamic SL și blocarea setup-urilor considerate unsafe.
//+------------------------------------------------------------------+
input bool InpUseDynamicSL              = false; // Clean hybrid baseline uses fixed 40-pip SL.
input bool InpSkipUnsafeDynamicSLTrades = false;


//+------------------------------------------------------------------+
//| DYNAMIC SL - PIP MULTIPLIERS
//| Baza SL și multiplicatorii folosiți pentru setup normal, noisy-good și unsafe.
//+------------------------------------------------------------------+
input double InpDynamicSL_BasePips         = 0.8;
input double InpDynamicSL_NormalMultiplier = 50.0; // Default normal SL = 40 pips.
input double InpDynamicSL_NoisyMultiplier  = 5.0;  // Default reduced SL = 4 pips.
input double InpDynamicSL_UnsafeMultiplier = 1.0;


//+------------------------------------------------------------------+
//| DYNAMIC SL - PROBABILITY CORE
//| Praguri minime de probabilitate și gap pentru clasificarea setup-ului.
//+------------------------------------------------------------------+
double InpDynSL_MinChosenProb          = 0.42;
double InpDynSL_MinGap                 = 0.12;


//+------------------------------------------------------------------+
//| DYNAMIC SL - ADX / RET / MACD / DISTANCE CORE
//| Praguri de trend, impuls, histogramă MACD și distanță față de suport/rezistență.
//+------------------------------------------------------------------+
double InpDynSL_MaxADXForNoisy         = 30.0;
double InpDynSL_MaxADXForUnsafe        = 44.0;

double InpDynSL_MinRet3ATRForNoisy     = 0.80;
double InpDynSL_MaxRet12ATRForNoisy    = 2.50;
double InpDynSL_MinRet12ATRForUnsafe   = 2.80;

double InpDynSL_MaxAbsMACDHistATRNoisy = 0.60;
double InpDynSL_MinAbsMACDHistATRUnsafe= 0.60;

double InpDynSL_MaxDistResATR_Sell     = 1.50;
double InpDynSL_MaxDistSupATR_Buy      = 1.50;


//+------------------------------------------------------------------+
//| DYNAMIC SL - EXTREME INDICATOR VOTES
//| Praguri RSI, CCI, Stochastic și Williams %R pentru voturile de extremă.
//+------------------------------------------------------------------+
double InpDynSL_MinRSIForSell          = 58.0;
double InpDynSL_MaxRSIForBuy           = 42.0;

double InpDynSL_MinCCIForSell          = 60.0;
double InpDynSL_MaxCCIForBuy           = -60.0;

double InpDynSL_MinStochForSell        = 75.0;
double InpDynSL_MaxStochForBuy         = 35.0;

double InpDynSL_MinWPRForSell          = -20.0;
double InpDynSL_MaxWPRForBuy           = -80.0;


//+------------------------------------------------------------------+
//| DYNAMIC SL - LOGGING AND CORE VOTES
//| Loguri și reguli nucleu folosite în clasificarea setup-ului Dynamic SL.
//+------------------------------------------------------------------+
bool   InpLogDynamicSLDetails          = false;

int    InpDynSL_MinExtremeVotes       = 2;
int    InpDynSL_MinUnsafeVotes        = 1;

bool   InpDynSL_UseRet3Core           = true;
bool   InpDynSL_UseDistanceCore       = true;
bool   InpDynSL_UseGapCore            = true;
bool   InpDynSL_UseChosenProbCore     = true;

bool   InpDynSL_RelaxUnsafeByGap      = false;
double InpDynSL_StrongGapOverride     = 0.28;
double InpDynSL_StrongProbOverride    = 0.56;



//+------------------------------------------------------------------+
//| BAD NORMAL RECLASSIFY FILTER
//| Recunoaște setup-uri care par normale, dar au semnale de risc și sunt reclasificate unsafe.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableBadNormalFilter          = true;

// SELL bad-normal detector
int    InpDynSL_MinExtremeVotesForBadSell      = 3;
int    InpDynSL_MinUnsafeVotesForBadSell       = 2;
double InpDynSL_MinADXForBadSell               = 30.0;
double InpDynSL_MinRet12ATRForBadSell          = 1.80;
double InpDynSL_MaxDistResATRForBadSell        = 1.50;

// BUY bad-normal detector
int    InpDynSL_MaxExtremeVotesForBadBuy       = 1;
int    InpDynSL_MinUnsafeVotesForBadBuy        = 2;
double InpDynSL_MinDistSupATRForBadBuy         = 3.00;
double InpDynSL_MinRet12ATRForBadBuy           = 3.00;


// optional extra protection
bool   InpDynSL_LogBadNormalReclassify         = false;


//+------------------------------------------------------------------+
//| FALLING KNIFE BUY FILTER
//| Protecție BUY pentru intrări în cădere puternică, aproape de suport dar fără confirmare suficientă.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableFallingKnifeBuyFilter    = true;

int    InpDynSL_MinExtremeVotesForKnifeBuy     = 3;
double InpDynSL_MaxDistSupATRForKnifeBuy       = 1.00;
double InpDynSL_MinRet12ATRForKnifeBuy         = 2.50;
bool   InpDynSL_RequireMACDHistNegForKnifeBuy  = true;
bool   InpDynSL_RequireBelowEMAForKnifeBuy     = true;

bool   InpDynSL_LogFallingKnifeBuyReclassify   = false;



//+------------------------------------------------------------------+
//| STRONG UPTREND SELL FILTER
//| Protecție SELL împotriva vânzărilor contra unui uptrend puternic.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableStrongUptrendSellFilter   = true;

int    InpDynSL_MinExtremeVotesForUptrendSell   = 2;
double InpDynSL_MinADXForUptrendSell            = 30.0;
double InpDynSL_MinRet12ATRForUptrendSell       = 2.0;
bool   InpDynSL_RequireMACDHistPosForUptrendSell= true;
//input bool   InpDynSL_RequireAboveEMAForUptrendSell   = true;
double InpDynSL_MaxDistResATRForUptrendSell     = 0.8;

bool   InpDynSL_LogStrongUptrendSellReclassify  = false;


//+------------------------------------------------------------------+
//| STRONG UPTREND CONTINUATION SELL FILTER
//| Blocks SELL entries when bullish momentum is still active,
//| even if price is no longer extremely close to resistance.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableStrongUptrendContinuationSellFilter = true;

double InpDynSL_MinADXForStrongUptrendContinuationSell      = 35.0;
double InpDynSL_MinRet12ATRForStrongUptrendContinuationSell = 2.0;
double InpDynSL_MinMACDHistATRForStrongUptrendContinuationSell = 0.25;

double InpDynSL_MaxDistResATRForStrongUptrendContinuationSell = 1.50;

double InpDynSL_MinRSIForStrongUptrendContinuationSell   = 58.0;
double InpDynSL_MinStochForStrongUptrendContinuationSell = 85.0;
double InpDynSL_MinCCIForStrongUptrendContinuationSell   = 80.0;

int    InpDynSL_MinOverheatedVotesForStrongUptrendContinuationSell = 1;

bool   InpDynSL_LogStrongUptrendContinuationSellReclassify = false;



//+------------------------------------------------------------------+
//| WEAK SELL FILTER
//| Filtru SELL opțional pentru setup-uri slabe, departe de rezistență sau fără impuls clar.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableWeakSellFilter            = false;
int    InpDynSL_MaxExtremeVotesForWeakSell      = 1;
int    InpDynSL_MaxUnsafeVotesForWeakSell       = 1;
double InpDynSL_MaxADXForWeakSell               = 24.0;
double InpDynSL_MaxRet12ATRForWeakSell          = 1.6;
double InpDynSL_MinDistResATRForWeakSell        = 2.0;
bool   InpDynSL_LogWeakSellReclassify           = false;



//+------------------------------------------------------------------+
//| WEAK REBOUND BUY FILTER
//| Filtru BUY opțional pentru rebound-uri slabe, unde revenirea poate fi insuficientă.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableWeakReboundBuyFilter      = true;
int    InpDynSL_MinExtremeVotesForWeakBuy       = 2;
double InpDynSL_MinADXForWeakBuy                = 16.0;
double InpDynSL_MinRet12ATRForWeakBuy           = 2.0;
double InpDynSL_MaxDistSupATRForWeakBuy         = 2.5;
bool   InpDynSL_RequireMACDHistNegForWeakBuy    = false;
bool   InpDynSL_LogWeakReboundBuyReclassify     = false;




//+------------------------------------------------------------------+
//| MID REBOUND BUY FILTER
//| Filtru BUY pentru rebound-uri medii care încă pot fi riscante după mișcări mari.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableMidReboundBuyFilter      = true;
int    InpDynSL_MinVotesForMidReboundBuy       = 2;
int    InpDynSL_MaxUnsafeVotesForMidReboundBuy = 1;
double InpDynSL_MaxADXForMidReboundBuy         = 30.0;
double InpDynSL_MinRet12ATRForMidReboundBuy    = 2.0;
double InpDynSL_MaxMACDHistATRForMidReboundBuy = 0.15;
double InpDynSL_MaxDistSupATRForMidReboundBuy  = 1.20;
bool   InpDynSL_LogMidReboundBuyReclassify     = false;



//+------------------------------------------------------------------+
//| LOCAL OVERBOUGHT SELL FILTER
//| Filtru SELL pentru supracumpărare locală lângă rezistență.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableLocalOverboughtSellFilter      = true;
int    InpDynSL_MinExtremeVotesForLocalOBSell        = 3;
int    InpDynSL_MaxUnsafeVotesForLocalOBSell         = 0;
double InpDynSL_MaxDistResATRForLocalOBSell          = 0.70;
double InpDynSL_MinADXForLocalOBSell                 = 35.0;
double InpDynSL_MaxRet12ATRForLocalOBSell            = 1.40;
double InpDynSL_MaxMACDHistATRForLocalOBSell         = 0.15;
bool   InpDynSL_LogLocalOverboughtSellReclassify     = false;

// patch: catch semi-dangerous sells that fall between the existing sell filters

//+------------------------------------------------------------------+
//| SEMI UNSAFE SELL FILTER
//| Prinde sell-uri semi-periculoase care nu intră în celelalte filtre SELL.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableSemiUnsafeSellFilter           = true;
int    InpDynSL_MinExtremeVotesForSemiUnsafeSell     = 3;
int    InpDynSL_MinUnsafeVotesForSemiUnsafeSell      = 1;
double InpDynSL_MinADXForSemiUnsafeSell              = 24.0;
double InpDynSL_MinRet12ATRForSemiUnsafeSell         = 2.8;
double InpDynSL_MaxDistResATRForSemiUnsafeSell       = 0.80;
double InpDynSL_MaxMACDHistATRForSemiUnsafeSell      = 0.40;
bool   InpDynSL_LogSemiUnsafeSellReclassify          = false;

// patch: catch late/chase sells entered after a down move, far from resistance

//+------------------------------------------------------------------+
//| LATE SELL CHASE FILTER
//| Evită sell-uri intrate târziu după o mișcare deja extinsă în jos.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableLateSellChaseFilter            = true;
int    InpDynSL_MaxExtremeVotesForLateSellChase      = 0;
int    InpDynSL_MinUnsafeVotesForLateSellChase       = 2;
double InpDynSL_MaxADXForLateSellChase               = 30.0;
double InpDynSL_MinRet12ATRForLateSellChase          = 2.5;
double InpDynSL_MinDistResATRForLateSellChase        = 2.0;
bool   InpDynSL_RequireMACDHistNegForLateSellChase   = true;
bool   InpDynSL_LogLateSellChaseReclassify           = false;


//+------------------------------------------------------------------+
//| LATE SESSION WIDE SL SELL FILTER
//| Blocks late-session SELL entries with wide SL, weak momentum,
//| and too much distance from resistance.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableLateSessionWideSLSellFilter = true;

int    InpDynSL_LateSessionSellStartHour          = 21;
double InpDynSL_MinSLPipsForLateSessionSell       = 40.0;

double InpDynSL_MinDistResATRForLateSessionSell   = 2.0;
double InpDynSL_MaxRet12ATRForLateSessionSell     = 2.0;
double InpDynSL_MaxMACDHistATRForLateSessionSell  = 0.25;

bool   InpDynSL_LogLateSessionWideSLSellReclassify = false;


//+------------------------------------------------------------------+
//| EARLY BULLISH EXPANSION SELL FILTER
//| Blocks SELL entries when price is still expanding upward near
//| resistance, but bearish reversal momentum is not confirmed yet.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableEarlyBullishExpansionSellFilter = true;

double InpDynSL_MinADXForEarlyBullishExpansionSell = 18.0;
double InpDynSL_MaxADXForEarlyBullishExpansionSell = 28.0;

double InpDynSL_MinRet3ATRForEarlyBullishExpansionSell  = 0.50;
double InpDynSL_MinRet12ATRForEarlyBullishExpansionSell = 1.50;

double InpDynSL_MaxDistResATRForEarlyBullishExpansionSell = 1.00;
double InpDynSL_MaxAbsMACDHistATRForEarlyBullishExpansionSell = 0.10;

int    InpDynSL_MinExtremeVotesForEarlyBullishExpansionSell = 2;
double InpDynSL_MinSLPipsForEarlyBullishExpansionSell = 40.0;

bool   InpDynSL_LogEarlyBullishExpansionSellReclassify = false;


//+------------------------------------------------------------------+
//| HIGH ADX WEAK PULLBACK SELL FILTER
//| Blocks SELL entries during strong-trend conditions when the bearish
//| pullback is weak and the setup would use a wide Stop Loss.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableHighADXWeakPullbackSellFilter = true;

double InpDynSL_MinADXForHighADXWeakPullbackSell        = 45.0;
double InpDynSL_MinRet12ATRForHighADXWeakPullbackSell   = 1.5;
double InpDynSL_MaxRet12ATRForHighADXWeakPullbackSell   = 2.2;
double InpDynSL_MaxRet3ATRForHighADXWeakPullbackSell    = 0.8;

double InpDynSL_MinDistResATRForHighADXWeakPullbackSell = 1.5;
double InpDynSL_MaxDistResATRForHighADXWeakPullbackSell = 2.2;

double InpDynSL_MaxMACDHistATRForHighADXWeakPullbackSell = 0.25;
int    InpDynSL_MaxExtremeVotesForHighADXWeakPullbackSell = 1;

double InpDynSL_MinSLPipsForHighADXWeakPullbackSell = 40.0;

bool   InpDynSL_LogHighADXWeakPullbackSellReclassify = false;


//+------------------------------------------------------------------+
//| LOCAL FADE SELL WEAK FILTER
//| Filtru SELL pentru fade local slab, cu ADX/ret/MACD controlate.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableLocalFadeSellWeakFilter      = true;
int    InpDynSL_MinExtremeVotesForLocalFadeSell    = 2;
int    InpDynSL_MaxExtremeVotesForLocalFadeSell    = 2;
int    InpDynSL_MaxUnsafeVotesForLocalFadeSell     = 0;
double InpDynSL_MaxDistResATRForLocalFadeSell      = 0.50;
double InpDynSL_MaxADXForLocalFadeSell             = 26.0;
double InpDynSL_MaxRet12ATRForLocalFadeSell        = 1.20;
double InpDynSL_MinCCIForLocalFadeSell             = 100.0;
double InpDynSL_MinWPRForLocalFadeSell             = -15.0;
double InpDynSL_MaxMACDHistATRForLocalFadeSell     = 0.20;
bool   InpDynSL_LogLocalFadeSellWeakReclassify     = false;


//+------------------------------------------------------------------+
//| WEAK NORMAL WIDE SL SELL FILTER
//| Blocks SELL entries that are classified as NORMAL but have weak
//| model confidence/gap and would use a wide Stop Loss, especially
//| when ADX is weak and price is far from resistance.
//| This targets cases like:
//| pSell around 0.49 - 0.52, gap around 0.15 - 0.24, SL around 40 pips,
//| ADX low and DistResATR high.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableWeakNormalWideSLSellFilter = true;

double InpDynSL_MaxChosenProbForWeakNormalWideSLSell = 0.52;
double InpDynSL_MaxGapForWeakNormalWideSLSell        = 0.24;
double InpDynSL_MinSLPipsForWeakNormalWideSLSell     = 40.0;

double InpDynSL_MaxADXForWeakNormalWideSLSell        = 24.0;
double InpDynSL_MinDistResATRForWeakNormalWideSLSell = 2.0;

// Optional oversold context. If false, WPR is ignored.
bool   InpDynSL_RequireWPROversoldForWeakNormalWideSLSell = false;
double InpDynSL_MaxWPRForWeakNormalWideSLSell             = -80.0;

bool   InpDynSL_LogWeakNormalWideSLSellReclassify = false;



//+------------------------------------------------------------------+
//| WEAK NEUTRAL SELL FILTER
//| Filtru SELL pentru setup-uri neutre/slabe, fără impuls clar și departe de rezistență.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableWeakNeutralSellFilter       = true;
int    InpDynSL_MaxExtremeVotesForWeakNeutralSell = 2;
int    InpDynSL_MaxUnsafeVotesForWeakNeutralSell  = 0;
double InpDynSL_MinDistResATRForWeakNeutralSell   = 2.0;
double InpDynSL_MaxRet12ATRForWeakNeutralSell     = 0.50;
double InpDynSL_MaxMACDHistATRForWeakNeutralSell  = 0.10;
double InpDynSL_MaxADXForWeakNeutralSell          = 35.0;
bool   InpDynSL_LogWeakNeutralSellReclassify      = false;


//+------------------------------------------------------------------+
//| OVERSOLD CHASE SELL FILTER
//| Blocks SELL entries after a strong bearish move when price is close
//| to support and the market is already oversold.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableOversoldChaseSellFilter = true;

double InpDynSL_MinADXForOversoldChaseSell      = 40.0;
double InpDynSL_MinRet12ATRForOversoldChaseSell = 2.0;
double InpDynSL_MaxDistSupATRForOversoldChaseSell = 1.0;

double InpDynSL_MaxRSIForOversoldChaseSell   = 30.0;
double InpDynSL_MaxStochForOversoldChaseSell = 20.0;
double InpDynSL_MaxWPRForOversoldChaseSell   = -80.0;
double InpDynSL_MaxCCIForOversoldChaseSell   = -100.0;

int    InpDynSL_MinOversoldVotesForOversoldChaseSell = 2;
double InpDynSL_MinSLPipsForOversoldChaseSell = 40.0;

bool   InpDynSL_LogOversoldChaseSellReclassify = false;


//+------------------------------------------------------------------+
//| BULLISH MOMENTUM WIDE SL SELL FILTER
//| Blocks SELL entries with wide SL when the market is overbought
//| but bullish momentum is still active.
//| This targets cases like:
//| weak pSell/gap, SL around 40 pips, high ADX, close to resistance,
//| strong CCI/Stoch, positive MACD histogram and strong ret3ATR.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableBullishMomentumWideSLSellFilter = true;

double InpDynSL_MaxChosenProbForBullishMomentumWideSLSell = 0.52;
double InpDynSL_MaxGapForBullishMomentumWideSLSell        = 0.20;
double InpDynSL_MinSLPipsForBullishMomentumWideSLSell     = 40.0;

double InpDynSL_MinADXForBullishMomentumWideSLSell        = 28.0;
double InpDynSL_MaxDistResATRForBullishMomentumWideSLSell = 1.0;

double InpDynSL_MinCCIForBullishMomentumWideSLSell        = 150.0;
double InpDynSL_MinStochForBullishMomentumWideSLSell      = 85.0;

bool   InpDynSL_RequireMACDHistPosForBullishMomentumWideSLSell = true;

double InpDynSL_MinRet3ATRForBullishMomentumWideSLSell    = 1.5;

bool   InpDynSL_LogBullishMomentumWideSLSellReclassify    = false;


//+------------------------------------------------------------------+
//| BULLISH REGIME PULLBACK WIDE SL SELL FILTER
//| Blocks SELL entries with wide SL in a bullish regime after a small
//| pullback, when trend pressure is still active.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableBullishRegimePullbackWideSLSellFilter = true;

double InpDynSL_MaxChosenProbForBullishRegimePullbackWideSLSell = 0.52;
double InpDynSL_MaxGapForBullishRegimePullbackWideSLSell        = 0.26;
double InpDynSL_MinSLPipsForBullishRegimePullbackWideSLSell     = 40.0;

double InpDynSL_MinADXForBullishRegimePullbackWideSLSell        = 35.0;
double InpDynSL_MinRet12ATRForBullishRegimePullbackWideSLSell   = 1.50;

double InpDynSL_MinDistResATRForBullishRegimePullbackWideSLSell = 1.0;
double InpDynSL_MaxDistResATRForBullishRegimePullbackWideSLSell = 2.5;

double InpDynSL_MinCCIForBullishRegimePullbackWideSLSell        = 0.0;
double InpDynSL_MinStochForBullishRegimePullbackWideSLSell      = 60.0;

bool   InpDynSL_RequireMACDHistPosForBullishRegimePullbackWideSLSell = true;

bool   InpDynSL_LogBullishRegimePullbackWideSLSellReclassify = false;



//+------------------------------------------------------------------+
//| WEAK NORMAL WIDE SL BUY FILTER
//| Blocks BUY entries that are classified as NORMAL but have weak
//| model confidence/gap and would use a wide Stop Loss.
//| This targets cases like:
//| pBuy around 0.49 - 0.52, gap around 0.15 - 0.20, SL around 40 pips.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableWeakNormalWideSLBuyFilter = true;

double InpDynSL_MaxChosenProbForWeakNormalWideSLBuy = 0.52;
double InpDynSL_MaxGapForWeakNormalWideSLBuy        = 0.20;
double InpDynSL_MinSLPipsForWeakNormalWideSLBuy     = 40.0;

bool   InpDynSL_LogWeakNormalWideSLBuyReclassify    = false;


//+------------------------------------------------------------------+
//| NEUTRAL WIDE SL BUY FILTER
//| Blocks BUY entries with wide SL when the setup is neutral,
//| has weak momentum and is not close enough to support.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableNeutralWideSLBuyFilter = true;

double InpDynSL_MaxChosenProbForNeutralWideSLBuy = 0.52;
double InpDynSL_MaxGapForNeutralWideSLBuy        = 0.20;

double InpDynSL_MaxADXForNeutralWideSLBuy        = 22.0;
double InpDynSL_MaxAbsRet12ATRForNeutralWideSLBuy = 0.50;
double InpDynSL_MaxAbsMACDHistATRForNeutralWideSLBuy = 0.05;

double InpDynSL_MinDistSupATRForNeutralWideSLBuy = 1.50;
double InpDynSL_MinDistResATRForNeutralWideSLBuy = 1.50;

double InpDynSL_MinSLPipsForNeutralWideSLBuy = 40.0;

bool   InpDynSL_LogNeutralWideSLBuyReclassify = false;


//+------------------------------------------------------------------+
//| STRONG BEARISH IMPULSE WIDE SL BUY FILTER
//| Blocks BUY entries opened against a strong bearish impulse,
//| with wide SL and weak confirmation.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableStrongBearishImpulseWideSLBuyFilter = true;

double InpDynSL_MaxChosenProbForStrongBearishImpulseWideSLBuy = 0.54;
double InpDynSL_MaxGapForStrongBearishImpulseWideSLBuy        = 0.18;
double InpDynSL_MinSLPipsForStrongBearishImpulseWideSLBuy     = 40.0;

double InpDynSL_MinADXForStrongBearishImpulseWideSLBuy        = 24.0;
double InpDynSL_MaxCCIForStrongBearishImpulseWideSLBuy        = -200.0;
double InpDynSL_MaxRSIForStrongBearishImpulseWideSLBuy        = 35.0;

double InpDynSL_MaxRet3ForStrongBearishImpulseWideSLBuy       = -0.0010;
double InpDynSL_MaxRet12ForStrongBearishImpulseWideSLBuy      = 0.0;

double InpDynSL_MinVolumeForStrongBearishImpulseWideSLBuy     = 900.0;
double InpDynSL_MinDistSupATRForStrongBearishImpulseWideSLBuy = 2.0;

bool   InpDynSL_RequireMACDHistNegForStrongBearishImpulseWideSLBuy = true;

bool   InpDynSL_LogStrongBearishImpulseWideSLBuyReclassify = false;


//+------------------------------------------------------------------+
//| BEARISH PULLBACK WIDE SL BUY FILTER
//| Blocks BUY entries with wide SL when the market is oversold but
//| still under bearish pressure, not close enough to support to be safe.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableBearishPullbackWideSLBuyFilter = true;

double InpDynSL_MaxChosenProbForBearishPullbackWideSLBuy = 0.52;
double InpDynSL_MaxGapForBearishPullbackWideSLBuy        = 0.21;
double InpDynSL_MinSLPipsForBearishPullbackWideSLBuy     = 40.0;

double InpDynSL_MaxADXForBearishPullbackWideSLBuy        = 18.0;
double InpDynSL_MinRet12ATRForBearishPullbackWideSLBuy   = 1.50;
double InpDynSL_MaxDistSupATRForBearishPullbackWideSLBuy = 1.30;

double InpDynSL_MaxCCIForBearishPullbackWideSLBuy        = -120.0;
double InpDynSL_MaxWPRForBearishPullbackWideSLBuy        = -90.0;
double InpDynSL_MaxStochForBearishPullbackWideSLBuy      = 15.0;

bool   InpDynSL_RequireMACDHistNegForBearishPullbackWideSLBuy = true;

bool   InpDynSL_LogBearishPullbackWideSLBuyReclassify = false;


//+------------------------------------------------------------------+
//| HIGH ADX BEARISH WIDE SL BUY FILTER
//| Blocks BUY entries with wide SL when the market still has strong
//| bearish pressure: high ADX, bearish MACD, oversold/weak oscillators,
//| and price is close to support.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableHighADXBearishWideSLBuyFilter = true;

double InpDynSL_MinADXForHighADXBearishWideSLBuy      = 30.0;
double InpDynSL_MaxDistSupATRForHighADXBearishWideSLBuy = 0.70;

double InpDynSL_MaxCCIForHighADXBearishWideSLBuy      = -150.0;
double InpDynSL_MaxWPRForHighADXBearishWideSLBuy      = -85.0;

bool   InpDynSL_RequireMACDHistNegForHighADXBearishWideSLBuy = true;

double InpDynSL_MinSLPipsForHighADXBearishWideSLBuy   = 40.0;

bool   InpDynSL_LogHighADXBearishWideSLBuyReclassify  = false;


//+------------------------------------------------------------------+
//| BEARISH SUPPORT WIDE SL BUY FILTER
//| Blocks BUY entries with wide SL when price is close to support,
//| but bearish pressure is still active.
//| This targets cases like:
//| pBuy around 0.51 - 0.53, gap around 0.20 - 0.25,
//| ADX low/mid, CCI/WPR bearish, MACD histogram negative.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableBearishSupportWideSLBuyFilter = true;

double InpDynSL_MaxChosenProbForBearishSupportWideSLBuy = 0.53;
double InpDynSL_MaxGapForBearishSupportWideSLBuy        = 0.25;
double InpDynSL_MinSLPipsForBearishSupportWideSLBuy     = 40.0;

double InpDynSL_MaxADXForBearishSupportWideSLBuy        = 25.0;
double InpDynSL_MaxDistSupATRForBearishSupportWideSLBuy = 0.80;

double InpDynSL_MaxCCIForBearishSupportWideSLBuy        = -120.0;
double InpDynSL_MaxWPRForBearishSupportWideSLBuy        = -80.0;

bool   InpDynSL_RequireMACDHistNegForBearishSupportWideSLBuy = true;

bool   InpDynSL_LogBearishSupportWideSLBuyReclassify = false;


//+------------------------------------------------------------------+
//| REPEAT WIDE SL BUY AFTER FAST TP FILTER
//| Blocks repeated BUY entries after a very fast BUY TP when the new
//| setup would use a wide Stop Loss.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableRepeatWideSLBuyAfterFastTPFilter = true;

// Maximum time, in minutes, from the previous BUY entry to its TP close
// to consider it a "fast TP".
int    InpDynSL_MaxMinutesForFastBuyTP = 3;

// Maximum time, in minutes, after the previous BUY TP close during which
// a new BUY with wide SL is blocked.
int    InpDynSL_BlockMinutesAfterFastBuyTP = 10;

// Minimum SL size for the new BUY to be blocked.
double InpDynSL_MinSLPipsForRepeatWideSLBuyAfterFastTP = 40.0;

bool   InpDynSL_LogRepeatWideSLBuyAfterFastTPReclassify = false;



//+------------------------------------------------------------------+
//| FRIDAY CLOSE PROTECTION
//| Force-closes EA positions on Friday at/after the configured time,
//| to avoid holding trades over the weekend.
//+------------------------------------------------------------------+
bool InpUseFridayCloseProtection = true;

int  InpFridayCloseHour   = 23;
int  InpFridayCloseMinute = 30;

bool InpLogFridayCloseProtection = false;



//+------------------------------------------------------------------+
//| MAX LOSS MONEY PROTECTION
//| Emergency protection for open positions. It does not reduce the initial SL;
//| it closes the position only if the floating loss reaches the configured
//| account-currency amount.
//+------------------------------------------------------------------+
input bool   InpUseMaxLossMoneyProtection = false;   // Enable emergency max loss per trade
input double InpMaxLossMoneyPerTrade = 200.0;  // Panel-adjustable emergency loss threshold.
bool   InpLogMaxLossMoneyProtection = false;   // Log forced close events


//+------------------------------------------------------------------+
//| PROFIT STEP POSITION MANAGEMENT
//| Mută SL-ul pe profit și extinde TP-ul în trepte, dacă poziția merge în direcția bună.
//| Exemplu: la +25 EUR profit curent, blochează +20 EUR prin SL și extinde TP la +50 EUR.
//+------------------------------------------------------------------+
bool   InpUseProfitStepManagement     = false;  // Internal only: profit steps disabled for release panel
bool   InpProfitStepManageEveryTick   = true;   // true = verifică pe fiecare tick; false = doar pe bară nouă
bool   InpLogProfitStepManagement     = false;   // Log pentru modificările SL/TP pe trepte

double InpProfitStep1_TriggerMoney    = 25.0;   // Step 1: profit curent necesar
double InpProfitStep1_LockMoney       = 20.0;   // Step 1: profit blocat prin SL
double InpProfitStep1_NewTPMoney      = 50.0;   // Step 1: noul TP în bani

double InpProfitStep2_TriggerMoney    = 50.0;   // Step 2: profit curent necesar
double InpProfitStep2_LockMoney       = 35.0;   // Step 2: profit blocat prin SL
double InpProfitStep2_NewTPMoney      = 75.0;   // Step 2: noul TP în bani

double InpProfitStep3_TriggerMoney    = 75.0;   // Step 3: profit curent necesar
double InpProfitStep3_LockMoney       = 60.0;   // Step 3: profit blocat prin SL
double InpProfitStep3_NewTPMoney      = 100.0;  // Step 3: noul TP în bani

double InpProfitStep4_TriggerMoney    = 100.0;  // Step 4: profit curent necesar
double InpProfitStep4_LockMoney       = 80.0;   // Step 4: profit blocat prin SL
double InpProfitStep4_NewTPMoney      = 150.0;  // Step 4: noul TP în bani


//+------------------------------------------------------------------+
//| MARKET STRUCTURE RISK MONITOR
//| Monitor post-entry mai selectiv: detectează respingeri repetate la
//| rezistență/suport, break de swing și recovery/reclaim. Ideea este
//| să lase trade-ul să respire până se rupe structura, nu să închidă
//| doar fiindcă au trecut X minute sau profitul curent este negativ.
//+------------------------------------------------------------------+
bool   InpUseMarketStructureRiskMonitor      = false;  // Master switch pentru monitorul nou
bool   InpMS_BuyEnabled                      = true;  // Activează pentru BUY
bool   InpMS_SellEnabled                     = true;  // Activează pentru SELL
bool   InpMS_Log                             = false;  // Log detaliat STRUCTURE_RISK/BREAK/RECOVERY

double InpMS_MinInitialSLPips                = 35.0;  // Monitorizează doar poziții cu SL inițial larg
int    InpMS_LookbackBars                    = 72;    // Bare M5 pentru suport/rezistență locală
int    InpMS_MinTouches                      = 3;     // Minim atingeri la nivel pentru risc structural
int    InpMS_MinBarsBetweenTouches           = 4;     // Separare minimă între atingeri
double InpMS_TouchToleranceATR               = 0.25;  // Cât de aproape de nivel contează ca atingere
double InpMS_NearLevelATR                    = 0.70;  // Intrare considerată aproape de rezistență/suport
double InpMS_MinRejectionWickATR             = 0.12;  // Wick minim pentru respingere

int    InpMS_SwingLeftRight                  = 2;     // Swing fractal: bare stânga/dreapta
double InpMS_CHoCHBreakATR                   = 0.12;  // Break sub/peste swing pentru change of character
double InpMS_ReclaimATR                      = 0.08;  // Reclaim peste/sub nivelul rupt
int    InpMS_MaxBarsToWaitForReclaim         = 4;     // Câte bare așteaptă recuperarea zonei rupte

bool   InpMS_UseFastImpulseAgainst           = true;  // Intră rapid în break dacă impulsul pleacă tare contra poziției
double InpMS_FastImpulseRet3ATR              = 0.70;  // Ret_3/ATR advers minim pentru fast impulse
double InpMS_FastImpulseRet12ATR             = 1.20;  // Ret_12/ATR advers minim pentru fast impulse
int    InpMS_FastReclaimBars                 = 2;     // Pentru fast impulse, câte bare așteaptă reclaim
bool   InpMS_UseVolumeSpikeConfirm           = true;  // Volum peste medie confirmă break-ul/impulsul
int    InpMS_VolumeAvgBars                   = 20;    // Media volumului pentru spike
double InpMS_VolumeSpikeMultiplier           = 1.50;  // Volume[1] > AvgVolume * multiplier

int    InpMS_MinStructureScore               = 5;     // Scor pentru STRUCTURE_RISK
int    InpMS_MinBreakScore                   = 4;     // Scor pentru CONFIRMED_BREAK
double InpMS_StructureRiskSLPips             = 35.0;  // La STRUCTURE_RISK, doar limitează ușor dacă poate
double InpMS_ConfirmedBreakSLPips            = 24.0;  // La break confirmat, SL mai defensiv
bool   InpMS_CloseOnReclaimFail              = false;  // Dacă nu recuperează zona, închide

double InpMS_ProfitStep1Trigger              = 5.0;   // Dacă revine pe profit: lock treptat
double InpMS_ProfitStep1Lock                 = 0.0;
double InpMS_ProfitStep2Trigger              = 10.0;
double InpMS_ProfitStep2Lock                 = 5.0;
double InpMS_ProfitStep3Trigger              = 15.0;
double InpMS_ProfitStep3Lock                 = 10.0;
double InpMS_ProfitStep4Trigger              = 20.0;
double InpMS_ProfitStep4Lock                 = 15.0;


//+------------------------------------------------------------------+
//| HIGH ADX BULLISH PRESSURE WIDE SL SELL FILTER
//| Blocks weak SELL entries with wide SL when bullish pressure is
//| still active in a high-ADX regime.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableHighADXBullishPressureWideSLSellFilter = true;

double InpDynSL_MaxChosenProbForHighADXBullishPressureWideSLSell = 0.50;
double InpDynSL_MaxGapForHighADXBullishPressureWideSLSell        = 0.22;
double InpDynSL_MinSLPipsForHighADXBullishPressureWideSLSell     = 40.0;

double InpDynSL_MinADXForHighADXBullishPressureWideSLSell        = 38.0;
double InpDynSL_MinRet12ATRForHighADXBullishPressureWideSLSell   = 0.80;

double InpDynSL_MinDistResATRForHighADXBullishPressureWideSLSell = 1.0;
double InpDynSL_MaxDistResATRForHighADXBullishPressureWideSLSell = 2.0;

double InpDynSL_MinCCIForHighADXBullishPressureWideSLSell        = 100.0;
double InpDynSL_MinStochForHighADXBullishPressureWideSLSell      = 80.0;

bool   InpDynSL_RequireMACDHistPosForHighADXBullishPressureWideSLSell = true;

bool   InpDynSL_LogHighADXBullishPressureWideSLSellReclassify = false;


//+------------------------------------------------------------------+
//| OVERBOUGHT NEAR RESISTANCE WIDE SL BUY FILTER
//| Blocks weak BUY entries opened very close to resistance,
//| with overbought indicators and wide SL.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableOverboughtNearResistanceWideSLBuyFilter = true;

double InpDynSL_MaxChosenProbForOverboughtNearResistanceWideSLBuy = 0.52;
double InpDynSL_MaxGapForOverboughtNearResistanceWideSLBuy        = 0.23;
double InpDynSL_MinSLPipsForOverboughtNearResistanceWideSLBuy     = 40.0;

double InpDynSL_MinRSIForOverboughtNearResistanceWideSLBuy        = 60.0;
double InpDynSL_MinStochForOverboughtNearResistanceWideSLBuy      = 85.0;
double InpDynSL_MinWPRForOverboughtNearResistanceWideSLBuy        = -10.0;
double InpDynSL_MinCCIForOverboughtNearResistanceWideSLBuy        = 70.0;

double InpDynSL_MaxADXForOverboughtNearResistanceWideSLBuy        = 22.0;
double InpDynSL_MaxDistResATRForOverboughtNearResistanceWideSLBuy = 0.15;
double InpDynSL_MinDistSupATRForOverboughtNearResistanceWideSLBuy = 2.0;

bool   InpDynSL_LogOverboughtNearResistanceWideSLBuyReclassify = false;


//+------------------------------------------------------------------+
//| WEAK LATE BULLISH BREAKOUT WIDE SL BUY FILTER
//| Blocks weak BUY entries after a late bullish push,
//| with high CCI, far support, weak/flat recent returns and wide SL.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableWeakLateBullishBreakoutWideSLBuyFilter = true;

double InpDynSL_MaxChosenProbForWeakLateBullishBreakoutWideSLBuy = 0.52;
double InpDynSL_MaxGapForWeakLateBullishBreakoutWideSLBuy        = 0.22;
double InpDynSL_MinSLPipsForWeakLateBullishBreakoutWideSLBuy     = 40.0;

double InpDynSL_MinCCIForWeakLateBullishBreakoutWideSLBuy        = 150.0;
double InpDynSL_MinADXForWeakLateBullishBreakoutWideSLBuy        = 20.0;
double InpDynSL_MaxADXForWeakLateBullishBreakoutWideSLBuy        = 28.0;

double InpDynSL_MinDistSupATRForWeakLateBullishBreakoutWideSLBuy = 2.0;

double InpDynSL_MaxRet3ForWeakLateBullishBreakoutWideSLBuy       = 0.0;
double InpDynSL_MaxRet12ForWeakLateBullishBreakoutWideSLBuy      = 0.00015;

bool   InpDynSL_RequireMACDHistPosForWeakLateBullishBreakoutWideSLBuy = true;

bool   InpDynSL_LogWeakLateBullishBreakoutWideSLBuyReclassify = false;

//+------------------------------------------------------------------+
//| BULLISH BREAKOUT CONTINUATION WIDE SL SELL FILTER
//+------------------------------------------------------------------+
bool   InpDynSL_BBCS_Enable = true;

double InpDynSL_BBCS_MaxProb    = 0.53;
double InpDynSL_BBCS_MaxGap     = 0.25;
double InpDynSL_BBCS_MinSL      = 40.0;

double InpDynSL_BBCS_MinADX     = 34.0;
double InpDynSL_BBCS_MinCCI     = 120.0;
double InpDynSL_BBCS_MinWPR     = -20.0;

double InpDynSL_BBCS_MinRet3ATR  = 0.20;
double InpDynSL_BBCS_MinRet12ATR = 0.60;

double InpDynSL_BBCS_MaxDistRes = 0.40;

bool   InpDynSL_BBCS_RequireMACDHistPos = true;
bool   InpDynSL_BBCS_Log = false;



bool   InpDynSL_XOFW_Enable = true;
double InpDynSL_XOFW_MaxProb = 0.56;
double InpDynSL_XOFW_MaxGap = 0.32;
double InpDynSL_XOFW_MinSL = 40.0;
double InpDynSL_XOFW_MaxADX = 22.0;
double InpDynSL_XOFW_MaxCCI = -250.0;
double InpDynSL_XOFW_MaxWPR = -95.0;
double InpDynSL_XOFW_MaxDistSup = 1.20;
bool   InpDynSL_XOFW_RequireMACDHistNeg = true;
bool   InpDynSL_XOFW_Log = false;


//+------------------------------------------------------------------+
//| BEARISH CONTINUATION NORMAL WIDE SL BUY FILTER
//| Blocks BUY entries that look normal by DynamicSL, but still have
//| bearish continuation pressure after a weak bounce near support.
//+------------------------------------------------------------------+
bool   InpDynSL_BCNW_Enable = true;
double InpDynSL_BCNW_MaxProb = 0.56;
double InpDynSL_BCNW_MaxGap = 0.25;
double InpDynSL_BCNW_MinSL = 40.0;
double InpDynSL_BCNW_MaxADX = 24.0;
double InpDynSL_BCNW_MaxCCI = -100.0;
double InpDynSL_BCNW_MaxWPR = -70.0;
double InpDynSL_BCNW_MaxStoch = 45.0;
double InpDynSL_BCNW_MaxDistSup = 1.00;
double InpDynSL_BCNW_MinBearishRet12ATR = 1.80;
bool   InpDynSL_BCNW_RequireMACDHistNeg = true;
bool   InpDynSL_BCNW_Log = false;


//+------------------------------------------------------------------+
//| LATE SESSION WEAK WIDE SL BUY FILTER
//| Blocks late-session NORMAL BUY entries with wide SL, weak reversal
//| confirmation and bearish short-term pressure.
//+------------------------------------------------------------------+
bool   InpDynSL_EnableLateSessionWeakWideSLBuyFilter = true;
int    InpDynSL_LateSessionWeakWideSLBuyStartHour = 22;
double InpDynSL_MaxChosenProbForLateSessionWeakWideSLBuy = 0.52;
double InpDynSL_MaxGapForLateSessionWeakWideSLBuy = 0.24;
double InpDynSL_MinSLPipsForLateSessionWeakWideSLBuy = 40.0;
double InpDynSL_MaxADXForLateSessionWeakWideSLBuy = 28.0;
double InpDynSL_MaxCCIForLateSessionWeakWideSLBuy = -80.0;
double InpDynSL_MaxStochForLateSessionWeakWideSLBuy = 20.0;
double InpDynSL_MaxWPRForLateSessionWeakWideSLBuy = -80.0;
double InpDynSL_MinDistSupATRForLateSessionWeakWideSLBuy = 1.20;
double InpDynSL_MinBearishRet12ATRForLateSessionWeakWideSLBuy = 1.50;
bool   InpDynSL_RequireMACDHistNegForLateSessionWeakWideSLBuy = true;
bool   InpDynSL_LogLateSessionWeakWideSLBuyReclassify = false;



#endif // __EA_ML_M5_INPUTS_MQH__

// V5.10.18: mutually exclusive live management modes. Monetary values use account currency.
// Modes 0/1/2 keep their validated behavior unchanged.
// Modes 3/4 add global profit protection alternatives; mode 5 overlays global +10/+5 on RECOVERY_ONLY.
enum ENUM_RECOVERY_MODE
{
   RECOVERY_NORMAL            = 0,
   RECOVERY_ONLY              = 1,
   RECOVERY_WITH_TRAIL        = 2,
   RECOVERY_GLOBAL_LOCK       = 3,
   RECOVERY_GLOBAL_STEP_TRAIL = 4,
   RECOVERY_GLOBAL_LOCK_PLUS_RECOVERY_ONLY = 5
};
input group "Recovery management - LIVE orders"
input ENUM_RECOVERY_MODE InpRecoveryMode=RECOVERY_ONLY;
input bool InpRecoveryScaleWithLot=true;
input double InpRecoveryReferenceLot=0.50;
input double InpRecoveryLossMoney=20.0;
input double InpRecoveryArmMoney=10.0;
input double InpRecoveryFloorMoney=5.0;
input double InpRecoveryMinMinutes=30.0;
input double InpRecoveryTrailMinutes=120.0;
input double InpRecoveryTrailPips=5.0;

input group "Global profit protection - LIVE orders"
// Used by RECOVERY_GLOBAL_LOCK / RECOVERY_GLOBAL_STEP_TRAIL and the combined mode 5.
// Values scale with lot when InpRecoveryScaleWithLot=true.
input double InpGlobalLockTriggerMoney=10.0;   // +10 -> protect +5 by default
input double InpGlobalLockFloorMoney=5.0;
input double InpGlobalStep1TriggerMoney=10.0;  // +10 -> +5
input double InpGlobalStep1FloorMoney=5.0;
input double InpGlobalStep2TriggerMoney=15.0;  // +15 -> +10
input double InpGlobalStep2FloorMoney=10.0;
input double InpGlobalStep3TriggerMoney=20.0;  // +20 -> +15
input double InpGlobalStep3FloorMoney=15.0;

input group "Recovery failure protection - LIVE orders"
input bool   InpRecoveryFailureProtection=true;
input double InpRecoveryFailureDelayMinutes=60.0;
input double InpRecoveryFailureActivationMoney=40.0;
input double InpRecoveryFailureStopMoney=160.0;
input double InpRecoveryFailureWindowMinutes=30.0;
input double InpRecoveryFailureNegativeRatio=0.90;
input double InpRecoveryFailureMaxSlopeMoneyPerMinute=0.0;
input int    InpRecoveryFailureSampleSeconds=60;
