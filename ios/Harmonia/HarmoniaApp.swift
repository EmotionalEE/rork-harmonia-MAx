import SwiftUI
import Observation

@main
struct HarmoniaApp: App {
    @State private var authStore: AuthStore = AuthStore()
    @State private var progressStore: UserProgressStore = UserProgressStore()
    @State private var journalStore: JournalStore = JournalStore()
    @State private var audioStore: AudioStore = AudioStore()
    @State private var vibroStore: VibroacousticStore = VibroacousticStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authStore)
                .environment(progressStore)
                .environment(journalStore)
                .environment(audioStore)
                .environment(vibroStore)
                .tint(.blue)
        }
    }
}
