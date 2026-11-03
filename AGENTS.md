# Antigravity Agent Rules (iOS App Development)

@[Antigravity.md](./Antigravity.md)

## 必須ルール
1. **下部バナー広告欄の標準搭載**: 今後作成するすべての iOS アプリでは、各主要画面の下部（`.safeAreaInset(edge: .bottom)`）にバナー広告欄（`AdBannerView`）を必ず配置すること。
2. **日本語UIの徹底**: アプリ内の表記はすべて日本語にすること。
3. **2段階リセット確認（初期値：いいえ）**: リセット操作は2回確認を行い、初期値（`.cancel`）は「いいえ」とすること。
4. **自動保存の徹底**: ゲーム履歴や進行状態は自動保存すること。
