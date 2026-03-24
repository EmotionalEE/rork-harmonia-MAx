import SwiftUI
import Observation
import AVFoundation
import PhotosUI
import UIKit

nonisolated struct AppUser: Codable, Sendable, Equatable {
    let id: String
    let email: String
    let name: String
}

nonisolated struct SubscriptionState: Codable, Sendable, Equatable {
    var isPaid: Bool
    var isInTrial: Bool
    var trialStartDate: String?
    var subscriptionStartDate: String?

    var isPaidSubscriber: Bool {
        if isPaid {
            return true
        }
        guard let trialStartDate, let date: Date = ISO8601DateFormatter().date(from: trialStartDate) else {
            return false
        }
        return Date().timeIntervalSince(date) <= 7 * 24 * 60 * 60
    }
}

nonisolated struct ProfilePictureState: Codable, Sendable, Equatable {
    var type: String
    var value: String
}

nonisolated struct EmotionTrackingState: Codable, Sendable, Equatable {
    var emotion: String
    var currentLevel: Int
    var desiredLevel: Int
}

nonisolated struct EmotionLog: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let emotion: String
    let level: Int
    let at: String
}

nonisolated struct ReflectionEntry: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let sessionId: String
    let sessionName: String
    let completedAt: String
    let sliderValue: Double
    let journalText: String?
    let insight: String
    let microLabel: String?
}

nonisolated struct UserProgressSnapshot: Codable, Sendable, Equatable {
    var name: String
    var totalSessions: Int
    var totalMinutes: Int
    var streak: Int
    var lastSessionDate: String?
    var completedSessions: [String]
    var emotionTracking: EmotionTrackingState?
    var emotionLogs: [EmotionLog]
    var reflectionLog: [ReflectionEntry]
    var subscription: SubscriptionState
    var profilePicture: ProfilePictureState
}

nonisolated struct JournalEntry: Codable, Sendable, Equatable, Identifiable {
    var id: String { date }
    let date: String
    var emotion: String
    var progress: Double
    var note: String?
}

nonisolated struct SessionAudioSource: Codable, Sendable, Hashable {
    let url: String
    let mimeType: String
}

nonisolated struct Session: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let title: String
    let description: String
    let duration: Int
    let frequency: String
    let gradientHex: [String]
    let targetEmotions: [String]
    let audioURL: String
    let audioSources: [SessionAudioSource]
    let tempoBPM: Int?

    var colors: [Color] {
        gradientHex.map { Color(hex: $0) }
    }
}

nonisolated struct EmotionalState: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let label: String
    let gradientHex: [String]
    let geometry: String

    var colors: [Color] {
        gradientHex.map { Color(hex: $0) }
    }
}

nonisolated struct VibroPattern: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let frequencies: [Double]
    let vibrationPattern: [Double]
    let hapticIntensity: Double
    let duration: Int
}

nonisolated enum AppRoute: Hashable, Identifiable, Sendable {
    case onboarding
    case introSession
    case session(String)
    case endReflection(String)
    case feelingsChat(FeelingsChatContext)
    case insights
    case resetPassword
    case terms
    case vibroSettings

    var id: String {
        switch self {
        case .onboarding: return "onboarding"
        case .introSession: return "intro-session"
        case .session(let id): return "session-\(id)"
        case .endReflection(let id): return "end-reflection-\(id)"
        case .feelingsChat(let context): return "feelings-chat-\(context.id)"
        case .insights: return "insights"
        case .resetPassword: return "reset-password"
        case .terms: return "terms"
        case .vibroSettings: return "vibro-settings"
        }
    }
}

nonisolated struct FeelingsChatContext: Hashable, Codable, Sendable, Identifiable {
    let id: String
    let source: String
    let sessionId: String?
    let sessionName: String?
    let feelingDelta: String?
    let feelingScore: Double?
    let dateISO: String?
    let userNote: String?
}

nonisolated struct ChatMessage: Hashable, Identifiable, Sendable {
    let id: String
    let role: String
    let text: String
}

@MainActor
@Observable
final class AuthStore {
    private let tokenKey: String = "auth_token"
    private let userKey: String = "auth_user"

    var token: String?
    var user: AppUser?
    var isLoading: Bool = true
    var authError: String?

    var isAuthenticated: Bool {
        token != nil && user != nil
    }

    init() {
        hydrate()
    }

    func hydrate() {
        isLoading = true
        let defaults: UserDefaults = .standard
        token = defaults.string(forKey: tokenKey)
        guard let rawUser: String = defaults.string(forKey: userKey), let data: Data = rawUser.data(using: .utf8) else {
            if token == nil {
                user = nil
            }
            isLoading = false
            return
        }
        do {
            let decoded: AppUser = try JSONDecoder().decode(AppUser.self, from: data)
            user = decoded
        } catch {
            clearAuth()
        }
        isLoading = false
    }

    func setAuth(token: String, user: AppUser) {
        self.token = token
        self.user = user
        authError = nil
        let defaults: UserDefaults = .standard
        defaults.set(token, forKey: tokenKey)
        if let data: Data = try? JSONEncoder().encode(user), let raw: String = String(data: data, encoding: .utf8) {
            defaults.set(raw, forKey: userKey)
        }
    }

    func clearAuth() {
        token = nil
        user = nil
        let defaults: UserDefaults = .standard
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: userKey)
    }

    func signIn(email: String, password: String, name: String? = nil) -> Bool {
        guard email.contains("@"), password.count >= 8 else {
            authError = "Please enter a valid email and password."
            return false
        }
        let resolvedName: String = name?.isEmpty == false ? name ?? "Harmonia Explorer" : user?.name ?? "Harmonia Explorer"
        let newUser = AppUser(id: UUID().uuidString, email: email, name: resolvedName)
        setAuth(token: UUID().uuidString, user: newUser)
        return true
    }

    func demoLogin() {
        let demoUser = AppUser(id: "demo-user", email: "test@example.com", name: "Harmonia Explorer")
        setAuth(token: "demo-token-local", user: demoUser)
    }
}

@MainActor
@Observable
final class UserProgressStore {
    private let progressKey: String = "harmonia_progress_v1"
    private let welcomeKey: String = "welcome_seen"
    private let onboardingKey: String = "onboarding_completed"

    var progress: UserProgressSnapshot
    var hasSeenWelcome: Bool
    var hasCompletedOnboarding: Bool

    init() {
        let defaults: UserDefaults = .standard
        hasSeenWelcome = defaults.bool(forKey: welcomeKey)
        hasCompletedOnboarding = defaults.bool(forKey: onboardingKey)
        progress = UserProgressStore.defaultProgress()
        hydrate()
    }

    static func defaultProgress() -> UserProgressSnapshot {
        UserProgressSnapshot(
            name: "Mindful Seeker",
            totalSessions: 0,
            totalMinutes: 0,
            streak: 0,
            lastSessionDate: nil,
            completedSessions: [],
            emotionTracking: nil,
            emotionLogs: [],
            reflectionLog: [],
            subscription: SubscriptionState(
                isPaid: false,
                isInTrial: true,
                trialStartDate: ISO8601DateFormatter().string(from: Date()),
                subscriptionStartDate: nil
            ),
            profilePicture: ProfilePictureState(type: "default", value: "default")
        )
    }

    func hydrate() {
        guard let raw: String = UserDefaults.standard.string(forKey: progressKey), raw.contains("{"), let data: Data = raw.data(using: .utf8) else {
            progress = Self.defaultProgress()
            persist()
            return
        }
        do {
            let decoded: UserProgressSnapshot = try JSONDecoder().decode(UserProgressSnapshot.self, from: data)
            if decoded.name.isEmpty {
                progress = Self.defaultProgress()
            } else {
                progress = decoded
            }
        } catch {
            progress = Self.defaultProgress()
            persist()
        }
    }

    func persist() {
        if let data: Data = try? JSONEncoder().encode(progress), let raw: String = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(raw, forKey: progressKey)
        }
        UserDefaults.standard.set(hasSeenWelcome, forKey: welcomeKey)
        UserDefaults.standard.set(hasCompletedOnboarding, forKey: onboardingKey)
    }

    func completeWelcome() {
        hasSeenWelcome = true
        persist()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        persist()
    }

    func addSession(sessionId: String, durationMinutes: Int) {
        let todayString: String = Date.harmoniaDayString(from: Date())
        if let last = progress.lastSessionDate, let lastDate: Date = Date.harmoniaDayFormatter.date(from: last), let todayDate: Date = Date.harmoniaDayFormatter.date(from: todayString) {
            let days: Int = Calendar.current.dateComponents([.day], from: lastDate, to: todayDate).day ?? 0
            if days == 1 {
                progress.streak += 1
            } else if days > 1 {
                progress.streak = 1
            }
        } else {
            progress.streak = 1
        }
        progress.lastSessionDate = todayString
        progress.totalSessions += 1
        progress.totalMinutes += durationMinutes
        progress.completedSessions.insert(sessionId, at: 0)
        persist()
    }

    func resetProgress() {
        progress = Self.defaultProgress()
        persist()
    }

    func updateEmotionTracking(emotion: String, currentLevel: Int, desiredLevel: Int) {
        progress.emotionTracking = EmotionTrackingState(emotion: emotion, currentLevel: currentLevel, desiredLevel: desiredLevel)
        persist()
    }

    func addEmotionLog(emotion: String, level: Int) {
        progress.emotionLogs.insert(EmotionLog(id: UUID().uuidString, emotion: emotion, level: level, at: ISO8601DateFormatter().string(from: Date())), at: 0)
        persist()
    }

    func addReflectionEntry(sessionId: String, sessionName: String, sliderValue: Double, journalText: String?, microLabel: String?) -> ReflectionEntry {
        let entry = ReflectionEntry(
            id: UUID().uuidString,
            sessionId: sessionId,
            sessionName: sessionName,
            completedAt: ISO8601DateFormatter().string(from: Date()),
            sliderValue: sliderValue,
            journalText: journalText,
            insight: "Emotional freedom often arrives in layers. What you notice today still counts as movement.",
            microLabel: microLabel
        )
        progress.reflectionLog.insert(entry, at: 0)
        progress.reflectionLog = Array(progress.reflectionLog.prefix(200))
        persist()
        return entry
    }

    func activateSubscription() {
        progress.subscription.isPaid = true
        progress.subscription.subscriptionStartDate = ISO8601DateFormatter().string(from: Date())
        persist()
    }

    func updateProfilePicture(type: String, value: String) {
        progress.profilePicture = ProfilePictureState(type: type, value: value)
        persist()
    }

    func updateName(name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        progress.name = name
        persist()
    }

    func logout() {
        hasSeenWelcome = false
        hasCompletedOnboarding = false
        persist()
    }

    func lastEmotionLevel(for emotion: String) -> Int? {
        progress.emotionLogs.first(where: { $0.emotion == emotion })?.level
    }
}

@MainActor
@Observable
final class JournalStore {
    private let key: String = "harmonia_journal_entries"
    var entries: [JournalEntry] = []
    var isLoading: Bool = true

    init() {
        refreshEntries()
    }

    func refreshEntries() {
        isLoading = true
        defer { isLoading = false }
        guard let raw: String = UserDefaults.standard.string(forKey: key), let data: Data = raw.data(using: .utf8), let decoded: [JournalEntry] = try? JSONDecoder().decode([JournalEntry].self, from: data) else {
            entries = Self.seedEntries()
            persist()
            return
        }
        entries = decoded.sorted { $0.date > $1.date }
    }

    static func seedEntries() -> [JournalEntry] {
        [
            JournalEntry(date: "2025-12-22", emotion: "anxious", progress: 0.28, note: "I softened after naming what felt urgent."),
            JournalEntry(date: "2025-12-24", emotion: "calm", progress: 0.63, note: "The body felt quieter tonight."),
            JournalEntry(date: "2025-12-28", emotion: "inspired", progress: 0.82, note: "A clearer story is starting to emerge.")
        ]
    }

    func getEntryByDate(_ date: String) -> JournalEntry? {
        entries.first(where: { $0.date == date })
    }

    func upsertEntry(_ entry: JournalEntry) {
        entries.removeAll { $0.date == entry.date }
        entries.insert(entry, at: 0)
        entries.sort { $0.date > $1.date }
        persist()
    }

    func removeEntry(_ date: String) {
        entries.removeAll { $0.date == date }
        persist()
    }

    private func persist() {
        if let data: Data = try? JSONEncoder().encode(entries), let raw: String = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(raw, forKey: key)
        }
    }
}

@MainActor
@Observable
final class AudioStore {
    var isPlaying: Bool = false
    var currentSessionID: String?
    var currentTime: Double = 0
    var duration: Double = 120
    var volume: Double = 0.8
    var errorMessage: String?

    private var player: AVPlayer?
    private var periodicObserver: Any?

    func preload(session: Session) {
        currentSessionID = session.id
        duration = Double(session.duration * 60)
        currentTime = 0
        errorMessage = nil
        guard let url: URL = URL(string: normalizeDropboxURL(session.audioURL)) else {
            return
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.volume = Float(volume)
        self.player = player
        installObserver(on: player)
    }

    func play(session: Session) {
        if currentSessionID != session.id || player == nil {
            preload(session: session)
        }
        isPlaying = true
        player?.play()
    }

    func pause() {
        isPlaying = false
        player?.pause()
    }

    func stop() {
        isPlaying = false
        player?.pause()
        player?.seek(to: .zero)
        currentTime = 0
    }

    func seek(to seconds: Double) {
        currentTime = min(max(0, seconds), duration)
        let time = CMTime(seconds: currentTime, preferredTimescale: 600)
        player?.seek(to: time)
    }

    func skip(by seconds: Double) {
        seek(to: currentTime + seconds)
    }

    func setVolume(_ value: Double) {
        volume = value
        player?.volume = Float(value)
    }

    func normalizeDropboxURL(_ raw: String) -> String {
        raw.replacingOccurrences(of: "?dl=0", with: "?raw=1")
    }

    private func installObserver(on player: AVPlayer) {
        if let periodicObserver, let oldPlayer = self.player {
            oldPlayer.removeTimeObserver(periodicObserver)
            self.periodicObserver = nil
        }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        periodicObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                if let itemDuration = player.currentItem?.duration.seconds, itemDuration.isFinite, itemDuration > 0 {
                    self.duration = itemDuration
                }
                if self.currentTime >= max(self.duration - 0.75, 1), self.isPlaying {
                    self.isPlaying = false
                }
            }
        }
    }
}

@MainActor
@Observable
final class VibroacousticStore {
    private let binauralKey: String = "session_binaural_intensity_v1"
    private let isoKey: String = "session_iso_intensity_v1"

    var isVibroacousticActive: Bool = false
    var currentPattern: String = "meditation"
    var intensity: Double = 0.6
    var hapticSensitivity: Double = 0.6
    var binauralIntensity: Double
    var isochronicIntensity: Double
    var baseFrequency: Double = 200
    var beatFrequency: Double = 10
    var isochronicFrequency: Double = 8

    let patterns: [VibroPattern] = [
        VibroPattern(id: "meditation", name: "Meditation", frequencies: [174, 285, 396], vibrationPattern: [0.4, 0.6, 0.3], hapticIntensity: 0.4, duration: 180),
        VibroPattern(id: "healing", name: "Healing", frequencies: [528, 639, 741], vibrationPattern: [0.5, 0.2, 0.5], hapticIntensity: 0.5, duration: 180),
        VibroPattern(id: "energizing", name: "Energizing", frequencies: [852, 963, 432], vibrationPattern: [0.8, 0.4, 0.8], hapticIntensity: 0.75, duration: 120),
        VibroPattern(id: "relaxation", name: "Relaxation", frequencies: [174, 432, 528], vibrationPattern: [0.2, 0.4, 0.2], hapticIntensity: 0.35, duration: 240),
        VibroPattern(id: "focus", name: "Focus", frequencies: [320, 480, 640], vibrationPattern: [0.5, 0.5, 0.2], hapticIntensity: 0.55, duration: 150)
    ]

    init() {
        let defaults: UserDefaults = .standard
        let savedBinaural = defaults.double(forKey: binauralKey)
        let savedIso = defaults.double(forKey: isoKey)
        binauralIntensity = savedBinaural == 0 ? 0.5 : savedBinaural
        isochronicIntensity = savedIso == 0 ? 0.5 : savedIso
    }

    func start(mode: String) {
        currentPattern = mode
        isVibroacousticActive = true
    }

    func stop() {
        isVibroacousticActive = false
    }

    func setBinauralIntensity(_ value: Double) {
        binauralIntensity = value
        UserDefaults.standard.set(value, forKey: binauralKey)
    }

    func setIsochronicIntensity(_ value: Double) {
        isochronicIntensity = value
        UserDefaults.standard.set(value, forKey: isoKey)
    }

    func configureDefaults(for sessionID: String) {
        switch sessionID {
        case "dynamic-energy-flow":
            baseFrequency = 220
            beatFrequency = 18
        case "welcome-intro":
            baseFrequency = 200
            beatFrequency = 12
        default:
            baseFrequency = 200
            beatFrequency = 10
        }
    }

    func isMobileBinauralAllowed(sessionID: String) -> Bool {
        sessionID == "dynamic-energy-flow" || sessionID == "welcome-intro"
    }
}

private let harmoniaStates: [EmotionalState] = [
    EmotionalState(id: "anxious", label: "Anxious", gradientHex: ["#14213D", "#4AA3FF"], geometry: "anxious"),
    EmotionalState(id: "stressed", label: "Stressed", gradientHex: ["#0B1022", "#1FD6C1"], geometry: "stressed"),
    EmotionalState(id: "sad", label: "Sad", gradientHex: ["#1A1C38", "#6E7FF3"], geometry: "sad"),
    EmotionalState(id: "angry", label: "Angry", gradientHex: ["#35111D", "#FF5A7A"], geometry: "angry"),
    EmotionalState(id: "calm", label: "Calm", gradientHex: ["#0C1A24", "#1FD6C1"], geometry: "calm"),
    EmotionalState(id: "happy", label: "Happy", gradientHex: ["#342112", "#F8C46C"], geometry: "happy"),
    EmotionalState(id: "inspired", label: "Inspired", gradientHex: ["#291737", "#8836E2"], geometry: "inspired"),
    EmotionalState(id: "energized", label: "Energized", gradientHex: ["#112534", "#1FD6C1"], geometry: "energized")
]

private let harmoniaSessions: [Session] = [
    Session(id: "welcome-intro", title: "Welcome / Intro Session", description: "Start here: a gentle introduction to Harmonia with a locked 12Hz binaural beat", duration: 2, frequency: "12Hz", gradientHex: ["#37D6EC", "#19B39F"], targetEmotions: ["anxious", "stressed", "calm"], audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3", audioSources: [], tempoBPM: 60),
    Session(id: "dissolution-anxiousness", title: "Quiet the Alarm", description: "Soften urgency and return to inner spaciousness.", duration: 9, frequency: "432 Hz", gradientHex: ["#0B1022", "#4AA3FF"], targetEmotions: ["anxious", "stressed"], audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3", audioSources: [], tempoBPM: 62),
    Session(id: "stress-release-flow", title: "Unwind the Mind", description: "Downshift from pressure into steadier rhythm.", duration: 11, frequency: "174 Hz", gradientHex: ["#0C1A24", "#1FD6C1"], targetEmotions: ["stressed", "angry"], audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3", audioSources: [], tempoBPM: 64),
    Session(id: "lifting-from-sadness", title: "Lifting from Sadness", description: "A synchronized lift toward warmth and motion.", duration: 12, frequency: "396 Hz", gradientHex: ["#1A1C38", "#6E7FF3"], targetEmotions: ["sad"], audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3", audioSources: [], tempoBPM: 58),
    Session(id: "alpha-waves", title: "Cooling the Edge", description: "Cool the nervous system and widen your view.", duration: 10, frequency: "10 Hz Alpha", gradientHex: ["#0B1022", "#1FD6C1"], targetEmotions: ["angry", "stressed"], audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3", audioSources: [], tempoBPM: 65),
    Session(id: "how-to-deepen-calm", title: "How to Deepen Calm", description: "A spoken sonic guide into grounded stillness.", duration: 8, frequency: "Theta Blend", gradientHex: ["#122030", "#4AA3FF"], targetEmotions: ["calm"], audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3", audioSources: [], tempoBPM: 54),
    Session(id: "741hz-detox", title: "Turn up the light", description: "Clear static and invite cleaner emotional space.", duration: 8, frequency: "741 Hz", gradientHex: ["#2F230C", "#F8C46C"], targetEmotions: ["inspired", "happy"], audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3", audioSources: [], tempoBPM: 68),
    Session(id: "theta-healing", title: "Settle the System", description: "Melt into a slower wave and let the body unclench.", duration: 14, frequency: "Theta 6 Hz", gradientHex: ["#1A245A", "#148C94"], targetEmotions: ["anxious", "sad", "calm"], audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3", audioSources: [], tempoBPM: 56),
    Session(id: "396hz-release", title: "Set the Field", description: "Release charge and re-enter the room of yourself.", duration: 9, frequency: "396 Hz", gradientHex: ["#211323", "#8836E2"], targetEmotions: ["sad", "angry"], audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3", audioSources: [], tempoBPM: 60),
    Session(id: "delta-sleep", title: "Held in Stillness", description: "A night-facing drift into depth and safety.", duration: 20, frequency: "Delta 2 Hz", gradientHex: ["#070A12", "#4AA3FF"], targetEmotions: ["anxious", "sad", "calm"], audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3", audioSources: [], tempoBPM: 48),
    Session(id: "gamma-insight", title: "Acceptance Flow", description: "A luminous channel toward insight and steadiness.", duration: 13, frequency: "40 Hz Gamma", gradientHex: ["#16202E", "#F8C46C"], targetEmotions: ["inspired", "energized", "happy"], audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3", audioSources: [], tempoBPM: 72),
    Session(id: "528hz-love", title: "Open to what is", description: "A heart-opening field for gentler self-contact.", duration: 10, frequency: "528 Hz", gradientHex: ["#102922", "#1FD6C1"], targetEmotions: ["calm", "happy"], audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3", audioSources: [], tempoBPM: 64),
    Session(id: "how-to-spark-inspiration", title: "How to Spark Inspiration", description: "Invite fresh language, movement, and courage.", duration: 7, frequency: "852 Hz", gradientHex: ["#291737", "#8836E2"], targetEmotions: ["inspired"], audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-13.mp3", audioSources: [], tempoBPM: 74),
    Session(id: "dynamic-energy-flow", title: "Dynamic Energy Flow", description: "Build clean momentum without losing inner coherence.", duration: 9, frequency: "18 Hz", gradientHex: ["#10303A", "#1FD6C1"], targetEmotions: ["energized", "happy"], audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-14.mp3", audioSources: [], tempoBPM: 88)
]

struct ContentView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(UserProgressStore.self) private var progressStore
    @State private var path: NavigationPath = NavigationPath()
    @State private var sheet: ActiveSheet?
    @State private var isHydrating: Bool = true
    @State private var loadFailed: Bool = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                HarmoniaBackgroundView(colors: [Color(hex: "#070A12"), Color(hex: "#0B1022")])
                rootContent
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppRoute.self) { route in
                routeView(route)
            }
            .sheet(item: $sheet) { item in
                sheetView(item)
            }
        }
        .task {
            await hydrateStartup()
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if isHydrating {
            StartupLoadingView()
        } else if loadFailed {
            StartupErrorView {
                Task {
                    await hydrateStartup()
                }
            }
        } else if !progressStore.hasSeenWelcome || !authStore.isAuthenticated {
            WelcomeView(
                onSuccess: {
                    progressStore.completeWelcome()
                },
                onResetPassword: {
                    path.append(AppRoute.resetPassword)
                },
                onTerms: {
                    path.append(AppRoute.terms)
                }
            )
        } else if !progressStore.hasCompletedOnboarding {
            OnboardingView {
                path.append(AppRoute.introSession)
            }
        } else {
            HomeView(
                onOpenSession: { session in
                    path.append(AppRoute.session(session.id))
                },
                onOpenInsights: {
                    path.append(AppRoute.insights)
                },
                onOpenJournal: {
                    sheet = .journal(Date.harmoniaDayString(from: Date()))
                },
                onOpenProfile: {
                    sheet = .profile
                },
                onOpenSubscription: {
                    sheet = .subscription
                }
            )
        }
    }

    private func hydrateStartup() async {
        isHydrating = true
        loadFailed = false
        do {
            try await Task.sleep(for: .milliseconds(900))
            authStore.hydrate()
            progressStore.hydrate()
            isHydrating = false
        } catch {
            loadFailed = true
            isHydrating = false
        }
    }

    @ViewBuilder
    private func routeView(_ route: AppRoute) -> some View {
        switch route {
        case .onboarding:
            OnboardingView {
                path.append(AppRoute.introSession)
            }
        case .introSession:
            IntroSessionView(
                onBegin: {
                    progressStore.completeOnboarding()
                    path = NavigationPath()
                    path.append(AppRoute.session("welcome-intro"))
                },
                onSkip: {
                    progressStore.completeOnboarding()
                    path = NavigationPath()
                }
            )
        case .session(let sessionID):
            SessionPlayerView(sessionID: sessionID) { completedSessionID in
                path.append(AppRoute.endReflection(completedSessionID))
            }
        case .endReflection(let sessionID):
            EndReflectionView(sessionID: sessionID) { context in
                path.append(AppRoute.feelingsChat(context))
            }
        case .feelingsChat(let context):
            FeelingsChatView(context: context)
        case .insights:
            InsightsView(onDismiss: {
                path.removeLast()
            })
        case .resetPassword:
            ResetPasswordView {
                path.removeLast()
            }
        case .terms:
            TermsView()
        case .vibroSettings:
            VibroacousticSettingsView()
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .profile:
            ProfileView(onOpenInsights: {
                self.sheet = nil
                path.append(AppRoute.insights)
            }, onOpenVibro: {
                self.sheet = nil
                path.append(AppRoute.vibroSettings)
            })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        case .subscription:
            SubscriptionView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        case .journal(let date):
            JournalEntryView(date: date, onDeepen: { context in
                self.sheet = nil
                path.append(AppRoute.feelingsChat(context))
            })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
    }
}

nonisolated enum ActiveSheet: Hashable, Identifiable, Sendable {
    case profile
    case subscription
    case journal(String)

    var id: String {
        switch self {
        case .profile: return "profile"
        case .subscription: return "subscription"
        case .journal(let date): return "journal-\(date)"
        }
    }
}

struct StartupLoadingView: View {
    @State private var animate: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            Circle()
                .fill(.linearGradient(colors: [Color(hex: "#8836E2"), Color(hex: "#1FD6C1")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 118, height: 118)
                .blur(radius: 1)
                .scaleEffect(animate ? 1.08 : 0.94)
                .opacity(animate ? 1 : 0.72)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: animate)
            Text("Preparing your session space")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("Just a moment while we set everything up.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(24)
        .task {
            animate = true
        }
    }
}

struct StartupErrorView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundStyle(Color(hex: "#F8C46C"))
            Text("Something went wrong")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("We couldn't prepare your space right now.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            Button(action: retry) {
                Text("Retry")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(HarmoniaPrimaryButtonStyle(colors: [Color(hex: "#5237D6"), Color(hex: "#8836E2")]))
            .padding(.horizontal, 32)
        }
        .padding(24)
    }
}

struct WelcomeView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(UserProgressStore.self) private var progressStore
    let onSuccess: () -> Void
    let onResetPassword: () -> Void
    let onTerms: () -> Void

    @State private var mode: Int = 0
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var acceptedTerms: Bool = false
    @State private var marketing: Bool = true
    @State private var hidePassword: Bool = true
    @State private var localError: String?
    @State private var pulse: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 18) {
                    Image("HarmoniaLoginLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 320)
                        .shadow(color: .white.opacity(0.12), radius: 24, y: 12)
                        .scaleEffect(pulse ? 1.05 : 0.95)
                        .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: pulse)
                        .accessibilityLabel("Harmonia")
                    Text("Transform your emotional landscape through the power of sound frequencies and music")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(maxWidth: 320)
                }
                .padding(.top, 48)

                VStack(spacing: 16) {
                    Picker("Auth Mode", selection: $mode) {
                        Text("Sign In").tag(0)
                        Text("Create Account").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if mode == 1 {
                        HarmoniaInputField(title: "Name", text: $name)
                    }
                    HarmoniaInputField(title: "Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    HStack(spacing: 12) {
                        Group {
                            if hidePassword {
                                SecureField("Password", text: $password)
                            } else {
                                TextField("Password", text: $password)
                            }
                        }
                        .font(.body)
                        .foregroundStyle(.white)
                        Button {
                            hidePassword.toggle()
                        } label: {
                            Image(systemName: hidePassword ? "eye.slash" : "eye")
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    }

                    if mode == 1 {
                        Toggle(isOn: $acceptedTerms) {
                            HStack(spacing: 4) {
                                Text("I agree to the")
                                Button("Terms") {
                                    onTerms()
                                }
                            }
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.8))
                        }
                        .tint(Color(hex: "#8836E2"))

                        Toggle(isOn: $marketing) {
                            Text("Keep me updated with new sessions")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .tint(Color(hex: "#8836E2"))
                    }

                    if let localError {
                        Text(localError)
                            .font(.footnote)
                            .foregroundStyle(Color(hex: "#FF5A7A"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        submit()
                    } label: {
                        Text(mode == 0 ? "Continue" : "Create Account")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(HarmoniaPrimaryButtonStyle(colors: [Color(hex: "#5237D6"), Color(hex: "#8836E2")]))
                    .testID("auth-cta")

                    if mode == 0 {
                        Button("Forgot password?") {
                            onResetPassword()
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.76))
                    }

                    Button {
                        authStore.demoLogin()
                        progressStore.completeWelcome()
                        onSuccess()
                    } label: {
                        Text("Continue with demo")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(HarmoniaGlassButtonStyle())
                    .testID("demo-login")
                }
                .padding(20)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 26))
                .overlay {
                    RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .scrollIndicators(.hidden)
        .background(
            LinearGradient(colors: [.black, Color(hex: "#5237D6"), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .task {
            pulse = true
        }
    }

    private func submit() {
        localError = nil
        guard email.contains("@") else {
            localError = "Please enter a valid email."
            return
        }
        guard password.count >= 8 else {
            localError = "Password must be at least 8 characters."
            return
        }
        if mode == 1 {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                localError = "Please enter your name."
                return
            }
            guard acceptedTerms else {
                localError = "Please accept the terms to continue."
                return
            }
        }
        let success: Bool = authStore.signIn(email: email, password: password, name: mode == 1 ? name : nil)
        guard success else {
            localError = authStore.authError
            return
        }
        progressStore.completeWelcome()
        onSuccess()
    }
}

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var page: Int = 0

    private let pages: [(String, String, String, [Color])] = [
        ("brain.head.profile", "Train Your Mind", "Use beautifully paced sound journeys to notice, name, and soften emotional charge.", [Color(hex: "#1A245A"), Color(hex: "#5237D6")]),
        ("waveform.path.ecg", "Binaural Beats & Frequencies", "Layer gentle resonance tools into sessions for a more immersive nervous-system experience.", [Color(hex: "#102922"), Color(hex: "#148C94")]),
        ("sparkles", "Build Emotional Resilience", "Track subtle change over time with reflections, check-ins, and guided AI support.", [Color(hex: "#291737"), Color(hex: "#8836E2")])
    ]

    var body: some View {
        ZStack {
            HarmoniaBackgroundView(colors: pages[page].3)
            VStack(spacing: 26) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 22) {
                            Image(systemName: item.0)
                                .font(.system(size: 56, weight: .medium))
                                .foregroundStyle(.white)
                                .symbolEffect(.pulse)
                            Text(item.1)
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(.white)
                            Text(item.2)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.78))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                        }
                        .tag(index)
                        .padding(.top, 90)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? .white : .white.opacity(0.26))
                            .frame(width: index == page ? 28 : 8, height: 8)
                            .animation(.snappy, value: page)
                    }
                }

                Button {
                    if page == pages.count - 1 {
                        onComplete()
                    } else {
                        page += 1
                    }
                } label: {
                    Text(page == pages.count - 1 ? "Continue" : "Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(HarmoniaPrimaryButtonStyle(colors: [Color.white.opacity(0.22), Color.white.opacity(0.08)]))
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea()
    }
}

struct IntroSessionView: View {
    let onBegin: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack {
            introBackground

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 28) {
                    VStack(spacing: 20) {
                        Text("Welcome to Harmonia")
                            .font(.system(.largeTitle, design: .default, weight: .bold).width(.compressed))
                            .foregroundStyle(.linearGradient(colors: [Color(hex: "#EAF6FF"), Color(hex: "#B7D9FF")], startPoint: .top, endPoint: .bottom))
                            .multilineTextAlignment(.center)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared || reduceMotion ? 0 : 22)

                        VStack(spacing: 16) {
                            introParagraph("Take a breath. You're about to step into a field of sound and energy designed to reconnect you with your center.")
                            introParagraph("This short guided session helps you feel what Harmonia truly is—calm, resonance, and subtle alignment.")
                            introParagraph("Headphones are recommended for the full effect.")
                        }
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared || reduceMotion ? 0 : 28)
                    }

                    HStack(spacing: 10) {
                        IntroInfoPill(text: "2 minutes", systemImage: "timer")
                        IntroInfoPill(text: "12 Hz Flow", systemImage: "waveform.path")
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared || reduceMotion ? 0 : 18)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 44)

                VStack(spacing: 18) {
                    Button(action: onBegin) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 34, height: 34)

                                Image(systemName: "play.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color(hex: "#13C7B7"))
                                    .offset(x: 1)
                            }

                            Text("Begin Intro Journey")
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HarmoniaPrimaryButtonStyle(colors: [Color(hex: "#47F0E0"), Color(hex: "#13C7B7")]))

                    Button("I'll explore later") {
                        onSkip()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#88A9C9"))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
        .ignoresSafeArea()
        .task {
            guard !hasAppeared else {
                return
            }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.easeOut(duration: 0.8)) {
                    hasAppeared = true
                }
            }
        }
    }

    private var introBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: "#091629"),
                Color(hex: "#0E233C"),
                Color(hex: "#071827")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#47F0E0").opacity(0.4), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 180
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -90, y: -80)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#3E7BFF").opacity(0.34), .clear],
                        center: .center,
                        startRadius: 12,
                        endRadius: 220
                    )
                )
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 110, y: 120)
                .accessibilityHidden(true)
        }
    }

    private func introParagraph(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Color(hex: "#B7CAE2"))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 340)
    }
}

struct IntroInfoPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(hex: "#D7EAFE"))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white.opacity(0.08), in: .capsule)
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
    }
}

struct HomeView: View {
    @Environment(UserProgressStore.self) private var progressStore
    @State private var selectedEmotionID: String?
    @State private var showAI: Bool = false

    let onOpenSession: (Session) -> Void
    let onOpenInsights: () -> Void
    let onOpenJournal: () -> Void
    let onOpenProfile: () -> Void
    let onOpenSubscription: () -> Void

    private var filteredSessions: [Session] {
        harmoniaSessions.filter { $0.id != "welcome-intro" && (selectedEmotionID == nil || $0.targetEmotions.contains(selectedEmotionID ?? "")) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                emotionStrip
                sessionsSection
                aiCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .sheet(isPresented: $showAI) {
            AIChatModal()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HarmoniaPill(text: "Daily check-in")
                Spacer()
                Button(action: onOpenSubscription) {
                    Label("Rork Max", systemImage: "crown.fill")
                }
                .buttonStyle(HarmoniaCapsuleButtonStyle())
                .testID("subscription-open")
                Button(action: onOpenProfile) {
                    Image(systemName: "person.crop.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(HarmoniaIconButtonStyle())
                .testID("profile-open")
            }
            Text("How are you feeling?")
                .font(.system(.largeTitle, design: .default, weight: .heavy).width(.compressed))
                .foregroundStyle(.white)
            Text("Pick the emotion that feels most present. We will cue sessions that match.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.74))
            Button(action: onOpenJournal) {
                HStack {
                    Label("Daily check-in", systemImage: "calendar")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(16)
                .background(.white.opacity(0.08), in: .rect(cornerRadius: 22))
            }
            .buttonStyle(.plain)
            .testID("daily-check-in")
        }
    }

    private var emotionStrip: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Emotional state")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.88))
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(harmoniaStates) { state in
                        EmotionFilterCard(
                            state: state,
                            isSelected: selectedEmotionID == state.id,
                            action: {
                                selectedEmotionID = selectedEmotionID == state.id ? nil : state.id
                                progressStore.addEmotionLog(emotion: state.id, level: Int.random(in: 3...8))
                            }
                        )
                    }
                }
            }
            .contentMargins(.horizontal, 1)
            .scrollIndicators(.hidden)
        }
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recommended sessions")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Button("Insights") {
                    onOpenInsights()
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(hex: "#1FD6C1"))
            }
            ForEach(filteredSessions) { session in
                SessionCardView(session: session) {
                    onOpenSession(session)
                }
            }
        }
    }

    private var aiCard: some View {
        Button {
            showAI = true
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(Color(hex: "#F8C46C"))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Chat about your feelings")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("A gentle check-in, powered by AI")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
                Image(systemName: "message")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(18)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct EmotionFilterCard: View {
    let state: EmotionalState
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                EmotionIconView(emotionID: state.id, color: state.colors.last ?? .white, size: 24)
                Text(state.label)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(isSelected ? "Selected" : "Tap to filter")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
            }
            .padding(16)
            .frame(width: 132, alignment: .leading)
            .background(
                LinearGradient(
                    colors: isSelected ? state.colors : [.white.opacity(0.10), .white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: 24)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(isSelected ? 0.24 : 0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SessionCardView: View {
    let session: Session
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(session.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        HarmoniaMiniTag(text: "\(session.duration) min")
                        HarmoniaMiniTag(text: session.frequency)
                    }
                }
                Spacer(minLength: 0)
                EmotionIconView(emotionID: session.targetEmotions.first ?? "calm", color: .white, size: 32)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(LinearGradient(colors: session.colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 28))
            .contentShape(.rect(cornerRadius: 28))
        }
        .buttonStyle(.plain)
        .contentShape(.rect(cornerRadius: 28))
    }
}

struct SessionPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioStore.self) private var audioStore
    @Environment(VibroacousticStore.self) private var vibroStore
    @Environment(UserProgressStore.self) private var progressStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let sessionID: String
    let onComplete: (String) -> Void

    @State private var showExitConfirmation: Bool = false
    @State private var showVibro: Bool = false
    @State private var showBinaural: Bool = false
    @State private var showIso: Bool = false
    @State private var hasCompletedPlayback: Bool = false

    private var session: Session? {
        harmoniaSessions.first(where: { $0.id == sessionID })
    }

    private var playbackRange: ClosedRange<Double> {
        0...max(audioStore.duration, 1)
    }

    private var isBinauralActive: Bool {
        vibroStore.isVibroacousticActive && vibroStore.currentPattern == "binaural"
    }

    private var isIsochronicActive: Bool {
        vibroStore.isVibroacousticActive && vibroStore.currentPattern == "isochronic"
    }

    var body: some View {
        Group {
            if let session {
                sessionBody(session: session)
            } else {
                VStack(spacing: 16) {
                    Text("Session not found")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Button("Go back") {
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(HarmoniaBackgroundView(colors: [Color(hex: "#070A12"), Color(hex: "#0B1022")]))
            }
        }
    }

    private func sessionBody(session: Session) -> some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: session.colors + [Color(hex: "#070A12")], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            SessionGeometryHost(session: session, isAnimating: audioStore.isPlaying)
                .ignoresSafeArea()

            exitButton
                .padding(.top, 22)
                .padding(.trailing, 20)

            VStack(spacing: 0) {
                Spacer(minLength: 230)
                sessionSheet(session: session)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            audioStore.preload(session: session)
            vibroStore.configureDefaults(for: session.id)
            hasCompletedPlayback = false
        }
        .onChange(of: audioStore.currentSessionID) { _, newValue in
            if newValue != session.id {
                hasCompletedPlayback = false
            }
        }
        .onChange(of: audioStore.currentTime) { _, newValue in
            guard audioStore.duration > 0, audioStore.currentSessionID == session.id, !hasCompletedPlayback else { return }
            if newValue >= max(audioStore.duration - 0.5, 1) {
                hasCompletedPlayback = true
                completeSession(session)
            }
        }
        .alert("Are you sure you want to end this session?", isPresented: $showExitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("End Session", role: .destructive) {
                endSession()
            }
        } message: {
            Text("Your audio and vibroacoustic session will stop.")
        }
    }

    private func sessionSheet(session: Session) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 1)
                        .id("sheet-top")

                    VStack(spacing: 20) {
                        Capsule()
                            .fill(.white.opacity(0.24))
                            .frame(width: 42, height: 5)
                            .padding(.top, 10)
                            .accessibilityHidden(true)

                        VStack(spacing: 8) {
                            Text(session.title)
                                .font(.title2.weight(.bold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                            Text(session.frequency)
                                .font(.headline)
                                .foregroundStyle(Color(hex: "#7CF7E7"))
                            Text(session.description)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.76))
                        }

                        SessionScrubberView(value: Binding(get: {
                            audioStore.currentTime
                        }, set: { newValue in
                            audioStore.seek(to: newValue)
                        }), range: playbackRange)

                        HStack {
                            Text(audioStore.currentTime.harmoniaPaddedClock)
                            Spacer()
                            Text(audioStore.duration.harmoniaPaddedClock)
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.66))

                        HStack(spacing: 20) {
                            PlayerTransportButton(direction: .backward, isDisabled: !audioStore.isPlaying) {
                                audioStore.skip(by: -10)
                                HarmoniaHaptics.selection()
                            }
                            SessionPlayPauseButton(isPlaying: audioStore.isPlaying) {
                                togglePlayback(for: session)
                            }
                            PlayerTransportButton(direction: .forward, isDisabled: !audioStore.isPlaying) {
                                audioStore.skip(by: 10)
                                HarmoniaHaptics.selection()
                            }
                        }

                        HStack(spacing: 10) {
                            SmallToggleButton(title: "Vibro", systemImage: "iphone.radiowaves.left.and.right", isActive: vibroStore.isVibroacousticActive || showVibro) {
                                showVibro.toggle()
                            }
                            SmallToggleButton(title: "Binaural", systemImage: "waveform.path.ecg", isActive: isBinauralActive || showBinaural) {
                                showBinaural.toggle()
                            }
                            SmallToggleButton(title: "Iso", systemImage: "chevron.left.forwardslash.chevron.right", isActive: isIsochronicActive || showIso) {
                                showIso.toggle()
                            }
                        }

                        if showVibro {
                            VibroControlsView(sessionID: session.id)
                        }
                        if showBinaural {
                            BinauralControlsView(sessionID: session.id)
                        }
                        if showIso {
                            IsochronicControlsView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 34)
                    .padding(.top, 6)
                }
            }
            .scrollIndicators(.hidden)
            .background(.black.opacity(0.26), in: .rect(topLeadingRadius: 34, topTrailingRadius: 34))
            .overlay {
                RoundedRectangle(cornerRadius: 34)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
            .clipShape(.rect(topLeadingRadius: 34, topTrailingRadius: 34))
            .presentationContentInteraction(.scrolls)
            .onAppear {
                DispatchQueue.main.async {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) {
                        proxy.scrollTo("sheet-top", anchor: .top)
                    }
                }
            }
        }
    }

    private var exitButton: some View {
        Button {
            showExitConfirmation = true
        } label: {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.16), lineWidth: 1)
                    .frame(width: 68, height: 68)
                Circle()
                    .stroke(.white.opacity(0.22), lineWidth: 1.5)
                    .frame(width: 54, height: 54)
                Circle()
                    .fill(.black.opacity(0.22))
                    .frame(width: 40, height: 40)
                SessionExitGlyph()
                    .frame(width: 16, height: 16)
            }
            .background(.white.opacity(0.04), in: .circle)
        }
        .buttonStyle(HarmoniaScaleButtonStyle())
        .accessibilityLabel("End session")
        .accessibilityHint("Shows confirmation before leaving the session")
    }

    private func togglePlayback(for session: Session) {
        if audioStore.isPlaying {
            audioStore.pause()
        } else {
            audioStore.play(session: session)
        }
        HarmoniaHaptics.impact()
    }

    private func endSession() {
        audioStore.stop()
        vibroStore.stop()
        dismiss()
    }

    private func completeSession(_ session: Session) {
        progressStore.addSession(sessionId: session.id, durationMinutes: max(Int(audioStore.currentTime / 60), session.duration))
        audioStore.stop()
        vibroStore.stop()
        onComplete(session.id)
    }
}

enum WelcomeIntroSkipDirection {
    case backward
    case forward
}

struct WelcomeIntroPlayButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 118, height: 118)
                .background(
                    LinearGradient(
                        colors: [.white.opacity(0.30), .white.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .circle
                )
        }
        .buttonStyle(HarmoniaScaleButtonStyle())
    }
}

struct WelcomeIntroSkipButton: View {
    let direction: WelcomeIntroSkipDirection
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: direction == .backward ? "backward.end.fill" : "forward.end.fill")
                    .font(.system(size: 28, weight: .regular))
                Text("10s")
                    .font(.system(size: 20, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.5))
            .frame(width: 118, height: 86)
            .background(.white.opacity(0.12), in: .rect(cornerRadius: 24))
        }
        .buttonStyle(HarmoniaScaleButtonStyle())
    }
}

struct WelcomeIntroToggleButton: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isActive ? .white.opacity(0.22) : .white.opacity(0.12), in: .capsule)
        }
        .buttonStyle(HarmoniaScaleButtonStyle())
    }
}

struct WelcomeIntroScrubberView: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        Slider(value: $value, in: range)
            .tint(.white.opacity(0.85))
            .padding(.top, 8)
    }
}

struct WelcomeIntroGeometryBackdrop: View {
    let isAnimating: Bool
    @State private var rotate: Bool = false
    @State private var breathe: Bool = false

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .stroke(.white.opacity(0.13), lineWidth: 2)
                    .frame(width: CGFloat(180 + index * 88), height: CGFloat(180 + index * 88))
            }

            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(0.08))
                    .frame(width: 2, height: 420)
                    .rotationEffect(.degrees(Double(index) * 30))
            }

            RoundedRectangle(cornerRadius: 120)
                .stroke(.white.opacity(0.12), lineWidth: 2)
                .frame(width: 320, height: 420)

            ForEach(0..<8, id: \.self) { index in
                Ellipse()
                    .stroke(.white.opacity(0.10), lineWidth: 2)
                    .frame(width: 360, height: 180)
                    .rotationEffect(.degrees(Double(index) * 45))
            }

            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 120, height: 120)
                .blur(radius: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .rotationEffect(.degrees(rotate ? 8 : -8))
        .scaleEffect(breathe ? 1.04 : 0.98)
        .opacity(0.95)
        .animation(isAnimating ? .easeInOut(duration: 8).repeatForever(autoreverses: true) : .easeInOut(duration: 1.2), value: rotate)
        .animation(isAnimating ? .easeInOut(duration: 5).repeatForever(autoreverses: true) : .easeInOut(duration: 1.2), value: breathe)
        .task {
            rotate = true
            breathe = true
        }
    }
}

struct WelcomeIntroPanelCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)
            content
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(.white.opacity(0.10), in: .rect(cornerRadius: 28))
    }
}

struct WelcomeIntroMetricRow: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(title): \(valueText)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            HStack(spacing: 14) {
                WelcomeIntroStepperButton(symbol: "minus") {
                    value = max(range.lowerBound, value - step)
                }
                Slider(value: $value, in: range)
                    .tint(Color(hex: "#10FF93"))
                    .disabled(isLocked)
                WelcomeIntroStepperButton(symbol: "plus") {
                    value = min(range.upperBound, value + step)
                }
                .disabled(isLocked)
            }
            .opacity(isLocked ? 0.45 : 1)
        }
    }
}

struct WelcomeIntroStepperButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.12), in: .circle)
        }
        .buttonStyle(HarmoniaScaleButtonStyle())
    }
}

struct WelcomeIntroPresetFrequencyGrid: View {
    let selection: Double
    let action: (Double) -> Void
    private let presets: [Double] = [1, 4, 8, 10, 15, 20, 30, 40]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preset Frequencies")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(presets, id: \.self) { preset in
                    Button("\(Int(preset))hz") {
                        action(preset)
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(abs(selection - preset) < 0.1 ? Color(hex: "#10FF93") : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(abs(selection - preset) < 0.1 ? .white.opacity(0.18) : .white.opacity(0.10), in: .capsule)
                    .buttonStyle(HarmoniaScaleButtonStyle())
                }
            }
        }
    }
}

struct WelcomeIntroVibroControlsView: View {
    @Environment(VibroacousticStore.self) private var vibroStore
    let sessionID: String

    var body: some View {
        WelcomeIntroPanelCard(title: "Vibroacoustic Settings") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Mode")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                FlowLayout(spacing: 10) {
                    ForEach(vibroStore.patterns) { pattern in
                        Button(pattern.name) {
                            vibroStore.currentPattern = pattern.id
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(vibroStore.currentPattern == pattern.id ? Color(hex: "#10FF93") : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(vibroStore.currentPattern == pattern.id ? .white.opacity(0.18) : .white.opacity(0.10), in: .capsule)
                        .buttonStyle(HarmoniaScaleButtonStyle())
                    }
                }
                WelcomeIntroMetricRow(title: "Intensity", valueText: vibroStore.intensity.harmoniaPercentString, value: Binding(get: {
                    vibroStore.intensity
                }, set: { newValue in
                    vibroStore.intensity = newValue
                }), range: 0...1, step: 0.1, isLocked: false)
                WelcomeIntroMetricRow(title: "Haptic Sensitivity", valueText: vibroStore.hapticSensitivity.harmoniaPercentString, value: Binding(get: {
                    vibroStore.hapticSensitivity
                }, set: { newValue in
                    vibroStore.hapticSensitivity = newValue
                }), range: 0...1, step: 0.1, isLocked: false)
                Button(vibroStore.isVibroacousticActive ? "Stop Vibroacoustics" : "Start Vibroacoustics") {
                    if vibroStore.isVibroacousticActive {
                        vibroStore.stop()
                    } else {
                        vibroStore.start(mode: vibroStore.currentPattern)
                    }
                }
                .buttonStyle(HarmoniaGlassButtonStyle())
            }
        }
    }
}

struct WelcomeIntroBinauralControlsView: View {
    @Environment(VibroacousticStore.self) private var vibroStore
    let sessionID: String

    var body: some View {
        WelcomeIntroPanelCard(title: "Binaural Beats") {
            VStack(alignment: .leading, spacing: 16) {
                WelcomeIntroMetricRow(title: "Intensity", valueText: vibroStore.binauralIntensity.harmoniaPercentString, value: Binding(get: {
                    vibroStore.binauralIntensity
                }, set: { newValue in
                    vibroStore.setBinauralIntensity(newValue)
                }), range: 0...1, step: 0.1, isLocked: false)
                WelcomeIntroMetricRow(title: "Base Frequency", valueText: "\(Int(vibroStore.baseFrequency))Hz (Locked for mobile)", value: Binding(get: {
                    vibroStore.baseFrequency
                }, set: { newValue in
                    vibroStore.baseFrequency = newValue
                }), range: 100...400, step: 10, isLocked: true)
                WelcomeIntroMetricRow(title: "Beat Frequency", valueText: "\(Int(vibroStore.beatFrequency))Hz (Locked for mobile)", value: Binding(get: {
                    vibroStore.beatFrequency
                }, set: { newValue in
                    vibroStore.beatFrequency = newValue
                }), range: 1...40, step: 1, isLocked: true)
                Button("Start \(Int(vibroStore.beatFrequency))Hz Mobile Binaural") {
                    vibroStore.start(mode: "binaural")
                }
                .buttonStyle(HarmoniaGlassButtonStyle())
            }
        }
    }
}

struct WelcomeIntroIsochronicControlsView: View {
    @Environment(VibroacousticStore.self) private var vibroStore

    var body: some View {
        WelcomeIntroPanelCard(title: "Isochronic Tones") {
            VStack(alignment: .leading, spacing: 16) {
                WelcomeIntroMetricRow(title: "Intensity", valueText: vibroStore.isochronicIntensity.harmoniaPercentString, value: Binding(get: {
                    vibroStore.isochronicIntensity
                }, set: { newValue in
                    vibroStore.setIsochronicIntensity(newValue)
                }), range: 0...1, step: 0.1, isLocked: false)
                WelcomeIntroMetricRow(title: "Frequency", valueText: "\(Int(vibroStore.isochronicFrequency))Hz", value: Binding(get: {
                    vibroStore.isochronicFrequency
                }, set: { newValue in
                    vibroStore.isochronicFrequency = newValue
                }), range: 1...40, step: 1, isLocked: false)
                WelcomeIntroPresetFrequencyGrid(selection: vibroStore.isochronicFrequency) { preset in
                    vibroStore.isochronicFrequency = preset
                }
                Button("Isochronic Tones (Web Only)") {
                }
                .buttonStyle(HarmoniaGlassButtonStyle())
                .disabled(true)
            }
        }
    }
}

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum PlayerTransportDirection {
    case backward
    case forward
}

struct PlayerTransportButton: View {
    let direction: PlayerTransportDirection
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: direction == .backward ? "backward.end.fill" : "forward.end.fill")
                    .font(.title3.weight(.semibold))
                Text("10s")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(isDisabled ? 0.35 : 0.82))
            .frame(width: 76, height: 64)
            .background(.white.opacity(isDisabled ? 0.04 : 0.08), in: .rect(cornerRadius: 22))
        }
        .buttonStyle(HarmoniaScaleButtonStyle())
        .disabled(isDisabled)
        .accessibilityLabel(direction == .backward ? "Seek back 10 seconds" : "Seek forward 10 seconds")
    }
}

struct SessionPlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: isPlaying ? 0 : 2)
                .frame(width: 88, height: 88)
                .background(
                    LinearGradient(
                        colors: [.white.opacity(0.30), .white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .circle
                )
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                }
        }
        .buttonStyle(HarmoniaScaleButtonStyle())
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }
}

struct SessionExitGlyph: View {
    var body: some View {
        Canvas { context, size in
            let horizontalInset: CGFloat = size.width * 0.18
            let verticalInset: CGFloat = size.height * 0.18

            var path = Path()
            path.move(to: CGPoint(x: horizontalInset, y: verticalInset))
            path.addLine(to: CGPoint(x: size.width - horizontalInset, y: size.height - verticalInset))
            path.move(to: CGPoint(x: size.width - horizontalInset, y: verticalInset))
            path.addLine(to: CGPoint(x: horizontalInset, y: size.height - verticalInset))

            context.stroke(path, with: .color(.white.opacity(0.86)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

struct SessionScrubberView: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    @State private var trackWidth: CGFloat = 1
    @State private var isDragging: Bool = false
    @State private var lastFeedbackStep: Int = -1

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let normalizedProgress: CGFloat = progress(for: value)
                let fillWidth: CGFloat = max(4, geometry.size.width * normalizedProgress)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.16))
                        .frame(height: 4)

                    Capsule()
                        .fill(.white.opacity(0.92))
                        .frame(width: fillWidth, height: 4)

                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 24 : 18, height: isDragging ? 24 : 18)
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                        .offset(x: thumbOffset(width: geometry.size.width, progress: normalizedProgress))
                }
                .frame(height: 30)
                .contentShape(.rect)
                .onAppear {
                    trackWidth = geometry.size.width
                }
                .onChange(of: geometry.size.width) { _, newValue in
                    trackWidth = newValue
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            isDragging = true
                            updateValue(for: drag.location.x, width: geometry.size.width)
                        }
                        .onEnded { drag in
                            updateValue(for: drag.location.x, width: geometry.size.width)
                            isDragging = false
                            lastFeedbackStep = -1
                        }
                )
            }
            .frame(height: 30)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue(value.harmoniaPaddedClock)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(range.upperBound, value + 10)
            case .decrement:
                value = max(range.lowerBound, value - 10)
            @unknown default:
                break
            }
        }
    }

    private func progress(for value: Double) -> CGFloat {
        let clampedValue: Double = min(max(value, range.lowerBound), range.upperBound)
        let total: Double = max(range.upperBound - range.lowerBound, 0.001)
        return CGFloat((clampedValue - range.lowerBound) / total)
    }

    private func thumbOffset(width: CGFloat, progress: CGFloat) -> CGFloat {
        let thumbSize: CGFloat = isDragging ? 24 : 18
        return min(max(0, width * progress - (thumbSize / 2)), width - thumbSize)
    }

    private func updateValue(for xPosition: CGFloat, width: CGFloat) {
        let safeWidth: CGFloat = max(width, 1)
        let clampedX: CGFloat = min(max(0, xPosition), safeWidth)
        let ratio: Double = clampedX / safeWidth
        value = range.lowerBound + ((range.upperBound - range.lowerBound) * ratio)

        let step: Int = Int((ratio * 24).rounded())
        if step != lastFeedbackStep {
            lastFeedbackStep = step
            HarmoniaHaptics.selection()
        }
    }
}

struct VibroControlsView: View {
    @Environment(VibroacousticStore.self) private var vibroStore
    let sessionID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vibroacoustic")
                .font(.headline)
                .foregroundStyle(.white)
            Picker("Mode", selection: Binding(get: {
                vibroStore.currentPattern
            }, set: { newValue in
                vibroStore.currentPattern = newValue
            })) {
                ForEach(vibroStore.patterns) { pattern in
                    Text(pattern.name).tag(pattern.id)
                }
            }
            .pickerStyle(.segmented)
            HarmoniaStepperRow(title: "Intensity", value: Binding(get: {
                vibroStore.intensity
            }, set: { newValue in
                vibroStore.intensity = newValue
            }))
            HarmoniaStepperRow(title: "Haptic sensitivity", value: Binding(get: {
                vibroStore.hapticSensitivity
            }, set: { newValue in
                vibroStore.hapticSensitivity = newValue
            }))
            Button(vibroStore.isVibroacousticActive ? "Stop resonance" : "Start resonance") {
                if vibroStore.isVibroacousticActive {
                    vibroStore.stop()
                } else {
                    vibroStore.start(mode: vibroStore.currentPattern)
                }
            }
            .buttonStyle(HarmoniaGlassButtonStyle())
        }
        .padding(16)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 22))
    }
}

struct BinauralControlsView: View {
    @Environment(VibroacousticStore.self) private var vibroStore
    let sessionID: String

    private var isActive: Bool {
        vibroStore.isVibroacousticActive && vibroStore.currentPattern == "binaural"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Binaural beats")
                .font(.headline)
                .foregroundStyle(.white)
            if vibroStore.isMobileBinauralAllowed(sessionID: sessionID) {
                HarmoniaStepperRow(title: "Intensity", value: Binding(get: {
                    vibroStore.binauralIntensity
                }, set: { newValue in
                    vibroStore.setBinauralIntensity(newValue)
                }))
                HarmoniaStepperRow(title: "Base frequency", value: Binding(get: {
                    vibroStore.baseFrequency
                }, set: { newValue in
                    vibroStore.baseFrequency = newValue
                }), step: 10)
                HarmoniaStepperRow(title: "Beat frequency", value: Binding(get: {
                    vibroStore.beatFrequency
                }, set: { newValue in
                    vibroStore.beatFrequency = newValue
                }), step: 1)
                Button(isActive ? "Stop binaural beats" : "Start binaural beats") {
                    if isActive {
                        vibroStore.stop()
                    } else {
                        vibroStore.start(mode: "binaural")
                    }
                }
                .buttonStyle(HarmoniaGlassButtonStyle())
            } else {
                Text("This mode is web-first and only unlocked on mobile for dedicated session flows.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(16)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 22))
    }
}

struct IsochronicControlsView: View {
    @Environment(VibroacousticStore.self) private var vibroStore
    let presets: [Double] = [1, 4, 8, 10, 15, 20, 30, 40]

    private var isActive: Bool {
        vibroStore.isVibroacousticActive && vibroStore.currentPattern == "isochronic"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Isochronic tones")
                .font(.headline)
                .foregroundStyle(.white)
            HarmoniaStepperRow(title: "Intensity", value: Binding(get: {
                vibroStore.isochronicIntensity
            }, set: { newValue in
                vibroStore.setIsochronicIntensity(newValue)
            }))
            HarmoniaStepperRow(title: "Frequency", value: Binding(get: {
                vibroStore.isochronicFrequency
            }, set: { newValue in
                vibroStore.isochronicFrequency = newValue
            }), step: 1)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { value in
                        Button("\(Int(value))") {
                            vibroStore.isochronicFrequency = value
                        }
                        .buttonStyle(HarmoniaCapsuleButtonStyle())
                    }
                }
            }
            .contentMargins(.horizontal, 1)
            Button(isActive ? "Stop isochronic tones" : "Start isochronic tones") {
                if isActive {
                    vibroStore.stop()
                } else {
                    vibroStore.start(mode: "isochronic")
                }
            }
            .buttonStyle(HarmoniaGlassButtonStyle())
            Text("Precise modulation is best on the web. Mobile uses a lighter approximation.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(16)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 22))
    }
}

struct EndReflectionView: View {
    @Environment(UserProgressStore.self) private var progressStore
    let sessionID: String
    let onDeepen: (FeelingsChatContext) -> Void

    @State private var sliderValue: Double = 0
    @State private var journalText: String = ""
    @State private var savedEntry: ReflectionEntry?

    private var session: Session? {
        harmoniaSessions.first(where: { $0.id == sessionID })
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#F4E8D3"), Color(hex: "#E7D4B5"), Color(hex: "#C7A36F")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let session {
                        Text("Completed: \(session.title)")
                            .font(.headline)
                            .foregroundStyle(Color.black.opacity(0.8))
                        reflectionCard(session: session)
                        insightCard
                        safetyCard
                        progressLog
                    }
                }
                .padding(20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func reflectionCard(session: Session) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How are you feeling now compared to before this session?")
                .font(.title3.weight(.bold))
            Slider(value: $sliderValue, in: -100...100)
                .tint(Color(hex: "#5237D6"))
            HStack {
                Text("Heavier")
                Spacer()
                Text("No Change")
                Spacer()
                Text("Lighter")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(microLabel)
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.75), in: .capsule)
            if sliderValue != 0 {
                TextField(journalPrompt, text: $journalText, axis: .vertical)
                    .padding(16)
                    .background(.white.opacity(0.82), in: .rect(cornerRadius: 20))
            }
            HStack(spacing: 12) {
                Button("Deepen") {
                    onDeepen(FeelingsChatContext(id: UUID().uuidString, source: "end-reflection", sessionId: session.id, sessionName: session.title, feelingDelta: microLabel, feelingScore: sliderValue, dateISO: ISO8601DateFormatter().string(from: Date()), userNote: journalText))
                }
                .buttonStyle(HarmoniaGlassButtonStyle(light: true))
                Button("Save reflection") {
                    savedEntry = progressStore.addReflectionEntry(sessionId: session.id, sessionName: session.title, sliderValue: sliderValue, journalText: journalText.isEmpty ? nil : journalText, microLabel: microLabel)
                }
                .buttonStyle(HarmoniaPrimaryButtonStyle(colors: [Color(hex: "#5237D6"), Color(hex: "#8836E2")]))
            }
        }
        .padding(20)
        .background(.white.opacity(0.48), in: .rect(cornerRadius: 28))
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Harmonia Insight")
                .font(.headline)
            Text("Progress is rarely loud. Sometimes the most important movement is simply becoming more honest with what is here.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.white.opacity(0.42), in: .rect(cornerRadius: 24))
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Safety reminder")
                .font(.headline)
            Text("Harmonia offers emotional support and reflection, not professional or emergency care.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.white.opacity(0.36), in: .rect(cornerRadius: 24))
    }

    private var progressLog: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Progress Log")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.black.opacity(0.85))
            if progressStore.progress.reflectionLog.isEmpty {
                Text("Reflections will appear here after you save your first entry.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(progressStore.progress.reflectionLog) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.sessionName)
                            .font(.headline)
                        Text(entry.microLabel ?? "More grounded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let journalText = entry.journalText {
                            Text(journalText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(16)
                    .background(.white.opacity(0.45), in: .rect(cornerRadius: 20))
                }
            }
        }
    }

    private var microLabel: String {
        switch sliderValue {
        case 60...100:
            return "Feeling lighter"
        case 20..<60:
            return "More connected"
        case 1..<20:
            return "More peaceful"
        case -19...(-1):
            return "More grounded"
        case -59...(-20):
            return "Still processing"
        default:
            return sliderValue <= -60 ? "Feeling unsettled" : "No change"
        }
    }

    private var journalPrompt: String {
        if sliderValue < 0 {
            return "Thank you for your honesty. What came up for you?"
        }
        return "Beautiful work. What shifted for you?"
    }
}

struct FeelingsChatView: View {
    let context: FeelingsChatContext
    @State private var messages: [ChatMessage] = []
    @State private var composer: String = ""
    @State private var isLoading: Bool = false

    private let presets: [String] = ["Body check", "What triggered it", "The story", "What I need", "Next step"]

    var body: some View {
        ZStack(alignment: .bottom) {
            HarmoniaBackgroundView(colors: [Color(hex: "#070A12"), Color(hex: "#0B1022")])
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Feelings")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Circle()
                            .fill(Color(hex: "#1FD6C1"))
                            .frame(width: 10, height: 10)
                    }
                    Text("A deeper check-in")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                    Text("Harmonia offers emotional support—not medical care. If you're in immediate danger, contact local emergency services.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                        .padding(10)
                        .background(.white.opacity(0.06), in: .capsule)
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.self) { item in
                                Button(item) {
                                    composer = item
                                }
                                .buttonStyle(HarmoniaCapsuleButtonStyle())
                            }
                        }
                    }
                    .contentMargins(.horizontal, 1)
                }
                .padding(20)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                Text("Start a deeper check-in")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.68))
                                    .padding(.top, 80)
                            }
                            ForEach(messages) { message in
                                HStack {
                                    if message.role == "assistant" { Spacer(minLength: 40) }
                                    Text(message.text)
                                        .font(.body)
                                        .foregroundStyle(.white)
                                        .padding(14)
                                        .background(message.role == "user" ? Color(hex: "#148C94") : .white.opacity(0.10), in: .rect(cornerRadius: 20))
                                    if message.role == "user" { Spacer(minLength: 40) }
                                }
                                .id(message.id)
                            }
                            if isLoading {
                                HStack {
                                    Text("Listening…")
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.7))
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 90)
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                TextField("Share what is here", text: $composer)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 20))
                    .foregroundStyle(.white)
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Color(hex: "#1FD6C1"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background(LinearGradient(colors: [.clear, Color.black.opacity(0.35)], startPoint: .top, endPoint: .bottom))
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if messages.isEmpty {
                let intro = "I’m here with you. Based on this moment\(context.sessionName.map { " after \($0)" } ?? ""), what feels most alive in your body right now?"
                messages = [ChatMessage(id: UUID().uuidString, role: "assistant", text: intro)]
            }
        }
    }

    private func send() {
        let trimmed: String = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(id: UUID().uuidString, role: "user", text: trimmed))
        composer = ""
        isLoading = true
        let reply = aiReply(for: trimmed)
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            isLoading = false
            messages.append(ChatMessage(id: UUID().uuidString, role: "assistant", text: reply))
        }
    }

    private func aiReply(for input: String) -> String {
        let replies: [String] = [
            "When you say '\(input)', I hear a part of you asking for more room. Where do you feel the tightest edge of it?",
            "That phrase '\(input)' sounds like a story carrying weight. What would become simpler if you didn’t have to hold all of it alone?",
            "There’s useful information in '\(input)'. If your body could ask for one small kindness next, what would it ask for?",
            "I notice the rhythm in '\(input)'. Does it feel more like pressure, ache, or restlessness right now?"
        ]
        return replies.randomElement() ?? "Stay with the phrase '\(input)' for a moment. What feels truest underneath it?"
    }
}

struct JournalEntryView: View {
    @Environment(JournalStore.self) private var journalStore
    let date: String
    let onDeepen: (FeelingsChatContext) -> Void

    @State private var emotion: String = "calm"
    @State private var progress: Double = 0.5
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How are you feeling?")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    Text(date)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Choose an emotion")
                            .font(.headline)
                            .foregroundStyle(.white)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(harmoniaStates) { state in
                                Button(state.label) {
                                    emotion = state.id
                                }
                                .buttonStyle(HarmoniaSelectableChipStyle(isActive: emotion == state.id))
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Shift slider")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Slider(value: $progress, in: 0...1)
                            .tint(Color(hex: "#F8C46C"))
                        Text(progress.harmoniaShiftLabel)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Journal")
                            .font(.headline)
                            .foregroundStyle(.white)
                        TextField("Private to you", text: $note, axis: .vertical)
                            .padding(16)
                            .background(.white.opacity(0.08), in: .rect(cornerRadius: 20))
                            .foregroundStyle(.white)
                    }
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Button("Deepen") {
                            onDeepen(FeelingsChatContext(id: UUID().uuidString, source: "journal-entry", sessionId: nil, sessionName: nil, feelingDelta: progress.harmoniaShiftLabel, feelingScore: progress * 100, dateISO: date, userNote: String(note.prefix(140))))
                        }
                        .buttonStyle(HarmoniaGlassButtonStyle())
                        Button("Save reflection") {
                            journalStore.upsertEntry(JournalEntry(date: date, emotion: emotion, progress: progress, note: note.isEmpty ? nil : note))
                        }
                        .buttonStyle(HarmoniaPrimaryButtonStyle(colors: [Color(hex: "#5237D6"), Color(hex: "#8836E2")]))
                    }
                    Text("Tip: honest notes make your insights more accurate.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
                .background(LinearGradient(colors: [.clear, Color.black.opacity(0.54)], startPoint: .top, endPoint: .bottom))
            }
            .background(LinearGradient(colors: [Color(hex: "#1A120F"), Color(hex: "#2B1B18"), Color.black], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .task {
                if let existing = journalStore.getEntryByDate(date) {
                    emotion = existing.emotion
                    progress = existing.progress
                    note = existing.note ?? ""
                }
            }
        }
    }
}

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserProgressStore.self) private var progressStore
    @Environment(AuthStore.self) private var authStore
    @Environment(JournalStore.self) private var journalStore
    @State private var showNameEditor: Bool = false
    @State private var draftName: String = ""
    @State private var resetArmed: Bool = false

    let onOpenInsights: () -> Void
    let onOpenVibro: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.white.opacity(0.08), in: .circle)
                        }
                    }
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(.linearGradient(colors: [Color(hex: "#5237D6"), Color(hex: "#1FD6C1")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 84, height: 84)
                            Image(systemName: "person.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(progressStore.progress.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            Button("Edit name") {
                                draftName = progressStore.progress.name
                                showNameEditor = true
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(hex: "#1FD6C1"))
                        }
                    }
                    ProfileStatCard()
                    Button("Open insights") {
                        dismiss()
                        onOpenInsights()
                    }
                    .buttonStyle(HarmoniaGlassButtonStyle())
                    HarmoniaJournalView(entries: journalStore.entries)
                    VStack(spacing: 12) {
                        Button("Vibroacoustic settings") {
                            dismiss()
                            onOpenVibro()
                        }
                        .buttonStyle(HarmoniaGlassButtonStyle())
                        Button(resetArmed ? "Tap again to reset progress" : "Reset progress") {
                            if resetArmed {
                                progressStore.resetProgress()
                                resetArmed = false
                            } else {
                                resetArmed = true
                            }
                        }
                        .buttonStyle(HarmoniaGlassButtonStyle())
                        Button("Sign out") {
                            authStore.clearAuth()
                            progressStore.logout()
                            dismiss()
                        }
                        .buttonStyle(HarmoniaGlassButtonStyle())
                    }
                }
                .padding(20)
            }
            .background(HarmoniaBackgroundView(colors: [Color(hex: "#070A12"), Color(hex: "#0B1022")]))
            .sheet(isPresented: $showNameEditor) {
                NavigationStack {
                    VStack(spacing: 16) {
                        TextField("Name", text: $draftName)
                            .padding(16)
                            .background(.regularMaterial, in: .rect(cornerRadius: 20))
                        Button("Save") {
                            progressStore.updateName(name: draftName)
                            showNameEditor = false
                        }
                        .buttonStyle(HarmoniaPrimaryButtonStyle(colors: [Color(hex: "#5237D6"), Color(hex: "#8836E2")]))
                        Spacer()
                    }
                    .padding(20)
                }
                .presentationDetents([.medium])
            }
        }
    }
}

struct ProfileStatCard: View {
    @Environment(UserProgressStore.self) private var progressStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights")
                .font(.headline)
                .foregroundStyle(.white)
            HStack {
                ProfileMetricView(title: "Sessions", value: "\(progressStore.progress.totalSessions)")
                ProfileMetricView(title: "Minutes", value: "\(progressStore.progress.totalMinutes)")
                ProfileMetricView(title: "Streak", value: "\(progressStore.progress.streak)")
            }
        }
        .padding(18)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 24))
    }
}

struct ProfileMetricView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.66))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HarmoniaJournalView: View {
    let entries: [JournalEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Journal")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(entries.prefix(5)) { entry in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color(hex: "#1FD6C1"))
                        .frame(width: 10, height: 10)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.date)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                        Text(entry.emotion.capitalized)
                            .font(.headline)
                            .foregroundStyle(.white)
                        if let note = entry.note {
                            Text(note)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(2)
                        }
                    }
                }
                .padding(14)
                .background(.white.opacity(0.06), in: .rect(cornerRadius: 18))
            }
        }
    }
}

struct InsightsView: View {
    @Environment(UserProgressStore.self) private var progressStore
    let onDismiss: () -> Void

    private var averageLength: Int {
        guard progressStore.progress.totalSessions > 0 else { return 0 }
        return progressStore.progress.totalMinutes / progressStore.progress.totalSessions
    }

    private var averageReflection: Double {
        guard !progressStore.progress.reflectionLog.isEmpty else { return 0 }
        let total = progressStore.progress.reflectionLog.reduce(0) { $0 + $1.sliderValue }
        return total / Double(progressStore.progress.reflectionLog.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "arrow.left")
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.08), in: .circle)
                    }
                    Spacer()
                }
                Text("Insights")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Harmonia intelligence")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: "#1FD6C1"))
                    Text("Dive deeper into your sonic rituals")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                HStack(spacing: 12) {
                    InsightMetricCard(title: "Completion", value: "\(progressStore.progress.totalSessions)")
                    InsightMetricCard(title: "Avg length", value: "\(averageLength)m")
                }
                HStack(spacing: 12) {
                    InsightMetricCard(title: "Reflections", value: "\(progressStore.progress.reflectionLog.count)")
                    InsightMetricCard(title: "Last session", value: progressStore.progress.lastSessionDate ?? "—")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reflection pulse")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(averageReflection == 0 ? "Your reflection pulse will appear after your first saved check-in." : "Average reflection score: \(Int(averageReflection))")
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(18)
                .background(.white.opacity(0.08), in: .rect(cornerRadius: 24))
            }
            .padding(20)
        }
        .background(HarmoniaBackgroundView(colors: [Color(hex: "#070A12"), Color(hex: "#0B1022")]))
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct InsightMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.66))
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 22))
    }
}

struct SubscriptionView: View {
    @Environment(UserProgressStore.self) private var progressStore
    @State private var selectedPlan: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        HarmoniaPill(text: "Rork Max")
                        HarmoniaPill(text: "Cancel anytime")
                    }
                    Text("Upgrade to Rork Max")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Deeper sessions, smarter insights, and faster AI guidance.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.72))
                    Picker("Plan", selection: $selectedPlan) {
                        Text("$79.99/year").tag(0)
                        Text("$9.99/month").tag(1)
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(["Unlimited access to all sessions", "Advanced theta wave frequencies", "Personalized recommendations", "Offline mode", "Progress tracking & insights", "Ad-free experience"], id: \.self) { feature in
                            Label(feature, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    Button("Start free trial") {
                        progressStore.activateSubscription()
                    }
                    .buttonStyle(HarmoniaPrimaryButtonStyle(colors: [Color(hex: "#F8C46C"), Color(hex: "#1FD6C1")]))
                }
                .padding(20)
            }
            .background(HarmoniaBackgroundView(colors: [Color(hex: "#070A12"), Color(hex: "#0B1022")]))
        }
    }
}

struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Terms of Service")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("Harmonia is a wellness app designed for reflection, not medical treatment. Use sessions safely, stop if distressed, and seek professional care when needed. Content remains owned by Harmonia. Liability is limited to the fullest extent permitted by California law. Contact: info@experienceharmonia.com • Carlsbad, CA.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(20)
        }
        .background(LinearGradient(colors: [Color.black, Color(hex: "#5237D6"), Color.black], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ResetPasswordView: View {
    let onBack: () -> Void
    @State private var email: String = ""
    @State private var didSubmit: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(hex: "#5237D6"), Color.black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.08), in: .circle)
                    }
                    Spacer()
                }
                if didSubmit {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("Check Your Email")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                    Text(email)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.82))
                } else {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.white)
                    Text("Reset Password")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                    HarmoniaInputField(title: "Email", text: $email)
                    Button("Send reset link") {
                        didSubmit = true
                    }
                    .buttonStyle(HarmoniaPrimaryButtonStyle(colors: [Color(hex: "#5237D6"), Color(hex: "#8836E2")]))
                }
                Spacer()
            }
            .padding(20)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct VibroacousticSettingsView: View {
    @Environment(VibroacousticStore.self) private var vibroStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Vibroacoustic settings")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                HarmoniaStepperRow(title: "Vibro intensity", value: Binding(get: {
                    vibroStore.intensity
                }, set: { newValue in
                    vibroStore.intensity = newValue
                }))
                HarmoniaStepperRow(title: "Haptic sensitivity", value: Binding(get: {
                    vibroStore.hapticSensitivity
                }, set: { newValue in
                    vibroStore.hapticSensitivity = newValue
                }))
                HarmoniaStepperRow(title: "Binaural intensity", value: Binding(get: {
                    vibroStore.binauralIntensity
                }, set: { newValue in
                    vibroStore.setBinauralIntensity(newValue)
                }))
                HarmoniaStepperRow(title: "Isochronic intensity", value: Binding(get: {
                    vibroStore.isochronicIntensity
                }, set: { newValue in
                    vibroStore.setIsochronicIntensity(newValue)
                }))
            }
            .padding(20)
        }
        .background(HarmoniaBackgroundView(colors: [Color(hex: "#070A12"), Color(hex: "#0B1022")]))
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct AIChatModal: View {
    @State private var messages: [ChatMessage] = [ChatMessage(id: UUID().uuidString, role: "assistant", text: "Hello! I'm here to support you on your journey. How are you feeling today?")]
    @State private var composer: String = ""
    @State private var isTyping: Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                HarmoniaBackgroundView(colors: [Color(hex: "#070A12"), Color(hex: "#0B1022")])
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Wellness Companion")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Reflect, release, and re-center")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                HStack {
                                    if message.role == "assistant" { Spacer(minLength: 40) }
                                    Text(message.text)
                                        .foregroundStyle(.white)
                                        .padding(14)
                                        .background(message.role == "user" ? Color(hex: "#148C94") : .white.opacity(0.08), in: .rect(cornerRadius: 20))
                                    if message.role == "user" { Spacer(minLength: 40) }
                                }
                            }
                            if isTyping {
                                Text("Thinking…")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.64))
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        TextField("How are you feeling?", text: $composer)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.08), in: .rect(cornerRadius: 20))
                            .foregroundStyle(.white)
                        Button(action: send) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(Color(hex: "#1FD6C1"))
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private func send() {
        let trimmed = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(id: UUID().uuidString, role: "user", text: trimmed))
        composer = ""
        isTyping = true
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            isTyping = false
            messages.append(ChatMessage(id: UUID().uuidString, role: "assistant", text: "When you say '\(trimmed)', what feels most in need of gentleness right now?"))
        }
    }
}

struct SessionGeometryHost: View {
    let session: Session
    let isAnimating: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var backgroundGradient: LinearGradient {
        if session.id == "lifting-from-sadness" || session.id == "stress-release-flow" || session.id == "dissolution-anxiousness" {
            LinearGradient(colors: session.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            LinearGradient(
                colors: [Color(hex: "#8AF6F4"), Color(hex: "#46D8E1"), Color(hex: "#179FB8")],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var playbackRate: Double {
        1
    }

    var body: some View {
        Group {
            if session.id == "lifting-from-sadness" {
                SynchroGeometryView(tempoBPM: session.tempoBPM ?? 72, isAnimating: isAnimating, reduceMotion: reduceMotion)
            } else if session.id == "stress-release-flow" {
                UnwindGeometryView(playbackRate: playbackRate, isAnimating: isAnimating, reduceMotion: reduceMotion)
            } else if session.id == "dissolution-anxiousness" {
                QuietAlarmGeometryView(playbackRate: playbackRate, isAnimating: isAnimating, reduceMotion: reduceMotion)
            } else {
                SacredGeometryView(playbackRate: playbackRate, isAnimating: isAnimating, reduceMotion: reduceMotion)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct UnwindGeometryView: View, Equatable {
    let playbackRate: Double
    let isAnimating: Bool
    let reduceMotion: Bool

    static func == (lhs: UnwindGeometryView, rhs: UnwindGeometryView) -> Bool {
        lhs.playbackRate == rhs.playbackRate && lhs.isAnimating == rhs.isAnimating && lhs.reduceMotion == rhs.reduceMotion
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = SessionGeometryLayout(size: proxy.size)
            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    let values = SessionGeometryValues.standard(
                        date: timeline.date,
                        isAnimating: isAnimating,
                        reduceMotion: reduceMotion,
                        playbackRate: playbackRate,
                        geometryHalfDuration: 8,
                        mandalaHalfDuration: 12,
                        breathCycle: 8.3
                    )
                    drawUnwindGeometry(context: &context, layout: layout, values: values)
                }
            }
        }
    }
}

struct QuietAlarmGeometryView: View, Equatable {
    let playbackRate: Double
    let isAnimating: Bool
    let reduceMotion: Bool

    static func == (lhs: QuietAlarmGeometryView, rhs: QuietAlarmGeometryView) -> Bool {
        lhs.playbackRate == rhs.playbackRate && lhs.isAnimating == rhs.isAnimating && lhs.reduceMotion == rhs.reduceMotion
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = SessionGeometryLayout(size: proxy.size)
            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    let values = SessionGeometryValues.quietAlarm(
                        date: timeline.date,
                        isAnimating: isAnimating,
                        reduceMotion: reduceMotion,
                        playbackRate: playbackRate,
                        breathCycle: 8.3
                    )
                    drawQuietAlarmGeometry(context: &context, layout: layout, values: values)
                }
            }
        }
    }
}

struct SacredGeometryView: View, Equatable {
    let playbackRate: Double
    let isAnimating: Bool
    let reduceMotion: Bool

    static func == (lhs: SacredGeometryView, rhs: SacredGeometryView) -> Bool {
        lhs.playbackRate == rhs.playbackRate && lhs.isAnimating == rhs.isAnimating && lhs.reduceMotion == rhs.reduceMotion
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = SessionGeometryLayout(size: proxy.size)
            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    let values = SessionGeometryValues.standard(
                        date: timeline.date,
                        isAnimating: isAnimating,
                        reduceMotion: reduceMotion,
                        playbackRate: playbackRate,
                        geometryHalfDuration: 8,
                        mandalaHalfDuration: 12,
                        breathCycle: 8.3
                    )
                    drawSacredGeometry(context: &context, layout: layout, values: values)
                }
            }
        }
    }
}

struct SynchroGeometryView: View, Equatable {
    let tempoBPM: Int
    let isAnimating: Bool
    let reduceMotion: Bool

    static func == (lhs: SynchroGeometryView, rhs: SynchroGeometryView) -> Bool {
        lhs.tempoBPM == rhs.tempoBPM && lhs.isAnimating == rhs.isAnimating && lhs.reduceMotion == rhs.reduceMotion
    }

    var body: some View {
        GeometryReader { proxy in
            let side: CGFloat = min(proxy.size.width, proxy.size.height) * 0.9
            let origin: CGPoint = CGPoint(x: (proxy.size.width - side) / 2, y: max(proxy.size.height * 0.15, (proxy.size.height - side) / 2))
            let frame: CGRect = CGRect(origin: origin, size: CGSize(width: side, height: side))
            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    let values = SynchroGeometryValues(
                        date: timeline.date,
                        isAnimating: isAnimating,
                        reduceMotion: reduceMotion,
                        tempoBPM: tempoBPM,
                        playbackRate: 1
                    )
                    drawSynchroGeometry(context: &context, frame: frame, values: values)
                }
            }
        }
    }
}

private struct SessionGeometryLayout {
    let center: CGPoint
    let side: CGFloat

    init(size: CGSize) {
        let baseSide: CGFloat = min(size.width * 0.9, 420)
        center = CGPoint(x: size.width / 2, y: size.height * 0.34)
        side = baseSide
    }
}

private struct SessionGeometryValues {
    let breathScale: CGFloat
    let breathOpacity: Double
    let glowOpacity: Double
    let geometryRotation: Double
    let mandalaRotation: Double

    static func standard(
        date: Date,
        isAnimating: Bool,
        reduceMotion: Bool,
        playbackRate: Double,
        geometryHalfDuration: Double,
        mandalaHalfDuration: Double
    ,
        breathCycle: Double
    ) -> SessionGeometryValues {
        guard isAnimating, !reduceMotion else {
            return SessionGeometryValues(breathScale: 1, breathOpacity: 0.82, glowOpacity: 0.18, geometryRotation: 0, mandalaRotation: 0)
        }

        let safeRate: Double = max(playbackRate, 0.25)
        let t: Double = date.timeIntervalSinceReferenceDate
        let breathValue: Double = breathProgress(time: t, cycle: breathCycle)
        let geometryValue: Double = oscillatingProgress(time: t, halfDuration: geometryHalfDuration / safeRate)
        let mandalaValue: Double = oscillatingProgress(time: t, halfDuration: mandalaHalfDuration / safeRate)

        return SessionGeometryValues(
            breathScale: CGFloat(0.92 + (0.28 * breathValue)),
            breathOpacity: 0.66 + (0.34 * breathValue),
            glowOpacity: 0.05 + (0.55 * breathValue),
            geometryRotation: 360 * geometryValue,
            mandalaRotation: -360 * mandalaValue
        )
    }

    static func quietAlarm(date: Date, isAnimating: Bool, reduceMotion: Bool, playbackRate: Double, breathCycle: Double) -> SessionGeometryValues {
        guard isAnimating, !reduceMotion else {
            return SessionGeometryValues(breathScale: 1, breathOpacity: 0.82, glowOpacity: 0.18, geometryRotation: 0, mandalaRotation: 0)
        }

        let safeRate: Double = max(playbackRate, 0.25)
        let t: Double = date.timeIntervalSinceReferenceDate
        let breathValue: Double = breathProgress(time: t, cycle: breathCycle)
        let geometryValue: Double = oscillatingProgress(time: t, halfDuration: 6 / safeRate)
        let mandalaValue: Double = oscillatingProgress(time: t, halfDuration: 10 / safeRate)

        return SessionGeometryValues(
            breathScale: CGFloat(0.92 + (0.28 * breathValue)),
            breathOpacity: 0.66 + (0.34 * breathValue),
            glowOpacity: 0.05 + (0.55 * breathValue),
            geometryRotation: 180 * geometryValue,
            mandalaRotation: -360 * mandalaValue
        )
    }
}

private struct SynchroGeometryValues {
    let breatheScale: CGFloat
    let ringRotation: Double
    let starRotation: Double
    let centerRadius: CGFloat

    init(date: Date, isAnimating: Bool, reduceMotion: Bool, tempoBPM: Int, playbackRate: Double) {
        guard isAnimating, !reduceMotion else {
            breatheScale = 1
            ringRotation = 0
            starRotation = 0
            centerRadius = 12
            return
        }

        let beatDuration: Double = min(max(60000 / (Double(max(tempoBPM, 1)) * max(playbackRate, 0.25)), 250), 6000) / 1000
        let time: Double = date.timeIntervalSinceReferenceDate
        let breatheValue: Double = oscillatingProgress(time: time, halfDuration: beatDuration * 4)
        let centerValue: Double = oscillatingProgress(time: time + 0.37, halfDuration: beatDuration * 2)

        breatheScale = CGFloat(0.97 + (0.07 * breatheValue))
        ringRotation = 360 * repeatingProgress(time: time, duration: beatDuration * 64)
        starRotation = -360 * repeatingProgress(time: time, duration: beatDuration * 52)
        centerRadius = CGFloat(10 + (6 * centerValue))
    }
}

private func breathProgress(time: Double, cycle: Double) -> Double {
    guard cycle > 0 else { return 0 }
    let phaseTime: Double = time.truncatingRemainder(dividingBy: cycle)

    if phaseTime < 3.8 {
        let progress: Double = phaseTime / 3.8
        return easedSineInOut(progress)
    }

    if phaseTime < 4.15 {
        return 1
    }

    if phaseTime < 7.95 {
        let progress: Double = (phaseTime - 4.15) / 3.8
        return 1 - easedSineInOut(progress)
    }

    return 0
}

private func easedSineInOut(_ progress: Double) -> Double {
    let clamped: Double = min(max(progress, 0), 1)
    return 0.5 - (cos(clamped * .pi) / 2)
}

private func repeatingProgress(time: Double, duration: Double) -> Double {
    guard duration > 0 else { return 0 }
    return (time.truncatingRemainder(dividingBy: duration)) / duration
}

private func oscillatingProgress(time: Double, halfDuration: Double) -> Double {
    guard halfDuration > 0 else { return 0 }
    let fullDuration: Double = halfDuration * 2
    let phaseTime: Double = time.truncatingRemainder(dividingBy: fullDuration)

    if phaseTime < halfDuration {
        let progress: Double = phaseTime / halfDuration
        return easedSineInOut(progress)
    }

    let progress: Double = (phaseTime - halfDuration) / halfDuration
    return 1 - easedSineInOut(progress)
}

private func drawSacredGeometry(context: inout GraphicsContext, layout: SessionGeometryLayout, values: SessionGeometryValues) {
    let seedRect: CGRect = CGRect(x: layout.center.x - layout.side / 2, y: layout.center.y - layout.side / 2, width: layout.side, height: layout.side)
    let mandalaSide: CGFloat = layout.side * 0.885
    let mandalaRect: CGRect = CGRect(x: layout.center.x - mandalaSide / 2, y: layout.center.y - mandalaSide / 2, width: mandalaSide, height: mandalaSide)

    var seedContext = context
    seedContext.translateBy(x: layout.center.x, y: layout.center.y)
    seedContext.scaleBy(x: values.breathScale, y: values.breathScale)
    seedContext.rotate(by: .degrees(values.geometryRotation))
    seedContext.translateBy(x: -layout.center.x, y: -layout.center.y)
    seedContext.opacity = values.breathOpacity * 0.42
    drawSeedOfLife(context: &seedContext, rect: seedRect, lineWidthScale: 1, opacityScale: 1)

    var seedGlowContext = context
    seedGlowContext.translateBy(x: layout.center.x, y: layout.center.y)
    seedGlowContext.scaleBy(x: values.breathScale * 1.07, y: values.breathScale * 1.07)
    seedGlowContext.rotate(by: .degrees(values.geometryRotation))
    seedGlowContext.translateBy(x: -layout.center.x, y: -layout.center.y)
    seedGlowContext.opacity = values.glowOpacity * 0.72
    drawSeedOfLife(context: &seedGlowContext, rect: seedRect, lineWidthScale: 1.35, opacityScale: 0.92)

    var mandalaContext = context
    mandalaContext.translateBy(x: layout.center.x, y: layout.center.y)
    mandalaContext.scaleBy(x: values.breathScale, y: values.breathScale)
    mandalaContext.rotate(by: .degrees(values.mandalaRotation))
    mandalaContext.translateBy(x: -layout.center.x, y: -layout.center.y)
    mandalaContext.opacity = values.breathOpacity * 0.26
    drawMandalaRays(context: &mandalaContext, rect: mandalaRect, lineWidthScale: 1, opacityScale: 1)

    var mandalaGlowContext = context
    mandalaGlowContext.translateBy(x: layout.center.x, y: layout.center.y)
    mandalaGlowContext.scaleBy(x: values.breathScale * 1.07, y: values.breathScale * 1.07)
    mandalaGlowContext.rotate(by: .degrees(values.mandalaRotation))
    mandalaGlowContext.translateBy(x: -layout.center.x, y: -layout.center.y)
    mandalaGlowContext.opacity = values.glowOpacity * 0.62 * 1.18
    drawMandalaRays(context: &mandalaGlowContext, rect: mandalaRect, lineWidthScale: 1.5, opacityScale: 0.9)
}

private func drawUnwindGeometry(context: inout GraphicsContext, layout: SessionGeometryLayout, values: SessionGeometryValues) {
    let rect: CGRect = CGRect(x: layout.center.x - layout.side / 2, y: layout.center.y - layout.side / 2, width: layout.side, height: layout.side)

    var spiralContext = context
    spiralContext.translateBy(x: layout.center.x, y: layout.center.y)
    spiralContext.scaleBy(x: values.breathScale, y: values.breathScale)
    spiralContext.rotate(by: .degrees(values.geometryRotation))
    spiralContext.translateBy(x: -layout.center.x, y: -layout.center.y)
    spiralContext.opacity = values.breathOpacity * 0.35
    drawUnwindSpiralField(context: &spiralContext, rect: rect, glow: false)

    var spiralGlowContext = context
    spiralGlowContext.translateBy(x: layout.center.x, y: layout.center.y)
    spiralGlowContext.scaleBy(x: values.breathScale * 1.05, y: values.breathScale * 1.05)
    spiralGlowContext.rotate(by: .degrees(values.geometryRotation))
    spiralGlowContext.translateBy(x: -layout.center.x, y: -layout.center.y)
    spiralGlowContext.opacity = values.glowOpacity * 0.5
    drawUnwindSpiralField(context: &spiralGlowContext, rect: rect, glow: true)

    var petalContext = context
    petalContext.translateBy(x: layout.center.x, y: layout.center.y)
    petalContext.scaleBy(x: values.breathScale, y: values.breathScale)
    petalContext.rotate(by: .degrees(values.mandalaRotation))
    petalContext.translateBy(x: -layout.center.x, y: -layout.center.y)
    petalContext.opacity = values.breathOpacity * 0.3
    drawUnwindPetals(context: &petalContext, rect: rect, glow: false)

    var waveContext = context
    waveContext.translateBy(x: layout.center.x, y: layout.center.y)
    waveContext.scaleBy(x: values.breathScale * 0.95, y: values.breathScale * 0.95)
    waveContext.rotate(by: .degrees(values.geometryRotation * 0.5))
    waveContext.translateBy(x: -layout.center.x, y: -layout.center.y)
    waveContext.opacity = values.breathOpacity * 0.2
    drawUnwindWaves(context: &waveContext, rect: rect)

    var petalGlowContext = context
    petalGlowContext.translateBy(x: layout.center.x, y: layout.center.y)
    petalGlowContext.scaleBy(x: values.breathScale * 1.08, y: values.breathScale * 1.08)
    petalGlowContext.rotate(by: .degrees(values.mandalaRotation))
    petalGlowContext.translateBy(x: -layout.center.x, y: -layout.center.y)
    petalGlowContext.opacity = values.glowOpacity * 0.4
    drawUnwindPetals(context: &petalGlowContext, rect: rect, glow: true)
}

private func drawQuietAlarmGeometry(context: inout GraphicsContext, layout: SessionGeometryLayout, values: SessionGeometryValues) {
    let rect: CGRect = CGRect(x: layout.center.x - layout.side / 2, y: layout.center.y - layout.side / 2, width: layout.side, height: layout.side)

    var rippleContext = context
    rippleContext.translateBy(x: layout.center.x, y: layout.center.y)
    rippleContext.scaleBy(x: values.breathScale, y: values.breathScale)
    rippleContext.rotate(by: .degrees(values.geometryRotation))
    rippleContext.translateBy(x: -layout.center.x, y: -layout.center.y)
    rippleContext.opacity = values.breathOpacity * 0.3
    drawQuietRipples(context: &rippleContext, rect: rect, glow: false)

    var rippleGlowContext = context
    rippleGlowContext.translateBy(x: layout.center.x, y: layout.center.y)
    rippleGlowContext.scaleBy(x: values.breathScale * 1.06, y: values.breathScale * 1.06)
    rippleGlowContext.rotate(by: .degrees(values.geometryRotation))
    rippleGlowContext.translateBy(x: -layout.center.x, y: -layout.center.y)
    rippleGlowContext.opacity = values.glowOpacity * 0.45
    drawQuietRipples(context: &rippleGlowContext, rect: rect, glow: true)

    var vesicaContext = context
    vesicaContext.translateBy(x: layout.center.x, y: layout.center.y)
    vesicaContext.scaleBy(x: values.breathScale, y: values.breathScale)
    vesicaContext.rotate(by: .degrees(values.mandalaRotation))
    vesicaContext.translateBy(x: -layout.center.x, y: -layout.center.y)
    vesicaContext.opacity = values.breathOpacity * 0.28
    drawQuietVesica(context: &vesicaContext, rect: rect)

    var curveContext = context
    curveContext.translateBy(x: layout.center.x, y: layout.center.y)
    curveContext.scaleBy(x: values.breathScale * 0.92, y: values.breathScale * 0.92)
    curveContext.rotate(by: .degrees(-values.geometryRotation * 0.6667))
    curveContext.translateBy(x: -layout.center.x, y: -layout.center.y)
    curveContext.opacity = values.breathOpacity * 0.32
    drawQuietBreathCurves(context: &curveContext, rect: rect, glow: false)

    var curveGlowContext = context
    curveGlowContext.translateBy(x: layout.center.x, y: layout.center.y)
    curveGlowContext.scaleBy(x: values.breathScale * 1.04, y: values.breathScale * 1.04)
    curveGlowContext.rotate(by: .degrees(values.mandalaRotation * 0.5))
    curveGlowContext.translateBy(x: -layout.center.x, y: -layout.center.y)
    curveGlowContext.opacity = values.glowOpacity * 0.35
    drawQuietBreathCurves(context: &curveGlowContext, rect: rect, glow: true)
}

private func drawSynchroGeometry(context: inout GraphicsContext, frame: CGRect, values: SynchroGeometryValues) {
    let center: CGPoint = CGPoint(x: frame.midX, y: frame.midY)
    let side: CGFloat = frame.width
    let scale: CGFloat = side / 300

    var rootContext = context
    rootContext.translateBy(x: center.x, y: center.y)
    rootContext.scaleBy(x: values.breatheScale * scale, y: values.breatheScale * scale)
    rootContext.translateBy(x: -150, y: -150)

    var ringsContext = rootContext
    ringsContext.translateBy(x: 150, y: 150)
    ringsContext.rotate(by: .degrees(values.ringRotation))
    ringsContext.translateBy(x: -150, y: -150)
    ringsContext.opacity = 0.8
    for (index, radius) in [40.0, 58, 76, 94, 112, 130, 148].enumerated() {
        let lineWidth: CGFloat = CGFloat(1.5 + (Double(index) * 0.3))
        let rect: CGRect = CGRect(x: 150 - radius, y: 150 - radius, width: radius * 2, height: radius * 2)
        let style = index.isMultiple(of: 3)
            ? StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [10, 6])
            : StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        ringsContext.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.8)), style: style)
    }

    rootContext.opacity = 0.25
    for index in 0..<12 {
        let angle: Double = (Double(index) / 12) * .pi * 2
        let circleCenter: CGPoint = CGPoint(x: 150 + CGFloat(cos(angle) * 60), y: 150 + CGFloat(sin(angle) * 60))
        let circleRect: CGRect = CGRect(x: circleCenter.x - 60, y: circleCenter.y - 60, width: 120, height: 120)
        rootContext.stroke(Path(ellipseIn: circleRect), with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1.2))
    }

    var starContext = rootContext
    starContext.translateBy(x: 150, y: 150)
    starContext.rotate(by: .degrees(values.starRotation))
    starContext.translateBy(x: -150, y: -150)
    let upward = Path { path in
        path.move(to: CGPoint(x: 150, y: 110))
        path.addLine(to: CGPoint(x: 185, y: 180))
        path.addLine(to: CGPoint(x: 115, y: 180))
        path.closeSubpath()
    }
    let downward = Path { path in
        path.move(to: CGPoint(x: 150, y: 190))
        path.addLine(to: CGPoint(x: 185, y: 120))
        path.addLine(to: CGPoint(x: 115, y: 120))
        path.closeSubpath()
    }
    starContext.stroke(upward, with: .color(Color(hex: "#FFF7E6").opacity(0.9)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
    starContext.stroke(downward, with: .color(Color(hex: "#FFF7E6").opacity(0.75)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))

    rootContext.fill(Path(ellipseIn: CGRect(x: 150 - values.centerRadius, y: 150 - values.centerRadius, width: values.centerRadius * 2, height: values.centerRadius * 2)), with: .color(Color(hex: "#FFF7E6")))
}

private func drawSeedOfLife(context: inout GraphicsContext, rect: CGRect, lineWidthScale: CGFloat, opacityScale: Double) {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let scale: CGFloat = rect.width / 520
    let baseRadius: CGFloat = 80 * scale
    let offsets: [CGPoint] = [
        .zero,
        CGPoint(x: 0, y: -60 * scale),
        CGPoint(x: 0, y: 60 * scale),
        CGPoint(x: -60 * scale, y: -30 * scale),
        CGPoint(x: 60 * scale, y: -30 * scale),
        CGPoint(x: -60 * scale, y: 30 * scale),
        CGPoint(x: 60 * scale, y: 30 * scale)
    ]

    for (index, offset) in offsets.enumerated() {
        let circleCenter = CGPoint(x: center.x + offset.x, y: center.y + offset.y)
        let rect = CGRect(x: circleCenter.x - baseRadius, y: circleCenter.y - baseRadius, width: baseRadius * 2, height: baseRadius * 2)
        let opacity = index == 0 ? 0.85 * opacityScale : 0.82 * opacityScale
        let lineWidth: CGFloat = (index == 0 ? 2 : 1.4) * lineWidthScale * scale
        context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)), style: StrokeStyle(lineWidth: lineWidth))
    }

    let outerHex = scaledPoints([
        CGPoint(x: 260, y: 140), CGPoint(x: 340, y: 200), CGPoint(x: 340, y: 320), CGPoint(x: 260, y: 380), CGPoint(x: 180, y: 320), CGPoint(x: 180, y: 200)
    ], in: rect)
    let innerHex = scaledPoints([
        CGPoint(x: 260, y: 180), CGPoint(x: 310, y: 210), CGPoint(x: 310, y: 310), CGPoint(x: 260, y: 340), CGPoint(x: 210, y: 310), CGPoint(x: 210, y: 210)
    ], in: rect)
    context.stroke(path(points: outerHex), with: .color(.white.opacity(0.8 * opacityScale)), style: StrokeStyle(lineWidth: 1.2 * lineWidthScale * scale, lineJoin: .round))
    context.stroke(path(points: innerHex), with: .color(.white.opacity(0.8 * opacityScale)), style: StrokeStyle(lineWidth: 1.2 * lineWidthScale * scale, lineJoin: .round))
}

private func drawMandalaRays(context: inout GraphicsContext, rect: CGRect, lineWidthScale: CGFloat, opacityScale: Double) {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let scale: CGFloat = rect.width / 460
    for index in 0..<16 {
        let angle = (Double(index) / 16) * .pi * 2
        let path = Path { path in
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle) * 150 * scale), y: center.y + CGFloat(sin(angle) * 150 * scale)))
            path.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle) * 180 * scale), y: center.y + CGFloat(sin(angle) * 180 * scale)))
            path.closeSubpath()
        }
        context.stroke(path, with: .color(.white.opacity(0.78 * opacityScale)), style: StrokeStyle(lineWidth: 1.6 * lineWidthScale * scale, lineCap: .round, lineJoin: .round))
    }

    for radius in [140.0, 70.0] {
        let ringRect = CGRect(x: center.x - CGFloat(radius) * scale, y: center.y - CGFloat(radius) * scale, width: CGFloat(radius * 2) * scale, height: CGFloat(radius * 2) * scale)
        context.stroke(Path(ellipseIn: ringRect), with: .color(.white.opacity(0.72 * opacityScale)), style: StrokeStyle(lineWidth: 1.8 * lineWidthScale * scale))
    }
}

private func drawUnwindSpiralField(context: inout GraphicsContext, rect: CGRect, glow: Bool) {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let scale = rect.width / 520
    let configs: [(maxRadius: CGFloat, turns: Double, lineWidth: CGFloat, opacity: Double, direction: Double)] = glow
        ? [(180, 3.5, 3.5, 0.5, 1), (160, 3, 3.1, 0.5, -1), (140, 2.5, 2.7, 0.5, 1)]
        : [(180, 3.5, 2.2, 0.85, 1), (160, 3, 1.9, 0.73, -1), (140, 2.5, 1.6, 0.61, 1)]
    let color: Color = glow ? Color(hex: "#FFECC8") : Color(hex: "#FFF7E6")

    for config in configs {
        context.stroke(spiralPath(center: center, minRadius: glow ? 8 : 8, maxRadius: config.maxRadius * scale, turns: config.turns, direction: config.direction), with: .color(color.opacity(config.opacity)), style: StrokeStyle(lineWidth: config.lineWidth * scale, lineCap: .round))
    }

    if !glow {
        for (index, radius) in [30.0, 60, 90, 120, 150, 180].enumerated() {
            let ringRect = CGRect(x: center.x - CGFloat(radius) * scale, y: center.y - CGFloat(radius) * scale, width: CGFloat(radius * 2) * scale, height: CGFloat(radius * 2) * scale)
            context.stroke(Path(ellipseIn: ringRect), with: .color(color.opacity(0.25)), style: StrokeStyle(lineWidth: 1.2 * scale, dash: [CGFloat(8 + (index * 2)), CGFloat(6 + (index * 3))]))
        }
    }
}

private func drawUnwindPetals(context: inout GraphicsContext, rect: CGRect, glow: Bool) {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let scale = rect.width / 520
    let innerColor: Color = glow ? Color(hex: "#FFECC8") : .white
    let outerColor: Color = glow ? Color(hex: "#FFECC8") : Color(hex: "#FFF7E6")

    let innerCount: Int = 8
    for index in 0..<innerCount {
        let angle = (Double(index) / Double(innerCount)) * .pi * 2
        let spread: Double = 0.6
        let path = petalPath(center: center, startRadius: 20 * scale, endRadius: 80 * scale, angle: angle, spread: spread)
        context.stroke(path, with: .color(innerColor.opacity(glow ? 0.8 : 1)), style: StrokeStyle(lineWidth: (glow ? 2.4 : 1.4) * scale, lineCap: .round))
    }

    if !glow {
        for index in 0..<12 {
            let angle = (Double(index) / 12) * .pi * 2
            let path = petalPath(center: center, startRadius: 50 * scale, endRadius: 150 * scale, angle: angle, spread: 0.4)
            context.stroke(path, with: .color(outerColor.opacity(0.8)), style: StrokeStyle(lineWidth: 1.2 * scale, lineCap: .round))
        }
    }

    if glow {
        context.fill(Path(ellipseIn: CGRect(x: center.x - 18 * scale, y: center.y - 18 * scale, width: 36 * scale, height: 36 * scale)), with: .color(Color(hex: "#FFF7E6").opacity(0.3)))
        context.fill(Path(ellipseIn: CGRect(x: center.x - 8 * scale, y: center.y - 8 * scale, width: 16 * scale, height: 16 * scale)), with: .color(Color(hex: "#FFF7E6").opacity(0.5)))
    }
}

private func drawUnwindWaves(context: inout GraphicsContext, rect: CGRect) {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let scale = rect.width / 520
    let configs: [(radius: CGFloat, peaks: Int, amplitude: CGFloat)] = [(60, 6, 8), (100, 8, 12), (140, 10, 10), (180, 12, 8)]
    for config in configs {
        context.stroke(waveLoopPath(center: center, radius: config.radius * scale, peaks: config.peaks, amplitude: config.amplitude * scale), with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 1.1 * scale, lineCap: .round, lineJoin: .round))
    }
}

private func drawQuietRipples(context: inout GraphicsContext, rect: CGRect, glow: Bool) {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let scale = rect.width / 520
    let rippleRadii: [CGFloat] = [25, 48, 72, 96, 120, 144, 168, 191]
    for (index, radius) in rippleRadii.enumerated() where !glow || index < 5 {
        let lineWidth: CGFloat = glow ? CGFloat(2.8 - (Double(index) * 0.3)) : 1.4
        let color: Color = glow ? Color(hex: "#FFDDD6") : Color(hex: "#FFE4E1")
        context.stroke(wobblePath(center: center, radius: radius * scale, lobes: 7 + index, wobble: (glow ? 6 : 8) * scale), with: .color(color.opacity(glow ? 0.9 : 0.8)), style: StrokeStyle(lineWidth: lineWidth * scale, lineCap: .round, lineJoin: .round))
    }

    if !glow {
        for (index, radius) in [140.0, 158, 176, 194, 212].enumerated() {
            let ringRect = CGRect(x: center.x - CGFloat(radius) * scale, y: center.y - CGFloat(radius) * scale, width: CGFloat(radius * 2) * scale, height: CGFloat(radius * 2) * scale)
            context.stroke(Path(ellipseIn: ringRect), with: .color(Color(hex: "#FFD5CC").opacity(0.7)), style: StrokeStyle(lineWidth: 1.2 * scale, dash: [CGFloat(10 + index * 3), CGFloat(10 + index * 4)]))
        }
    }
}

private func drawQuietVesica(context: inout GraphicsContext, rect: CGRect) {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let scale = rect.width / 520
    for index in 0..<6 {
        let angle = (Double(index) / 6) * .pi * 2
        let offset = CGPoint(x: CGFloat(cos(angle) * 28 * scale), y: CGFloat(sin(angle) * 28 * scale))
        let leftRect = CGRect(x: center.x + offset.x - 55 * scale, y: center.y + offset.y - 55 * scale, width: 110 * scale, height: 110 * scale)
        let rightRect = CGRect(x: center.x - offset.x - 55 * scale, y: center.y - offset.y - 55 * scale, width: 110 * scale, height: 110 * scale)
        context.stroke(Path(ellipseIn: leftRect), with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1.2 * scale))
        context.stroke(Path(ellipseIn: rightRect), with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1.2 * scale))
    }

    for index in 0..<16 {
        let radius = CGFloat(60 + (index % 6) * 18) * scale
        let start = Angle.degrees(Double(index) * 22.5)
        let end = Angle.degrees(Double(index) * 22.5 + 14)
        context.stroke(Path { path in path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false) }, with: .color(Color(hex: "#FFE8E0").opacity(0.7)), style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round))
    }
}

private func drawQuietBreathCurves(context: inout GraphicsContext, rect: CGRect, glow: Bool) {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let scale = rect.width / 520
    if glow {
        for index in 0..<6 {
            let angle = (Double(index) / 6) * .pi * 2
            let path = quadraticArcPath(center: center, startRadius: 40 * scale, endRadius: 75 * scale, angle: angle, arcDepth: 22 * scale)
            context.stroke(path, with: .color(Color(hex: "#FFD0C5").opacity(0.8)), style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round))
        }
        context.fill(Path(ellipseIn: CGRect(x: center.x - 22 * scale, y: center.y - 22 * scale, width: 44 * scale, height: 44 * scale)), with: .color(Color(hex: "#FFE4E1").opacity(0.18)))
        context.fill(Path(ellipseIn: CGRect(x: center.x - 10 * scale, y: center.y - 10 * scale, width: 20 * scale, height: 20 * scale)), with: .color(.white.opacity(0.35)))
        context.fill(Path(ellipseIn: CGRect(x: center.x - 4 * scale, y: center.y - 4 * scale, width: 8 * scale, height: 8 * scale)), with: .color(.white.opacity(0.5)))
    } else {
        for index in 0..<10 {
            let angle = (Double(index) / 10) * .pi * 2
            let path = quadraticArcPath(center: center, startRadius: 120 * scale, endRadius: 170 * scale, angle: angle, arcDepth: 28 * scale)
            context.stroke(path, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 1.2 * scale, lineCap: .round))
        }
        for index in 0..<6 {
            let angle = (Double(index) / 6) * .pi * 2
            let path = quadraticArcPath(center: center, startRadius: 40 * scale, endRadius: 75 * scale, angle: angle, arcDepth: 18 * scale)
            context.stroke(path, with: .color(Color(hex: "#FFDDD6").opacity(0.85)), style: StrokeStyle(lineWidth: 1.4 * scale, lineCap: .round))
        }
    }
}

private func scaledPoints(_ points: [CGPoint], in rect: CGRect) -> [CGPoint] {
    let scaleX = rect.width / 520
    let scaleY = rect.height / 520
    return points.map { point in
        CGPoint(x: rect.minX + (point.x * scaleX), y: rect.minY + (point.y * scaleY))
    }
}

private func path(points: [CGPoint]) -> Path {
    Path { path in
        guard let first = points.first else { return }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
    }
}

private func spiralPath(center: CGPoint, minRadius: CGFloat, maxRadius: CGFloat, turns: Double, direction: Double) -> Path {
    Path { path in
        let steps: Int = 160
        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            let angle = progress * turns * .pi * 2 * direction
            let radius = minRadius + ((maxRadius - minRadius) * CGFloat(progress))
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            guard point.x.isFinite, point.y.isFinite else { continue }
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
    }
}

private func petalPath(center: CGPoint, startRadius: CGFloat, endRadius: CGFloat, angle: Double, spread: Double) -> Path {
    let start = CGPoint(x: center.x + CGFloat(cos(angle - spread / 2)) * startRadius, y: center.y + CGFloat(sin(angle - spread / 2)) * startRadius)
    let tip = CGPoint(x: center.x + CGFloat(cos(angle)) * endRadius, y: center.y + CGFloat(sin(angle)) * endRadius)
    let end = CGPoint(x: center.x + CGFloat(cos(angle + spread / 2)) * startRadius, y: center.y + CGFloat(sin(angle + spread / 2)) * startRadius)
    return Path { path in
        path.move(to: start)
        path.addQuadCurve(to: tip, control: CGPoint(x: center.x + CGFloat(cos(angle - spread * 0.15)) * (endRadius * 0.72), y: center.y + CGFloat(sin(angle - spread * 0.15)) * (endRadius * 0.72)))
        path.addQuadCurve(to: end, control: CGPoint(x: center.x + CGFloat(cos(angle + spread * 0.15)) * (endRadius * 0.72), y: center.y + CGFloat(sin(angle + spread * 0.15)) * (endRadius * 0.72)))
    }
}

private func waveLoopPath(center: CGPoint, radius: CGFloat, peaks: Int, amplitude: CGFloat) -> Path {
    Path { path in
        let steps: Int = 180
        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            let angle = progress * .pi * 2
            let modulatedRadius = radius + CGFloat(sin(angle * Double(peaks))) * amplitude
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * modulatedRadius, y: center.y + CGFloat(sin(angle)) * modulatedRadius)
            guard point.x.isFinite, point.y.isFinite else { continue }
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
    }
}

private func wobblePath(center: CGPoint, radius: CGFloat, lobes: Int, wobble: CGFloat) -> Path {
    Path { path in
        let steps: Int = 160
        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            let angle = progress * .pi * 2
            let currentRadius = radius + CGFloat(sin(angle * Double(lobes))) * wobble
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * currentRadius, y: center.y + CGFloat(sin(angle)) * currentRadius)
            guard point.x.isFinite, point.y.isFinite else { continue }
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
    }
}

private func quadraticArcPath(center: CGPoint, startRadius: CGFloat, endRadius: CGFloat, angle: Double, arcDepth: CGFloat) -> Path {
    let start = CGPoint(x: center.x + CGFloat(cos(angle - 0.18)) * startRadius, y: center.y + CGFloat(sin(angle - 0.18)) * startRadius)
    let end = CGPoint(x: center.x + CGFloat(cos(angle + 0.18)) * endRadius, y: center.y + CGFloat(sin(angle + 0.18)) * endRadius)
    let control = CGPoint(x: center.x + CGFloat(cos(angle)) * ((startRadius + endRadius) / 2 + arcDepth), y: center.y + CGFloat(sin(angle)) * ((startRadius + endRadius) / 2 + arcDepth))
    return Path { path in
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
    }
}

struct EmotionIconView: View {
    let emotionID: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color)
    }

    private var iconName: String {
        switch emotionID {
        case "anxious": return "circle.hexagongrid.fill"
        case "stressed": return "triangle.fill"
        case "sad": return "moon.stars.fill"
        case "angry": return "bolt.fill"
        case "calm": return "circle.dotted"
        case "happy": return "sun.max.fill"
        case "inspired": return "sparkles"
        default: return "figure.run.circle.fill"
        }
    }
}

struct HarmoniaBackgroundView: View {
    let colors: [Color]

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            Circle()
                .fill(colors.last?.opacity(0.32) ?? .clear)
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: -140, y: -260)
            Circle()
                .fill(Color(hex: "#1FD6C1").opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: 140, y: 260)
        }
    }
}

struct HarmoniaInputField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .font(.body)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

struct HarmoniaPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.08), in: .capsule)
    }
}

struct HarmoniaMiniTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.18), in: .capsule)
    }
}

struct HarmoniaStepperRow: View {
    let title: String
    @Binding var value: Double
    var step: Double = 0.1

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.white)
            Spacer()
            Button("−") {
                value = max(0, value - step)
            }
            .buttonStyle(HarmoniaCapsuleButtonStyle())
            Text(value.harmoniaShortNumber)
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 44)
            Button("+") {
                value = min(999, value + step)
            }
            .buttonStyle(HarmoniaCapsuleButtonStyle())
        }
        .padding(16)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 18))
    }
}

struct SmallToggleButton: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(HarmoniaSelectableChipStyle(isActive: isActive, activeColor: Color(hex: "#1EBE83")))
    }
}

nonisolated enum HarmoniaHaptics {
    static func impact() {
        #if os(iOS)
        Task { @MainActor in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        #endif
    }

    static func selection() {
        #if os(iOS)
        Task { @MainActor in
            UISelectionFeedbackGenerator().selectionChanged()
        }
        #endif
    }
}

struct HarmoniaPrimaryButtonStyle: ButtonStyle {
    let colors: [Color]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 20))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

struct HarmoniaGlassButtonStyle: ButtonStyle {
    var light: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(light ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background((light ? Color.white.opacity(0.7) : Color.white.opacity(0.08)), in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(light ? 0.2 : 0.1), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

struct HarmoniaCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white.opacity(0.08), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

struct HarmoniaIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(.white.opacity(0.08), in: .circle)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

struct HarmoniaScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

struct HarmoniaSelectableChipStyle: ButtonStyle {
    let isActive: Bool
    var activeColor: Color = Color(hex: "#5237D6")

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isActive ? activeColor : .white.opacity(0.08), in: .capsule)
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(isActive ? 0.12 : 0.06), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

extension Color {
    nonisolated init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch sanitized.count {
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

extension Date {
    nonisolated static let harmoniaDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    nonisolated static func harmoniaDayString(from date: Date) -> String {
        harmoniaDayFormatter.string(from: date)
    }
}

extension Double {
    var harmoniaClock: String {
        let total: Int = max(Int(self), 0)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var harmoniaPaddedClock: String {
        let total: Int = max(Int(self), 0)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var harmoniaShortNumber: String {
        String(format: self >= 10 ? "%.0f" : "%.1f", self)
    }

    var harmoniaPercentString: String {
        "\(Int((self * 100).rounded()))%"
    }

    var harmoniaShiftLabel: String {
        switch self {
        case 0..<0.2: return "Feeling unsettled"
        case 0.2..<0.4: return "Still processing"
        case 0.4..<0.55: return "More grounded"
        case 0.55..<0.7: return "More peaceful"
        case 0.7..<0.85: return "More connected"
        default: return "Feeling lighter"
        }
    }
}

extension View {
    func testID(_ id: String) -> some View {
        accessibilityIdentifier(id)
    }
}

#Preview {
    ContentView()
        .environment(AuthStore())
        .environment(UserProgressStore())
        .environment(JournalStore())
        .environment(AudioStore())
        .environment(VibroacousticStore())
}
