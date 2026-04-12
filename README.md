# 叱咤激励 iOS App

## 機能
- 🌅 **月曜朝 6:00** — 週の始まりに喝を入れる通知
- 🔥 **木曜朝 6:00** — 折り返しで追い込む通知
- 🎉 **金曜夜 20:00** — はっちゃけろ通知
- ⏰ **カスタムアラーム** — 任意の時刻にセット可能
- 🗣️ **音声読み上げ** (AVSpeechSynthesizer) — メッセージを日本語で読み上げ
- 📦 **メッセージバンク** — 各モード10パターン、重複なしローテーション

## Xcodeセットアップ

### 1. プロジェクト作成
```
File > New > Project > App
Product Name: ShittaGekiRei
Interface: SwiftUI
Language: Swift
```

### 2. ファイルをコピー
以下のファイルをXcodeプロジェクトに追加:
- `ShittaGekiReiApp.swift`（既存ファイルを置き換え）
- `ContentView.swift`（既存ファイルを置き換え）
- `MessageBank.swift`（新規追加）
- `NotificationManager.swift`（新規追加）
- `AlarmManager.swift`（新規追加）

### 3. Info.plist に追記
```xml
<key>NSUserNotificationUsageDescription</key>
<string>月曜・木曜の朝と金曜の夜に叱咤激励通知を送ります。</string>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### 4. Capabilities 追加
Xcode > Signing & Capabilities > + Capability:
- **Push Notifications**（ローカル通知のみなら不要）
- **Background Modes** > Audio, AirPlay, and Picture in Picture

### 5. カスタムアラーム音（任意）
`alarm.caf` という名前でサウンドファイルをプロジェクトに追加すると
カスタムアラーム音として使用される。なければデフォルト音にフォールバック。

## メッセージを追加する方法
`MessageBank.swift` の各配列に文字列を追加するだけ。
```swift
static let monday: [String] = [
    // ここに追加
    "新しいメッセージ",
]
```

## 将来の拡張案
- Claude API連携でAI生成メッセージ
- メッセージのユーザー編集UI
- ウィジェット対応（カウントダウン表示）
- Apple Watch対応（振動+読み上げ）
- iCloud同期でメッセージバンク共有
