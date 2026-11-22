import SwiftUI

/// タブ3：保存済みブックマーク＆Web閲覧履歴管理画面
struct SavedAndHistoryView: View {
    @EnvironmentObject private var storage: SafetyStorage

    enum SubTab: String, CaseIterable, Identifiable {
        case bookmarks = "保存済み記事"
        case history = "閲覧履歴"
        var id: String { rawValue }
    }

    @State private var selectedSubTab: SubTab = .bookmarks
    @State private var filterText: String = ""

    // 2段階リセット確認フラグ（ブックマーク全消去）
    @State private var showClearBookmarksStep1 = false
    @State private var showClearBookmarksStep2 = false

    // 2段階リセット確認フラグ（閲覧履歴全消去）
    @State private var showClearHistoryStep1 = false
    @State private var showClearHistoryStep2 = false

    private var filteredBookmarks: [SavedArticleItem] {
        let q = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return storage.savedArticles }
        return storage.savedArticles.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.prefectureName.localizedCaseInsensitiveContains(q) ||
            $0.note.localizedCaseInsensitiveContains(q)
        }
    }

    private var filteredHistory: [BrowsingHistoryItem] {
        let q = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return storage.browsingHistory }
        return storage.browsingHistory.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.urlString.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("表示切替", selection: $selectedSubTab) {
                    ForEach(SubTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if selectedSubTab == .bookmarks {
                    bookmarksListView
                } else {
                    historyListView
                }
            }
            .navigationTitle("保存済み・閲覧履歴")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $filterText, prompt: "タイトル・地域・メモで絞り込み")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if selectedSubTab == .bookmarks && !storage.savedArticles.isEmpty {
                        Button(role: .destructive) {
                            showClearBookmarksStep1 = true
                        } label: {
                            Label("全件消去", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    } else if selectedSubTab == .history && !storage.browsingHistory.isEmpty {
                        Button(role: .destructive) {
                            showClearHistoryStep1 = true
                        } label: {
                            Label("履歴を消去", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                AdBannerView()
            }
            // ブックマーク全件消去 1段階目確認
            .alert("保存済み記事をすべて消去しますか？", isPresented: $showClearBookmarksStep1) {
                Button("いいえ", role: .cancel) {}
                Button("はい（最終確認へ）", role: .destructive) {
                    showClearBookmarksStep2 = true
                }
            } message: {
                Text("保存したブックマーク（\(storage.savedArticles.count)件）と防犯メモをすべてリセットしようとしています。")
            }
            // ブックマーク全件消去 2段階目確認
            .alert("【最終確認】本当に保存済み記事をすべて消去しますか？", isPresented: $showClearBookmarksStep2) {
                Button("いいえ", role: .cancel) {}
                Button("すべて消去する", role: .destructive) {
                    storage.clearSavedArticles()
                }
            } message: {
                Text("この操作を実行すると元に戻すことはできません。")
            }
            // 閲覧履歴全件消去 1段階目確認
            .alert("閲覧履歴をすべてリセットしますか？", isPresented: $showClearHistoryStep1) {
                Button("いいえ", role: .cancel) {}
                Button("はい（最終確認へ）", role: .destructive) {
                    showClearHistoryStep2 = true
                }
            } message: {
                Text("これまでに閲覧したページの履歴（\(storage.browsingHistory.count)件）をすべて消去しようとしています。")
            }
            // 閲覧履歴全件消去 2段階目確認
            .alert("【最終確認】本当に閲覧履歴をすべて消去しますか？", isPresented: $showClearHistoryStep2) {
                Button("いいえ", role: .cancel) {}
                Button("履歴を消去する", role: .destructive) {
                    storage.clearBrowsingHistory()
                }
            } message: {
                Text("この操作を実行すると元に戻すことはできません。")
            }
        }
    }

    // MARK: - ブックマーク一覧
    private var bookmarksListView: some View {
        Group {
            if filteredBookmarks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("保存された不審者情報はありません")
                        .font(.headline)
                    Text("「不審者情報サイト」タブの下部にある「保存」ボタンから、気になる事案や地域の防犯記事をメモ付きで保存できます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredBookmarks) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.prefectureName)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.16))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())

                                Spacer()

                                Text(item.savedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Text(item.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)

                            if !item.note.isEmpty {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "note.text")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(item.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }

                            HStack(spacing: 12) {
                                Button {
                                    storage.openURLInWebTab(item.urlString)
                                } label: {
                                    Label("ページを開く", systemImage: "safari.fill")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                Button {
                                    storage.startAddPinFromWebPage(title: item.title, urlString: item.urlString)
                                } label: {
                                    Label("マップに記録", systemImage: "mappin.and.ellipse")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                storage.removeSavedArticle(id: item.id)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - 閲覧履歴一覧
    private var historyListView: some View {
        Group {
            if filteredHistory.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("閲覧履歴はまだありません")
                        .font(.headline)
                    Text("不審者情報サイトで閲覧したページが自動的に記録されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredHistory) { entry in
                        Button {
                            storage.openURLInWebTab(entry.urlString)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)

                                Text(entry.urlString)
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                    .lineLimit(1)

                                Text("閲覧日時：\(entry.visitedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}
