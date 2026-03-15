# Contributing to GenZFlow

## Development Setup

1. Fork and clone
2. Open in Xcode 15+ (macOS 14 Sonoma required)
3. Copy `GenZFlow/Config.example.swift` to `GenZFlow/Config.swift`
4. Add your OpenAI API key
5. Build and run

## Adding New Slang Styles

1. Add a new case to `SlangStyle` enum in `Config.swift`
2. Add the icon and system prompt
3. The style picker auto-updates via `CaseIterable`

## Architecture

```
Fn key -> AudioService -> TranscriptionService -> TranslationService -> PasteService
```

Each service is independent. Swap Whisper for another STT or GPT-4o for Claude by implementing the same interface.

## Pull Requests

- Keep PRs focused
- Test on Apple Silicon (WhisperKit requires it)
- Don't commit API keys
