import SwiftUI

struct FeelingsChatView: View {
    let context: FeelingsChatContext
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = []
    @State private var composer: String = ""
    @State private var isLoading: Bool = false
    @State private var hasError: Bool = false
    @State private var hasStarted: Bool = false
    @State private var chatService: ChatService = ChatService()

    private let bg0 = Color(hex: "#060712")
    private let teal = Color(hex: "#1FD6C1")
    private let blue = Color(hex: "#4AA3FF")
    private let violet = Color(hex: "#9B87FF")
    private let textColor = Color(hex: "#F5F7FF")
    private let textDim = Color(hex: "#F5F7FF").opacity(0.74)
    private let textFaint = Color(hex: "#F5F7FF").opacity(0.58)
    private let danger = Color(hex: "#FF5A7A")

    private var allPresets: [String] {
        var chips: [String] = []
        if context.feelingDelta == "heavier" {
            chips.append("It got heavier")
        } else if context.feelingDelta == "lighter" {
            chips.append("It got lighter")
        }
        chips.append(contentsOf: ["Body check", "What triggered it", "The story", "What I need", "Next step"])
        return chips
    }

    private var systemPrompt: String {
        let contextJSON: [String: Any] = [
            "mode": "feelings-guide",
            "source": context.source,
            "sessionId": context.sessionId ?? "",
            "sessionName": context.sessionName ?? "",
            "feelingDelta": context.feelingDelta ?? "no-change",
            "feelingScore": context.feelingScore ?? 0,
            "dateISO": context.dateISO ?? "",
            "userNote": context.userNote ?? ""
        ]
        let contextData = try? JSONSerialization.data(withJSONObject: contextJSON)
        let contextString = contextData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        return """
        You are Harmonia's feelings guide — a deeply perceptive, emotionally intelligent companion. \
        You use 6 rotating interaction lenses: Somatic, Metaphor, Cognitive, Micro-Intervention, Rhythm/Energy, Needs. \
        Keep responses under 100 words. Ask one focused question per response. Match emotional intensity. \
        Never say: "I understand", "That must be hard", "I'm sorry to hear that", "Have you tried", "You should". \
        Context: \(contextString)
        """
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(hex: "#060712"), Color(hex: "#0A0E22"), Color(hex: "#081A1E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                safetyDisclaimer
                messageArea
            }

            composerBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if messages.isEmpty {
                let intro = buildIntroMessage()
                messages = [ChatMessage(id: UUID().uuidString, role: "assistant", text: intro)]
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                HarmoniaHaptics.selection()
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(textColor)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Feelings")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(textColor)
                    .tracking(0.2)
                Text("A deeper check-in")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(textDim)
            }

            Spacer()

            Circle()
                .fill(teal.opacity(0.95))
                .frame(width: 10, height: 10)
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var safetyDisclaimer: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(textColor.opacity(0.8))
            Text("Harmonia offers emotional support—not medical care. If you're in immediate danger, contact local emergency services.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(textColor.opacity(0.72))
                .lineSpacing(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }

    private var messageArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !hasStarted {
                        heroCard
                    }

                    if messages.isEmpty && !hasStarted {
                        emptyState
                    }

                    ForEach(messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    if isLoading {
                        loadingIndicator
                    }

                    if hasError {
                        errorCard
                    }

                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(teal)
                .frame(width: 38, height: 38)
                .background(teal.opacity(0.10), in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(teal.opacity(0.22), lineWidth: 1)
                }
                .padding(.bottom, 10)

            Text("Let's go deeper than 'fine'.")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(textColor)
                .padding(.bottom, 6)

            Text("Pick a direction, or just start typing. I'll ask one focused question at a time.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textDim)
                .lineSpacing(3)
                .padding(.bottom, 12)

            FlowChipLayout(spacing: 10) {
                ForEach(allPresets, id: \.self) { preset in
                    Button {
                        composer = preset
                        sendMessage()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(violet)
                            Text(preset)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(textColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.08), in: .capsule)
                        .overlay {
                            Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        }
                    }
                    .buttonStyle(PlanCardButtonStyle())
                }
            }
            .padding(.bottom, 12)

            if !hasStarted {
                Button {
                    startConversation()
                } label: {
                    Text("Start a deeper check-in")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color(hex: "#041116"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(colors: [teal.opacity(0.95), blue.opacity(0.95)], startPoint: .leading, endPoint: .trailing),
                            in: .rect(cornerRadius: 14)
                        )
                }
                .buttonStyle(PlanCardButtonStyle())
            }
        }
        .padding(16)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .padding(.bottom, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No messages yet")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(textColor)
            Text("Tap \"Start a deeper check-in\" or send a message below.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(textDim)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.top, 18)
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 50) }
            Text(message.text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(message.role == "user" ? Color(hex: "#031018") : textColor)
                .lineSpacing(3)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    message.role == "user"
                        ? AnyShapeStyle(teal.opacity(0.92))
                        : AnyShapeStyle(.white.opacity(0.07)),
                    in: .rect(
                        topLeadingRadius: message.role == "assistant" ? 6 : 18,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: 18,
                        topTrailingRadius: message.role == "user" ? 6 : 18
                    )
                )
                .overlay {
                    UnevenRoundedRectangle(
                        topLeadingRadius: message.role == "assistant" ? 6 : 18,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: 18,
                        topTrailingRadius: message.role == "user" ? 6 : 18
                    )
                    .strokeBorder(
                        message.role == "user" ? teal.opacity(0.45) : .white.opacity(0.12),
                        lineWidth: 1
                    )
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.86, alignment: message.role == "user" ? .trailing : .leading)
            if message.role == "assistant" { Spacer(minLength: 50) }
        }
        .padding(.bottom, 10)
    }

    private var loadingIndicator: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(teal)
            Text("Listening…")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(textDim)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var errorCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Couldn't reach the guide")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(textColor)
            Text("Try again in a moment.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(textColor.opacity(0.75))
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(danger.opacity(0.08), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(danger.opacity(0.35), lineWidth: 1)
        }
        .padding(.top, 12)
    }

    private var composerBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 1)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("What's really going on for you?", text: $composer, axis: .vertical)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textColor)
                    .lineSpacing(3)
                    .lineLimit(1...6)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#06121A"))
                        .frame(width: 44, height: 44)
                        .background(teal.opacity(0.95), in: .rect(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(teal.opacity(0.55), lineWidth: 1)
                        }
                }
                .disabled(composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .opacity(composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                .buttonStyle(PlanCardButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bg0.opacity(0.92))
        }
    }

    private func startConversation() {
        hasStarted = true
        HarmoniaHaptics.selection()
    }

    private func sendMessage() {
        let trimmed = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        hasStarted = true
        hasError = false
        messages.append(ChatMessage(id: UUID().uuidString, role: "user", text: trimmed))
        composer = ""
        isLoading = true
        HarmoniaHaptics.impact()

        Task {
            if let reply = await chatService.sendMessage(history: messages, systemPrompt: systemPrompt) {
                isLoading = false
                messages.append(ChatMessage(id: UUID().uuidString, role: "assistant", text: reply))
            } else {
                isLoading = false
                hasError = true
            }
        }
    }

    private func buildIntroMessage() -> String {
        if let sessionName = context.sessionName, !sessionName.isEmpty {
            return "I'm here with you. Based on this moment after \(sessionName), what feels most alive in your body right now?"
        }
        return "I'm here with you. What feels most alive in your body right now?"
    }
}
