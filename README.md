# GenZFlow

A macOS menu bar app that captures your voice and transcribes it in Gen Z slang (and other fun styles).

**Press Fn → Talk → Translated text appears in your active text field.**

No cap, this thing is bussin fr fr.

## Architecture

```
Fn key pressed → Mic capture (AVAudioEngine)
    → Local STT (whisper.cpp via WhisperKit)
    → Style translation (OpenAI GPT-4o)
    → Paste into active text field (NSPasteboard + Cmd+V)
```

## Translation Styles

| Style | Vibe | Example |
|-------|------|---------|
| **Gen Z** | Natural Gen Z slang | "that presentation lowkey ate no cap" |
| **Brainrot** | Maximum unhinged TikTok | "GOOD MORNING chat lets get this sigma meeting started" |
| **Corporate Gen Z** | Professional with Gen Z energy | "The quarterly report absolutely ate, no notes" |
| **Shakespeare** | Ye olde English | "Alas, the ethereal connection hath forsaken us" |
| **Pirate** | Swashbuckling pirate speak | "Arr, send that scroll me way or ye'll walk the plank" |

## Tech Stack

- **Language**: Swift 5.9+
- **Platform**: macOS 14.0+ (Sonoma)
- **STT**: WhisperKit (Apple Silicon optimized, runs locally)
- **LLM**: OpenAI GPT-4o API
- **UI**: SwiftUI menu bar app (MenuBarExtra)

## Setup

1. Clone this repo
2. Set `OPENAI_API_KEY` in your shell, or create a local ignored `GenZFlow/Config.swift` from `GenZFlow/Config.example.swift`
3. Open in Xcode 15+ or run `./scripts/run-macos-app.sh`
4. Grant microphone + accessibility permissions
5. Press `Control + Option + Space` to toggle recording

## License

MIT
