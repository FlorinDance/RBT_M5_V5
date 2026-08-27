//+------------------------------------------------------------------+
//| RBT_V58_ModelEngine.mqh                                          |
//| Deterministic reader and inference engine for RBT V5.8.          |
//+------------------------------------------------------------------+
#ifndef RBT_V58_MODEL_ENGINE_MQH
#define RBT_V58_MODEL_ENGINE_MQH

#define RBTV58_MODEL_FORMAT_VERSION 1
#define RBTV58_WORDS_PER_BITSET     8
#define RBTV58_FLAG_LEAF            1
#define RBTV58_FLAG_MISSING_LEFT    2
#define RBTV58_FLAG_CATEGORICAL     4

union SRBTV58DoubleBits
{
   ulong  bits;
   double value;
};

struct SRBTV58Node
{
   int    featureIndex;
   int    leftIndex;
   int    rightIndex;
   int    bitsetIndex;
   uint   flags;
   double threshold;
   double value;
};

struct SRBTV58Tree
{
   int outputIndex;
   int nodeStart;
   int nodeCount;
   int bitsetStart;
   int bitsetCount;
};

bool RBTV58_ReadUInt32(const uchar &bytes[], int &position, uint &value)
{
   if(position < 0 || position + 4 > ArraySize(bytes))
      return false;
   value = (uint)bytes[position]
      | ((uint)bytes[position + 1] << 8)
      | ((uint)bytes[position + 2] << 16)
      | ((uint)bytes[position + 3] << 24);
   position += 4;
   return true;
}

bool RBTV58_ReadInt32(const uchar &bytes[], int &position, int &value)
{
   uint raw = 0;
   if(!RBTV58_ReadUInt32(bytes, position, raw))
      return false;
   value = (int)raw;
   return true;
}

bool RBTV58_ReadDouble(const uchar &bytes[], int &position, double &value)
{
   if(position < 0 || position + 8 > ArraySize(bytes))
      return false;
   ulong raw = 0;
   for(int index = 0; index < 8; index++)
      raw |= ((ulong)bytes[position + index] << (8 * index));
   position += 8;
   SRBTV58DoubleBits converted;
   converted.bits = raw;
   value = converted.value;
   return MathIsValidNumber(value);
}

class CRBTV58Model
{
private:
   int m_rawDimension;
   int m_pcaDimension;
   int m_motifCount;
   int m_decisionDimension;
   int m_classCount;
   int m_wordsPerBitset;
   bool m_loaded;

   double m_scalerMean[];
   double m_scalerScale[];
   double m_pcaProjectedMean[];
   double m_pcaComponents[];
   double m_pcaWhitenScale[];
   double m_motifCenters[];
   double m_classifierBaseline[];
   double m_regressorBaseline;

   SRBTV58Tree m_classifierTrees[];
   SRBTV58Tree m_regressorTrees[];
   SRBTV58Node m_classifierNodes[];
   SRBTV58Node m_regressorNodes[];
   uint m_classifierBitsets[];
   uint m_regressorBitsets[];

   bool ReadDoubleArray(const uchar &bytes[], int &position,
                        double &destination[], const int count)
   {
      if(count < 0 || ArrayResize(destination, count) != count)
         return false;
      for(int index = 0; index < count; index++)
      {
         if(!RBTV58_ReadDouble(bytes, position, destination[index]))
            return false;
      }
      return true;
   }

   bool ReadTreeGroup(const uchar &bytes[], int &position,
                      SRBTV58Tree &trees[], SRBTV58Node &nodes[], uint &bitsets[],
                      const int treeCount, const int expectedNodeCount,
                      const int expectedBitsetCount)
   {
      if(treeCount < 0 || expectedNodeCount < 0 || expectedBitsetCount < 0)
         return false;
      if(ArrayResize(trees, treeCount) != treeCount ||
         ArrayResize(nodes, expectedNodeCount) != expectedNodeCount ||
         ArrayResize(bitsets, expectedBitsetCount * m_wordsPerBitset) !=
            expectedBitsetCount * m_wordsPerBitset)
         return false;

      int nodeCursor = 0;
      int bitsetCursor = 0;
      for(int treeIndex = 0; treeIndex < treeCount; treeIndex++)
      {
         int outputIndex = 0;
         uint nodeCountRaw = 0;
         uint bitsetCountRaw = 0;
         if(!RBTV58_ReadInt32(bytes, position, outputIndex) ||
            !RBTV58_ReadUInt32(bytes, position, nodeCountRaw) ||
            !RBTV58_ReadUInt32(bytes, position, bitsetCountRaw))
            return false;
         const int nodeCount = (int)nodeCountRaw;
         const int bitsetCount = (int)bitsetCountRaw;
         if(nodeCount <= 0 || bitsetCount < 0 ||
            nodeCursor + nodeCount > expectedNodeCount ||
            bitsetCursor + bitsetCount * m_wordsPerBitset > ArraySize(bitsets))
            return false;

         trees[treeIndex].outputIndex = outputIndex;
         trees[treeIndex].nodeStart = nodeCursor;
         trees[treeIndex].nodeCount = nodeCount;
         trees[treeIndex].bitsetStart = bitsetCursor;
         trees[treeIndex].bitsetCount = bitsetCount;

         for(int localNode = 0; localNode < nodeCount; localNode++)
         {
            SRBTV58Node node;
            if(!RBTV58_ReadInt32(bytes, position, node.featureIndex) ||
               !RBTV58_ReadInt32(bytes, position, node.leftIndex) ||
               !RBTV58_ReadInt32(bytes, position, node.rightIndex) ||
               !RBTV58_ReadInt32(bytes, position, node.bitsetIndex) ||
               !RBTV58_ReadUInt32(bytes, position, node.flags) ||
               !RBTV58_ReadDouble(bytes, position, node.threshold) ||
               !RBTV58_ReadDouble(bytes, position, node.value))
               return false;
            nodes[nodeCursor + localNode] = node;
         }
         nodeCursor += nodeCount;

         const int words = bitsetCount * m_wordsPerBitset;
         for(int word = 0; word < words; word++)
         {
            if(!RBTV58_ReadUInt32(bytes, position, bitsets[bitsetCursor + word]))
               return false;
         }
         bitsetCursor += words;
      }
      return (nodeCursor == expectedNodeCount &&
              bitsetCursor == expectedBitsetCount * m_wordsPerBitset);
   }

   double TreeValue(const SRBTV58Tree &tree, const SRBTV58Node &nodes[],
                    const uint &bitsets[], const double &features[]) const
   {
      int localIndex = 0;
      while(localIndex >= 0 && localIndex < tree.nodeCount)
      {
         const SRBTV58Node node = nodes[tree.nodeStart + localIndex];
         if((node.flags & RBTV58_FLAG_LEAF) != 0)
            return node.value;
         if(node.featureIndex < 0 || node.featureIndex >= ArraySize(features))
            return 0.0;

         const double feature = features[node.featureIndex];
         bool goLeft = false;
         if(!MathIsValidNumber(feature))
         {
            goLeft = ((node.flags & RBTV58_FLAG_MISSING_LEFT) != 0);
         }
         else if((node.flags & RBTV58_FLAG_CATEGORICAL) != 0)
         {
            const int category = (int)feature;
            if(category >= 0 && category < m_wordsPerBitset * 32 &&
               node.bitsetIndex >= 0 && node.bitsetIndex < tree.bitsetCount)
            {
               const int wordIndex = tree.bitsetStart
                  + node.bitsetIndex * m_wordsPerBitset + category / 32;
               const uint mask = ((uint)1 << (category % 32));
               goLeft = ((bitsets[wordIndex] & mask) != 0);
            }
            else
            {
               goLeft = ((node.flags & RBTV58_FLAG_MISSING_LEFT) != 0);
            }
         }
         else
         {
            goLeft = (feature <= node.threshold);
         }
         localIndex = (goLeft ? node.leftIndex : node.rightIndex);
      }
      return 0.0;
   }

public:
   CRBTV58Model(void)
   {
      m_loaded = false;
      m_rawDimension = 0;
      m_pcaDimension = 0;
      m_motifCount = 0;
      m_decisionDimension = 0;
      m_classCount = 0;
      m_wordsPerBitset = 0;
      m_regressorBaseline = 0.0;
   }

   bool Load(const uchar &bytes[])
   {
      m_loaded = false;
      if(ArraySize(bytes) < 60)
         return false;
      const uchar expectedMagic[8] = {'R','B','T','V','5','8','M','1'};
      for(int index = 0; index < 8; index++)
      {
         if(bytes[index] != expectedMagic[index])
            return false;
      }
      int position = 8;
      uint version = 0, rawDimension = 0, pcaDimension = 0, motifCount = 0;
      uint decisionDimension = 0, classCount = 0, classifierTreeCount = 0;
      uint regressorTreeCount = 0, wordsPerBitset = 0;
      uint classifierNodeCount = 0, classifierBitsetCount = 0;
      uint regressorNodeCount = 0, regressorBitsetCount = 0;
      if(!RBTV58_ReadUInt32(bytes, position, version) ||
         !RBTV58_ReadUInt32(bytes, position, rawDimension) ||
         !RBTV58_ReadUInt32(bytes, position, pcaDimension) ||
         !RBTV58_ReadUInt32(bytes, position, motifCount) ||
         !RBTV58_ReadUInt32(bytes, position, decisionDimension) ||
         !RBTV58_ReadUInt32(bytes, position, classCount) ||
         !RBTV58_ReadUInt32(bytes, position, classifierTreeCount) ||
         !RBTV58_ReadUInt32(bytes, position, regressorTreeCount) ||
         !RBTV58_ReadUInt32(bytes, position, wordsPerBitset) ||
         !RBTV58_ReadUInt32(bytes, position, classifierNodeCount) ||
         !RBTV58_ReadUInt32(bytes, position, classifierBitsetCount) ||
         !RBTV58_ReadUInt32(bytes, position, regressorNodeCount) ||
         !RBTV58_ReadUInt32(bytes, position, regressorBitsetCount))
         return false;

      if(version != RBTV58_MODEL_FORMAT_VERSION || rawDimension != 254 ||
         pcaDimension != 16 || motifCount != 128 || decisionDimension != 31 ||
         classCount != 3 || classifierTreeCount != 480 ||
         regressorTreeCount != 160 || wordsPerBitset != RBTV58_WORDS_PER_BITSET)
         return false;

      m_rawDimension = (int)rawDimension;
      m_pcaDimension = (int)pcaDimension;
      m_motifCount = (int)motifCount;
      m_decisionDimension = (int)decisionDimension;
      m_classCount = (int)classCount;
      m_wordsPerBitset = (int)wordsPerBitset;

      if(!ReadDoubleArray(bytes, position, m_scalerMean, m_rawDimension) ||
         !ReadDoubleArray(bytes, position, m_scalerScale, m_rawDimension) ||
         !ReadDoubleArray(bytes, position, m_pcaProjectedMean, m_pcaDimension) ||
         !ReadDoubleArray(bytes, position, m_pcaComponents,
                          m_pcaDimension * m_rawDimension) ||
         !ReadDoubleArray(bytes, position, m_pcaWhitenScale, m_pcaDimension) ||
         !ReadDoubleArray(bytes, position, m_motifCenters,
                          m_motifCount * m_pcaDimension) ||
         !ReadDoubleArray(bytes, position, m_classifierBaseline, m_classCount) ||
         !RBTV58_ReadDouble(bytes, position, m_regressorBaseline))
         return false;

      if(!ReadTreeGroup(bytes, position, m_classifierTrees, m_classifierNodes,
                        m_classifierBitsets, (int)classifierTreeCount,
                        (int)classifierNodeCount, (int)classifierBitsetCount) ||
         !ReadTreeGroup(bytes, position, m_regressorTrees, m_regressorNodes,
                        m_regressorBitsets, (int)regressorTreeCount,
                        (int)regressorNodeCount, (int)regressorBitsetCount))
         return false;
      if(position != ArraySize(bytes))
         return false;
      m_loaded = true;
      return true;
   }

   bool IsLoaded(void) const { return m_loaded; }
   int RawDimension(void) const { return m_rawDimension; }
   int DecisionDimension(void) const { return m_decisionDimension; }

   bool Discover(const double &rawFeatures[], int &motifId, double &embedding[],
                 double &motifDistance, double &motifMargin) const
   {
      if(!m_loaded || ArraySize(rawFeatures) != m_rawDimension)
         return false;
      if(ArrayResize(embedding, m_pcaDimension) != m_pcaDimension)
         return false;

      double scaled[];
      if(ArrayResize(scaled, m_rawDimension) != m_rawDimension)
         return false;
      for(int feature = 0; feature < m_rawDimension; feature++)
      {
         if(!MathIsValidNumber(rawFeatures[feature]) ||
            m_scalerScale[feature] <= 0.0)
            return false;
         scaled[feature] = (rawFeatures[feature] - m_scalerMean[feature])
            / m_scalerScale[feature];
      }

      for(int component = 0; component < m_pcaDimension; component++)
      {
         double projected = 0.0;
         const int offset = component * m_rawDimension;
         for(int feature = 0; feature < m_rawDimension; feature++)
            projected += scaled[feature] * m_pcaComponents[offset + feature];
         projected -= m_pcaProjectedMean[component];
         if(m_pcaWhitenScale[component] <= 0.0)
            return false;
         embedding[component] = projected / m_pcaWhitenScale[component];
      }

      motifId = -1;
      double nearest = 1.0e308;
      double second = 1.0e308;
      for(int motif = 0; motif < m_motifCount; motif++)
      {
         double squared = 0.0;
         const int offset = motif * m_pcaDimension;
         for(int component = 0; component < m_pcaDimension; component++)
         {
            const double delta = embedding[component]
               - m_motifCenters[offset + component];
            squared += delta * delta;
         }
         const double distance = MathSqrt(MathMax(0.0, squared));
         if(distance < nearest)
         {
            second = nearest;
            nearest = distance;
            motifId = motif;
         }
         else if(distance < second)
         {
            second = distance;
         }
      }
      if(motifId < 0 || !MathIsValidNumber(nearest) || !MathIsValidNumber(second))
         return false;
      motifDistance = nearest;
      motifMargin = second - nearest;
      return true;
   }

   bool Predict(const double &features[], double &pDown, double &pNone,
                double &pUp, double &predictedReturn) const
   {
      if(!m_loaded || ArraySize(features) != m_decisionDimension)
         return false;
      double raw[3];
      for(int classIndex = 0; classIndex < 3; classIndex++)
         raw[classIndex] = m_classifierBaseline[classIndex];
      for(int treeIndex = 0; treeIndex < ArraySize(m_classifierTrees); treeIndex++)
      {
         const int output = m_classifierTrees[treeIndex].outputIndex;
         if(output < 0 || output >= 3)
            return false;
         raw[output] += TreeValue(m_classifierTrees[treeIndex], m_classifierNodes,
                                  m_classifierBitsets, features);
      }

      predictedReturn = m_regressorBaseline;
      for(int treeIndex = 0; treeIndex < ArraySize(m_regressorTrees); treeIndex++)
         predictedReturn += TreeValue(m_regressorTrees[treeIndex], m_regressorNodes,
                                      m_regressorBitsets, features);

      const double maximum = MathMax(raw[0], MathMax(raw[1], raw[2]));
      const double downValue = MathExp(raw[0] - maximum);
      const double noneValue = MathExp(raw[1] - maximum);
      const double upValue = MathExp(raw[2] - maximum);
      const double total = downValue + noneValue + upValue;
      if(total <= 0.0 || !MathIsValidNumber(total) ||
         !MathIsValidNumber(predictedReturn))
         return false;
      pDown = downValue / total;
      pNone = noneValue / total;
      pUp = upValue / total;
      return true;
   }
};

#endif
