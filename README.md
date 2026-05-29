# WalletAI

An intelligent expense tracker for iOS 26, built with SwiftUI and the Apple Liquid Glass design system.

## Features

- **Voice Logging** — Say "I spent $45 on groceries" and it auto-fills a transaction
- **DeepSeek AI** — Free AI assistant that analyzes your spending and gives financial insights
- **Apple Pay Automation** — Shortcut-based trigger to auto-log transactions after Apple Pay
- **Custom Categories** — Create categories with custom icons, colors, and monthly budgets
- **Budget Tracking** — Progress rings, bar charts, and over-budget alerts
- **Liquid Glass UI** — Full iOS 26 `.glassEffect()` design language throughout

## Requirements

- **Xcode 26+** (for iOS 26 SDK with `glassEffect` APIs)
- **iOS 26.0+** deployment target
- **DeepSeek API Key** — Free at [platform.deepseek.com](https://platform.deepseek.com)

## Setup

1. Open `WalletAI.xcodeproj` in Xcode 26
2. Select your team in Signing & Capabilities
3. Build & run (or archive for sideloading)
4. On first launch, go to Settings → AI Assistant → Set API Key

## Apple Pay Automation Setup

1. Open **Shortcuts** app
2. Tap **Automation** → **New Automation** → **Apple Pay**
3. Add **Open URL** action with:
   ```
   walletai://applepay?amount=[Payment Amount]&merchant=[Merchant Name]
   ```
4. Enable **Run Immediately**

## Project Structure

```
WalletAI/
├── App/           # Entry point, root tab view
├── Models/        # SwiftData models (Transaction, Category, Budget, AIConversation)
├── Services/      # SpeechRecognitionService, DeepSeekService, ApplePayObserver
├── Components/    # Reusable glass UI components
├── Views/         # All screens (Dashboard, Transactions, Categories, AI, Settings, Onboarding)
├── Utilities/     # Extensions, Constants, SeedData
└── Resources/     # Assets, Info.plist, Entitlements
```

## Liquid Glass Implementation

Uses iOS 26 native APIs throughout:
- `.glassEffect(.regular.tint(color).interactive(), in: .shape)` on buttons/cards
- `GlassEffectContainer(spacing:)` for grouped glass elements
- `glassEffectID` + `@Namespace` for morphing transitions
- `.buttonStyle(.glass)` on standard buttons

## AI Architecture

DeepSeek `deepseek-chat` model with:
- Streaming responses via SSE
- Financial context injected via system prompt (current month spend, categories, budget)
- Voice transcript → AI transaction parsing pipeline
- Local regex parsing as fallback when API is unavailable
