# Antigravity 開発ルール・引き継ぎメモ (iOSアプリ共通仕様)

## 1. iOSアプリにおける広告バナーの必須搭載ルール
- **今後作成・改修するすべての iOS アプリには、画面下部にバナー広告欄（`AdBannerView`：標準 320×50 相当）を必ず配置すること。**
- SwiftUI では `.safeAreaInset(edge: .bottom)` 等を使用し、メインコンテンツや操作ボタンと重ならないよう画面下部に固定配置する。
- Google AdMob の審査・申し込み完了前は、共通コンポーネント `AdBannerView` をプレースホルダー（またはテスト広告枠）として実装し、後から `アプリ ID` と `広告ユニット ID` を設定するだけで即座に本番の Google AdMob バナーへ切り替えられる構造にしておくこと。

---

## 2. Google AdMob 申し込み後に差し替える手順（メモ）
AdMob（https://admob.google.com/intl/ja/home/）でアカウント登録＆アプリ追加を行った後、以下の2つのIDを AI エージェントに伝えるだけで本番広告へ切り替え可能：
1. **AdMob アプリ ID**（例：`ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy`）
   - `Info.plist` の `GADApplicationIdentifier` キーに設定する。
2. **バナー用 広告ユニット ID**（例：`ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz`）
   - `AdBannerView.swift` 内の `GADBannerView` に設定する。

---

## 3. その他の共通開発方針
- **日本語UIの徹底**: アプリ内の表示テキスト・ボタン・アラート・音声案内はすべて自然な日本語で統一する。
- **重要なリセット操作の保護**: 「ゲームをリセットする」等のデータ消去を伴う操作は必ず **2回確認ダイアログ** を表示し、初期選択（`.cancel` ロール）は **「いいえ」** に設定する。
- **履歴データの自動保存**: 進行中のゲーム履歴・状態は操作ごとに即座に `UserDefaults` 等へ自動保存し、アプリ再起動時にも失われないようにする。
