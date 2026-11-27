# App Store 登録・申請準備ガイド（ビンゴマスター / Bingo Master）

本ドキュメントは、`com.naritamasayuki.bingomaster` を App Store Connect に登録・提出するための手順および入力用メタデータ一式です。

---

## 1. アプリ基本情報・ビルド確認状況

- **アプリ名（基本）**: ビンゴマスター / Bingo Master
- **Bundle Identifier**: `com.naritamasayuki.bingomaster`
- **Development Team ID**: `4KR684T6KV`
- **バージョン / ビルド番号**: `1.0` / `Build 1`
- **対応 iOS バージョン**: iOS 16.0 以降（iPhone / iPad 対応）
- **対応言語**: 日本語 (`ja`)、英語 (`en`)、中国語 簡体字 (`zh-Hans`)、中国語 繁体字 (`zh-Hant`)
- **輸出コンプライアンス**: `ITSAppUsesNonExemptEncryption = false` 設定済み
- **プライバシーマニフェスト**: `PrivacyInfo.xcprivacy` 組み込み済み（`NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1`）
- **アプリアイコン**: `1024×1024`（透過なし）確認済み
- **Release アーカイブ検証**: `xcodebuild archive` 成功済み（ストアバリデーション通過）

---

## 2. サポート URL・プライバシーポリシー URL の公開手順

リポジトリ内の [`docs/index.html`](docs/index.html) に4言語対応のサポート＆プライバシーポリシーページを用意しています。

1. GitHub リポジトリ `naritamasayuki/BingoMaster` を開く
2. **Settings** ＞ **Pages** を開く
3. **Build and deployment** ＞ **Source** で `Deploy from a branch` を選択
4. **Branch** を `main`、フォルダを `/docs` に設定して **Save**
5. 数分後に以下の URL が公開されるため、App Store Connect の **プライバシーポリシーURL** および **サポートURL** に設定してください：
   - `https://naritamasayuki.github.io/BingoMaster/`

---

## 3. App Store Connect メタデータ（そのままコピー＆ペースト可能）

### 日本語（プライマリ言語）
- **名前（30文字以内）**:
  `ビンゴマスター`
- **サブタイトル（30文字以内）**:
  `通信不要・音声読み上げ＆P2P同期ビンゴ`
- **プロモーションテキスト（170文字以内）**:
  `パーティーや社内イベントに最適！インターネット不要で近くの端末と自動接続し、音声読み上げ・カード配布・リーチ/ビンゴ自動検算までこれ1台で完結します。`
- **キーワード（100文字以内）**:
  `ビンゴ,ビンゴゲーム,パーティー,イベント,抽選,ルーレット,オフライン,二次会,忘年会,新年会`
- **概要**:
  ```text
  「ビンゴマスター」は、パーティー・懇親会・社内イベント・二次会などで使える、インターネット不要の本格ビンゴ進行＆カードアプリです。

  【主な特徴】
  1. 司会者（ホスト）モード
  ・1〜75の番号をルーレット演出付きで抽選（演出時間は「短め・普通・長い」の3段階から選択可能）
  ・自然な音声アナウンス（2回読み上げ＋会場を盛り上げる合いの手機能付き）
  ・1〜75 出目一覧ボード＆出目履歴のゆっくり読み上げ機能
  ・参加者のリーチ／ビンゴ達成を自動検算し、5×5カードの答え合わせもワンタップで確認可能

  2. 参加者（プレイヤー）モード
  ・5×5の専用デジタルビンゴカードを自動発行
  ・出た数字を自動で開ける「自動穴あけモード」と、自分で探して押す「手動タップモード」を切り替え可能
  ・リーチ／ビンゴ達成時の祝福演出＆紙吹雪エフェクト
  ・不正防止ロック（ゲーム開始後のカード引き直しや名前変更をブロック）

  3. ネット不要の近距離P2P自動同期＆自動保存
  ・Wi-FiとBluetoothをオンにするだけで、近くの端末同士が自動接続（MultipeerConnectivity）
  ・1球ごとに自動保存されるため、アプリ再起動や途中参加でも即座に状態を復元できます

  ※本アプリはイベント進行補助用のユーティリティツールであり、金銭を賭ける行為や懸賞・景品の提供は一切行いません。
  ```

### English (U.S.)
- **Name (max 30 chars)**:
  `Bingo Master`
- **Subtitle (max 30 chars)**:
  `Offline P2P Party Bingo & Host`
- **Promotional Text (max 170 chars)**:
  `Perfect for parties and events! Connect nearby devices without internet—includes roulette draw, voice callouts, 5x5 cards, and automatic host verification.`
- **Keywords (max 100 chars)**:
  `bingo,party,game,host,caller,roulette,offline,card,event,numbers`
- **Description**:
  ```text
  Bingo Master is an all-in-one party and event Bingo utility that works without an internet connection.

  [Host Mode]
  • Draw numbers 1–75 with an animated roulette (Short, Normal, or Long spin modes)
  • Built-in voice announcements in your device language, plus slow history read-back
  • 1–75 master board and real-time player status tracking
  • Tap any player to inspect and verify their 5x5 card

  [Player Mode]
  • Instant 5x5 digital bingo card synced in real time with the host
  • Switch between Auto-Daub mode and Manual Tap mode
  • Celebration banners and confetti effects on Reach and Bingo
  • Anti-cheat card lock and automatic save/restore

  [Nearby P2P Sync — No Internet Required]
  • Automatically connects nearby hosts and players using Wi-Fi and Bluetooth
  • Game progress is auto-saved after every draw

  Note: This app is strictly a party/event utility tool and does not offer real-money gambling or prizes.
  ```

### 简体中文 (Simplified Chinese)
- **名称（30字以内）**:
  `宾果大师`
- **副标题（30字以内）**:
  `无需联网・语音播报与P2P同步宾果`
- **宣传文本（170字以内）**:
  `派对与公司活动的理想助手！无需互联网即可与附近设备自动同步，支持转盘抽号、语音播报、5×5电子宾果卡与自动核验。`
- **关键词（100字以内）**:
  `宾果,Bingo,派对游戏,抽奖,转盘,聚会,离线,主持人,年会,互动`
- **描述**:
  ```text
  「宾果大师」是一款专为派对、聚会与公司活动打造的宾果辅助应用，无需互联网即可与附近设备实时同步游玩。

  【主持人模式】
  ・支持1〜75号球动画转盘抽号（可切换较快、标准、较长三种节奏）
  ・自动语音播报号码，并支持慢速播报历史开奖号码
  ・1〜75号码总览板与参与者听牌/宾果状态实时统计
  ・点击参与者姓名即可核验其5×5宾果卡

  【参与者模式】
  ・自动生成专属5×5电子宾果卡，与主持人实时同步
  ・支持「自动标记」与「手动点击」两种玩法
  ・听牌与宾果达成时的庆祝动画效果
  ・防作弊卡片锁定与自动保存恢复功能

  注：本应用仅为聚会活动辅助工具，不涉及任何真钱赌博或抽奖奖品。
  ```

### 繁體中文 (Traditional Chinese)
- **名稱（30字以內）**:
  `賓果大師`
- **副標題（30字以內）**:
  `無需聯網・語音播報與P2P同步賓果`
- **宣傳文字（170字以內）**:
  `派對與公司活動的最佳助手！無需網際網路即可與附近裝置自動同步，支援轉盤抽號、語音播報、5×5電子賓果卡與自動核驗。`
- **關鍵字（100字以內）**:
  `賓果,Bingo,派對遊戲,抽獎,轉盤,聚會,離線,主持人,尾牙,春酒`
- **描述**:
  ```text
  「賓果大師」是一款專為派對、聚會與公司活動打造的賓果輔助應用程式，無需網際網路即可與附近裝置即時同步遊玩。

  【主持人模式】
  ・支援1〜75號球動畫轉盤抽號（可切換較快、標準、較長三種節奏）
  ・自動語音播報號碼，並支援慢速播報歷史開獎號碼
  ・1〜75號碼總覽板與參與者聽牌/賓果狀態即時統計
  ・點擊參與者姓名即可核驗其5×5賓果卡

  【參與者模式】
  ・自動產生專屬5×5電子賓果卡，與主持人即時同步
  ・支援「自動標記」與「手動點擊」兩種玩法
  ・聽牌與賓果達成時的慶祝動畫效果
  ・防作弊卡片鎖定與自動儲存恢復功能

  註：本應用程式僅為聚會活動輔助工具，不涉及任何真錢賭博或抽獎獎品。
  ```

---

## 4. App Privacy・年齢制限・審査メモ設定

- **カテゴリ**: プライマリ「エンターテインメント」 / セカンダリ「ユーティリティ」
- **価格**: 無料（App内課金なし）
- **App Privacy（プライバシーの質問票）**:
  - **「はい、このアプリからデータを収集します」** を選択（App Store Connect 公開済み）。
  - Google AdMob SDK による収集データ（おおよその場所、デバイスID、製品の操作、広告データ＝トラッキング使用・ユーザー非紐付け／クラッシュデータ、パフォーマンスデータ、その他の診断データ＝トラッキング不使用・ユーザー非紐付け）を申告。
- **年齢制限指定**:
  - すべての項目で「なし」（特に「シミュレートされたギャンブル」も「なし」— 非賭博ユーティリティツールであるため）。→ **4+** になります。
- **App Review（審査メモ）欄への記載例（英語）**:
  ```text
  Bingo Master is a party/event utility app for running Bingo games offline with nearby devices via MultipeerConnectivity (Local Network).
  - Sign-in is NOT required.
  - To test Host/Player sync: launch the app on two nearby iOS devices (or one device in Host mode and test drawing numbers with voice announcements).
  - This app is strictly for event facilitation and does not involve real-money gambling or prizes.
  ```

---

## 5. Xcode からのアップロード手順（署名・提出）

現在、Mac には開発用証明書（`Apple Development`）のみがインストールされているため、以下の手順で **Xcode から App Store Connect へ直接アップロード** するのが最も確実です：

1. App Store Connect（<https://appstoreconnect.apple.com>）にログインし、「マイApp」＞「＋」＞「新規App」から以下を登録する：
   - プラットフォーム: `iOS`
   - 名前: `ビンゴマスター`
   - プライマリ言語: `日本語`
   - バンドルID: `com.naritamasayuki.bingomaster`
   - SKU: `bingomaster-ios-001`
2. Mac で `BingoMaster.xcodeproj` を Xcode で開く
3. メニュー **Product** ＞ **Archive** を実行する（または既に生成した `/tmp/BingoMaster.xcarchive` をダブルクリックして Organizer を開く）
4. **Organizer** 画面でアーカイブを選択し、**Distribute App** ＞ **App Store Connect** ＞ **Upload** をクリック
5. 初回のみ「Apple Distribution」証明書と App Store 用プロビジョニングプロファイルの自動作成（Automatically manage signing）を確認されるため、そのまま進める
6. アップロード完了後、App Store Connect 上でスクリーンショット（iPhone 6.7"/6.9" および iPad 13" 等）を設定し、**「審査へ提出」** をクリックする
