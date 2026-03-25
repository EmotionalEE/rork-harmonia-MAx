import SwiftUI

struct AIChatModal: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = [
        ChatMessage(id: UUID().uuidString, role: "assistant", text: "Hello! I'm here to support you on your journey. How are you feeling today?")
    ]
    @State private var composer: String = ""
    @State private var isTyping: Bool = false
    @State private var hasError: Bool = false
    @State private var chatService: ChatService = ChatService()

    private let bg0 = Color(hex: "#070A12")
    private let bg1 = Color(hex: "#0B1022")
    private let textColor = Color(hex: "#F5F7FF")
    private let textFaint = Color(hex: "#F5F7FF").opacity(0.58)
    private let teal = Color(hex: "#1FD6C1")
    private let blue = Color(hex: "#4AA3FF")
    private let gold = Color(hex: "#F8C46C")
    private let purple = Color(hex: "#9333EA")

    private let systemPrompt: String = """
    You are Harmonia's Wellness Companion — a warm, perceptive emotional support guide. \
    You use 6 rotating response styles: Somatic, Metaphor, Cognitive, Micro-Intervention, Rhythm/Energy, Needs. \
    Keep responses under 100 words. Ask one focused question per response. Match emotional intensity. \
    Never say: "I understand", "That must be hard", "I'm sorry to hear that", "Have you tried", "You should".
    """

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#070A12"), Color(hex: "#0B1022"), Color(hex: "#071A24")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                glowOrbs

                VStack(spacing: 0) {
                    header
                    messageList
                    inputArea
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var glowOrbs: some View {
        ZStack {
            Circle()
                .fill(blue.opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: 140, y: -280)
                .rotationEffect(.degrees(18))

            Circle()
                .fill(teal.opacity(0.16))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: -160, y: 400)
                .rotationEffect(.degrees(-10))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(purple.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Circle().strokeBorder(purple, lineWidth: 2)
                    }
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(gold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Wellness Companion")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Text("Reflect, release, and re-center")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Button {
                HarmoniaHaptics.selection()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(textColor)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                    }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        chatBubble(message)
                            .id(message.id)
                    }

                    if isTyping {
                        typingIndicator
                    }

                    if hasError {
                        errorBubble
                    }
                }
                .padding(20)
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

    private func chatBubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == "assistant" {
                ZStack {
                    Circle()
                        .fill(purple.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(gold)
                }
                .padding(.top, 4)
            }

            if message.role == "user" { Spacer(minLength: 60) }

            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(message.role == "user" ? Color(hex: "#0b1220") : .white)
                .lineSpacing(3)
                .padding(14)
                .background(
                    message.role == "user"
                        ? AnyShapeStyle(Color(hex: "#14b8a6"))
                        : AnyShapeStyle(purple.opacity(0.12)),
                    in: .rect(cornerRadius: 18)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            message.role == "user" ? .clear : purple.opacity(0.2),
                            lineWidth: 1
                        )
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == "user" ? .trailing : .leading)

            if message.role == "assistant" { Spacer(minLength: 60) }
        }
        .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
    }

    private var typingIndicator: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(purple.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(gold)
            }
            .padding(.top, 4)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(purple.opacity(0.6))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(purple.opacity(0.12), in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(purple.opacity(0.2), lineWidth: 1)
            }

            Spacer()
        }
    }

    private var errorBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(purple.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(gold)
            }
            .padding(.top, 4)

            Text("Sorry, I had trouble responding. Please try again.")
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .lineSpacing(3)
                .padding(14)
                .background(purple.opacity(0.12), in: .rect(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(purple.opacity(0.2), lineWidth: 1)
                }

            Spacer()
        }
    }

    private var inputArea: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)

            HStack(spacing: 10) {
                TextField("Share how you're feeling...", text: $composer, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    }
                    .onChange(of: composer) { _, newValue in
                        if newValue.count > 500 {
                            composer = String(newValue.prefix(500))
                        }
                    }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSendEnabled ? bg0 : textFaint)
                        .frame(width: 44, height: 44)
                        .background(
                            isSendEnabled
                                ? AnyShapeStyle(LinearGradient(colors: [teal, blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.10)], startPoint: .leading, endPoint: .trailing)),
                            in: .circle
                        )
                }
                .disabled(!isSendEnabled)
                .opacity(isSendEnabled ? 1 : 0.5)
                .buttonStyle(PlanCardButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.black.opacity(0.3))
        }
    }

    private var isSendEnabled: Bool {
        !composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
    }

    private func sendMessage() {
        let trimmed = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        hasError = false
        messages.append(ChatMessage(id: UUID().uuidString, role: "user", text: trimmed))
        composer = ""
        isTyping = true
        HarmoniaHaptics.selection()

        Task {
            if let reply = await chatService.sendMessage(history: messages, systemPrompt: systemPrompt) {
                isTyping = false
                messages.append(ChatMessage(id: UUID().uuidString, role: "assistant", text: reply))
            } else {
                isTyping = false
                hasError = true
            }
        }
    }
}
