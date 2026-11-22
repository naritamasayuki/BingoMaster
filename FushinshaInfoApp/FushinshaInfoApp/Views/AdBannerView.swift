import SwiftUI

/// 画面下部に固定表示する広告バナー枠コンポーネント（標準 320×50 相当）
/// Google AdMob 申し込み完了後は、Info.plist の GADApplicationIdentifier と
/// この View 内の広告ユニット ID を設定するだけで本番バナーへ切り替え可能です。
struct AdBannerView: View {
    /// 後から本番用 AdMob 広告ユニット ID に差し替える定数（現在は Google 公式テスト用 ID を保持）
    static let adUnitID = "ca-app-pub-3940256099942544/2934735716"

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 10) {
                Text("広告")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("スポンサー広告スペース（320×50 バナー枠）")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("ここにバナー広告が表示されます")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "megaphone.fill")
                    .font(.subheadline)
                    .foregroundStyle(.blue.opacity(0.75))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(uiColor: .secondarySystemBackground))
        }
    }
}
