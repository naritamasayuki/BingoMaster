import SwiftUI

/// 画面下部に固定表示する広告バナー枠コンポーネント
/// （将来 Google AdMob 等の SDK を導入した際も、この View 内部を UIViewRepresentable に差し替えるだけで全画面に反映されます）
struct AdBannerView: View {
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
