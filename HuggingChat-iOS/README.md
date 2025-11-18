# HuggingChat iOS

An iOS SwiftUI app with feature parity to the HuggingChat macOS app, providing a native chat interface for HuggingFace's open-source AI models.

## Features

### Core Features
- **Multi-conversation support**: Create, browse, and manage multiple chat conversations
- **Real-time streaming**: Stream responses from AI models in real-time
- **Web search integration**: Get search-augmented responses with source attribution
- **File attachment support**: Upload images and files for context
- **Message history**: Persistent conversation storage both locally and server-side
- **Model switching**: Choose from multiple LLM models via HuggingFace API

### Advanced Features
- **Local LLM inference**: Run models on-device using MLX Swift (Qwen2.5-3B, SmolLM-135M)
- **Speech-to-text**: Real-time voice transcription using WhisperKit
- **Markdown rendering**: Full markdown support with syntax highlighting for code blocks
- **Multiple themes**: Choose from Default, McIntosh Classic, Pixel Pals, and 404 themes
- **Native iOS design**: Optimized for both iPhone and iPad with adaptive layouts

### iOS-Specific Features
- **OAuth authentication**: Secure sign-in with ASWebAuthenticationSession
- **TabView navigation**: Intuitive tab-based navigation (Chats, Models, Settings)
- **Photo picker integration**: Native iOS photo picker for attachments
- **Swipe actions**: Delete conversations with swipe gestures
- **Pull to refresh**: Refresh conversation list with pull-to-refresh gesture
- **Keyboard management**: Smart keyboard handling and focus management

## Requirements

- iOS 17.0 or later
- Xcode 16.0 or later
- Swift 6.0
- HuggingFace account for authentication

## Installation

### Using Xcode

1. Clone this repository:
```bash
git clone <repository-url>
cd chat-macOS/HuggingChat-iOS
```

2. Open `HuggingChat-iOS.xcodeproj` in Xcode

3. Select your target device or simulator

4. Build and run (⌘R)

### Using Swift Package Manager

The project uses SPM for dependency management. Dependencies will be automatically resolved when you build the project.

## Dependencies

- **MLX Swift**: On-device LLM inference using Apple's Metal framework
- **WhisperKit**: Speech-to-text transcription using CoreML
- **MarkdownUI**: Markdown rendering with syntax highlighting
- **Pow**: Powerful animations and transitions
- **Transformers**: HuggingFace model utilities

## Architecture

### MVVM + Coordinator Pattern
- **Models**: Data structures (Message, Conversation, LLMModel, HuggingChatUser)
- **ViewModels**: Observable state managers (@Observable)
  - `ConversationViewModel`: Manages chat state and message streaming
  - `MenuViewModel`: Handles conversation list and grouping
  - `ModelManager`: Local model management
  - `AudioModelManager`: Speech recognition
  - `ThemingEngine`: Theme management
  - `CoordinatorModel`: Authentication flow
- **Views**: SwiftUI views
- **Network**: API service layer

### Key Components

#### Authentication Flow
1. User taps "Sign in with HuggingFace"
2. ASWebAuthenticationSession opens OAuth flow
3. Callback URL captured with code and state
4. Token exchanged and stored in UserDefaults
5. User info fetched and session established

#### Message Streaming
1. User sends message
2. POST request to `/chat/conversation/{id}`
3. Server-Sent Events (SSE) stream tokens
4. UI updates incrementally with each token
5. Completed message stored in conversation

#### Local Model Inference
1. User selects local model from Models tab
2. Model downloaded from HuggingFace Hub
3. MLX loads model for Metal GPU acceleration
4. Generate text using on-device inference
5. Stream results back to UI

## Project Structure

```
HuggingChat-iOS/
├── HuggingChatApp.swift          # App entry point
├── Models/                       # Data models
│   ├── HuggingChatUser.swift
│   ├── Conversation.swift
│   ├── Message.swift
│   ├── LLMModel.swift
│   ├── LocalModel.swift
│   └── HuggingChatSession.swift
├── ViewModels/                   # State management
│   ├── CoordinatorModel.swift
│   ├── ConversationViewModel.swift
│   ├── MenuViewModel.swift
│   ├── ModelManager.swift
│   ├── AudioModelManager.swift
│   └── ThemingEngine.swift
├── Views/                        # UI components
│   ├── OnboardingView.swift
│   ├── MainTabView.swift
│   ├── ConversationsView.swift
│   ├── ChatDetailView.swift
│   ├── InputView.swift
│   ├── ModelsView.swift
│   ├── SettingsView.swift
│   ├── MarkdownMessageView.swift
│   └── NewConversationSheet.swift
├── Network/                      # API layer
│   ├── NetworkService.swift
│   └── HFError.swift
├── Extensions/                   # Utility extensions
│   └── Date+Extensions.swift
├── Animations/                   # Custom animations
│   └── LoadingIndicator.swift
└── Info.plist                    # App configuration
```

## Usage

### First Launch

1. Launch the app
2. Tap "Sign in with HuggingFace"
3. Complete OAuth authentication
4. Grant permissions if prompted

### Creating a New Chat

1. Tap the compose icon (top-right)
2. Select a model from the list
3. Tap "Create"
4. Start chatting!

### Sending Messages

1. Type your message in the input field
2. Toggle "Web Search" for search-augmented responses
3. Tap the photo icon to attach images
4. Tap the mic icon for voice input
5. Tap send (↑) to send

### Using Local Models

1. Navigate to "Models" tab
2. Scroll to "Local Models" section
3. Tap download icon next to a model
4. Wait for download to complete
5. Toggle "Local" in chat input to use local generation

### Voice Input

1. Navigate to Settings > Voice
2. Tap "Load Whisper Model"
3. In chat, tap the microphone icon
4. Speak your message
5. Tap stop to transcribe

### Changing Themes

1. Navigate to Settings
2. Tap "Theme"
3. Select your preferred theme
4. Theme applies immediately

## iPad Support

The app includes iPad-specific optimizations:
- Larger layout for conversation list
- Side-by-side navigation on larger screens
- Optimized touch targets
- Landscape mode support

## API Endpoints

The app communicates with HuggingFace Chat API:

- **Base URL**: `https://huggingface.co` (configurable)
- **Authentication**: Cookie-based (`hf-chat`)
- **Conversations**: `/chat/api/conversations`
- **Models**: `/chat/api/models`
- **Messages**: `/chat/conversation/{id}` (SSE streaming)

## Privacy

- All authentication tokens stored securely in UserDefaults
- No data collection or analytics
- Local models run entirely on-device
- Speech recognition performed locally via CoreML

## Differences from macOS App

### Replaced Features
- **Floating panel** → TabView navigation
- **Menu bar integration** → Standard iOS app
- **Keyboard shortcuts** → Touch gestures and buttons
- **Auto-updates (Sparkle)** → App Store updates

### iOS-Specific Additions
- **ASWebAuthenticationSession** for OAuth
- **PhotosPicker** for attachments
- **Swipe actions** for deletion
- **Pull-to-refresh** for conversations
- **Adaptive layouts** for iPhone/iPad

### Maintained Features
- All core chat functionality
- Local LLM inference with MLX
- Speech-to-text with WhisperKit
- Markdown rendering
- Theme engine
- Web search integration
- Model management

## Future Enhancements

- [ ] Widget support for recent conversations
- [ ] Share extension for sharing to HuggingChat
- [ ] Siri shortcuts integration
- [ ] iCloud sync for conversations
- [ ] iPad split view for multitasking
- [ ] CarPlay support for voice interaction
- [ ] Apple Watch companion app

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on both iPhone and iPad
5. Submit a pull request

## License

This project follows the same license as the original HuggingChat macOS app.

## Acknowledgments

- **HuggingFace** for the Chat API and models
- **MLX Team** for the MLX Swift framework
- **Argmax** for WhisperKit
- **Original macOS app** for design inspiration

## Support

For issues and feature requests, please use the GitHub issue tracker.

---

Built with ❤️ using SwiftUI and Apple native APIs
