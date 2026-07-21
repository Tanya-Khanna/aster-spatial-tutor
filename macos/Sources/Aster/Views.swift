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
    @State private var previewStep = 0

    var body: some View {
        ZStack {
            asterCanvas.ignoresSafeArea()
            Circle().fill(asterSignal.opacity(0.12)).frame(width: 680, height: 680).blur(radius: 80).offset(x: 470, y: -320)
            Circle().fill(asterMint.opacity(0.08)).frame(width: 520, height: 520).blur(radius: 90).offset(x: -460, y: 350)
            if model.requiresApplicationRelocation {
                relocationGuard
            } else {
                VStack(spacing: 0) {
                    appHeader
                    if model.isOnboardingComplete {
                        home
                    } else {
                        onboarding
                    }
                }
            }
        }
        .frame(minWidth: 1_040, minHeight: 720)
    }

    private var relocationGuard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                AsterMark(size: 31)
                Text("Aster✱").font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer()
                Label("SETUP REQUIRED", systemImage: "lock.shield.fill")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(asterSignal)
            }
            .padding(.horizontal, 34).padding(.vertical, 20)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) { Divider() }

            VStack(spacing: 28) {
                ZStack {
                    Circle().fill(asterSignal.opacity(0.12)).frame(width: 140, height: 140)
                    RoundedRectangle(cornerRadius: 24)
                        .fill(asterSurface)
                        .frame(width: 92, height: 92)
                        .overlay(Image(systemName: "folder.fill").font(.system(size: 46, weight: .medium)).foregroundStyle(asterSignal))
                        .shadow(color: asterSignal.opacity(0.16), radius: 24, y: 10)
                    AsterMark(size: 34).offset(x: 50, y: 47)
                }

                VStack(spacing: 12) {
                    Text("Aster✱ needs a permanent home.")
                        .font(.system(size: 43, weight: .medium, design: .rounded)).tracking(-1.4)
                    Text("macOS can run downloaded apps from a temporary, randomized location. Screen & System Audio Recording cannot reliably attach to that copy, so Aster✱ must live in Applications before setup begins.")
                        .font(.system(size: 16)).foregroundStyle(asterSecondary)
                        .multilineTextAlignment(.center).lineSpacing(4).frame(maxWidth: 690)
                }

                AsterCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("ONE SAFE COPY", systemImage: "checkmark.shield.fill")
                            .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(asterSignal)
                        Text(model.relocationStatus.isInApplications
                             ? "Aster✱ is already in Applications, but macOS quarantine is still attached. Finish setup to clear it and relaunch this same copy."
                             : "Aster✱ will copy itself to /Applications, clear the download quarantine, reopen from its stable location, and close this temporary copy.")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(asterSecondary).lineSpacing(3)
                        if let message = model.relocationErrorMessage {
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(asterSignal)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Button {
                            model.moveToApplicationsAndRelaunch()
                        } label: {
                            HStack {
                                if model.isRelocatingApplication { ProgressView().controlSize(.small) }
                                Text(model.isRelocatingApplication
                                     ? "Moving Aster✱…"
                                     : model.relocationStatus.isInApplications
                                        ? "Finish Setup & Relaunch"
                                        : "Move to Applications & Relaunch")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .padding(.horizontal, 6).frame(height: 38)
                        }
                        .buttonStyle(.borderedProminent).tint(asterSignal).controlSize(.large)
                        .disabled(model.isRelocatingApplication)
                    }
                }
                .frame(maxWidth: 690)

                HStack(spacing: 8) {
                    Text("Prefer to do it yourself? Drag Aster✱ to your Applications folder, then reopen it.")
                    Button("Show Applications") { model.revealApplicationsFolder() }
                        .buttonStyle(.plain).foregroundStyle(asterSignal).fontWeight(.semibold)
                }
                .font(.system(size: 12)).foregroundStyle(asterSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(48)
        }
    }

    private var appHeader: some View {
        HStack(spacing: 11) {
            AsterMark(size: 31)
            Text("Aster✱").font(.system(size: 20, weight: .semibold, design: .rounded))
            Spacer()
            ConnectionPill(status: model.apiKeyStatus)
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
                case .permissions:
                    ScrollView {
                        HStack(alignment: .top) {
                            Spacer(minLength: 0)
                            permissionsStep
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                    }
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
        HStack(spacing: 12) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                HStack(spacing: 9) {
                    Circle()
                        .fill(step.rawValue <= model.onboardingStep.rawValue ? asterSignal : asterLine)
                        .frame(width: 10, height: 10)
                    Text(["Meet Aster✱", "Permissions", "Connect", "Ready"][step.rawValue])
                        .font(.system(size: 13, weight: step == model.onboardingStep ? .semibold : .medium))
                        .foregroundStyle(step == model.onboardingStep ? asterInk : asterSecondary)
                }
                if step != .ready { Rectangle().fill(asterLine).frame(width: 46, height: 1) }
            }
        }
        .padding(.vertical, 22)
    }

    private var introductionStep: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= 1_260
            HStack(alignment: .center, spacing: isWide ? 68 : 36) {
                introductionCopy(isWide: isWide)
                presencePreview(isWide: isWide)
            }
            .frame(maxWidth: isWide ? 1_440 : .infinity, maxHeight: .infinity)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func introductionCopy(isWide: Bool) -> some View {
        VStack(alignment: .leading, spacing: isWide ? 28 : 22) {
                Text("POINT TO IT. LEARN IT IN PLACE.")
                    .font(.system(size: isWide ? 14 : 12, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(asterSignal)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Your screen becomes the")
                        .font(.system(size: isWide ? 54 : 40, weight: .medium, design: .rounded)).tracking(-1.7)
                    Text("whiteboard.")
                        .font(.system(size: isWide ? 66 : 50, weight: .medium, design: .rounded)).italic().tracking(-1.8)
                        .foregroundStyle(asterSignal)
                        .overlay(alignment: .bottom) {
                            Capsule().fill(asterSignal.opacity(0.52)).frame(height: 4).offset(y: 5)
                        }
                }
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(3)
                Text("Press Option–Space and Aster✱ appears as a slim bar above your work. Ask about the whole screen, point to one thing, draw a region, or loop it freehand—then Aster✱ diagnoses first and teaches in place.")
                    .font(.system(size: isWide ? 18 : 16)).foregroundStyle(asterSecondary).lineSpacing(isWide ? 6 : 4).frame(maxWidth: isWide ? 560 : 440, alignment: .leading)
                HStack(spacing: 14) {
                    feature("viewfinder", "See", "Whole, point, box, or loop")
                    feature("pencil.and.outline", "Teach", "Voice + spatial marks")
                    feature("brain.head.profile", "Adapt", "Local mastery memory")
                }
            }
            .frame(width: isWide ? 600 : 410, alignment: .leading)
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(asterSignal)
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(detail).font(.system(size: 11)).foregroundStyle(asterSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func presencePreview(isWide: Bool) -> some View {
        AsterCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 7) {
                    Circle().fill(.red.opacity(0.8)).frame(width: 8, height: 8)
                    Circle().fill(.yellow.opacity(0.8)).frame(width: 8, height: 8)
                    Circle().fill(.green.opacity(0.8)).frame(width: 8, height: 8)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(previewStep == 1 ? asterSignal : asterSecondary).frame(width: 6, height: 6)
                        Text(previewStep == 0 ? "ASTER✱ IS DIAGNOSING" : previewStep == 1 ? "ASTER✱ IS TEACHING" : "YOUR TURN")
                    }
                    .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(previewStep == 1 ? asterSignal : asterSecondary)
                }

                Text("Why divide attention by √dₖ?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(asterSecondary)

                HStack(spacing: 5) {
                    Text("softmax(").font(.system(size: 22, design: .serif))
                    VStack(spacing: 3) {
                        Text("QKᵀ").font(.system(size: 20, design: .serif))
                        Rectangle().fill(asterInk).frame(width: 55, height: 1)
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(asterSignal.opacity(previewStep == 1 ? 0.16 : 0.04))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(asterSignal.opacity(previewStep == 1 ? 0.9 : 0), lineWidth: 2))
                                .frame(width: 65, height: 34)
                            Text("√dₖ").font(.system(size: 20, design: .serif))
                        }
                    }
                    Text(")V").font(.system(size: 22, design: .serif))
                    Spacer()
                    AsterMark(size: previewStep == 1 ? 34 : 25)
                        .opacity(previewStep == 1 ? 1 : 0.55)
                        .rotationEffect(.degrees(previewStep == 1 ? -8 : 0))
                }
                .frame(maxWidth: .infinity)

                Group {
                    if previewStep == 0 {
                        lessonPreviewCard("DIAGNOSE", "What feels unclear—the dimensions, the square root, or what scaling changes?", "scope")
                    } else if previewStep == 1 {
                        lessonPreviewCard("TEACH", "This term keeps larger dot products from making softmax overconfident.", "waveform")
                    } else {
                        lessonPreviewCard("CHECK", "If dₖ grows, what happens before we divide by √dₖ?", "arrow.turn.down.right")
                    }
                }
                .id(previewStep)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))

                HStack {
                    Label("Voice + marks, synchronized", systemImage: "speaker.wave.2.fill")
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule().fill(index == previewStep ? asterSignal : asterLine).frame(width: index == previewStep ? 18 : 6, height: 6)
                        }
                    }
                }
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(asterSecondary)
            }
            .padding(20)
            .background(asterSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 15))
            .frame(width: isWide ? 560 : 440, height: isWide ? 430 : 370)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_400_000_000)
                guard !Task.isCancelled else { break }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                    previewStep = (previewStep + 1) % 3
                }
            }
        }
    }

    private func lessonPreviewCard(_ label: String, _ text: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                Circle().fill(asterSignal.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(asterSignal)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(asterSignal)
                Text(text).font(.system(size: 12, weight: .medium)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(asterCanvas.opacity(0.76), in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(asterLine.opacity(0.65), lineWidth: 1))
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Permission, with purpose.").font(.system(size: 42, weight: .medium, design: .rounded)).tracking(-1.5)
            Text("Aster✱ asks only for capabilities a spatial tutor needs. Screen & System Audio Recording is required. Voice remains optional.")
                .font(.system(size: 16)).foregroundStyle(asterSecondary).frame(maxWidth: 680, alignment: .leading)
            AsterCard {
                VStack(spacing: 0) {
                    PermissionRow(icon: "rectangle.dashed.badge.record", title: "Screen & System Audio Recording", detail: "Required for the whole-screen, point, region, and freehand-loop views you explicitly choose.", state: model.screenPermission, required: true) {
                        model.requestScreenPermission()
                    }
                    Divider().padding(.vertical, 4)
                    PermissionRow(icon: "waveform", title: "Microphone + Speech Recognition", detail: "Optional. Enables questions and follow-ups by voice.", state: voicePermissionState, required: false) {
                        voicePermissionState == .denied ? model.openVoicePermissionSettings() : model.requestVoicePermissions()
                    }
                }
            }
            .frame(maxWidth: 760)
            if model.screenPermission == .denied {
                ScreenPermissionRecovery(model: model).frame(maxWidth: 760)
            }
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
            Text("Press Option–Space anywhere. Aster✱ stays above your work with Whole Screen, Point, Region, and Freehand Loop modes. Ask by text or voice; nothing is sent until you do.")
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
        GeometryReader { geometry in
            let isWide = geometry.size.width >= 1_360
            HStack(spacing: isWide ? 80 : 42) {
                VStack(alignment: .leading, spacing: isWide ? 31 : 25) {
                Text("READY WHEN YOU ARE").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(asterSignal)
                Text("Point to the question.\nKeep your place.")
                    .font(.system(size: isWide ? 64 : 52, weight: .medium, design: .rounded)).tracking(-2)
                Text("Aster✱ opens as a movable bar above your work, watches the view you choose locally, and teaches with synchronized voice and drawing only after you ask.")
                    .font(.system(size: isWide ? 19 : 17)).foregroundStyle(asterSecondary).lineSpacing(5).frame(maxWidth: isWide ? 580 : 480, alignment: .leading)
                Button { model.activateFromHotKey() } label: {
                    HStack(spacing: 11) { Image(systemName: "sparkle.magnifyingglass"); Text("Ask Aster✱"); Spacer(); Text("⌥ SPACE").font(.system(size: 10, weight: .bold, design: .monospaced)).opacity(0.72) }
                        .padding(.horizontal, 18).frame(width: 280, height: 52)
                }
                .buttonStyle(.borderedProminent).tint(asterSignal).controlSize(.large)
                Button { model.showSettings() } label: { Label("Settings", systemImage: "gearshape") }
                    .buttonStyle(.bordered)
            }
            .frame(width: isWide ? 620 : nil, alignment: .leading)
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    MetricCard(value: "\(model.learnerProfile.concepts.count)", label: "Concepts remembered", icon: "brain.head.profile")
                    MetricCard(value: "\(model.learnerProfile.dueReviews.count)", label: "Reviews ready", icon: "calendar.badge.clock")
                }
                AsterCard {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Text("THE LEARNING LOOP").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(asterSignal); Spacer(); ConnectionPill(status: model.apiKeyStatus) }
                        ForEach(Array([("1", "See", "The whole screen, point, box, or loop"), ("2", "Diagnose", "One question before explaining"), ("3", "Teach", "Voice, drawing, and notebook together"), ("4", "Check", "A prediction before moving on")]), id: \.0) { item in
                            HStack(spacing: 13) { Text(item.0).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(asterSignal).frame(width: 24, height: 24).background(asterSignal.opacity(0.1), in: Circle()); VStack(alignment: .leading, spacing: 2) { Text(item.1).font(.system(size: 13, weight: .semibold)); Text(item.2).font(.system(size: 11)).foregroundStyle(asterSecondary) }; Spacer() }
                        }
                    }
                }
            }
            .frame(width: isWide ? 540 : 430)
            }
            .frame(maxWidth: isWide ? 1_440 : .infinity, maxHeight: .infinity)
            .frame(width: geometry.size.width, height: geometry.size.height)
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
                Button(state == .denied ? "Request again" : "Allow") { action() }.buttonStyle(.bordered).controlSize(.small)
            }
        }.padding(.vertical, 8)
    }
}

private struct ScreenPermissionRecovery: View {
    @ObservedObject var model: TutorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill").foregroundStyle(asterSignal)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.screenPermissionRecoveryMessage == nil ? "Access still not detected?" : "Aster✱ checked again — access is still missing.")
                        .font(.system(size: 12, weight: .semibold))
                    VStack(alignment: .leading, spacing: 5) {
                        recoveryStep(1, "Choose Request again above.")
                        recoveryStep(2, "If Aster✱ is still absent, open Privacy & Security → Screen & System Audio Recording.")
                        recoveryStep(3, "Remove old Aster entries, click +, and choose /Applications/Aster.app.")
                        recoveryStep(4, "Turn it on, return here, and check again; restart if macOS asks.")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(2)
                }
            }
            HStack(spacing: 8) {
                Label(model.isRunningFromApplications ? "Running from Applications" : "Not running from Applications", systemImage: model.isRunningFromApplications ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(model.isRunningFromApplications ? Color.green : asterSignal)
                Spacer()
                Button("Open System Settings") { model.openScreenPermissionSettings() }
                Button("Show this copy") { model.revealRunningApplication() }
            }
            .buttonStyle(.bordered).controlSize(.small)
            HStack(spacing: 8) {
                Spacer()
                Button("I granted access — Check again") { model.checkScreenPermissionAfterGrant() }
                Button("Restart Aster✱") { model.restartApplication() }.buttonStyle(.borderedProminent).tint(asterSignal)
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(13)
        .background(asterSignal.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(asterSignal.opacity(0.20), lineWidth: 1))
    }

    private func recoveryStep(_ number: Int, _ instruction: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(number).")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(asterSignal)
                .frame(width: 15, alignment: .trailing)
            Text(instruction)
                .font(.system(size: 10))
                .foregroundStyle(asterSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
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

    var body: some View {
        TutorBarView(model: model)
    }
}

private struct TutorBarView: View {
    @ObservedObject var model: TutorModel
    @State private var surface = "Transcript"
    @State private var pulse = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            composer
            if model.isPanelExpanded {
                Divider().opacity(0.6)
                drawer.transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(.ultraThickMaterial)
        .background(asterCanvas.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(asterLine.opacity(0.75), lineWidth: 1))
        .shadow(color: .black.opacity(0.24), radius: 26, y: 12)
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: model.isPanelExpanded)
        .onAppear { pulse = true }
        .onReceive(NotificationCenter.default.publisher(for: .asterFocusComposer)) { _ in
            composerFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(asterSecondary.opacity(0.65))
                .help("Drag the bar to move Aster✱")
            ZStack {
                AsterMark(size: 27)
                if model.phase != .ready && model.phase != .following {
                    Circle().stroke(asterSignal.opacity(0.32), lineWidth: 1.5)
                        .frame(width: 38, height: 38)
                        .scaleEffect(pulse ? 1.16 : 0.88)
                        .opacity(pulse ? 0 : 1)
                        .animation(.easeOut(duration: 1.1).repeatForever(autoreverses: false), value: pulse)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Aster✱").font(.system(size: 14, weight: .semibold, design: .rounded))
                HStack(spacing: 5) {
                    Circle().fill(model.isFollowing ? asterMint : asterSecondary).frame(width: 6, height: 6)
                    Text(privacyStatus)
                }
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(privacyStatus.hasPrefix("LOCAL") ? asterSecondary : asterSignal)
            }

            HStack(spacing: 5) {
                ForEach(ContextMode.allCases) { mode in
                    Button { model.setContextMode(mode) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode.systemImage)
                            Text(mode.label)
                        }
                        .font(.system(size: 10, weight: model.contextMode == mode ? .semibold : .medium))
                        .foregroundStyle(model.contextMode == mode ? Color.white : asterInk)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(model.contextMode == mode ? asterSignal : asterSurface.opacity(0.82), in: Capsule())
                        .overlay(Capsule().stroke(model.contextMode == mode ? Color.clear : asterLine.opacity(0.7), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help(mode.guidance)
                }
            }

            Spacer(minLength: 8)
            if model.isVideoMode {
                Label("LIVE FRAMES", systemImage: "play.rectangle.fill")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(asterSignal)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(asterSignal.opacity(0.10), in: Capsule())
            }
            Button { model.showSettings() } label: { Image(systemName: "gearshape") }.help("Settings")
            Button { model.setPanelExpanded(!model.isPanelExpanded) } label: {
                Image(systemName: model.isPanelExpanded ? "chevron.up" : "chevron.down")
            }.help(model.isPanelExpanded ? "Collapse lesson" : "Open transcript and lesson")
            Button { model.closePanel() } label: { Image(systemName: "xmark") }.help("Close Aster✱")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 15).padding(.top, 10).padding(.bottom, 7)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            Button { model.toggleListening() } label: {
                Image(systemName: model.isListening ? "waveform" : "mic.slash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(model.isListening ? asterSignal : asterSecondary)
                    .frame(width: 36, height: 36)
                    .background(model.isListening ? asterSignal.opacity(0.12) : asterSurface, in: Circle())
            }
            .help(model.isListening ? "Mute voice input" : "Listen for a spoken question")
            TextField(composerPlaceholder, text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .focused($composerFocused)
                .onSubmit { model.submit() }
            Text(model.isListening ? "Listening… pause briefly to send" : model.contextMode.guidance)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(model.isListening ? asterSignal : asterSecondary)
                .lineLimit(1)
            Button { model.submit() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 31, height: 31).background(asterSignal, in: Circle())
            }
            .disabled(model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.contextTarget == nil)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(asterSurface.opacity(0.88), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(asterLine.opacity(0.75), lineWidth: 1))
        .padding(.horizontal, 15).padding(.bottom, 10)
    }

    private var drawer: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                phaseRail
                Spacer()
                Text(model.anchorStatus).lineLimit(1)
                    .font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(asterSecondary)
                Picker("Surface", selection: $surface) {
                    Text("Transcript").tag("Transcript")
                    Text("Notebook").tag("Notebook")
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 188)
                Image(systemName: "tortoise").foregroundStyle(asterSecondary)
                Slider(value: $model.narrationRate, in: 0.34...0.62).frame(width: 120)
                Image(systemName: "hare").foregroundStyle(asterSecondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(asterSurface.opacity(0.34))

            if case .error(let message) = model.phase {
                errorCard(message).padding(.horizontal, 14).padding(.top, 10)
            }

            HStack(alignment: .top, spacing: 14) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 9) {
                            ForEach(visibleMessages) { message in MessageBubble(message: message).id(message.id) }
                        }
                        .padding(.bottom, 12)
                    }
                    .onChange(of: model.messages.count) { _ in
                        if let id = visibleMessages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 10) {
                    if let diagnostic = model.diagnostic {
                        DiagnosticChoiceCard(diagnostic: diagnostic) { model.chooseDiagnostic($0) }
                    }
                    teachingControls
                    if let lesson = model.lastLesson, lesson.toolSuggestion != "none" {
                        Button { model.runSuggestedTool() } label: {
                            HStack {
                                Image(systemName: lesson.toolSuggestion == "desmos" ? "function" : "play.rectangle")
                                Text(lesson.toolSuggestion == "desmos" ? "Open Desmos sandbox" : "Animate with Manim")
                                Spacer()
                                Text("Preview →").foregroundStyle(asterSignal)
                            }
                        }
                        .buttonStyle(.plain).font(.system(size: 10, weight: .semibold))
                        .padding(10).background(asterSignal.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 330, alignment: .topLeading)
            }
            .padding(14)
        }
    }

    private var privacyStatus: String {
        switch model.phase {
        case .ready, .following, .selectingContext, .listening: return "LOCAL ONLY · NOTHING SENT"
        default: return "SENT FOR THIS QUESTION"
        }
    }

    private var composerPlaceholder: String {
        if model.phase == .awaitingUnderstanding { return "Answer Aster✱’s understanding check…" }
        switch model.contextMode {
        case .wholeScreen: return "Ask anything about what’s visible…"
        case .point: return "Point at it, then ask…"
        case .region: return "Ask about the boxed region…"
        case .freehandLoop: return "Ask about what you looped…"
        }
    }

    private var visibleMessages: [ChatMessage] {
        surface == "Notebook"
            ? model.messages.filter { [.insight, .check, .assessment, .memory].contains($0.kind) }
            : model.messages
    }

    private var phaseRail: some View {
        HStack(spacing: 5) {
            ForEach([("See", 0), ("Diagnose", 1), ("Teach", 2), ("Check", 3)], id: \.0) { item in
                HStack(spacing: 5) {
                    Circle().fill(phaseIndex >= item.1 ? asterSignal : asterLine).frame(width: 6, height: 6)
                    Text(item.0)
                }
                .font(.system(size: 8, weight: phaseIndex == item.1 ? .bold : .medium, design: .monospaced))
                .foregroundStyle(phaseIndex == item.1 ? asterInk : asterSecondary)
                if item.1 < 3 { Rectangle().fill(asterLine).frame(width: 20, height: 1) }
            }
        }
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

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 5) {
                Text("Aster✱ needs attention").font(.system(size: 11, weight: .semibold))
                Text(message).font(.system(size: 10)).foregroundStyle(asterSecondary)
                HStack {
                    if message.localizedCaseInsensitiveContains("Screen & System Audio Recording") {
                        Button("Fix permission") { model.showSettings(.permissions) }
                    }
                    Button("Dismiss") { model.recoverFromError() }
                }.buttonStyle(.link)
            }
            Spacer()
        }
        .padding(10).background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private var teachingControls: some View {
        if model.phase == .teaching, let lesson = model.lastLesson {
            HStack {
                Button { model.previousStep() } label: { Image(systemName: "chevron.left") }.disabled(model.lessonStepIndex == 0)
                Text("Step \(model.lessonStepIndex + 1) of \(lesson.steps.count)")
                Button { model.replayCurrentStep() } label: { Label("Replay", systemImage: "arrow.counterclockwise") }
                Spacer()
                Button("Next →") { model.nextStep() }
            }
            .buttonStyle(.plain).font(.system(size: 10, weight: .semibold)).foregroundStyle(asterSecondary)
        }
        if model.phase == .awaitingUnderstanding {
            HStack(spacing: 7) {
                Button("Simpler") { model.requestReteach("more simply") }
                Button("Follow-up") { model.askFollowUpInstead() }
                Button("Challenge me") { model.increaseDifficulty() }
            }.buttonStyle(.bordered).controlSize(.small)
        }
        if let assessment = model.lastAssessment, !assessment.correct {
            HStack(spacing: 7) {
                Button("Explain more simply") { model.requestReteach("more simply") }
                Button("Use an analogy") { model.requestReteach("with a concrete analogy") }
            }.buttonStyle(.bordered).controlSize(.small)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: TutorModel
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            asterCanvas.ignoresSafeArea()
            VStack(spacing: 0) {
                settingsHeader
                Divider()
                ScrollView {
                    paneContent
                        .frame(maxWidth: 740, alignment: .topLeading)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 28)
                }
            }
        }
        .frame(width: 820, height: 620)
        .alert("Reset learner memory?", isPresented: $confirmReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset memory", role: .destructive) { model.resetLearnerMemory() }
        } message: { Text("This permanently deletes Aster✱’s local mastery evidence, shaky areas, review schedule, and learning preferences. Your API key is not affected.") }
    }

    private var settingsHeader: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(asterSignal.opacity(0.10)).frame(width: 46, height: 46)
                Image(systemName: model.settingsPane.systemImage).font(.system(size: 20, weight: .semibold)).foregroundStyle(asterSignal)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(model.settingsPane.title).font(.system(size: 23, weight: .semibold, design: .rounded))
                Text(model.settingsPane.subtitle).font(.system(size: 11)).foregroundStyle(asterSecondary)
            }
            Spacer()
            if model.settingsPane == .account { ConnectionPill(status: model.apiKeyStatus) }
        }
        .padding(.horizontal, 32).padding(.vertical, 20)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder private var paneContent: some View {
        switch model.settingsPane {
        case .general:
            VStack(alignment: .leading, spacing: 22) {
                settingsSection("ACTIVATION", "Available anywhere on your Mac.") {
                    VStack(spacing: 15) {
                        HStack {
                            Label("Ask Aster✱", systemImage: "viewfinder").font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text("⌥ SPACE").font(.system(size: 10, weight: .bold, design: .monospaced)).padding(.horizontal, 10).padding(.vertical, 7).background(asterSurface, in: RoundedRectangle(cornerRadius: 8))
                        }
                        Divider()
                        Toggle(isOn: $model.precisionMode) {
                            settingLabel("High-precision reasoning", "Use deeper reasoning for unusually dense pages.")
                        }
                    }
                }
                settingsSection("AGENT ACTIONS", "Bounded, visible, and permissioned.") {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Permission mode", selection: $model.actionPermission) {
                            ForEach(ActionPermission.allCases) { value in Text(value.label).tag(value) }
                        }
                        .pickerStyle(.radioGroup)
                        Divider()
                        Label("Aster✱ never takes over graded work. Desmos, Manim, scratch work, and typing previews stay learner-controlled and reversible where possible.", systemImage: "hand.raised.fill")
                            .font(.system(size: 10)).foregroundStyle(asterSecondary)
                    }
                }
            }
        case .voice:
            VStack(alignment: .leading, spacing: 22) {
                settingsSection("NARRATION", "Make every explanation comfortable.") {
                    HStack(spacing: 12) {
                        Label("Narration speed", systemImage: "speaker.wave.2.fill").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Image(systemName: "tortoise")
                        Slider(value: $model.narrationRate, in: 0.34...0.62).frame(width: 260)
                        Image(systemName: "hare")
                    }
                }
                settingsSection("CONVERSATION", "Voice remains optional and learner-controlled.") {
                    VStack(spacing: 16) {
                        Toggle(isOn: $model.listenOnOpen) { settingLabel("Listen when Aster✱ opens", "Start listening immediately; typing always remains available.") }
                        Divider()
                        Toggle(isOn: $model.autoSendVoice) { settingLabel("Send after a short pause", "Aster✱ submits your spoken question after about one second of silence.") }
                        Divider()
                        Toggle(isOn: $model.conversationMode) { settingLabel("Conversational follow-ups", "Listen again after each understanding check.") }
                        Divider()
                        Toggle(isOn: $model.wakePhraseEnabled) { settingLabel("“Hey Aster” wake phrase", "Optional continuous on-device wake listening.") }
                        HStack(spacing: 9) {
                            Circle()
                                .fill(model.wakeListeningState.isListening ? Color.green : asterSecondary.opacity(0.7))
                                .frame(width: 7, height: 7)
                            Text(model.wakeListeningState.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(asterSecondary)
                            Spacer()
                            Button("Test “Hey Aster”") { model.testWakePhrase() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }
        case .permissions:
            VStack(alignment: .leading, spacing: 22) {
                settingsSection("SCREEN", "Required only for the context you choose.") {
                    VStack(spacing: 14) {
                        PermissionRow(icon: "rectangle.dashed.badge.record", title: "Screen & System Audio Recording", detail: "Required for Whole Screen, Point, Region, and Freehand Loop context.", state: model.screenPermission, required: true) {
                            model.requestScreenPermission()
                        }
                        if model.screenPermission == .denied { ScreenPermissionRecovery(model: model) }
                    }
                }
                settingsSection("VOICE INPUT", "Optional for spoken questions and follow-ups.") {
                    PermissionRow(icon: "waveform", title: "Microphone + Speech Recognition", detail: "Used only when you choose voice conversation.", state: settingsVoicePermissionState, required: false) {
                        settingsVoicePermissionState == .denied ? model.openVoicePermissionSettings() : model.requestVoicePermissions()
                    }
                }
                Label("Selected context stays local until you ask. Aster✱ excludes its own windows from capture.", systemImage: "lock.shield.fill")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(asterSecondary)
            }
        case .learning:
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    usageMetric("\(model.learnerProfile.concepts.count)", "Concepts remembered")
                    usageMetric("\(model.learnerProfile.totalChecks)", "Understanding checks")
                    usageMetric("\(model.learnerProfile.dueReviews.count)", "Reviews ready")
                }
                settingsSection("LEARNER MEMORY", "Compact evidence stored only on this Mac.") {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Aster✱ remembers demonstrated strengths, shaky areas, review timing, and the next teaching strategy—not screenshots.", systemImage: "brain.head.profile")
                            .font(.system(size: 11)).foregroundStyle(asterSecondary)
                        Divider()
                        HStack {
                            settingLabel("Start learning history over", "Deletes local mastery evidence and teaching preferences.")
                            Spacer()
                            Button("Reset learner memory", role: .destructive) { confirmReset = true }.buttonStyle(.bordered)
                        }
                    }
                }
            }
        case .account:
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    settingsHeading("OPENAI", "Your key belongs to you.")
                    APIKeyCard(model: model, allowsRemoval: true)
                }
                settingsSection("USAGE & BUDGET", "Live spend remains under your OpenAI account.") {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            usageMetric("\(model.sessionRequestCount)", "Requests this session")
                            usageMetric(model.sessionUsage.inputTokens.formatted(), "Input tokens")
                            usageMetric(model.sessionUsage.outputTokens.formatted(), "Output tokens")
                        }
                        HStack {
                            Text("Aster✱ does not estimate dollar cost because model pricing can change.").font(.system(size: 10)).foregroundStyle(asterSecondary)
                            Spacer()
                            Button("View live spend ↗") { model.openUsageDashboard() }
                            Button("Manage budget ↗") { model.openBudgetSettings() }
                        }.buttonStyle(.link)
                    }
                }
            }
        }
    }

    private func settingLabel(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 12, weight: .semibold))
            Text(detail).font(.system(size: 10)).foregroundStyle(asterSecondary)
        }
    }

    private func settingsSection<Content: View>(_ kicker: String, _ subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            settingsHeading(kicker, subtitle)
            AsterCard { content() }
        }
    }

    private func settingsHeading(_ kicker: String, _ subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(kicker).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.1).foregroundStyle(asterSignal)
            Text(subtitle).font(.system(size: 10)).foregroundStyle(asterSecondary)
            Spacer()
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
