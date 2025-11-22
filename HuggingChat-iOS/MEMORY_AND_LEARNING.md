# Memory & Learning System

This document describes the comprehensive memory and learning system that enables HuggingChat iOS to learn from user behavior, maintain context awareness, and provide proactive assistance.

## 🧠 Overview

The Memory & Learning System consists of four interconnected components:

1. **MemoryManager** - Persistent storage using CoreData
2. **ContextProvider** - Real-time context awareness
3. **UserBehaviorAnalyzer** - Pattern recognition and learning
4. **ProactiveAssistant** - Intelligent suggestions

Together, these create an AI assistant that learns and adapts to help you better over time.

---

## 📦 Component 1: MemoryManager

**Location**: `Memory/MemorySystem.swift`

### Purpose
Persistent storage system for conversations, preferences, patterns, and contextual information using CoreData.

### Features

#### Memory Types
```swift
enum MemoryType {
    case conversation  // Chat messages and topics
    case preference    // User preferences and settings
    case pattern       // Behavioral patterns
    case context       // Contextual information
    case interaction   // User interactions
    case fact          // Extracted facts and insights
    case other         // Miscellaneous
}
```

#### Storage Capabilities
- **Store Memories**: Save any type of information with importance scoring (0.0-1.0)
- **Retrieve by Type**: Get all memories of a specific type
- **Semantic Search**: Find relevant memories using NaturalLanguage framework
- **Tag-Based Search**: Search by multiple tags
- **Conversation Association**: Link memories to specific conversations
- **Importance Weighting**: Prioritize important memories

#### User Feedback Loop
- Mark memories as useful → Increases importance by +0.1
- Mark as not useful → Decreases importance by -0.2
- Auto-cleanup of low-importance old memories

### Usage Examples

```swift
// Store a conversation memory
MemoryManager.shared.storeConversationMemory(
    conversationId: "123",
    content: "Discussion about Swift async/await",
    context: "Programming help",
    importance: 0.7,
    tags: ["swift", "programming", "async"]
)

// Store user preference
MemoryManager.shared.storeUserPreference(
    key: "preferred_model",
    value: "llama-3.1-70b",
    importance: 0.9
)

// Retrieve relevant memories
let memories = MemoryManager.shared.getRelevantMemories(
    for: "async programming",
    limit: 10,
    minImportance: 0.5
)

// Get statistics
let stats = MemoryManager.shared.getMemoryStatistics()
print("Total memories: \(stats.totalMemories)")
print("Average importance: \(stats.averageImportance)")
```

### Data Model

```swift
struct Memory {
    let id: UUID
    let type: MemoryType
    let content: String
    let context: String?
    let timestamp: Date
    var importance: Double // 0.0 to 1.0
    let tags: [String]
    let associatedConversationId: String?
    var userFeedback: UserFeedback?
}
```

### Privacy
- **All data stored locally** on device using CoreData
- **No cloud sync** (can be enabled in future)
- **User control**: Delete all memories or cleanup old ones
- **Exportable**: Export memories to JSON for backup

---

## 📍 Component 2: ContextProvider

**Location**: `Context/ContextProvider.swift`

### Purpose
Provides real-time contextual information from the device and system.

### Capabilities

#### Device Context
```swift
struct DeviceContext {
    let deviceModel: String         // iPhone model
    let osVersion: String           // iOS version
    let batteryLevel: Float         // 0.0 to 1.0
    let isLowPowerMode: Bool        // Power saving
    let networkType: NetworkType    // WiFi/Cellular/Offline
    let timeOfDay: TimeOfDay        // Morning/Afternoon/Evening/Night
    let dayOfWeek: Int              // 1-7
    let clipboardContent: String?   // Current clipboard
}
```

#### Clipboard Monitoring
- **Automatic detection** of clipboard changes
- **History tracking** (last 10 items)
- **Type detection** (text, URL, image)
- **Privacy-conscious**: Can be toggled on/off

#### Context Categories
- **Battery Status**: Detect low battery, suggest power-saving features
- **Network Status**: Suggest offline/local features when offline
- **Time of Day**: Morning/afternoon/evening/night patterns
- **Clipboard**: Detect URLs, code, long text for smart suggestions

### Usage Examples

```swift
// Get current context
let context = ContextProvider.shared.getCurrentContext()

if context.batteryLevel < 0.2 {
    print("Low battery - suggest local model")
}

if context.networkType == .offline {
    print("Offline - enable local-only features")
}

// Get clipboard history
let clipboardHistory = ContextProvider.shared.getClipboardHistory(limit: 5)
for item in clipboardHistory {
    print("Clipboard: \(item.content)")
}

// Start/stop monitoring
ContextProvider.shared.startMonitoring()
ContextProvider.shared.stopMonitoring()
```

### Future Enhancements
- **Screen Content** (iOS 18+): Analyze on-screen content
- **Recent Apps**: Track app usage patterns
- **Location Context**: Time at location for patterns
- **Calendar Integration**: Awareness of meetings/events

---

## 🔍 Component 3: UserBehaviorAnalyzer

**Location**: `Intelligence/UserBehaviorAnalyzer.swift`

### Purpose
Analyzes user behavior to identify patterns and make predictions.

### Capabilities

#### Pattern Detection

**1. Message Sending Patterns**
- Frequency of web search usage
- Attachment usage patterns
- Model preferences
- Time-of-day preferences

**2. Feature Usage Patterns**
- Most-used features
- Underutilized features (for suggestions)
- Feature sequences

**3. Timing Patterns**
- Most active time of day
- Day of week patterns
- Session duration patterns

**4. Model Preferences**
- Favorite model
- Model switching patterns
- Model performance perception

#### Identified Patterns

```swift
struct BehaviorPattern {
    let name: String           // e.g., "frequent_web_search"
    let description: String    // Human-readable description
    let frequency: Double      // 0.0 to 1.0
    let confidence: Double     // 0.0 to 1.0
    let suggestion: String     // Action suggestion
}
```

#### Prediction Engine

```swift
func predictNextAction() -> PredictedAction?
```

Predicts user's next likely action based on:
- Time of day
- Recent actions
- Clipboard content
- Identified patterns

### Usage Examples

```swift
// Track message sent
UserBehaviorAnalyzer.shared.trackMessageSent(
    modelId: "llama-3.1",
    hasWebSearch: true,
    hasAttachments: false,
    timeOfDay: .morning
)

// Track feature used
UserBehaviorAnalyzer.shared.trackFeatureUsed(
    "voice_input",
    context: "successful"
)

// Track preference change
UserBehaviorAnalyzer.shared.trackPreferenceChange(
    key: "default_web_search",
    value: true
)

// Get identified patterns
let patterns = UserBehaviorAnalyzer.shared.identifiedPatterns
for pattern in patterns {
    print("\(pattern.description) - \(pattern.confidence * 100)% confidence")
    print("Suggestion: \(pattern.suggestion)")
}

// Predict next action
if let prediction = UserBehaviorAnalyzer.shared.predictNextAction() {
    print("Predicted: \(prediction.action)")
    print("Reason: \(prediction.reason)")
    print("Confidence: \(prediction.confidence * 100)%")
}
```

### Learning Algorithm

1. **Track Interactions** → Store in memory
2. **Analyze Patterns** → Identify recurring behaviors
3. **Calculate Confidence** → Based on frequency and consistency
4. **Generate Suggestions** → Actionable recommendations
5. **Refine Over Time** → Improve with more data

---

## 💡 Component 4: ProactiveAssistant

**Location**: `Intelligence/ProactiveAssistant.swift`

### Purpose
Generates intelligent, contextual suggestions to help users more efficiently.

### Suggestion Types

```swift
enum SuggestionType {
    case quickAction   // Immediate actions
    case tip           // Helpful tips
    case feature       // Feature discovery
    case preference    // Setting suggestions
    case reminder      // Reminders
}
```

### Suggestion Sources

#### 1. Context-Based Suggestions
- **Low Battery**: Switch to local model
- **Offline**: Enable offline features
- **Time-based**: Good morning routine

#### 2. Pattern-Based Suggestions
- **Frequent web search**: Auto-enable by default
- **Preferred model**: Set as default
- **Frequent attachments**: Suggest Vision features

#### 3. Memory-Based Suggestions
- **Past preferences**: Remind about customizations
- **Frequent topics**: Continue learning about topic
- **Unused features**: Feature discovery

#### 4. Clipboard-Based Suggestions
- **URL detected**: "Ask about this URL"
- **Code detected**: "Explain this code"
- **Long text**: "Summarize clipboard"

### Proactive Suggestions

```swift
struct ProactiveSuggestion {
    let type: SuggestionType
    let title: String
    let description: String
    let action: String
    let relevanceScore: Double  // 0.0 to 1.0
    let icon: String
}
```

### Usage Examples

```swift
// Generate suggestions
let suggestions = ProactiveAssistant.shared.generateSuggestions()

for suggestion in suggestions {
    print("[\(suggestion.type.rawValue)] \(suggestion.title)")
    print("  \(suggestion.description)")
    print("  Relevance: \(suggestion.relevanceScore * 100)%")
}

// Execute suggestion
ProactiveAssistant.shared.executeSuggestion(suggestions.first!)

// Dismiss suggestion
ProactiveAssistant.shared.dismissSuggestion(suggestions.first!)

// Toggle proactive assistant
ProactiveAssistant.shared.toggleProactive(true)
```

### Relevance Scoring

Suggestions are scored based on:
- **Context relevance** (40%)
- **Pattern confidence** (30%)
- **User feedback history** (20%)
- **Timing appropriateness** (10%)

Top 5 suggestions shown at any time.

---

## 🔎 Bonus: Semantic Search

**Location**: `Intelligence/SemanticSearch.swift`

### Purpose
Advanced memory search using NaturalLanguage framework for semantic understanding.

### Features

#### 1. Semantic Similarity
Uses sentence embeddings to find semantically similar memories:

```swift
let results = SemanticSearch.shared.searchMemories(
    query: "async programming",
    in: allMemories,
    limit: 10
)
// Finds: "asynchronous Swift code", "await patterns", "concurrency", etc.
```

#### 2. Keyword Extraction
```swift
let keywords = SemanticSearch.shared.extractKeywords(
    from: "How do I use async/await in Swift?",
    limit: 5
)
// Returns: ["async", "await", "Swift", "use"]
```

#### 3. Memory Clustering
Groups related memories:

```swift
let clusters = SemanticSearch.shared.clusterMemories(memories)
// Groups memories by topic/tag similarity
```

#### 4. Similarity Scoring

```swift
struct ScoredMemory {
    let memory: Memory
    let score: Double        // 0.0 to 1.0
    let matchType: MatchType // semantic/keyword/tag
}
```

### Search Types

- **Semantic**: NaturalLanguage sentence embeddings
- **Keyword**: Word overlap and tag matching (fallback)
- **Tag**: Exact tag matching

### Algorithm

1. **Generate query embedding** using NLEmbedding
2. **Generate embeddings for all memories**
3. **Calculate cosine similarity**
4. **Boost by importance**: `score = similarity * (0.7 + importance * 0.3)`
5. **Sort by score**
6. **Return top N results**

---

## 🖥️ User Interface

### MemoryDashboardView

**Access**: Settings → AI Memory (or dedicated tab)

#### Sections

1. **Memory Statistics**
   - Total memories count
   - Average importance
   - Distribution chart by type

2. **Proactive Suggestions**
   - Current active suggestions
   - Swipe to execute or dismiss
   - Real-time relevance scores

3. **Learned Patterns**
   - Identified behavior patterns
   - Confidence scores
   - Action suggestions

4. **Browse Memories**
   - Filter by type
   - Search with semantic understanding
   - View details and context

5. **Privacy & Control**
   - Toggle proactive assistant
   - Toggle clipboard monitoring
   - Clean up old memories
   - Delete all memories

6. **Data Management**
   - Export memories to JSON
   - Import memories (future)
   - Sync settings (future)

### MemoryBrowserView

**Features**:
- List memories by type
- Semantic search bar
- Relevance scoring display
- Context menus for feedback
- Importance indicators

---

## 🔒 Privacy & Security

### Data Storage
- **100% on-device**: CoreData local database
- **No cloud sync**: All data stays on your device
- **Encrypted**: iOS encrypts app data at rest
- **Sandboxed**: App cannot access other apps' data

### User Control
- **Toggle features**: Turn off any feature anytime
- **Delete data**: Clear specific memories or all data
- **Export option**: Take your data with you
- **Transparent**: View all stored memories

### What's Collected
- ✅ Messages you send (for context)
- ✅ Preferences you set (for personalization)
- ✅ Feature usage (for pattern detection)
- ✅ Clipboard (only when monitoring enabled)
- ❌ NO personal identifiable information
- ❌ NO location data (unless future feature)
- ❌ NO app usage outside HuggingChat

### What's NOT Shared
- Nothing is sent to servers
- Nothing is shared with third parties
- Learning happens entirely on-device
- Memories are never uploaded

---

## 🎯 How It Learns

### Learning Cycle

```
1. User Interaction
   ↓
2. Track & Store
   ↓
3. Analyze Patterns
   ↓
4. Generate Insights
   ↓
5. Proactive Suggestions
   ↓
6. User Feedback
   ↓
(repeat)
```

### Example Learning Scenarios

#### Scenario 1: Web Search Preference
```
Day 1: User enables web search 3 times
Day 2: User enables web search 5 times
Day 3: Pattern detected: "frequent_web_search" (70% frequency)
Day 4: Suggestion: "Auto-enable web search by default?"
User accepts → Preference stored
```

#### Scenario 2: Clipboard Assistance
```
User copies URL
  ↓
Context detects URL in clipboard
  ↓
Suggestion: "Ask about this URL?"
  ↓
User taps → Message pre-filled with URL
  ↓
Track interaction → Learn pattern
```

#### Scenario 3: Model Preference
```
Week 1: User uses Llama 3.1 70% of the time
  ↓
Pattern detected: "preferred_model"
  ↓
Suggestion: "Set Llama 3.1 as default?"
  ↓
User accepts → Auto-select in new chats
```

---

## 📊 Statistics & Insights

### Memory Statistics
```swift
struct MemoryStatistics {
    let totalMemories: Int
    let memoriesByType: [MemoryType: Int]
    let averageImportance: Double
    let totalStorageSize: Int
    let oldestMemory: Date?
    let newestMemory: Date?
}
```

### Behavior Insights
- Most active time of day
- Most used features
- Preferred models
- Topic interests
- Usage patterns

---

## 🚀 Future Enhancements

### Planned Features
- [ ] **iCloud sync** across devices
- [ ] **Conversation summaries** with AI
- [ ] **Smart reminders** based on patterns
- [ ] **Cross-app context** (iOS 18+ Screen Intelligence)
- [ ] **Location-aware** suggestions
- [ ] **Calendar integration** for context
- [ ] **Predictive text** based on writing style
- [ ] **Topic clustering** visualization
- [ ] **Memory importance** auto-tuning with ML
- [ ] **Federated learning** (privacy-preserving collaborative learning)

### Advanced AI Features (iOS 18.1+)
- Apple Intelligence summaries
- On-device LLM for memory analysis
- Automated memory importance scoring
- Natural language memory queries
- Conversation insights generation

---

## 💻 Developer Guide

### Integration Checklist

#### 1. Track User Actions
```swift
// In your view model or view
UserBehaviorAnalyzer.shared.trackFeatureUsed("feature_name")
```

#### 2. Store Important Information
```swift
MemoryManager.shared.storeMemory(Memory(
    type: .conversation,
    content: "Key information",
    context: "Where it came from",
    importance: 0.7,
    tags: ["relevant", "tags"]
))
```

#### 3. Generate Suggestions
```swift
let suggestions = ProactiveAssistant.shared.generateSuggestions()
// Display in UI
```

#### 4. Provide Feedback Loops
```swift
// When user finds suggestion useful
ProactiveAssistant.shared.executeSuggestion(suggestion)

// When user dismisses
ProactiveAssistant.shared.dismissSuggestion(suggestion)
```

### Best Practices

1. **Track Meaningful Actions**: Focus on user intent, not UI events
2. **Set Appropriate Importance**: Higher for explicit preferences (0.7-1.0), lower for inferred patterns (0.3-0.6)
3. **Use Relevant Tags**: Help with search and clustering
4. **Respect Privacy**: Don't store sensitive information
5. **Provide Feedback**: Always give users a way to provide feedback

---

## 🎉 Summary

The Memory & Learning System transforms HuggingChat iOS into an intelligent assistant that:

✅ **Remembers** your preferences and conversations
✅ **Learns** from your behavior patterns
✅ **Adapts** to help you more efficiently
✅ **Suggests** proactive actions
✅ **Understands** context from your device
✅ **Protects** your privacy (100% on-device)
✅ **Improves** over time with use

**The more you use it, the better it gets at helping you!**

---

**Total Components**: 4 core + 1 bonus
**Total Swift Files**: 11
**Lines of Code**: ~3,500+
**Privacy**: 100% on-device
**Learning**: Continuous and adaptive
**User Control**: Complete transparency and control
