import SwiftUI
import WebKit

/// WebView の操作と状態を管理する ObservableObject
@MainActor
final class WebBrowserController: ObservableObject {
    @Published var pageTitle: String = "日本不審者情報センター"
    @Published var currentURLString: String = SafetySiteProvider.fushinshaCenter.baseURLString
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var estimatedProgress: Double = 0.0

    weak var webView: WKWebView?

    func load(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        load(url: url)
    }

    func load(url: URL) {
        currentURLString = url.absoluteString
        webView?.load(URLRequest(url: url))
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }
}

/// WKWebView の SwiftUI ラッパー
struct SafetyWebViewRepresentable: UIViewRepresentable {
    @ObservedObject var controller: WebBrowserController
    let initialURLString: String
    let onPageFinished: (String, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, onPageFinished: onPageFinished)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        controller.webView = webView
        context.coordinator.setupObservers(for: webView)

        if let url = URL(string: initialURLString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let controller: WebBrowserController
        let onPageFinished: (String, String) -> Void
        private var observations: [NSKeyValueObservation] = []

        init(controller: WebBrowserController, onPageFinished: @escaping (String, String) -> Void) {
            self.controller = controller
            self.onPageFinished = onPageFinished
        }

        func setupObservers(for webView: WKWebView) {
            observations.removeAll()

            observations.append(webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in
                    self?.controller.canGoBack = view.canGoBack
                }
            })
            observations.append(webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in
                    self?.controller.canGoForward = view.canGoForward
                }
            })
            observations.append(webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in
                    self?.controller.isLoading = view.isLoading
                }
            })
            observations.append(webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in
                    self?.controller.estimatedProgress = view.estimatedProgress
                }
            })
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let title = webView.title ?? "不審者情報ページ"
            let urlStr = webView.url?.absoluteString ?? ""
            Task { @MainActor in
                controller.pageTitle = title.isEmpty ? "不審者情報ページ" : title
                if !urlStr.isEmpty {
                    controller.currentURLString = urlStr
                    onPageFinished(controller.pageTitle, urlStr)
                }
            }
        }
    }
}

/// タブ1：不審者情報サイト閲覧＆マイ地域ショートカット画面
struct SafetyWebPortalView: View {
    @EnvironmentObject private var storage: SafetyStorage
    @StateObject private var browser = WebBrowserController()

    @State private var searchQuery: String = ""
    @State private var showingPrefectureEditor = false
    @State private var showingBookmarkSheet = false
    @State private var bookmarkNote: String = ""
    @State private var bookmarkPrefectureName: String = "全国・未指定"
    @State private var showSavedToast = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 上部コントロールヘッダー（情報源切替＋マイ地域バー＋キーワード検索）
                topControlBar

                if browser.isLoading {
                    ProgressView(value: browser.estimatedProgress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                }

                // メイン WebView
                SafetyWebViewRepresentable(
                    controller: browser,
                    initialURLString: storage.currentURLString
                ) { title, urlString in
                    storage.currentURLString = urlString
                    storage.recordBrowsingHistory(title: title, urlString: urlString)
                }

                // 下部ブラウザ操作＆保存ツールバー
                bottomBrowserToolbar
            }
            .navigationTitle("不審者情報サイト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(SafetySiteProvider.allCases) { provider in
                            Button {
                                storage.selectedProvider = provider
                                browser.load(urlString: provider.baseURLString)
                            } label: {
                                Label(provider.rawValue, systemImage: provider.iconName)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: storage.selectedProvider.iconName)
                            Text("サイト切替")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPrefectureEditor = true
                    } label: {
                        Label("マイ地域設定", systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                AdBannerView()
            }
            .overlay(alignment: .top) {
                if showSavedToast {
                    Text("ブックマークに保存しました")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green.gradient, in: Capsule())
                        .shadow(radius: 4)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showingPrefectureEditor) {
                FavoritePrefecturePickerSheet()
            }
            .sheet(isPresented: $showingBookmarkSheet) {
                bookmarkSaveSheet
            }
            .onChange(of: storage.requestedWebURL) { newURL in
                if let url = newURL {
                    browser.load(url: url)
                    storage.requestedWebURL = nil
                }
            }
        }
    }

    // MARK: - 上部バー（マイ地域チップ＆サイト内キーワード検索）
    private var topControlBar: some View {
        VStack(spacing: 8) {
            // マイ地域ワンタップ切替バー
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        browser.load(urlString: storage.selectedProvider.baseURLString)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "globe.asia.australia.fill")
                            Text("全国トップ")
                        }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                    }

                    ForEach(storage.favoritePrefectures) { pref in
                        Button {
                            bookmarkPrefectureName = pref.name
                            let url = storage.selectedProvider.urlForPrefecture(pref)
                            browser.load(url: url)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                Text(pref.name)
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .foregroundStyle(.primary)
                            .clipShape(Capsule())
                        }
                    }

                    Button {
                        showingPrefectureEditor = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus.circle.fill")
                            Text("地域を追加")
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 12)
            }

            // 市区町村・キーワード検索バー
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("市区町村名・小学校名・事案（例：世田谷区 声かけ）", text: $searchQuery)
                        .font(.subheadline)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit {
                            performKeywordSearch()
                        }
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button {
                    performKeywordSearch()
                } label: {
                    Text("検索")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            Divider()
        }
        .padding(.top, 6)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - 下部ブラウザ操作バー
    private var bottomBrowserToolbar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                Button {
                    browser.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .disabled(!browser.canGoBack)

                Button {
                    browser.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .disabled(!browser.canGoForward)

                Button {
                    browser.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        .frame(width: 32, height: 32)
                }

                Spacer()

                // ブックマーク保存ボタン
                Button {
                    bookmarkNote = ""
                    showingBookmarkSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark.fill")
                        Text("保存")
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.16))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
                }

                // 防犯マップへピン登録ボタン
                Button {
                    storage.startAddPinFromWebPage(
                        title: browser.pageTitle,
                        urlString: browser.currentURLString
                    )
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("マップに記録")
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(uiColor: .systemBackground))
        }
    }

    // MARK: - ブックマーク保存シート
    private var bookmarkSaveSheet: some View {
        NavigationStack {
            Form {
                Section("保存するページ情報") {
                    LabeledContent("タイトル", value: browser.pageTitle)
                    LabeledContent("URL") {
                        Text(browser.currentURLString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Section("地域タグと防犯メモ") {
                    Picker("関連地域", selection: $bookmarkPrefectureName) {
                        Text("全国・未指定").tag("全国・未指定")
                        ForEach(PrefectureItem.all) { pref in
                            Text(pref.name).tag(pref.name)
                        }
                    }

                    TextField("気になった点や通学路の注意点などをメモ（任意）", text: $bookmarkNote, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("不審者情報を保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        showingBookmarkSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存する") {
                        storage.addSavedArticle(
                            title: browser.pageTitle,
                            urlString: browser.currentURLString,
                            prefectureName: bookmarkPrefectureName,
                            note: bookmarkNote
                        )
                        showingBookmarkSheet = false
                        withAnimation {
                            showSavedToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            withAnimation {
                                showSavedToast = false
                            }
                        }
                    }
                    .fontWeight(.bold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                AdBannerView()
            }
        }
    }

    private func performKeywordSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let query: String
        switch storage.selectedProvider {
        case .fushinshaCenter:
            query = "site:fushinsha-joho.co.jp \(trimmed)"
        case .gaccomSafety:
            query = "site:gaccom.jp/safety \(trimmed)"
        default:
            query = "不審者情報 防犯 \(trimmed)"
        }

        if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://www.google.co.jp/search?q=\(encoded)") {
            browser.load(url: url)
        }
    }
}

/// マイ地域（47都道府県）の選択シート
struct FavoritePrefecturePickerSheet: View {
    @EnvironmentObject private var storage: SafetyStorage
    @Environment(\.dismiss) private var dismiss

    private let regions = [
        "北海道・東北", "関東", "甲信越・北陸", "東海", "関西", "中国・四国", "九州・沖縄"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("よく確認する都道府県にチェックを入れると、画面上部のショートカットバーに並び、ワンタップで地域の不審者情報を表示できます（自動保存されます）。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(regions, id: \.self) { region in
                    Section(region) {
                        ForEach(PrefectureItem.all.filter { $0.region == region }) { pref in
                            Button {
                                storage.toggleFavoritePrefecture(pref)
                            } label: {
                                HStack {
                                    Text(pref.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if storage.isFavoritePrefecture(pref) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("マイ地域の登録・編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                AdBannerView()
            }
        }
    }
}
