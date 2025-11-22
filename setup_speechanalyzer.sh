#!/bin/bash

# Setup script for SpeechAnalyzer integration
# This script helps verify and complete the integration

set -e

echo "🎤 SpeechAnalyzer & Foundation Models Integration Setup"
echo "======================================================"
echo ""

# Check macOS version
echo "Checking macOS version..."
sw_vers -productVersion
echo ""

# Check for required files
echo "Verifying new files exist..."
FILES=(
    "HuggingChat-Mac/LocalSTT/SpeechAnalyzerService.swift"
    "HuggingChat-Mac/LocalSTT/SummarizationService.swift"
    "HuggingChat-Mac/Views/TranscriptionSummaryView.swift"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ Missing: $file"
        exit 1
    fi
done
echo ""

# Check modified files
echo "Verifying modified files..."
MODIFIED=(
    "HuggingChat-Mac/LocalSTT/AudioModelManager.swift"
    "HuggingChat-Mac/Views/ConversationView.swift"
    "HuggingChat-Mac/Settings/DictationSettings.swift"
)

for file in "${MODIFIED[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ Missing: $file"
        exit 1
    fi
done
echo ""

# Git status
echo "Git status:"
git status --short
echo ""

# Instructions
echo "📝 Next Steps:"
echo ""
echo "1. Open HuggingChat-Mac.xcodeproj in Xcode"
echo ""
echo "2. Add new Swift files to the project:"
echo "   • Right-click 'LocalSTT' → Add Files..."
echo "   • Add: SpeechAnalyzerService.swift, SummarizationService.swift"
echo "   • Right-click 'Views' → Add Files..."
echo "   • Add: TranscriptionSummaryView.swift"
echo ""
echo "3. Build the project (⌘B)"
echo ""
echo "4. Test the integration:"
echo "   • Go to Settings → Dictation"
echo "   • Enable 'Use Apple SpeechAnalyzer'"
echo "   • Click microphone button and speak"
echo "   • Verify transcription and summary appear"
echo ""
echo "5. Read SPEECHANALYZER_INTEGRATION.md for detailed documentation"
echo ""
echo "✨ Integration files are ready!"
echo ""
