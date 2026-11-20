import SwiftUI
import UIKit

/// 不具合・バグ報告のカテゴリ区分
enum BugReportCategory: String, CaseIterable, Identifiable {
    case bug = "不具合・バグの報告"
    case connection = "P2P通信・接続のトラブル"
    case audioOrDisplay = "音声読み上げ・画面表示の不具合"
    case featureRequest = "機能改善のご要望・その他"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .bug: return String(localized: "不具合・バグの報告")
        case .connection: return String(localized: "P2P通信・接続のトラブル")
        case .audioOrDisplay: return String(localized: "音声読み上げ・画面表示の不具合")
        case .featureRequest: return String(localized: "機能改善のご要望・その他")
        }
    }
}

/// 不具合報告の本文および送信URLを組み立てるユーティリティ（ユニットテスト検証対応）
enum BugReportBuilder {
    /// GitHub Issue 作成ページのベースURL（Info.plist の BugReportIssuesURL で上書き可能）
    static var issuesBaseURLString: String {
        if let customURL = Bundle.main.object(forInfoDictionaryKey: "BugReportIssuesURL") as? String {
            let trimmed = customURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return "https://github.com/naritamasayuki/BingoMaster/issues/new"
    }

    /// サポート受付メールアドレス（Info.plist の BugReportSupportEmail で設定可能）
    static var supportEmail: String {
        if let customEmail = Bundle.main.object(forInfoDictionaryKey: "BugReportSupportEmail") as? String {
            let trimmed = customEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return ""
    }

    /// 診断情報付きのバグ報告テキストを生成する
    static func buildReportBody(
        category: BugReportCategory,
        userDescription: String,
        roleLabel: String,
        drawnCount: Int,
        connectedPeerCount: Int,
        systemVersion: String = UIDevice.current.systemVersion,
        deviceModel: String = UIDevice.current.model
    ) -> String {
        let appVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        let buildNumber = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
        let trimmedDesc = userDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyText = trimmedDesc.isEmpty ? String(localized: "（詳細未入力）") : trimmedDesc
        let timestamp = BingoStorage.formatJapaneseDate(Date())

        let categoryHeader = String(localized: "【カテゴリ】")
        let detailHeader = String(localized: "【発生内容・詳細】")
        let diagnosticHeader = String(localized: "【自動取得された診断情報（※個人情報は含まれません）】")
        let occurredAtLine = String(localized: "・発生日時: \(timestamp)")
        let appVersionLine = String(localized: "・アプリバージョン: \(appVersion) (Build \(buildNumber))")
        let osVersionLine = String(localized: "・iOSバージョン: iOS \(systemVersion) (\(deviceModel))")
        let roleLine = String(localized: "・利用モード: \(roleLabel)")
        let progressLine = String(localized: "・進行状況: 抽選済み \(drawnCount) 球 / 接続ピア数 \(connectedPeerCount) 台")

        return """
        \(categoryHeader)
        \(category.localizedTitle)

        \(detailHeader)
        \(bodyText)

        ------------------------------
        \(diagnosticHeader)
        \(occurredAtLine)
        \(appVersionLine)
        \(osVersionLine)
        \(roleLine)
        \(progressLine)
        """
    }

    /// メール送信用（mailto:）URLを生成する
    static func makeMailtoURL(category: BugReportCategory, reportBody: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        let subject = String(localized: "【ビンゴマスター】\(category.localizedTitle)")
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: reportBody)
        ]
        return components.url
    }

    /// GitHub Issues 新規作成用URLを生成する
    static func makeGitHubIssueURL(category: BugReportCategory, reportBody: String) -> URL? {
        guard var components = URLComponents(string: issuesBaseURLString) else {
            return nil
        }
        let title = String(localized: "[\(category.localizedTitle)] アプリ内からの報告")
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: reportBody)
        ]
        return components.url
    }
}

/// アプリ内のどこからでも呼び出せる「不具合・バグ報告シート」
struct BugReportSheetView: View {
    let roleLabel: String
    let drawnCount: Int
    let connectedPeerCount: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedCategory: BugReportCategory = .bug
    @State private var descriptionText: String = ""
    @State private var showCopiedAlert: Bool = false
    @State private var showMailFallbackAlert: Bool = false

    private static let draftStorageKey = "BingoMaster.bugReport.draftText"

    private var generatedReport: String {
        BugReportBuilder.buildReportBody(
            category: selectedCategory,
            userDescription: descriptionText,
            roleLabel: roleLabel,
            drawnCount: drawnCount,
            connectedPeerCount: connectedPeerCount
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("1. 報告の種類を選択してください") {
                    Picker("カテゴリ", selection: $selectedCategory) {
                        ForEach(BugReportCategory.allCases) { category in
                            Text(category.localizedTitle).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        if descriptionText.isEmpty {
                            Text("例：参加者が5人を超えたときに音声が途切れた、〇〇ボタンを押した時に画面が動かなくなった 等")
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.7))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $descriptionText)
                            .frame(minHeight: 110)
                            .font(.subheadline)
                            .onChange(of: descriptionText) { newValue in
                                // オフライン会場でも入力内容が消えないよう下書きを自動保存する
                                UserDefaults.standard.set(newValue, forKey: Self.draftStorageKey)
                            }
                    }
                } header: {
                    Text("2. 発生した状況・詳細（任意）")
                } footer: {
                    Text("※入力内容は自動的に下書き保存されるため、電波のないイベント会場で記録して後から送信することも可能です。")
                        .font(.caption2)
                }

                Section("3. 自動添付される診断情報（個人情報なし）") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("・利用モード: \(roleLabel)")
                        Text("・進行状況: 抽選済み \(drawnCount) 球 / 接続台数 \(connectedPeerCount) 台")
                        Text("・端末環境: iOS \(UIDevice.current.systemVersion) (\(UIDevice.current.model))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("4. 送信・共有方法を選択") {
                    // 方法A: OS標準の共有シート（メール・LINE・メモ帳・AirDropなど全てのアプリに対応）
                    ShareLink(
                        item: generatedReport,
                        subject: Text("【ビンゴマスター】\(selectedCategory.localizedTitle)")
                    ) {
                        Label("共有シートで送る（メール・LINE・メモ等）", systemImage: "square.and.arrow.up.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.blue)
                    }

                    // 方法B: メールアプリを起動
                    Button {
                        if let mailURL = BugReportBuilder.makeMailtoURL(
                            category: selectedCategory,
                            reportBody: generatedReport
                        ) {
                            openURL(mailURL) { accepted in
                                if !accepted {
                                    UIPasteboard.general.string = generatedReport
                                    showMailFallbackAlert = true
                                }
                            }
                        }
                    } label: {
                        Label("メールアプリで報告を作成する", systemImage: "envelope.fill")
                            .font(.subheadline.weight(.semibold))
                    }

                    // 方法C: GitHub Issue で報告
                    Button {
                        if let issueURL = BugReportBuilder.makeGitHubIssueURL(
                            category: selectedCategory,
                            reportBody: generatedReport
                        ) {
                            openURL(issueURL)
                        }
                    } label: {
                        Label("開発元ページ（GitHub Issue）で報告する", systemImage: "ladybug.fill")
                            .font(.subheadline.weight(.semibold))
                    }

                    // 方法D: クリップボードにコピー
                    Button {
                        UIPasteboard.general.string = generatedReport
                        showCopiedAlert = true
                    } label: {
                        Label("報告テキストをコピーする", systemImage: "doc.on.doc.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .navigationTitle("不具合・ご要望の報告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !descriptionText.isEmpty {
                        Button("下書きクリア", role: .destructive) {
                            descriptionText = ""
                            UserDefaults.standard.removeObject(forKey: Self.draftStorageKey)
                        }
                        .font(.caption)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if descriptionText.isEmpty,
                   let savedDraft = UserDefaults.standard.string(forKey: Self.draftStorageKey),
                   !savedDraft.isEmpty {
                    descriptionText = savedDraft
                }
            }
            .alert("コピーしました", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("診断情報を含む報告テキストをクリップボードにコピーしました。メールやSNS等に貼り付けて送信できます。")
            }
            .alert("メールアプリを開けませんでした", isPresented: $showMailFallbackAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("お使いの端末に標準メールアカウントが設定されていないため、報告内容をクリップボードに自動コピーしました。「共有シートで送る」から送信いただけます。")
            }
        }
    }
}
