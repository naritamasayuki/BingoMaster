import SwiftUI

/// モード選択画面や司会者画面のフッターに配置する「ビンゴ関連グッズ（PR）」導線カード
struct PartyGoodsBannerCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "bag.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("PR")
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.18))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                        Text("ビンゴ景品・パーティーグッズを探す")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    Text("景品セット・紙カード・スピーカー等を Amazon でチェック")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Amazonアソシエイトリンク一覧を表示するシート（景品表示法に配慮した PR 表記付き）
struct PartyGoodsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AmazonAffiliateHelper.recommendedItems) { item in
                        Button {
                            if let url = AmazonAffiliateHelper.makeSearchURL(for: item) {
                                openURL(url)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.iconName)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(item.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.primary)
                                        Text("PR")
                                            .font(.system(size: 9, weight: .black))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.orange.opacity(0.18))
                                            .foregroundStyle(.orange)
                                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                    }

                                    Text(item.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 4)

                                Image(systemName: "arrow.up.right.square")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("おすすめビンゴ・パーティーグッズ（Amazon）")
                } footer: {
                    Text("※【PR】本ページのリンクは Amazon アソシエイト・プログラム等のアフィリエイトリンクを含んでいます。商品の価格・在庫は遷移先の Amazon ページにてご確認ください。")
                        .font(.caption2)
                }
            }
            .navigationTitle("ビンゴ関連グッズ（PR）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}
