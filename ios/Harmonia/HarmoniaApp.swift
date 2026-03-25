import SwiftUI
import Observation
import RevenueCat

@main
struct HarmoniaApp: App {
    @State private var authStore: AuthStore = AuthStore()
    @State private var progressStore: UserProgressStore = UserProgressStore()
    @State private var journalStore: JournalStore = JournalStore()
    @State private var audioStore: AudioStore = AudioStore()
    @State private var vibroStore: VibroacousticStore = VibroacousticStore()
    @State private var storeVM: StoreViewModel = StoreViewModel()

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY)
        #else
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authStore)
                .environment(progressStore)
                .environment(journalStore)
                .environment(audioStore)
                .environment(vibroStore)
                .environment(storeVM)
                .tint(.blue)
        }
    }
}
