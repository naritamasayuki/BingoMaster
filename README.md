# ビンゴマスター (Bingo Master) - iOS版

インターネット接続不要！`MultipeerConnectivity`（Wi-Fi Direct / Bluetooth）を活用し、近くの司会者と参加者が自動でつながるオフライン対応ビンゴアプリです。

## 主な特徴
- **オフライン近距離P2P自動同期**: 司会者（ホスト）と参加者（プレイヤー）が近づくだけで自動接続。途中参加や再接続時にもこれまでの全出目を即時同期します。
- **司会者モード（ホスト）**:
  - 3段階（短め・普通・長い）から選べるルーレット減速演出・クリック音＆振動フィードバック
  - `AVSpeechSynthesizer` による日本語音声での2回繰り返し読み上げ＆合いの手ボイス演出
  - 参加者からのリーチ・ビンゴ通知のリアルタイム実況アナウンス・自動検算＆5×5カード答え合わせ機能
  - 出目履歴のゆっくり一括読み上げ機能（再生／停止）
  - 誤操作を防ぐ2段階リセット確認（初期選択「いいえ」）＆過去ゲーム履歴の自動保存・復元
- **参加者モード（プレイヤー）**:
  - B・I・N・G・O 各列の数値範囲に準拠した 5×5 デジタルビンゴカード自動生成（中央フリー）
  - **選べる穴あけモード**: 「手動タップモード（出た数字がゴールド枠＋パルス点滅し、タップでスタンプ開封）」と「⚡ 自動穴あけモード」をいつでも切り替え可能
  - 縦5列・横5行・斜め2本の計12ライン自動判定、リーチ・ビンゴ達成バナー＆紙吹雪エフェクト
  - 不正防止ロック（Keychain＋司会者台帳照合によるカード引き直し防止・なりすまし防止）
- **完全データ永続化**: アプリが再起動されても、ゲームリセットされるまで司会者の出目・参加者のカード状態を自動復元します。

## 動作環境・技術スタック
- **Target OS**: iOS 16.0 以降
- **言語 / UI**: Swift 5.9+ / SwiftUI (`@MainActor`, `ObservableObject`)
- **使用フレームワーク**: `SwiftUI`, `MultipeerConnectivity`, `AVFoundation`, `AudioToolbox`, `Security`, `UIKit`

## App Store 審査・提出対応済み項目
- **Privacy Manifest (`BingoMaster/PrivacyInfo.xcprivacy`)**: `NSPrivacyAccessedAPICategoryUserDefaults` (`CA92.1`) 宣言済み（ITMS-91053 対策）
- **App Icon (`AppIcon.png`)**: 透過（アルファチャンネル）なしの 24bit RGB 1024×1024px アイコン同梱済み（ITMS-90717 対策）
- **iPad マルチタスク・画面向き対応 (`Info.plist`)**: `UIRequiresFullScreen` および全4方向指定済み（ITMS-90474 対策）
- **輸出コンプライアンス設定 (`Info.plist`)**: `ITSAppUsesNonExemptEncryption = false` 設定済み
- **規約・プライバシー・非賭博免責事項表示**: モード選択画面下部に「ご利用規約・プライバシーポリシー・免責事項」シートを搭載（Guideline 5.1.1 / 5.3 対策）

## ビルド・App Store アップロード方法
1. `BingoMaster.xcodeproj` を Xcode で開きます。
2. ターゲット `BingoMaster` の Signing & Capabilities でご自身の Team を選択します。
3. 実機ビルドまたは **Any iOS Device (arm64)** を選択し、**Product > Archive** から App Store Connect へアップロードします。
