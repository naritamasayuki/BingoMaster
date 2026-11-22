import SwiftUI

@main
struct FushinshaInfoApp: App {
    @StateObject private var storage = SafetyStorage()
    @StateObject private var buzzer = SecurityBuzzerManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(storage)
                .environmentObject(buzzer)
        }
    }
}
