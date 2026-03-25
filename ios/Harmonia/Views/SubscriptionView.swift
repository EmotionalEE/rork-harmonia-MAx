import SwiftUI

nonisolated enum SubscriptionPlan: Int, Sendable {
    case annual = 0
    case monthly = 1
}

nonisolated enum PaymentMethod: String, Sendable {
    case card
    case applePay
}

struct SubscriptionView: View {
    @Environment(UserProgressStore.self) private var progressStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: SubscriptionPlan = .annual
    @State private var selectedPayment: PaymentMethod = .applePay
    @State private var isProcessing: Bool = false
    @State private var showCardModal: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""

    private let bg0 = Color(hex: "#070A12")
    private let bg1 = Color(hex: "#0B1022")
    private let gold = Color(hex: "#F8C46C")
    private let teal = Color(hex: "#1FD6C1")
    private let blue = Color(hex: "#4AA3FF")
    private let textColor = Color(hex: "#F5F7FF")
    private let textDim = Color(hex: "#F5F7FF").opacity(0.78)
    private let textFaint = Color(hex: "#F5F7FF").opacity(0.58)

    private var priceText: String {
        selectedPlan == .annual ? "$79.99/year" : "$9.99/month"
    }

    private var priceSummary: String {
        selectedPlan == .annual
            ? "Then $79.99/year. Billed yearly. Cancel anytime."
            : "Then $9.99/month. Billed monthly. Cancel anytime."
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(hex: "#070A12"), Color(hex: "#0B1022"), Color(hex: "#071A24")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            glowOrbs

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    closeBar
                    heroSection
                    planSection
                    paymentMethodSection
                    trustRow
                    featuresSection
                    legalLinks
                    Color.clear.frame(height: 110)
                }
            }
            .scrollIndicators(.hidden)

            stickyFooter
        }
        .sheet(isPresented: $showCardModal) {
            CardPaymentSheet(
                selectedPlan: selectedPlan,
                onSuccess: {
                    progressStore.activateSubscription()
                    showCardModal = false
                    alertTitle = "Welcome to Rork Max!"
                    alertMessage = "Your subscription is now active."
                    showAlert = true
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
            .presentationBackground(Color(hex: "#0B1022"))
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                if alertTitle == "Welcome to Rork Max!" {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }

    private var glowOrbs: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#4AA3FF").opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: 140, y: -280)
                .rotationEffect(.degrees(18))

            Circle()
                .fill(Color(hex: "#1FD6C1").opacity(0.16))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: -160, y: 400)
                .rotationEffect(.degrees(-10))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var closeBar: some View {
        HStack {
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
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                badgePill(icon: "sparkles", iconColor: gold, text: "Rork Max", textColor: gold, bgColor: gold.opacity(0.10), borderColor: gold.opacity(0.22))
                badgePill(icon: "shield", iconColor: textDim, text: "Cancel anytime", textColor: textDim, bgColor: .white.opacity(0.06), borderColor: .white.opacity(0.12))
            }

            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(gold.opacity(0.95))
                        .frame(width: 30, height: 30)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(bg0)
                }

                Text("Upgrade to Rork Max")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(textColor)
                    .tracking(-0.3)
            }
            .padding(.top, 14)

            Text("Unlock the most advanced Harmonia experience with deeper sessions, smarter insights, and faster AI guidance.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(textDim)
                .lineSpacing(3)
                .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private func badgePill(icon: String, iconColor: Color, text: String, textColor: Color, bgColor: Color, borderColor: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(iconColor)
            Text(text)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(textColor)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(bgColor, in: .capsule)
        .overlay {
            Capsule().strokeBorder(borderColor, lineWidth: 1)
        }
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your plan")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(textColor)
                .tracking(0.2)

            HStack(spacing: 12) {
                annualCard
                monthlyCard
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var annualCard: some View {
        let isSelected = selectedPlan == .annual
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedPlan = .annual
            }
            HarmoniaHaptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("BEST VALUE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(textFaint)
                    Spacer()
                    Text("Save 33%")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(teal)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(teal.opacity(0.20), in: .capsule)
                        .overlay {
                            Capsule().strokeBorder(teal.opacity(0.30), lineWidth: 1)
                        }
                }

                Text("Annual")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(textColor)
                    .padding(.top, 12)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("$79.99")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(textColor)
                    Text("/year")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(textFaint)
                }
                .padding(.top, 4)

                HStack {
                    Text("$6.67/mo")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textDim)
                    Spacer()
                    selectionIndicator(isSelected: isSelected)
                }
                .padding(.top, 8)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 152)
            .background(
                LinearGradient(
                    colors: isSelected ? [teal.opacity(0.22), blue.opacity(0.18)] : [.white.opacity(0.08), .white.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: isSelected ? .black.opacity(0.25) : .clear, radius: 16, y: 10)
        }
        .buttonStyle(PlanCardButtonStyle())
    }

    private var monthlyCard: some View {
        let isSelected = selectedPlan == .monthly
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedPlan = .monthly
            }
            HarmoniaHaptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("FLEXIBLE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(textFaint)
                    Spacer()
                    Text("—")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(textFaint)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(.white.opacity(0.06), in: .capsule)
                        .overlay {
                            Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1)
                        }
                }

                Text("Monthly")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(textColor)
                    .padding(.top, 12)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("$9.99")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(textColor)
                    Text("/month")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(textFaint)
                }
                .padding(.top, 4)

                HStack {
                    Text("Billed monthly.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textDim)
                    Spacer()
                    selectionIndicator(isSelected: isSelected)
                }
                .padding(.top, 8)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 152)
            .background(
                LinearGradient(
                    colors: isSelected ? [teal.opacity(0.22), blue.opacity(0.18)] : [.white.opacity(0.08), .white.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: isSelected ? .black.opacity(0.25) : .clear, radius: 16, y: 10)
        }
        .buttonStyle(PlanCardButtonStyle())
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? teal : .white.opacity(0.06))
                .frame(width: 26, height: 26)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? teal.opacity(0.8) : .white.opacity(0.14), lineWidth: 1)
                }
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(bg0)
            }
        }
    }

    private var paymentMethodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pay with")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(textColor)
                .tracking(0.2)

            HStack(spacing: 10) {
                paymentChip(icon: "creditcard", label: "Card", method: .card)
                paymentChip(icon: "apple.logo", label: "Apple Pay", method: .applePay)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
    }

    private func paymentChip(icon: String, label: String, method: PaymentMethod) -> some View {
        let isSelected = selectedPayment == method
        return Button {
            selectedPayment = method
            HarmoniaHaptics.selection()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isSelected ? textColor : textDim)
                    .frame(width: 28, height: 28)
                    .background(
                        isSelected ? .white.opacity(0.12) : .white.opacity(0.08),
                        in: .rect(cornerRadius: 10)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(isSelected ? 0.16 : 0.12), lineWidth: 1)
                    }
                Text(label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isSelected ? textColor : textDim)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                isSelected ? teal.opacity(0.14) : .white.opacity(0.06),
                in: .rect(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? teal.opacity(0.30) : .white.opacity(0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var trustRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(textDim)
                Text("Secure checkout")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(textDim)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1, height: 18)

            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14))
                    .foregroundStyle(textDim)
                Text("Easy restore")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(textDim)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What you get")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(textColor)
                .tracking(0.2)

            VStack(spacing: 0) {
                ForEach([
                    "Unlimited access to all sessions",
                    "Advanced theta wave frequencies",
                    "Personalized recommendations",
                    "Offline mode",
                    "Progress tracking & insights",
                    "Ad-free experience"
                ], id: \.self) { feature in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(gold.opacity(0.95))
                                .frame(width: 26, height: 26)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(bg0)
                        }
                        Text(feature)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(textColor)
                            .lineSpacing(2)
                    }
                    .padding(.vertical, 10)
                }
            }
            .padding(14)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
    }

    private var legalLinks: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("Terms") {}
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(textFaint)
            Text("•")
                .foregroundStyle(.white.opacity(0.26))
            Button("Privacy") {}
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(textFaint)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }

    private var stickyFooter: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color(hex: "#070A12").opacity(0),
                    Color(hex: "#070A12").opacity(0.70),
                    Color(hex: "#070A12").opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)
            .allowsHitTesting(false)

            VStack(spacing: 10) {
                VStack(spacing: 4) {
                    Text("7-day free trial")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(textColor)
                    Text(priceSummary)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textDim)
                        .lineSpacing(2)
                        .multilineTextAlignment(.center)
                }

                Button {
                    HarmoniaHaptics.impact()
                    handleSubscribe()
                } label: {
                    Text(isProcessing ? "Processing…" : "Start free trial")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(bg0)
                        .tracking(0.2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            isProcessing
                                ? AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.10)], startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(LinearGradient(colors: [teal, blue], startPoint: .leading, endPoint: .trailing)),
                            in: .rect(cornerRadius: 18)
                        )
                }
                .disabled(isProcessing)
                .buttonStyle(PlanCardButtonStyle())

                Button {
                    HarmoniaHaptics.selection()
                    alertTitle = "Restore Purchases"
                    alertMessage = "No previous purchases found (demo)."
                    showAlert = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                            .foregroundStyle(textFaint)
                        Text("Restore purchases")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(textFaint)
                    }
                    .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color(hex: "#070A12").opacity(0.98))
        }
    }

    private func handleSubscribe() {
        if selectedPayment == .card {
            showCardModal = true
        } else {
            isProcessing = true
            Task {
                try? await Task.sleep(for: .milliseconds(1200))
                isProcessing = false
                progressStore.activateSubscription()
                HarmoniaHaptics.success()
                alertTitle = "Welcome to Rork Max!"
                alertMessage = "Your subscription is now active."
                showAlert = true
            }
        }
    }
}

struct PlanCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct CardPaymentSheet: View {
    let selectedPlan: SubscriptionPlan
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cardholderName: String = ""
    @State private var cardNumber: String = ""
    @State private var expiry: String = ""
    @State private var cvv: String = ""
    @State private var isProcessing: Bool = false

    private let bg0 = Color(hex: "#070A12")
    private let textColor = Color(hex: "#F5F7FF")
    private let textDim = Color(hex: "#F5F7FF").opacity(0.78)
    private let textFaint = Color(hex: "#F5F7FF").opacity(0.58)
    private let gold = Color(hex: "#F8C46C")

    private var chargeText: String {
        selectedPlan == .annual ? "$79.99/year" : "$9.99/month"
    }

    private var payButtonText: String {
        selectedPlan == .annual ? "Pay $79.99" : "Pay $9.99"
    }

    private var isFormValid: Bool {
        !cardholderName.trimmingCharacters(in: .whitespaces).isEmpty
        && cardNumber.filter(\.isNumber).count >= 12
        && expiry.filter(\.isNumber).count == 4
        && cvv.count >= 3
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    chargeBanner

                    VStack(alignment: .leading, spacing: 12) {
                        cardField(label: "Cardholder name", text: $cardholderName, placeholder: "Jane Doe")

                        cardField(label: "Card number", text: $cardNumber, placeholder: "1234 5678 9012 3456", keyboardType: .numberPad)
                            .onChange(of: cardNumber) { _, newValue in
                                cardNumber = formatCardNumber(newValue)
                            }

                        HStack(spacing: 12) {
                            cardField(label: "Expiry", text: $expiry, placeholder: "MM/YY", keyboardType: .numberPad)
                                .onChange(of: expiry) { _, newValue in
                                    expiry = formatExpiry(newValue)
                                }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("CVV")
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(textDim)
                                SecureField("123", text: $cvv)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(textColor)
                                    .keyboardType(.numberPad)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 12)
                                    .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                                    }
                            }
                            .onChange(of: cvv) { _, newValue in
                                if newValue.count > 4 {
                                    cvv = String(newValue.prefix(4))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Button {
                        processPayment()
                    } label: {
                        Text(isProcessing ? "Processing…" : payButtonText)
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(bg0)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                isProcessing
                                    ? AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.10)], startPoint: .leading, endPoint: .trailing))
                                    : AnyShapeStyle(LinearGradient(colors: [gold, Color(hex: "#FF9D5C")], startPoint: .leading, endPoint: .trailing)),
                                in: .rect(cornerRadius: 16)
                            )
                    }
                    .disabled(!isFormValid || isProcessing)
                    .opacity(isFormValid ? 1 : 0.5)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .buttonStyle(PlanCardButtonStyle())

                    Text("Secure payment processing (demo)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(textFaint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Card details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(textColor)
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.08), in: .rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                            }
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var chargeBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(gold.opacity(0.95))
                    .frame(width: 28, height: 28)
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#070A12"))
            }
            Text("You'll be charged after your 7-day free trial: \(chargeText).")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textDim)
                .lineSpacing(2)
        }
        .padding(12)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }

    private func cardField(label: String, text: Binding<String>, placeholder: String, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(textDim)
            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(textColor)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(keyboardType == .numberPad ? .never : .words)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private func formatCardNumber(_ input: String) -> String {
        let digits = input.filter(\.isNumber)
        let limited = String(digits.prefix(16))
        var result = ""
        for (index, char) in limited.enumerated() {
            if index > 0, index % 4 == 0 { result += " " }
            result.append(char)
        }
        return result
    }

    private func formatExpiry(_ input: String) -> String {
        let digits = input.filter(\.isNumber)
        let limited = String(digits.prefix(4))
        if limited.count > 2 {
            return String(limited.prefix(2)) + "/" + String(limited.dropFirst(2))
        }
        return limited
    }

    private func processPayment() {
        isProcessing = true
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            isProcessing = false
            HarmoniaHaptics.success()
            cardholderName = ""
            cardNumber = ""
            expiry = ""
            cvv = ""
            onSuccess()
        }
    }
}
