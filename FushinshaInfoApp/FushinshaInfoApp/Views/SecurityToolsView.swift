import SwiftUI
import UIKit

/// タブ4：防犯ブザー・緊急連絡・防犯チェックリスト・データ管理画面
struct SecurityToolsView: View {
    @EnvironmentObject private var storage: SafetyStorage
    @EnvironmentObject private var buzzer: SecurityBuzzerManager

    // 2段階リセット確認フラグ（マップピン全消去）
    @State private var showResetPinsStep1 = false
    @State private var showResetPinsStep2 = false

    // 2段階リセット確認フラグ（チェックリスト初期化）
    @State private var showResetChecklistStep1 = false
    @State private var showResetChecklistStep2 = false

    // 2段階リセット確認フラグ（アプリ全データ初期化）
    @State private var showResetAllStep1 = false
    @State private var showResetAllStep2 = false

    private var completedCheckCount: Int {
        storage.checklistItems.filter(\.isChecked).count
    }

    var body: some View {
        NavigationStack {
            List {
                // 1. 緊急防犯ブザーセクション
                Section {
                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: buzzer.isBuzzerActive ? "light.beacon.max.fill" : "bell.and.waves.left.and.right.fill")
                                .font(.title2)
                                .foregroundStyle(buzzer.isBuzzerActive ? Color.white : Color.red)
                            Text(buzzer.isBuzzerActive ? "【作動中】防犯ブザー鳴動中！" : "緊急防犯ブザー・音声威嚇")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(buzzer.isBuzzerActive ? Color.white : Color.primary)
                            Spacer()
                        }

                        Text("危険を感じた際や不審者に遭遇した際、ボタンを押すと大音量の警報サイレンと画面点滅・音声アナウンスで周囲に異常を知らせます。")
                            .font(.caption)
                            .foregroundStyle(buzzer.isBuzzerActive ? Color.white.opacity(0.9) : Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Toggle(isOn: $buzzer.useVoiceAlert) {
                            Text("日本語の緊急音声（「助けてください」）も同時に流す")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(buzzer.isBuzzerActive ? Color.white : Color.primary)
                        }
                        .tint(.orange)

                        Button {
                            buzzer.toggleBuzzer()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: buzzer.isBuzzerActive ? "stop.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.title3.weight(.bold))
                                Text(buzzer.isBuzzerActive ? "防犯ブザーを停止する" : "防犯ブザーを鳴らす（緊急）")
                                    .font(.headline.weight(.heavy))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(buzzer.isBuzzerActive ? Color.black.opacity(0.85) : Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(
                        buzzer.isBuzzerActive
                        ? (buzzer.isFlashScreenRed ? Color.red : Color.orange)
                        : Color(uiColor: .secondarySystemGroupedBackground)
                    )
                } header: {
                    Text("防犯ブザー")
                }

                // 2. 緊急通報・警察相談ダイヤル
                Section {
                    emergencyCallRow(
                        title: "110番（警察・緊急通報）",
                        subtitle: "事件・事故・目の前の不審者など緊急時",
                        phoneNumber: "110",
                        color: .red,
                        icon: "phone.fill.badge.plus"
                    )

                    emergencyCallRow(
                        title: "#9110（警察相談専用電話）",
                        subtitle: "緊急ではない不審者情報・ストーカー・防犯相談",
                        phoneNumber: "#9110",
                        color: .blue,
                        icon: "person.badge.shield.checkmark.fill"
                    )

                    emergencyCallRow(
                        title: "119番（消防・救急）",
                        subtitle: "怪我・急病・火災などの緊急時",
                        phoneNumber: "119",
                        color: .orange,
                        icon: "cross.case.fill"
                    )
                } header: {
                    Text("緊急連絡・相談窓口")
                } footer: {
                    Text("※タップするとiPhoneの電話発信確認が表示されます。")
                }

                // 3. 防犯セルフチェックリスト（自動保存）
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("防犯対策の達成状況")
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            Text("\(completedCheckCount) / \(storage.checklistItems.count) 項目完了")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.blue)
                        }
                        ProgressView(
                            value: Double(completedCheckCount),
                            total: Double(max(storage.checklistItems.count, 1))
                        )
                        .tint(.green)
                    }
                    .padding(.vertical, 4)

                    ForEach(storage.checklistItems) { item in
                        Button {
                            storage.toggleChecklistItem(id: item.id)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(item.isChecked ? Color.green : Color.secondary)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.category)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.blue)
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .strikethrough(item.isChecked, color: .secondary)
                                    Text(item.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Button(role: .destructive) {
                        showResetChecklistStep1 = true
                    } label: {
                        Label("チェックリストのチェック状態をリセット", systemImage: "arrow.counterclockwise")
                            .font(.subheadline)
                    }
                } header: {
                    Text("外出・登下校・在宅の防犯チェックリスト")
                }

                // 4. データ管理・リセット（すべて2段階確認・初期値「いいえ」）
                Section {
                    Button {
                        storage.restoreSampleIncidentPins()
                    } label: {
                        Label("見本（サンプル）のマップピンを再読み込み", systemImage: "mappin.circle.fill")
                    }

                    Button(role: .destructive) {
                        showResetPinsStep1 = true
                    } label: {
                        Label("マップに記録した全事案ピンを消去する", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        showResetAllStep1 = true
                    } label: {
                        Label("アプリ内の全データを初期状態にリセットする", systemImage: "trash.slash.fill")
                    }
                } header: {
                    Text("データ管理・初期化")
                } footer: {
                    Text("すべての記録・マイ地域・履歴は操作ごとに自動保存されています。")
                }
            }
            .navigationTitle("防犯ツール・設定")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                AdBannerView()
            }
            // チェックリストリセット 1段階目
            .alert("防犯チェックリストをリセットしますか？", isPresented: $showResetChecklistStep1) {
                Button("いいえ", role: .cancel) {}
                Button("はい（最終確認へ）", role: .destructive) {
                    showResetChecklistStep2 = true
                }
            } message: {
                Text("すべてのチェック項目を未完了の状態に戻そうとしています。")
            }
            // チェックリストリセット 2段階目
            .alert("【最終確認】本当にチェック状態をリセットしますか？", isPresented: $showResetChecklistStep2) {
                Button("いいえ", role: .cancel) {}
                Button("リセットする", role: .destructive) {
                    storage.resetChecklistChecks()
                }
            } message: {
                Text("チェック状態がすべて初期化されます。")
            }
            // マップピン全消去 1段階目
            .alert("マップの事案ピンをすべてリセットしますか？", isPresented: $showResetPinsStep1) {
                Button("いいえ", role: .cancel) {}
                Button("はい（最終確認へ）", role: .destructive) {
                    showResetPinsStep2 = true
                }
            } message: {
                Text("登録されている不審者・防犯マップのピン（\(storage.incidentPins.count)件）をすべて消去しようとしています。")
            }
            // マップピン全消去 2段階目
            .alert("【最終確認】本当にマップピンをすべて消去しますか？", isPresented: $showResetPinsStep2) {
                Button("いいえ", role: .cancel) {}
                Button("すべて消去する", role: .destructive) {
                    storage.clearAllIncidentPins()
                }
            } message: {
                Text("この操作を実行すると元に戻すことはできません。")
            }
            // アプリ全データ初期化 1段階目
            .alert("アプリ内の全データをリセットしますか？", isPresented: $showResetAllStep1) {
                Button("いいえ", role: .cancel) {}
                Button("はい（最終確認へ）", role: .destructive) {
                    showResetAllStep2 = true
                }
            } message: {
                Text("保存したブックマーク、閲覧履歴、マップピン、マイ地域設定をすべて初期状態に戻そうとしています。")
            }
            // アプリ全データ初期化 2段階目
            .alert("【最終確認】本当にすべてのデータを初期化しますか？", isPresented: $showResetAllStep2) {
                Button("いいえ", role: .cancel) {}
                Button("全データを初期化する", role: .destructive) {
                    storage.resetAllAppData()
                }
            } message: {
                Text("消去されたデータは復元できません。本当によろしいですか？")
            }
        }
    }

    private func emergencyCallRow(
        title: String,
        subtitle: String,
        phoneNumber: String,
        color: Color,
        icon: String
    ) -> some View {
        Button {
            let encoded = phoneNumber.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? phoneNumber
            if let url = URL(string: "tel://\(encoded)") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "phone.arrow.up.right.fill")
                    .font(.subheadline)
                    .foregroundStyle(color)
            }
            .padding(.vertical, 2)
        }
    }
}
