#ifndef __RBT_V2_TYPES_MQH__
#define __RBT_V2_TYPES_MQH__

enum ERBTExecutionMode
{
   RBT_MODE_DIAGNOSTIC = 0,
   RBT_MODE_DATASET_EXPORT = 1,
   RBT_MODE_TRADE = 2
};

enum ERBTDirection
{
   RBT_DIR_SELL = -1,
   RBT_DIR_HOLD = 0,
   RBT_DIR_BUY  = 1
};

enum ERBTStructureDirection
{
   RBT_STRUCTURE_BEARISH = -1,
   RBT_STRUCTURE_NEUTRAL = 0,
   RBT_STRUCTURE_BULLISH = 1
};

enum ERBTPivotKind
{
   RBT_PIVOT_NONE = 0,
   RBT_PIVOT_HIGH = 1,
   RBT_PIVOT_LOW  = 2
};

enum ERBTSwingType
{
   RBT_SWING_NONE = 0,
   RBT_SWING_HH,
   RBT_SWING_HL,
   RBT_SWING_LH,
   RBT_SWING_LL,
   RBT_SWING_EQUAL_HIGH,
   RBT_SWING_EQUAL_LOW
};

enum ERBTTradeState
{
   RBT_TRADE_NONE = 0,
   RBT_TRADE_ENTRY,
   RBT_TRADE_ACTIVE,
   RBT_TRADE_NORMAL_PULLBACK,
   RBT_TRADE_FAVORABLE_IMPULSE,
   RBT_TRADE_PROTECTED,
   RBT_TRADE_STRUCTURE_WARNING,
   RBT_TRADE_INVALIDATED,
   RBT_TRADE_EXIT
};

enum ERBTBinaryLabel
{
   RBT_LABEL_CENSORED = -1,
   RBT_LABEL_LOSS = 0,
   RBT_LABEL_WIN = 1
};

struct SRuntimeState
{
   bool ready;
   bool selfTestsPassed;
   bool tradingUnlocked;
   datetime lastSeenBarTime;
   datetime lastProcessedBarTime;
   datetime initializedAt;
   long processedBars;
   string lastError;
};

struct SMarketDataCache
{
   MqlRates rates[];
   int requestedBars;
   int loadedBars;
   datetime refreshedAt;
   bool valid;
   string error;
};

struct SIndicatorHandles
{
   int atr;
   int rsi;
   int macd;
   int adx;
   int ema9;
   int ema20;
   int ema50;
   int ema100;
   int bands;
};

struct SIndicatorSnapshot
{
   datetime barTime;
   int shift;

   double atr;
   double rsi;
   double macd;
   double macdSignal;
   double macdHistogram;
   double adx;
   double plusDI;
   double minusDI;

   double ema9;
   double ema20;
   double ema50;
   double ema100;
   double ema9SlopeATR;
   double ema20SlopeATR;
   double ema50SlopeATR;
   double ema100SlopeATR;

   double bbUpper;
   double bbMiddle;
   double bbLower;
   double bbWidthATR;
   double bbPosition;

   double momentum14Price;
   double momentum14ATR;
   double volumeRatio20;
   double volumeZScore20;

   bool valid;
   string error;
};

struct SSwingPoint
{
   datetime time;
   int shift;
   int kind;
   int classification;
   double price;
   double atr;
   double prominenceATR;
};

struct SSwingSeries
{
   SSwingPoint points[];
   int count;
   int pivotBars;
   double minSwingATR;
   double equalToleranceATR;
   bool valid;
   string error;
};

struct SStructureLayerSnapshot
{
   int direction;
   int lastSwingType;

   double lastHigh;
   double lastLow;
   datetime lastHighTime;
   datetime lastLowTime;
   int lastHighShift;
   int lastLowShift;

   int bullishCount;
   int bearishCount;
   int barsSinceHigh;
   int barsSinceLow;

   bool bullishBOS;
   bool bearishBOS;
   bool bullishCHOCH;
   bool bearishCHOCH;
   int barsSinceBullishBOS;
   int barsSinceBearishBOS;
   int barsSinceBullishCHOCH;
   int barsSinceBearishCHOCH;
   double lastBOSStrengthATR;
   double lastBOSBodyStrength;
   double lastCHOCHStrengthATR;
   double breakStrengthATR;
   double breakBodyStrength;

   bool valid;
   string error;
};

struct SStructureSnapshot
{
   SStructureLayerSnapshot internalLayer;
   SStructureLayerSnapshot externalLayer;

   int alignment;
   double pullbackDepth;
   int pullbackBars;
   double pullbackVelocity;
   double rangePosition;
   double impulseSizeATR;
   int impulseBars;
   double impulseVelocity;
   double impulseEfficiency;

   bool valid;
   string error;
};

struct SPriceZone
{
   int kind;
   double center;
   double lower;
   double upper;
   int touches;
   int newestShift;
   int oldestShift;
   double reactionATR;
   bool valid;
};

struct SZoneSnapshot
{
   SPriceZone support;
   SPriceZone resistance;
   int supportZoneCount;
   int resistanceZoneCount;
   double distanceSupportATR;
   double distanceResistanceATR;
   double supportFreshness;
   double resistanceFreshness;
   double equalHighsStrength;
   double equalLowsStrength;
   bool bullishLiquiditySweep;
   bool bearishLiquiditySweep;
   bool bullishBreakRetest;
   bool bearishBreakRetest;
   double roomUpATR;
   double roomDownATR;
   bool valid;
   string error;
};

struct SFeatureDiagnostics
{
   double minimum;
   double maximum;
   double meanAbsolute;
   double checksum;
   int finiteCount;
   bool valid;
   string error;
};

struct SFeatureVector
{
   double values[];
   int count;
   int schemaVersion;
   bool valid;
   string error;
};

struct SMLPrediction
{
   double pSell;
   double pHold;
   double pBuy;
   double pTradeSuccess;
   double expectedMFE_R;
   double expectedMAE_R;
   double calibratedConfidence;
   double entropy;
   double decisionGap;
   int direction;
   bool valid;
   string error;
};

struct STradeCandidate
{
   int direction;
   double entryPrice;
   double stopLoss;
   double takeProfit;
   double riskPips;
   double rewardPips;
   double riskReward;
   double expectedValueR;
   double confidence;
   bool accepted;
   string rejectionReason;
};

struct SDatasetLabels
{
   datetime decisionTime;
   datetime entryTime;
   double decisionClose;
   double entryBid;
   double entryAsk;
   double atrPrice;
   double atrPips;
   double spreadPips;

   int directionLabel;
   int directionHitBars;
   bool directionAmbiguous;

   int buyQualityLabel;
   int buyHitBars;
   bool buyAmbiguous;

   int sellQualityLabel;
   int sellHitBars;
   bool sellAmbiguous;

   double buyMFE_ATR;
   double buyMAE_ATR;
   double buyMFE_R;
   double buyMAE_R;
   double sellMFE_ATR;
   double sellMAE_ATR;
   double sellMFE_R;
   double sellMAE_R;
   double buyHorizonReturnR;
   double sellHorizonReturnR;

   bool valid;
   string error;
};

struct SDatasetExporterState
{
   bool initialized;
   bool active;
   bool completed;
   bool failed;
   int fileHandle;
   string fileName;
   string fullPath;
   string manifestFileName;
   string manifestFullPath;
   datetime startedAt;
   datetime finishedAt;
   long startedWallMs;
   long finishedWallMs;
   int sourceBarsLoaded;
   int sourceLoadAttempts;
   datetime lastVisitedDecisionTime;
   bool startCoverageValidated;
   bool endCoverageValidated;

   datetime availableOldestDecisionTime;
   datetime availableNewestDecisionTime;
   datetime selectedOldestDecisionTime;
   datetime selectedNewestDecisionTime;
   datetime firstWrittenDecisionTime;
   datetime lastWrittenDecisionTime;

   int oldestDecisionShift;
   int newestDecisionShift;
   int currentDecisionShift;
   int candidatesVisited;
   int rowsWritten;
   int rowsSkipped;
   int rowsCensored;
   int rowErrors;
   double lastProgressPercent;
   string completionReason;
   string lastError;
};


enum ERBTSetupType
{
   RBT_SETUP_NONE = 0,
   RBT_SETUP_TREND_PULLBACK = 1,
   RBT_SETUP_BOS_RETEST = 2,
   RBT_SETUP_CHOCH_RETEST = 3,
   RBT_SETUP_SWEEP_RECLAIM = 4
};

enum ERBTTargetSource
{
   RBT_TARGET_NONE = 0,
   RBT_TARGET_NEAREST_ZONE = 1,
   RBT_TARGET_EXTERNAL_SWING = 2,
   RBT_TARGET_R_CAP = 3
};

enum ERBTEventExitReason
{
   RBT_EVENT_EXIT_NONE = 0,
   RBT_EVENT_EXIT_TARGET = 1,
   RBT_EVENT_EXIT_STOP = 2,
   RBT_EVENT_EXIT_TIMEOUT = 3,
   RBT_EVENT_EXIT_AMBIGUOUS = 4
};

enum ERBTEventBuildResult
{
   RBT_EVENT_BUILD_ERROR = -1,
   RBT_EVENT_BUILD_NO_SETUP = 0,
   RBT_EVENT_BUILD_PLAN_REJECTED = 1,
   RBT_EVENT_BUILD_READY = 2
};

enum ERBTSetupConfluence
{
   RBT_CONF_EXTERNAL_ALIGNED = 1,
   RBT_CONF_INTERNAL_ALIGNED = 2,
   RBT_CONF_NEAR_ZONE = 4,
   RBT_CONF_BOS = 8,
   RBT_CONF_CHOCH = 16,
   RBT_CONF_SWEEP = 32,
   RBT_CONF_RETEST = 64,
   RBT_CONF_DISPLACEMENT = 128
};

struct SSetupEvent
{
   int type;
   int direction;
   datetime eventTime;
   datetime confirmationTime;
   double eventLevel;
   double invalidationReference;
   double targetReference;
   double eventStrengthATR;
   double confirmationBodyStrength;
   double confirmationCloseLocation;
   double retestQuality;
   int originAgeBars;
   int confluenceMask;
   int externalDirection;
   int internalDirection;
   int alignment;
   double pullbackDepth;
   int pullbackBars;
   bool valid;
   string rejectionReason;
};

struct SStructuralTradePlan
{
   int direction;
   datetime decisionTime;
   datetime entryTime;
   double entryBid;
   double entryAsk;
   double entryPrice;
   double stopLoss;
   double takeProfit;
   double riskPrice;
   double rewardPrice;
   double riskPips;
   double rewardPips;
   double stopATR;
   double targetATR;
   double riskRewardGross;
   double costR;
   double winNetR;
   double lossNetR;
   int targetSource;
   bool accepted;
   string rejectionReason;
};

struct SEventLabel
{
   int label;
   int hitBars;
   int exitReason;
   datetime exitTime;
   bool ambiguous;
   double realizedR;
   double mfeR;
   double maeR;
   double horizonReturnR;
   bool valid;
   string error;
};

struct SEventDatasetExporterState
{
   bool initialized;
   bool active;
   bool completed;
   bool failed;
   int fileHandle;
   string fileName;
   string fullPath;
   string manifestFileName;
   string manifestFullPath;
   datetime startedAt;
   datetime finishedAt;
   long startedWallMs;
   long finishedWallMs;
   datetime lastVisitedDecisionTime;
   datetime firstWrittenDecisionTime;
   datetime lastWrittenDecisionTime;
   datetime lastEventTimeByKey[8];
   int sourceBarsLoaded;
   int sourceRefreshes;
   int barsScanned;
   int setupsDetected;
   int plansRejected;
   int cooldownSkipped;
   int rowsWritten;
   int rowsCensored;
   int rowErrors;
   int trendPullbackRows;
   int bosRetestRows;
   int chochRetestRows;
   int sweepReclaimRows;
   int buyRows;
   int sellRows;
   int winRows;
   int lossRows;
   double lastProgressPercent;
   string completionReason;
   string lastError;
};

#endif
