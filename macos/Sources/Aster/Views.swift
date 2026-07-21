import SwiftUI

private let asterSignal = Color(red: 0.937, green: 0.357, blue: 0.208)
private let asterCoral = Color(red: 1.0, green: 0.49, blue: 0.36)
private let asterMint = Color(red: 0.55, green: 0.94, blue: 0.75)
private let asterInk = Color(nsColor: .labelColor)
private let asterSecondary = Color(nsColor: .secondaryLabelColor)
private let asterCanvas = Color(nsColor: .windowBackgroundColor)
private let asterSurface = Color(nsColor: .controlBackgroundColor)
private let asterLine = Color(nsColor: .separatorColor)

struct AsterMark: View {
    var size: CGFloat = 28

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / 32
            let stroke = StrokeStyle(lineWidth: 3.2 * scale, lineCap: .round, lineJoin: .round)
            var cursor = Path()
            cursor.move(to: CGPoint(x: 3 * scale, y: 3 * scale))
            cursor.addLine(to: CGPoint(x: 6.2 * scale, y: 15.2 * scale))
            cursor.addLine(to: CGPoint(x: 9 * scale, y: 11.9 * scale))
            cursor.addLine(to: CGPoint(x: 14.2 * scale, y: 17.1 * scale))
            cursor.addLine(to: CGPoint(x: 16.7 * scale, y: 14.6 * scale))
            cursor.addLine(to: CGPoint(x: 11.5 * scale, y: 9.4 * scale))
            cursor.addLine(to: CGPoint(x: 15.2 * scale, y: 6.3 * scale))
            cursor.closeSubpath()
            context.fill(cursor, with: .color(asterSignal))

            var rays = Path()
            rays.move(to: CGPoint(x: 23 * scale, y: 13 * scale)); rays.addLine(to: CGPoint(x: 29 * scale, y: 7 * scale))
            rays.move(to: CGPoint(x: 23 * scale, y: 23 * scale)); rays.addLine(to: CGPoint(x: 29 * scale, y: 28 * scale))
            rays.move(to: CGPoint(x: 18 * scale, y: 24 * scale)); rays.addLine(to: CGPoint(x: 18 * scale, y: 30 * scale))
            rays.move(to: CGPoint(x: 13 * scale, y: 19 * scale)); rays.addLine(to: CGPoint(x: 3 * scale, y: 19 * scale))
            context.stroke(rays, with: .color(asterSignal), style: stroke)
            context.fill(Path(ellipseIn: CGRect(x: 15.2 * scale, y: 16.2 * scale, width: 5.6 * scale, height: 5.6 * scale)), with: .color(asterSignal))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct AsterCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(asterLine.opacity(0.65), lineWidth: 1))
    }
}

private struct ConnectionPill: View {
    let status: APIKeyStatus

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).lineLimit(1)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(asterSecondary)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(asterSurface.opacity(0.78), in: Capsule())
        .overlay(Capsule().stroke(asterLine.opacity(0.65), lineWidth: 1))
    }

    private var color: Color {
        switch status {
        case .authenticated: return .green
        case .validating: return .orange
        case .invalid: return .red
        case .unauthenticated: return asterSecondary
        }
    }

    private var label: String {
        switch status {
        case .authenticated: return "OpenAI connected"
        case .validating: return "Validating key…"
        case .invalid: return "Connection needs attention"
        case .unauthenticated: return "API key required"
        }
    }
}

struct WelcomeView: View {
    @ObservedObject var model: TutorModel

    var body: some View {
        ZStack {
            asterCanvas.ignoresSafeArea()
            Circle().fill(asterSignal.opacity(0.12)).frame(width: 680, height: 680).blur(radius: 80).offset(x: 470, y: -320)
            Circle().fill(asterMint.opacity(0.08)).frame(width: 520, height: 520).blur(radius: 90).offset(x: -460, y: 350)
            VStack(spacing: 0) {
                appHeader
                if model.isOnboardingComplete {
                    home
                } else {
                    onboarding
                }
            }
        }
        .frame(minWidth: 1_040, minHeight: 720)
    }

    private var appHeader: some View {
        HStack(spacing: 11) {
            AsterMark(size: 31)
            Text("Aster✱").font(.system(size: 20, weight: .semibold, design: .rounded))
            Spacer()
            ConnectionPill(status: model.apiKeyStatus)
            Button { model.showSettings() } label: {
                Image(systemName: "gearshape").frame(width: 30, height: 30)
            }
            .buttonStyle(.plain).help("Settings")
        }
        .padding(.horizontal, 34).padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var onboarding: some View {
        VStack(spacing: 0) {
            onboardingProgress
            Group {
                switch model.onboardingStep {
                case .introduction: introductionStep
                case .permissions: permissionsStep
                case .apiKey: apiKeyStep
                case .ready: readyStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            onboardingFooter
        }
        .padding(.horizontal, 54).padding(.bottom, 34)
    }

    private var onboardingProgress: some View {
        HStack(spacing: 9) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                HStack(spacing: 7) {
                    Circle()
                        .fill(step.rawValue <= model.onboardingStep.rawValue ? asterSignal : asterLine)
                        .frame(width: 8, height: 8)
                    Text(["Meet Aster✱", "Permissions", "Connect", "Ready"][step.rawValue])
                        .font(.system(size: 10, weight: step == model.onboardingStep ? .semibold : .regular))
                        .foregroundStyle(step == model.onboardingStep ? asterInk : asterSecondary)
                }
                if step != .ready { Rectangle().fill(asterLine).frame(width: 34, height: 1) }
            }
        }
        .padding(.vertical, 24)
    }

    private var introductionStep: some View {
        HStack(spacing: 54) {
            VStack(alignment: .leading, spacing: 24) {
                Text("THE TUTOR THAT MEETS YOU THERE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(asterSignal)
                Text("Your screen becomes\nthe whiteboard.")
                    .font(.system(size: 52, weight: .medium, design: .rounded)).tracking(-2.2)
                Text("Press Option–Space, point at the exact equation, diagram, paragraph, graph, or code block, and ask. Aster✱ diagnoses first, teaches in place, checks understanding, and remembers what needs work.")
                    .font(.system(size: 17)).foregroundStyle(asterSecondary).lineSpacing(5).frame(maxWidth: 470, alignment: .leading)
                HStack(spacing: 18) {
                    feature("viewfinder", "See", "Exact selected context")
                    feature("pencil.and.outline", "Teach", "Voice + spatial marks")
                    feature("brain.head.profile", "Adapt", "Local mastery memory")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            presencePreview
        }
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(asterSignal)
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(detail).font(.system(size: 10)).foregroundStyle(asterSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var presencePreview: some View {
        AsterCard {
            ZStack {
                RoundedRectangle(cornerRadius: 15).fill(asterSurface.opacity(0.55))
                VStack(alignment: .leading, spacing: 20) {
                    HStack { Circle().fill(.red.opacity(0.8)).frame(width: 8, height: 8); Circle().fill(.yellow.opacity(0.8)).frame(width: 8, height: 8); Circle().fill(.green.opacity(0.8)).frame(width: 8, height: 8); Spacer(); Text("YOUR LEARNING CONTEXT").font(.system(size: 8, design: .monospaced)).foregroundStyle(asterSecondary) }
                    Text("Attention(Q, K, V) = softmax( QKᵀ / √dₖ )V").font(.system(size: 24, design: .serif))
                    ZStack(alignment: .leading) {
                        Capsule().fill(asterCoral.opacity(0.15)).frame(width: 88, height: 28).offset(x: 280)
                        HStack(spacing: 8) { AsterMark(size: 26); Text("I’ll point to the exact term while I explain why it matters.").font(.system(size: 12, weight: .medium)).foregroundStyle(asterSecondary) }
                    }
                    Spacer()
                    HStack { Label("Quiet until invited", systemImage: "hand.raised.fill"); Spacer(); Text("⌥ SPACE").font(.system(size: 9, weight: .bold, design: .monospaced)) }
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(asterSecondary)
                }.padding(22)
            }
            .frame(width: 430, height: 360)
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Permission, with purpose.").font(.system(size: 42, weight: .medium, design: .rounded)).tracking(-1.5)
            Text("Aster✱ asks only for capabilities a spatial tutor needs. Screen Recording is required. Voice remains optional.")
                .font(.system(size: 16)).foregroundStyle(asterSecondary).frame(maxWidth: 680, alignment: .leading)
            AsterCard {
                VStack(spacing: 0) {
                    PermissionRow(icon: "rectangle.dashed.badge.record", title: "Screen Recording", detail: "Required to capture only the region or window you select.", state: model.screenPermission, required: true) {
                        model.screenPermission == .denied ? model.openScreenPermissionSettings() : model.requestScreenPermission()
                    }
                    Divider().padding(.vertical, 4)
                    PermissionRow(icon: "waveform", title: "Microphone + Speech Recognition", detail: "Optional. Enables questions and follow-ups by voice.", state: voicePermissionState, required: false) {
                        voicePermissionState == .denied ? model.openVoicePermissionSettings() : model.requestVoicePermissions()
                    }
                }
            }
            .frame(maxWidth: 760)
            Label("No screen content is sent to OpenAI until you explicitly ask Aster✱ a question.", systemImage: "lock.shield.fill")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(asterSecondary)
        }
        .frame(maxWidth: 800, alignment: .leading)
    }

    private var voicePermissionState: PermissionState {
        if model.microphonePermission == .denied || model.speechPermission == .denied { return .denied }
        if model.microphonePermission == .granted && model.speechPermission == .granted { return .granted }
        return .notDetermined
    }

    private var apiKeyStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Connect your OpenAI account.").font(.system(size: 42, weight: .medium, design: .rounded)).tracking(-1.5)
            Text("Aster✱ requires your own OpenAI API key for live visual reasoning. The key is validated before it is saved and remains removable at any time.")
                .font(.system(size: 16)).foregroundStyle(asterSecondary).frame(maxWidth: 720, alignment: .leading)
            APIKeyCard(model: model, allowsRemoval: false).frame(maxWidth: 760)
        }
        .frame(maxWidth: 800, alignment: .leading)
    }

    private var readyStep: some View {
        VStack(spacing: 26) {
            ZStack { Circle().fill(asterSignal.opacity(0.12)).frame(width: 126, height: 126); AsterMark(size: 66) }
            Text("Aster✱ is ready.").font(.system(size: 46, weight: .medium, design: .rounded)).tracking(-1.6)
            Text("Press Option–Space anywhere, drag over what you’re learning, then ask by text or voice. Aster✱ stays above your work while it teaches.")
                .font(.system(size: 16)).foregroundStyle(asterSecondary).multilineTextAlignment(.center).lineSpacing(4).frame(maxWidth: 620)
            HStack(spacing: 10) {
                readiness("OpenAI", model.isAuthenticated)
                readiness("Screen", model.screenPermission == .granted)
                readiness("Voice optional", voicePermissionState == .granted)
            }
        }
    }

    private func readiness(_ label: String, _ ready: Bool) -> some View {
        Label(label, systemImage: ready ? "checkmark.circle.fill" : "circle.dashed")
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(ready ? Color.green : asterSecondary)
            .padding(.horizontal, 12).padding(.vertical, 8).background(asterSurface.opacity(0.7), in: Capsule())
    }

    private var onboardingFooter: some View {
        HStack {
            Button("Back") { model.moveOnboardingBack() }
                .buttonStyle(.plain).foregroundStyle(asterSecondary).disabled(model.onboardingStep == .introduction)
            Spacer()
            if model.onboardingStep == .permissions {
                Text("Voice can be enabled later in Settings.").font(.system(size: 11)).foregroundStyle(asterSecondary)
            }
            Button(model.onboardingStep == .ready ? "Start using Aster✱" : "Continue") {
                model.onboardingStep == .ready ? model.finishOnboarding() : model.advanceOnboarding()
            }
            .buttonStyle(.borderedProminent).tint(asterSignal).controlSize(.large)
            .disabled(model.onboardingStep == .apiKey && !model.isAuthenticated)
        }
    }

    private var home: some View {
        HStack(spacing: 42) {
            VStack(alignment: .leading, spacing: 25) {
                Text("READY WHEN YOU ARE").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(asterSignal)
                Text("Point to the question.\nKeep your place.")
                    .font(.system(size: 52, weight: .medium, design: .rounded)).tracking(-2)
                Text("Aster✱ follows the exact context you select, diagnoses what is unclear, and teaches with synchronized voice and drawing.")
                    .font(.system(size: 17)).foregroundStyle(asterSecondary).lineSpacing(5).frame(maxWidth: 480, alignment: .leading)
                Button { model.activateFromHotKey() } label: {
                    HStack(spacing: 11) { Image(systemName: "viewfinder"); Text("Point to something"); Spacer(); Text("⌥ SPACE").font(.system(size: 10, weight: .bold, design: .monospaced)).opacity(0.72) }
                        .padding(.horizontal, 18).frame(width: 280, height: 52)
                }
                .buttonStyle(.borderedProminent).tint(asterSignal).controlSize(.large)
                HStack(spacing: 9) {
                    Button { model.selectCurrentWindow() } label: { Label("Use current window", systemImage: "macwindow") }
                    Button { model.showSettings() } label: { Label("Settings", systemImage: "gearshape") }
                }.buttonStyle(.bordered)
            }
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    MetricCard(value: "\(model.learnerProfile.concepts.count)", label: "Concepts remembered", icon: "brain.head.profile")
                    MetricCard(value: "\(model.learnerProfile.dueReviews.count)", label: "Reviews ready", icon: "calendar.badge.clock")
                }
                AsterCard {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Text("THE LEARNING LOOP").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(asterSignal); Spacer(); ConnectionPill(status: model.apiKeyStatus) }
                        ForEach(Array([("1", "See", "The exact thing you selected"), ("2", "Diagnose", "One question before explaining"), ("3", "Teach", "Voice, drawing, and notebook together"), ("4", "Check", "A prediction before moving on")]), id: \.0) { item in
                            HStack(spacing: 13) { Text(item.0).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(asterSignal).frame(width: 24, height: 24).background(asterSignal.opacity(0.1), in: Circle()); VStack(alignment: .leading, spacing: 2) { Text(item.1).font(.system(size: 13, weight: .semibold)); Text(item.2).font(.system(size: 11)).foregroundStyle(asterSecondary) }; Spacer() }
                        }
                    }
                }
            }
            .frame(width: 430)
        }
        .padding(54).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MetricCard: View {
    let value: String
    let label: String
    let icon: String
    var body: some View {
        AsterCard {
            VStack(alignment: .leading, spacing: 11) {
                Image(systemName: icon).foregroundStyle(asterSignal)
                Text(value).font(.system(size: 30, weight: .semibold, design: .rounded))
                Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(asterSecondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let detail: String
    let state: PermissionState
    let required: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon).font(.system(size: 18, weight: .medium)).foregroundStyle(asterSignal).frame(width: 36, height: 36).background(asterSignal.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) { HStack(spacing: 7) { Text(title).font(.system(size: 13, weight: .semibold)); Text(required ? "REQUIRED" : "OPTIONAL").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(required ? asterSignal : asterSecondary) }; Text(detail).font(.system(size: 11)).foregroundStyle(asterSecondary) }
            Spacer()
            if state == .granted {
                Label("Allowed", systemImage: "checkmark.circle.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(.green)
            } else {
                Button(state == .denied ? "Open Settings" : "Allow") { action() }.buttonStyle(.bordered).controlSize(.small)
            }
        }.padding(.vertical, 8)
    }
}

private struct APIKeyCard: View {
    @ObservedObject var model: TutorModel
    let allowsRemoval: Bool
    @State private var confirmRemoval = false

    var body: some View {
        AsterCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: model.isAuthenticated ? "checkmark.shield.fill" : "key.horizontal.fill").foregroundStyle(model.isAuthenticated ? Color.green : asterSignal)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.isAuthenticated ? "OpenAI connected" : "OpenAI API key").font(.system(size: 14, weight: .semibold))
                        if case .authenticated(let hint) = model.apiKeyStatus { Text(hint).font(.system(size: 10, design: .monospaced)).foregroundStyle(asterSecondary) }
                    }
                    Spacer()
                    Button("Get a key ↗") { model.openAPIKeyPage() }.buttonStyle(.plain).foregroundStyle(asterSignal).font(.system(size: 11, weight: .semibold))
                }
                if !model.isAuthenticated {
                    SecureField("sk-…", text: $model.apiKeyDraft)
                        .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                        .padding(12).background(asterSurface, in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(asterLine, lineWidth: 1))
                    HStack {
                        keyFeedback
                        Spacer()
                        Button(model.apiKeyStatus == .validating ? "Validating…" : "Validate and save") { model.saveAPIKey() }
                            .buttonStyle(.borderedProminent).tint(asterSignal).disabled(model.apiKeyDraft.isEmpty || model.apiKeyStatus == .validating)
                    }
                }
                if allowsRemoval && !model.apiKey.isEmpty {
                    Divider()
                    HStack {
                        Text("Saved in macOS Keychain after validation. Never bundled or written to logs.").font(.system(size: 10)).foregroundStyle(asterSecondary)
                        Spacer()
                        Button("Remove API key / Sign out", role: .destructive) { confirmRemoval = true }.buttonStyle(.bordered)
                    }
                }
                Label("All Responses API requests use store: false.", systemImage: "lock.fill")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(asterSecondary)
            }
        }
        .alert("Remove API key?", isPresented: $confirmRemoval) {
            Button("Cancel", role: .cancel) {}
            Button("Remove and sign out", role: .destructive) { model.removeAPIKey() }
        } message: {
            Text("The key will be deleted from macOS Keychain immediately. Aster✱ will require a key before another teaching turn.")
        }
    }

    @ViewBuilder private var keyFeedback: some View {
        switch model.apiKeyStatus {
        case .invalid(let message): Label(message, systemImage: "exclamationmark.circle.fill").foregroundStyle(.red)
        case .validating: Label("Checking with OpenAI…", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(asterSecondary)
        default: Text("The key is saved only after validation.").foregroundStyle(asterSecondary)
        }
    }
}

struct TutorPanelView: View {
    @ObservedObject var model: TutorModel
    @State private var transcriptExpanded = true
    @State private var surface = "Transcript"
    @State private var pulse = false

    var body: some View {
        ZStack {
            asterCanvas.opacity(0.98).ignoresSafeArea()
            VStack(spacing: 0) {
                panelHeader
                phaseRail
                if !model.isAuthenticated {
                    accountRequired
                } else {
                    contextBar
                    if case .error(let message) = model.phase { errorCard(message) }
                    transcript
                    if let diagnostic = model.diagnostic { DiagnosticChoiceCard(diagnostic: diagnostic) { model.chooseDiagnostic($0) }.padding(.horizontal, 14).padding(.bottom, 8) }
                    composer
                }
            }
        }
        .frame(width: 420, height: 720)
    }

    private var panelHeader: some View {
        HStack(spacing: 11) {
            ZStack { AsterMark(size: 30); if isActive { Circle().stroke(asterSignal.opacity(0.35), lineWidth: 2).frame(width: 41, height: 41).scaleEffect(pulse ? 1.18 : 0.88).opacity(pulse ? 0 : 1).animation(.easeOut(duration: 1.1).repeatForever(autoreverses: false), value: pulse) } }
            VStack(alignment: .leading, spacing: 2) { Text("Aster✱").font(.system(size: 15, weight: .semibold, design: .rounded)); Text(model.phase.label).font(.system(size: 10, weight: .medium)).foregroundStyle(asterSecondary).lineLimit(1) }
            Spacer()
            Button { model.showSettings() } label: { Image(systemName: "gearshape") }.help("Settings")
            Button { model.closePanel() } label: { Image(systemName: "xmark") }.help("Close")
        }
        .buttonStyle(.plain).padding(.horizontal, 17).padding(.vertical, 14).background(.ultraThinMaterial)
        .onAppear { pulse = true }
    }

    private var isActive: Bool { model.phase != .ready && model.phase != .following }

    private var phaseRail: some View {
        HStack(spacing: 5) {
            ForEach([("See", 0), ("Diagnose", 1), ("Teach", 2), ("Check", 3)], id: \.0) { item in
                HStack(spacing: 5) { Circle().fill(phaseIndex >= item.1 ? asterSignal : asterLine).frame(width: 6, height: 6); Text(item.0) }
                    .font(.system(size: 8, weight: phaseIndex == item.1 ? .bold : .medium, design: .monospaced)).foregroundStyle(phaseIndex == item.1 ? asterInk : asterSecondary)
                if item.1 < 3 { Rectangle().fill(asterLine).frame(height: 1) }
            }
        }.padding(.horizontal, 16).padding(.vertical, 9).background(asterSurface.opacity(0.45))
    }

    private var phaseIndex: Int {
        switch model.phase {
        case .seeing, .selectingContext, .following: return 0
        case .diagnosing, .clarifying: return 1
        case .thinking, .teaching, .runningTool: return 2
        case .awaitingUnderstanding, .assessing: return 3
        default: return 0
        }
    }

    private var accountRequired: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack { Circle().fill(asterSignal.opacity(0.1)).frame(width: 92, height: 92); Image(systemName: "key.horizontal.fill").font(.system(size: 32)).foregroundStyle(asterSignal) }
            Text("Connect OpenAI to begin").font(.system(size: 22, weight: .semibold, design: .rounded))
            Text("Aster✱ does not use canned lessons. Add and validate your API key before selecting learning context.").font(.system(size: 13)).foregroundStyle(asterSecondary).multilineTextAlignment(.center).lineSpacing(3).frame(maxWidth: 300)
            Button("Open setup") { model.onShowWelcome?() }.buttonStyle(.borderedProminent).tint(asterSignal)
            Spacer()
        }.frame(maxWidth: .infinity)
    }

    private var contextBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button { model.selectContext() } label: { Label(model.contextRegion == nil ? "Point / select" : "Reselect", systemImage: "viewfinder") }
                Button { model.selectCurrentWindow() } label: { Label("Window", systemImage: "macwindow") }
                Button { model.toggleFollowing() } label: { Image(systemName: model.isFollowing ? "dot.radiowaves.left.and.right" : "pause.circle") }.help(model.isFollowing ? "Following locally" : "Resume following")
                Button { model.toggleVideoMode() } label: { Image(systemName: model.isVideoMode ? "play.rectangle.fill" : "play.rectangle") }.help("Recent-frame video tutoring")
                Spacer()
            }
            HStack(spacing: 6) { Circle().fill(model.isFollowing ? asterMint : asterSecondary).frame(width: 6, height: 6); Text(model.anchorStatus).lineLimit(1); Spacer(); Text(model.isVideoMode ? "4 FRAMES" : "LOCAL") }
                .font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(asterSecondary)
        }
        .buttonStyle(.plain).font(.system(size: 10, weight: .semibold)).padding(.horizontal, 15).padding(.vertical, 10).background(asterSurface.opacity(0.34))
    }

    private var transcript: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Surface", selection: $surface) { Text("Transcript").tag("Transcript"); Text("Notebook").tag("Notebook") }.pickerStyle(.segmented).labelsHidden().frame(width: 190)
                Spacer()
                Button { transcriptExpanded.toggle() } label: { Image(systemName: transcriptExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical") }.buttonStyle(.plain).help("Collapse transcript")
            }.padding(.horizontal, 15).padding(.vertical, 9)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 11) {
                        ForEach(visibleMessages) { message in MessageBubble(message: message).id(message.id) }
                    }.padding(.horizontal, 15).padding(.bottom, 12)
                }
                .onChange(of: model.messages.count) { _ in if let id = visibleMessages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } } }
            }
        }.frame(maxHeight: .infinity)
    }

    private var visibleMessages: [ChatMessage] {
        let source = surface == "Notebook" ? model.messages.filter { [.insight, .check, .assessment, .memory].contains($0.kind) } : model.messages
        return transcriptExpanded ? source : Array(source.suffix(3))
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 5) { Text("Aster✱ needs attention").font(.system(size: 11, weight: .semibold)); Text(message).font(.system(size: 10)).foregroundStyle(asterSecondary); HStack { if message.localizedCaseInsensitiveContains("Screen Recording") { Button("Open Privacy Settings") { model.openScreenPermissionSettings() } } else if !model.isAuthenticated { Button("Open setup") { model.onShowWelcome?() } }; Button("Dismiss") { model.recoverFromError() } }.buttonStyle(.link) }
            Spacer()
        }.padding(12).background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 13)).padding(.horizontal, 14).padding(.top, 10)
    }

    private var composer: some View {
        VStack(spacing: 9) {
            if let lesson = model.lastLesson, lesson.toolSuggestion != "none" {
                Button { model.runSuggestedTool() } label: { HStack { Image(systemName: lesson.toolSuggestion == "desmos" ? "function" : "play.rectangle"); Text(lesson.toolSuggestion == "desmos" ? "Show in Desmos sandbox" : "Animate with Manim"); Spacer(); Text("Preview →").font(.system(size: 10, weight: .bold)).foregroundStyle(asterSignal) }.contentShape(Rectangle()) }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).padding(10).background(asterSignal.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
            }
            teachingControls
            HStack(spacing: 8) {
                Button { model.toggleListening() } label: { Image(systemName: model.isListening ? "stop.fill" : "waveform").frame(width: 34, height: 34).background(model.isListening ? Color.red.opacity(0.14) : asterSurface, in: Circle()) }
                TextField(model.phase == .awaitingUnderstanding ? "Answer the understanding check…" : "Ask about the selected context…", text: $model.query, axis: .vertical).textFieldStyle(.plain).font(.system(size: 13)).onSubmit { model.submit() }
                Button { model.submit() } label: { Image(systemName: "arrow.up").font(.system(size: 12, weight: .bold)).foregroundStyle(.white).frame(width: 30, height: 30).background(asterSignal, in: Circle()) }.disabled(model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .buttonStyle(.plain).padding(8).background(asterSurface, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(asterLine.opacity(0.7), lineWidth: 1))
            HStack(spacing: 8) { Image(systemName: "tortoise"); Slider(value: $model.narrationRate, in: 0.34...0.62); Image(systemName: "hare"); Text("Narration").font(.system(size: 9, weight: .medium)) }.foregroundStyle(asterSecondary)
            HStack { Text("Selected context is sent only after you ask"); Spacer(); Text("⌥ SPACE") }.font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(asterSecondary)
        }.padding(13).background(.ultraThinMaterial)
    }

    @ViewBuilder private var teachingControls: some View {
        if model.phase == .teaching, let lesson = model.lastLesson {
            HStack { Button { model.previousStep() } label: { Image(systemName: "chevron.left") }.disabled(model.lessonStepIndex == 0); Text("Step \(model.lessonStepIndex + 1) of \(lesson.steps.count)"); Button { model.replayCurrentStep() } label: { Label("Replay", systemImage: "arrow.counterclockwise") }; Spacer(); Button("Next →") { model.nextStep() } }.buttonStyle(.plain).font(.system(size: 10, weight: .semibold)).foregroundStyle(asterSecondary)
        }
        if model.phase == .awaitingUnderstanding {
            HStack(spacing: 7) { Button("Simpler") { model.requestReteach("more simply") }; Button("Follow-up") { model.askFollowUpInstead() }; Button("Challenge me") { model.increaseDifficulty() } }.buttonStyle(.bordered).controlSize(.small)
        }
        if let assessment = model.lastAssessment, !assessment.correct {
            HStack(spacing: 7) { Button("Explain more simply") { model.requestReteach("more simply") }; Button("Use an analogy") { model.requestReteach("with a concrete analogy") } }.buttonStyle(.bordered).controlSize(.small)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: TutorModel
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            asterCanvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack { AsterMark(size: 34); VStack(alignment: .leading, spacing: 2) { Text("Aster✱ Settings").font(.system(size: 24, weight: .semibold, design: .rounded)); Text("Your account, voice, permissions, actions, and learning history.").font(.system(size: 11)).foregroundStyle(asterSecondary) }; Spacer(); ConnectionPill(status: model.apiKeyStatus) }
                    settingsSection("ACCOUNT", "Your key belongs to you.") { APIKeyCard(model: model, allowsRemoval: true) }
                    settingsSection("VOICE", "Make narration comfortable.") {
                        VStack(spacing: 14) {
                            HStack { Label("Narration speed", systemImage: "speaker.wave.2.fill"); Spacer(); Image(systemName: "tortoise"); Slider(value: $model.narrationRate, in: 0.34...0.62).frame(width: 220); Image(systemName: "hare") }
                            Divider()
                            Toggle(isOn: $model.conversationMode) { VStack(alignment: .leading, spacing: 2) { Text("Conversational follow-ups").font(.system(size: 12, weight: .semibold)); Text("Listen again after each understanding check.").font(.system(size: 10)).foregroundStyle(asterSecondary) } }
                            Toggle(isOn: $model.wakePhraseEnabled) { VStack(alignment: .leading, spacing: 2) { Text("“Hey Aster” wake phrase").font(.system(size: 12, weight: .semibold)); Text("Optional continuous on-device wake listening.").font(.system(size: 10)).foregroundStyle(asterSecondary) } }
                        }.font(.system(size: 12))
                    }
                    settingsSection("AGENT ACTIONS", "Bounded and permissioned.") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Permission mode", selection: $model.actionPermission) { ForEach(ActionPermission.allCases) { value in Text(value.label).tag(value) } }.pickerStyle(.radioGroup)
                            Divider()
                            Toggle(isOn: $model.precisionMode) { VStack(alignment: .leading, spacing: 2) { Text("High-precision reasoning").font(.system(size: 12, weight: .semibold)); Text("Use the deeper reasoning model for unusually dense pages.").font(.system(size: 10)).foregroundStyle(asterSecondary) } }
                            Text("Aster✱ never takes over graded work. Desmos, Manim, scratch work, and typing previews remain learner-controlled and reversible where possible.").font(.system(size: 10)).foregroundStyle(asterSecondary)
                        }
                    }
                    settingsSection("USAGE & BUDGET", "Live spend remains under your OpenAI account.") {
                        VStack(spacing: 14) {
                            HStack(spacing: 12) { usageMetric("\(model.sessionRequestCount)", "Requests this session"); usageMetric(model.sessionUsage.inputTokens.formatted(), "Input tokens"); usageMetric(model.sessionUsage.outputTokens.formatted(), "Output tokens") }
                            HStack { Text("Aster✱ does not guess dollar cost because model pricing can change.").font(.system(size: 10)).foregroundStyle(asterSecondary); Spacer(); Button("View live spend ↗") { model.openUsageDashboard() }; Button("Manage budget ↗") { model.openBudgetSettings() } }.buttonStyle(.link)
                        }
                    }
                    settingsSection("PRIVACY & MEMORY", "Local evidence, visible controls.") {
                        VStack(spacing: 14) {
                            PermissionRow(icon: "rectangle.dashed.badge.record", title: "Screen Recording", detail: "Required for selected-region teaching.", state: model.screenPermission, required: true) { model.screenPermission == .denied ? model.openScreenPermissionSettings() : model.requestScreenPermission() }
                            Divider()
                            PermissionRow(icon: "waveform", title: "Microphone + Speech Recognition", detail: "Optional voice questions and wake phrase.", state: settingsVoicePermissionState, required: false) { settingsVoicePermissionState == .denied ? model.openVoicePermissionSettings() : model.requestVoicePermissions() }
                            Divider()
                            HStack { VStack(alignment: .leading, spacing: 3) { Text("Learner memory").font(.system(size: 12, weight: .semibold)); Text("\(model.learnerProfile.concepts.count) concepts · \(model.learnerProfile.totalChecks) understanding checks · stored locally").font(.system(size: 10)).foregroundStyle(asterSecondary) }; Spacer(); Button("Reset learner memory", role: .destructive) { confirmReset = true }.buttonStyle(.bordered) }
                        }
                    }
                    Text("Aster✱ · Native spatial tutoring for macOS").font(.system(size: 9, design: .monospaced)).foregroundStyle(asterSecondary).frame(maxWidth: .infinity).padding(.top, 4)
                }.padding(32)
            }
        }
        .frame(minWidth: 720, minHeight: 720)
        .alert("Reset learner memory?", isPresented: $confirmReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset memory", role: .destructive) { model.resetLearnerMemory() }
        } message: { Text("This permanently deletes Aster✱’s local mastery evidence, shaky areas, review schedule, and learning preferences. Your API key is not affected.") }
    }

    private func settingsSection<Content: View>(_ kicker: String, _ subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) { Text(kicker).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.1).foregroundStyle(asterSignal); Text(subtitle).font(.system(size: 10)).foregroundStyle(asterSecondary); Spacer() }
            AsterCard { content() }
        }
    }

    private func usageMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(value).font(.system(size: 20, weight: .semibold, design: .rounded)); Text(label).font(.system(size: 9)).foregroundStyle(asterSecondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(asterSurface.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
    }

    private var settingsVoicePermissionState: PermissionState {
        if model.microphonePermission == .denied || model.speechPermission == .denied { return .denied }
        if model.microphonePermission == .granted && model.speechPermission == .granted { return .granted }
        return .notDetermined
    }
}

struct DiagnosticChoiceCard: View {
    let diagnostic: DiagnosticPlan
    let choose: (DiagnosticOption) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack { Label("DIAGNOSE FIRST", systemImage: "scope"); Spacer(); Text(diagnostic.conceptTitle).foregroundStyle(asterSecondary) }.font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(asterSignal)
            Text(diagnostic.question).font(.system(size: 12, weight: .semibold))
            ForEach(diagnostic.options) { option in Button { choose(option) } label: { HStack { Text(option.label); Spacer(); Image(systemName: "arrow.right") }.padding(.horizontal, 11).padding(.vertical, 9).background(asterSurface, in: RoundedRectangle(cornerRadius: 10)).contentShape(Rectangle()) }.buttonStyle(.plain).font(.system(size: 10, weight: .medium)) }
        }.padding(13).background(asterSignal.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            if message.role == .learner { Spacer(minLength: 46) }
            VStack(alignment: .leading, spacing: 6) {
                if let metadata { Label(metadata.0, systemImage: metadata.1).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(metadata.2) }
                Text(message.text).font(.system(size: 12)).lineSpacing(3).foregroundStyle(message.role == .learner ? Color.white : asterInk).textSelection(.enabled)
            }.padding(.horizontal, 13).padding(.vertical, 11).background(background, in: RoundedRectangle(cornerRadius: 15))
            if message.role == .aster { Spacer(minLength: 28) }
        }
    }

    private var metadata: (String, String, Color)? {
        switch message.kind {
        case .insight: return ("KEEP", "bookmark.fill", asterSignal)
        case .check: return ("YOUR TURN", "arrow.turn.down.right", .green)
        case .diagnostic: return ("DIAGNOSIS", "scope", asterSignal)
        case .assessment: return ("UNDERSTANDING", "checkmark.seal.fill", .green)
        case .memory: return ("REMEMBERED", "brain.head.profile", asterSignal)
        case .tool: return ("TEACHING TOOL", "play.rectangle.fill", asterSignal)
        case .message: return nil
        }
    }

    private var background: Color {
        if message.role == .learner { return Color(nsColor: .labelColor) }
        switch message.kind {
        case .insight, .diagnostic: return asterSignal.opacity(0.09)
        case .check, .assessment: return asterMint.opacity(0.22)
        case .memory: return Color.blue.opacity(0.08)
        case .tool: return Color.orange.opacity(0.10)
        case .message: return asterSurface
        }
    }
}
