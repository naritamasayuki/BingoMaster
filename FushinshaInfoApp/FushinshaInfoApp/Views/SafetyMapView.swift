import SwiftUI
import MapKit
import CoreLocation

/// タブ2：不審者・地域防犯マップ画面（MapKit ピン留め・検索・一覧管理）
struct SafetyMapView: View {
    @EnvironmentObject private var storage: SafetyStorage

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6895, longitude: 139.6917),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    @State private var selectedCategoryFilter: IncidentCategory? = nil
    @State private var placeSearchText: String = ""
    @State private var isSearchingPlace: Bool = false
    @State private var searchErrorMessage: String?

    @State private var selectedPin: SafetyIncidentPin?
    @State private var showingAddPinSheet: Bool = false
    @State private var draftTitle: String = ""
    @State private var draftURL: String = ""

    private var filteredPins: [SafetyIncidentPin] {
        storage.incidentPins.filter { pin in
            if let category = selectedCategoryFilter {
                return pin.category == category
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 上部：地名・駅名検索バー＆カテゴリフィルタ
                topMapControls

                // 中央：MapKit マップ（中心照準マーク付き）
                ZStack {
                    Map(coordinateRegion: $mapRegion, annotationItems: filteredPins) { pin in
                        MapAnnotation(coordinate: pin.coordinate) {
                            Button {
                                selectedPin = pin
                            } label: {
                                VStack(spacing: 2) {
                                    ZStack {
                                        Circle()
                                            .fill(pin.isResolved ? Color.gray : pin.category.pinColor)
                                            .frame(width: 34, height: 34)
                                            .shadow(radius: 3)
                                        Image(systemName: pin.category.iconName)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    Text(pin.title)
                                        .font(.system(size: 10, weight: .bold))
                                        .lineLimit(1)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                            }
                        }
                    }
                    .ignoresSafeArea(edges: .horizontal)

                    // 中心位置を示すターゲット十字（現在の中央にピンを追加しやすくする）
                    Image(systemName: "plus.viewfinder")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.red.opacity(0.65))
                        .allowsHitTesting(false)

                    // マップ右下の「この場所にピン追加」フローティングボタン
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                draftTitle = ""
                                draftURL = ""
                                showingAddPinSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("マップ中央に事案を記録")
                                }
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .shadow(radius: 4)
                            }
                            .padding(12)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                // 下部：登録済み事案の横スクロールまたはコンパクト一覧
                incidentListDrawer
            }
            .navigationTitle("防犯・不審者マップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Section("マイ地域へ移動") {
                            ForEach(storage.favoritePrefectures) { pref in
                                Button(pref.name) {
                                    moveMap(to: pref.coordinate, spanDelta: 0.12)
                                }
                            }
                        }
                        Section("全国主要都市へ移動") {
                            ForEach(PrefectureItem.all) { pref in
                                Button(pref.name) {
                                    moveMap(to: pref.coordinate, spanDelta: 0.12)
                                }
                            }
                        }
                    } label: {
                        Label("地域ジャンプ", systemImage: "location.magnifyingglass")
                            .font(.subheadline)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        draftTitle = ""
                        draftURL = ""
                        showingAddPinSheet = true
                    } label: {
                        Label("事案を追加", systemImage: "plus")
                            .font(.subheadline.weight(.bold))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                AdBannerView()
            }
            .sheet(item: $selectedPin) { pin in
                IncidentPinDetailSheet(pin: pin) { coordinate in
                    moveMap(to: coordinate, spanDelta: 0.02)
                }
            }
            .sheet(isPresented: $showingAddPinSheet) {
                AddIncidentPinSheet(
                    initialCoordinate: mapRegion.center,
                    initialTitle: draftTitle,
                    initialURLString: draftURL
                ) { newPin in
                    storage.addIncidentPin(newPin)
                    moveMap(to: newPin.coordinate, spanDelta: 0.025)
                }
            }
            .onAppear {
                if storage.shouldPresentAddPinSheetFromWeb {
                    draftTitle = storage.pendingDraftPinTitle
                    draftURL = storage.pendingDraftPinURL
                    storage.shouldPresentAddPinSheetFromWeb = false
                    showingAddPinSheet = true
                }
            }
            .onChange(of: storage.shouldPresentAddPinSheetFromWeb) { shouldPresent in
                if shouldPresent {
                    draftTitle = storage.pendingDraftPinTitle
                    draftURL = storage.pendingDraftPinURL
                    storage.shouldPresentAddPinSheetFromWeb = false
                    showingAddPinSheet = true
                }
            }
        }
    }

    // MARK: - 上部コントロール（地名検索＆種別フィルタ）
    private var topMapControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("住所・駅名・学校名で地図を移動（例：新宿駅）", text: $placeSearchText)
                        .font(.subheadline)
                        .submitLabel(.search)
                        .onSubmit {
                            searchLocationOnMap()
                        }
                    if !placeSearchText.isEmpty {
                        Button {
                            placeSearchText = ""
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
                    searchLocationOnMap()
                } label: {
                    if isSearchingPlace {
                        ProgressView()
                            .frame(width: 44, height: 32)
                    } else {
                        Text("移動")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 12)

            if let error = searchErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
            }

            // 種別フィルタチップ
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        selectedCategoryFilter = nil
                    } label: {
                        Text("すべて (\(storage.incidentPins.count))")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(selectedCategoryFilter == nil ? Color.blue : Color(uiColor: .tertiarySystemFill))
                            .foregroundStyle(selectedCategoryFilter == nil ? Color.white : Color.primary)
                            .clipShape(Capsule())
                    }

                    ForEach(IncidentCategory.allCases) { category in
                        let isSelected = selectedCategoryFilter == category
                        Button {
                            selectedCategoryFilter = isSelected ? nil : category
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: category.iconName)
                                    .font(.system(size: 10))
                                Text(category.rawValue)
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? category.pinColor : Color(uiColor: .tertiarySystemFill))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 6)

            Divider()
        }
        .padding(.top, 6)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - 下部事案カード一覧
    private var incidentListDrawer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack {
                Text("記録済みの不審者・防犯ポイント（\(filteredPins.count)件）")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("タップで地図移動・詳細")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)

            if filteredPins.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("該当する事案ピンがありません")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("右上の「＋」またはWeb画面の「マップに記録」から登録できます")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 14)
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(filteredPins) { pin in
                            Button {
                                moveMap(to: pin.coordinate, spanDelta: 0.018)
                                selectedPin = pin
                            } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(pin.category.pinColor.opacity(0.18))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: pin.category.iconName)
                                            .foregroundStyle(pin.category.pinColor)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(pin.title)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(pin.addressOrArea)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        Text(pin.occurredAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(10)
                                .frame(width: 240, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func moveMap(to coordinate: CLLocationCoordinate2D, spanDelta: Double) {
        withAnimation {
            mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
            )
        }
    }

    private func searchLocationOnMap() {
        let query = placeSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearchingPlace = true
        searchErrorMessage = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = mapRegion

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            Task { @MainActor in
                isSearchingPlace = false
                if let item = response?.mapItems.first {
                    moveMap(to: item.placemark.coordinate, spanDelta: 0.025)
                } else if error != nil {
                    searchErrorMessage = "場所が見つかりませんでした。別の地名でお試しください。"
                }
            }
        }
    }
}

/// 新規事案ピンの追加シート
struct AddIncidentPinSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialCoordinate: CLLocationCoordinate2D
    let initialTitle: String
    let initialURLString: String
    let onSave: (SafetyIncidentPin) -> Void

    @State private var title: String = ""
    @State private var category: IncidentCategory = .approaching
    @State private var addressOrArea: String = ""
    @State private var latitude: Double = 35.6895
    @State private var longitude: Double = 139.6917
    @State private var occurredAt: Date = Date()
    @State private var details: String = ""
    @State private var sourceURLString: String = ""
    @State private var isGeocoding: Bool = false
    @State private var geocodeStatusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("事案の基本情報") {
                    TextField("タイトル（例：〇〇小学校付近で声かけ事案）", text: $title)

                    Picker("事案の種別", selection: $category) {
                        ForEach(IncidentCategory.allCases) { item in
                            Label(item.rawValue, systemImage: item.iconName)
                                .tag(item)
                        }
                    }

                    DatePicker("発生・確認日時", selection: $occurredAt)
                }

                Section("発生場所・位置情報") {
                    HStack {
                        TextField("地名・住所（例：東京都世田谷区三軒茶屋）", text: $addressOrArea)
                        Button {
                            lookupAddressCoordinates()
                        } label: {
                            if isGeocoding {
                                ProgressView()
                            } else {
                                Text("住所から座標取得")
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(addressOrArea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGeocoding)
                    }

                    if let status = geocodeStatusMessage {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("緯度 / 経度") {
                        Text(String(format: "%.4f, %.4f", latitude, longitude))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                Section("詳細メモ・特徴・情報元URL") {
                    TextField("不審者の特徴・服装・注意点などを入力", text: $details, axis: .vertical)
                        .lineLimit(3...6)

                    TextField("情報元ページのURL（任意）", text: $sourceURLString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
            }
            .navigationTitle("防犯マップに事案を記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("登録する") {
                        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalArea = addressOrArea.trimmingCharacters(in: .whitespacesAndNewlines)
                        let newPin = SafetyIncidentPin(
                            title: finalTitle.isEmpty ? category.rawValue : finalTitle,
                            category: category,
                            addressOrArea: finalArea.isEmpty ? "地図指定ポイント" : finalArea,
                            latitude: latitude,
                            longitude: longitude,
                            occurredAt: occurredAt,
                            details: details,
                            sourceURLString: sourceURLString
                        )
                        onSave(newPin)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                AdBannerView()
            }
            .onAppear {
                latitude = initialCoordinate.latitude
                longitude = initialCoordinate.longitude
                if !initialTitle.isEmpty {
                    title = initialTitle
                }
                if !initialURLString.isEmpty {
                    sourceURLString = initialURLString
                }
            }
        }
    }

    private func lookupAddressCoordinates() {
        let query = addressOrArea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isGeocoding = true
        geocodeStatusMessage = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            Task { @MainActor in
                isGeocoding = false
                if let item = response?.mapItems.first {
                    latitude = item.placemark.coordinate.latitude
                    longitude = item.placemark.coordinate.longitude
                    geocodeStatusMessage = "「\(item.name ?? query)」の座標を設定しました"
                } else {
                    geocodeStatusMessage = "該当する住所が見つかりませんでした（現在のマップ中央座標を使用します）"
                }
            }
        }
    }
}

/// ピンの詳細表示・編集・削除シート
struct IncidentPinDetailSheet: View {
    @EnvironmentObject private var storage: SafetyStorage
    @Environment(\.dismiss) private var dismiss

    let pin: SafetyIncidentPin
    let onFocusOnMap: (CLLocationCoordinate2D) -> Void

    @State private var showDeleteStep1 = false
    @State private var showDeleteStep2 = false

    var body: some View {
        NavigationStack {
            List {
                Section("事案概要") {
                    HStack(spacing: 10) {
                        Image(systemName: pin.category.iconName)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(pin.category.pinColor, in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(pin.title)
                                .font(.headline)
                            Text(pin.category.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(pin.category.pinColor)
                        }
                    }

                    LabeledContent("場所・エリア", value: pin.addressOrArea)
                    LabeledContent("発生・記録日時", value: pin.occurredAt.formatted(date: .long, time: .shortened))
                    LabeledContent("状態") {
                        Text(pin.isResolved ? "解決済み・警戒解除" : "警戒・注意継続中")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(pin.isResolved ? Color.secondary : Color.red)
                    }
                }

                if !pin.details.isEmpty {
                    Section("詳細メモ・特徴") {
                        Text(pin.details)
                            .font(.body)
                    }
                }

                if !pin.sourceURLString.isEmpty {
                    Section("情報元ページ") {
                        Button {
                            dismiss()
                            storage.openURLInWebTab(pin.sourceURLString)
                        } label: {
                            Label("情報元のWeb記事を開く", systemImage: "safari.fill")
                        }
                    }
                }

                Section("操作") {
                    Button {
                        var updated = pin
                        updated.isResolved.toggle()
                        storage.updateIncidentPin(updated)
                        dismiss()
                    } label: {
                        Label(
                            pin.isResolved ? "「警戒・注意継続中」に戻す" : "「解決済み・警戒解除」にする",
                            systemImage: pin.isResolved ? "exclamationmark.shield" : "checkmark.shield.fill"
                        )
                    }

                    Button {
                        onFocusOnMap(pin.coordinate)
                        dismiss()
                    } label: {
                        Label("このピンの位置を地図の中心に表示", systemImage: "scope")
                    }

                    Button(role: .destructive) {
                        showDeleteStep1 = true
                    } label: {
                        Label("この事案ピンを削除する", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("事案ピンの詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                AdBannerView()
            }
            // 2段階削除確認（1回目）
            .alert("この事案ピンを削除しますか？", isPresented: $showDeleteStep1) {
                Button("いいえ", role: .cancel) {}
                Button("はい（最終確認へ）", role: .destructive) {
                    showDeleteStep2 = true
                }
            } message: {
                Text("「\(pin.title)」をマップから消去しようとしています。")
            }
            // 2段階削除確認（2回目）
            .alert("【最終確認】本当に削除してもよろしいですか？", isPresented: $showDeleteStep2) {
                Button("いいえ", role: .cancel) {}
                Button("削除する", role: .destructive) {
                    storage.deleteIncidentPin(id: pin.id)
                    dismiss()
                }
            } message: {
                Text("削除したピン情報は元に戻せません。")
            }
        }
    }
}
