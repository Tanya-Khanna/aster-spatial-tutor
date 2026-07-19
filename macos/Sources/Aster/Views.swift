import SwiftUI

private let ink = Color(red: 0.055, green: 0.06, blue: 0.07)
private let canvas = Color(red: 0.965, green: 0.963, blue: 0.945)
private let violet = Color(red: 0.47, green: 0.31, blue: 0.98)
private let mint = Color(red: 0.55, green: 0.94, blue: 0.75)

struct AsterMark: View {
    var size: CGFloat = 28
    var body: some View {
        ZStack {
            Circle().fill(ink)
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct WelcomeView: View {
    @ObservedObject var model: TutorModel
    @State private var selectedDemo = "paper"

    var body: some View {
        ZStack {
            canvas.ignoresSafeArea()
            RadialGradient(colors: [violet.opacity(0.18), .clear], center: .topTrailing, startRadius: 0, endRadius: 560)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header
                HStack(spacing: 46) {
                    introduction
                    interactivePreview
                }
                .padding(.horizontal, 54)
                .padding(.top, 36)
                .padding(.bottom, 42)
            }
        }
        .frame(minWidth: 980, minHeight: 680)
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                AsterMark(size: 30)
                Text("Aster").font(.system(size: 20, weight: .semibold, design: .rounded))
            }
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(Color.green).frame(width: 7, height: 7)
                Text(model.apiKey.isEmpty ? "Demo mode" : "GPT-5.6 connected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 13).padding(.vertical, 8)
            .background(.white.opacity(0.72), in: Capsule())
        }
        .padding(.horizontal, 34).padding(.vertical, 22)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("YOUR SCREEN,\nNOW A WHITEBOARD.")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(violet)
            Text("Understand anything\nright where it lives.")
                .font(.system(size: 50, weight: .medium, design: .rounded))
                .tracking(-2.5)
                .foregroundStyle(ink)
            Text("Point at an equation, research figure, or anatomy diagram. Aster sees your screen, teaches by voice, and draws the explanation in place.")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .frame(maxWidth: 410, alignment: .leading)

            Button {
                model.runDemo(selectedDemo)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "option")
                    Text("Try Aster")
                    Text("Space").font(.system(size: 12, weight: .semibold, design: .monospaced)).opacity(0.6)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22).padding(.vertical, 14)
                .background(ink, in: Capsule())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 9) {
                Text("OPENAI API KEY").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(.secondary)
                HStack {
                    SecureField("sk-…  Leave empty for demo mode", text: $model.apiKey)
                        .textFieldStyle(.plain)
                    Button("Save") { model.saveAPIKey() }
                        .buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(violet)
                }
                .padding(12)
                .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 13))
                Text("Stored in your Mac Keychain. Aster stops API requests at $5.")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: 410)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var interactivePreview: some View {
        VStack(spacing: 16) {
            HStack {
                ForEach([("paper", "Research"), ("graph", "Math"), ("anatomy", "Anatomy")], id: \.0) { item in
                    Button(item.1) { selectedDemo = item.0 }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: selectedDemo == item.0 ? .semibold : .regular))
                        .padding(.horizontal, 13).padding(.vertical, 8)
                        .background(selectedDemo == item.0 ? ink : Color.clear, in: Capsule())
                        .foregroundStyle(selectedDemo == item.0 ? .white : .secondary)
                }
            }
            .padding(5).background(.white.opacity(0.72), in: Capsule())

            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 28)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.09), radius: 30, y: 18)
                VStack(alignment: .leading, spacing: 19) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle().fill(Color.red.opacity(0.8)).frame(width: 8, height: 8)
                            Circle().fill(Color.yellow.opacity(0.8)).frame(width: 8, height: 8)
                            Circle().fill(Color.green.opacity(0.8)).frame(width: 8, height: 8)
                        }
                        Spacer()
                        Text(selectedDemo == "anatomy" ? "Atlas · Respiratory system" : "Paper · Visual reasoning")
                            .font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                    }
                    Divider().opacity(0.5)
                    previewContent
                    Spacer()
                }
                .padding(24)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 7) { AsterMark(size: 20); Text("Aster noticed").font(.system(size: 11, weight: .semibold)) }
                    Text(selectedDemo == "anatomy" ? "The membrane is thin for a reason." : "This term controls the direction of change.")
                        .font(.system(size: 12, weight: .medium)).lineLimit(2)
                    Text("Show me →").font(.system(size: 11, weight: .semibold)).foregroundStyle(violet)
                }
                .padding(14).frame(width: 185, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 17))
                .padding(18)
            }
            .frame(width: 430, height: 470)
        }
    }

    @ViewBuilder private var previewContent: some View {
        if selectedDemo == "anatomy" {
            VStack(alignment: .leading, spacing: 18) {
                Text("ALVEOLAR GAS EXCHANGE").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1)
                ZStack {
                    Capsule().fill(Color.blue.opacity(0.08)).frame(height: 115)
                    HStack(spacing: 2) {
                        Circle().fill(Color.blue.opacity(0.3)).frame(width: 80, height: 80)
                        RoundedRectangle(cornerRadius: 8).fill(mint.opacity(0.6)).frame(width: 22, height: 112)
                        Circle().fill(Color.red.opacity(0.22)).frame(width: 110, height: 110)
                    }
                    Image(systemName: "arrow.right").font(.system(size: 28, weight: .bold)).foregroundStyle(violet)
                }
                Text("Diffusion rate ∝ surface area × concentration gradient / membrane thickness")
                    .font(.system(size: 16, weight: .medium, design: .serif)).lineSpacing(5)
            }
        } else {
            VStack(alignment: .leading, spacing: 17) {
                Text(selectedDemo == "graph" ? "FUNCTION TRANSFORMATIONS" : "EQUATION 4 · DYNAMICAL SYSTEM").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1)
                Text(selectedDemo == "graph" ? "y = (x − h)² + k" : "∂p(x,t) / ∂t = −∇ · J(x,t)")
                    .font(.system(size: 29, weight: .regular, design: .serif))
                    .padding(.vertical, 14)
                Text(selectedDemo == "graph" ? "The parameters h and k translate the parent function without changing its curvature." : "The continuity equation states that probability is locally conserved. The divergence term describes net flow from a region.")
                    .font(.system(size: 13, design: .serif)).foregroundStyle(.secondary).lineSpacing(6)
                HStack(spacing: 18) {
                    ForEach(0..<3) { index in
                        RoundedRectangle(cornerRadius: 10).fill(index == 1 ? violet.opacity(0.18) : Color.black.opacity(0.05)).frame(height: 70)
                    }
                }
            }
        }
    }
}

struct TutorPanelView: View {
    @ObservedObject var model: TutorModel
    @State private var pulse = false
    @State private var transcriptExpanded = true

    var body: some View {
        ZStack {
            canvas.opacity(0.97).ignoresSafeArea()
            VStack(spacing: 0) {
                panelHeader
                contextBar
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 11) {
                            ForEach(Array(transcriptExpanded ? model.messages[...] : model.messages.suffix(3))) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: model.messages.count) { _ in
                        if let id = model.messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                    }
                }
                if let diagnostic = model.diagnostic {
                    DiagnosticChoiceCard(diagnostic: diagnostic) { model.chooseDiagnostic($0) }
                        .padding(.horizontal, 13)
                        .padding(.bottom, 8)
                }
                composer
            }
        }
        .frame(width: 390, height: 620)
        .preferredColorScheme(.light)
    }

    private var panelHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                AsterMark(size: 29)
                if model.phase != .ready {
                    Circle().stroke(violet.opacity(0.4), lineWidth: 2).frame(width: 38, height: 38).scaleEffect(pulse ? 1.15 : 0.9).opacity(pulse ? 0 : 1)
                        .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: pulse)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Aster").font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(model.phase.label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }
            Spacer()
            if let lesson = model.lastLesson, let concept = model.learnerProfile.memory(for: lesson.conceptID) {
                Text("\(Int(concept.mastery * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(violet)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(violet.opacity(0.1), in: Capsule())
                    .help("Persistent mastery for \(concept.title)")
            }
            Button { model.precisionMode.toggle() } label: {
                Image(systemName: model.precisionMode ? "scope" : "leaf")
            }
            .help(model.precisionMode ? "Precision mode" : "Budget mode")
            Button { model.closePanel() } label: { Image(systemName: "xmark") }
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .padding(.horizontal, 17).padding(.vertical, 15)
        .background(.white.opacity(0.72))
        .onAppear { pulse = true }
    }

    private var contextBar: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                Button { model.selectContext() } label: {
                    Label(model.contextRegion == nil ? "Point / select" : "Reselect", systemImage: "viewfinder")
                }
                Button { model.selectCurrentWindow() } label: { Label("Window", systemImage: "macwindow") }
                Button { model.toggleFollowing() } label: {
                    Image(systemName: model.isFollowing ? "dot.radiowaves.left.and.right" : "pause.circle")
                }.help(model.isFollowing ? "Following locally" : "Resume following")
                Button { model.toggleVideoMode() } label: {
                    Image(systemName: model.isVideoMode ? "play.rectangle.fill" : "play.rectangle")
                }.help("Recent-frame video tutoring")
                Spacer()
                Button { transcriptExpanded.toggle() } label: {
                    Image(systemName: transcriptExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                }.help("Collapse synchronized transcript")
            }
            HStack(spacing: 5) {
                Circle().fill(model.isFollowing ? mint : Color.secondary).frame(width: 6, height: 6)
                Text(model.anchorStatus)
                    .lineLimit(1)
                Spacer()
                Text(model.isVideoMode ? "4 FRAMES" : "LOCAL")
            }
            .font(.system(size: 8, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .font(.system(size: 10, weight: .semibold))
        .padding(.horizontal, 15).padding(.vertical, 9)
        .background(ink.opacity(0.035))
    }

    private var composer: some View {
        VStack(spacing: 10) {
            if let lesson = model.lastLesson, lesson.toolSuggestion != "none" {
                Button { model.runSuggestedTool() } label: {
                    HStack {
                        Image(systemName: lesson.toolSuggestion == "desmos" ? "function" : "play.rectangle")
                        Text(lesson.toolSuggestion == "desmos" ? "Show in Desmos sandbox" : "Animate with Manim")
                        Spacer()
                        Text("Preview →").font(.system(size: 10, weight: .bold)).foregroundStyle(violet)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .padding(11).background(violet.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            }
            if model.phase == .teaching, let lesson = model.lastLesson {
                HStack {
                    Button { model.previousStep() } label: { Image(systemName: "chevron.left") }.disabled(model.lessonStepIndex == 0)
                    Text("Step \(model.lessonStepIndex + 1) of \(lesson.steps.count)")
                    Button { model.replayCurrentStep() } label: { Label("Replay", systemImage: "arrow.counterclockwise") }
                    Spacer()
                    Button { model.nextStep() } label: { Text("Next →") }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                HStack(spacing: 7) {
                    Image(systemName: "tortoise")
                    Slider(value: $model.narrationRate, in: 0.34...0.62)
                    Image(systemName: "hare")
                }
                .foregroundStyle(.secondary)
            }
            if model.phase == .awaitingUnderstanding {
                HStack(spacing: 7) {
                    Button("Explain more simply") { model.requestReteach("more simply") }
                    Button("Ask a follow-up") { model.askFollowUpInstead() }
                    Button("Challenge me") { model.increaseDifficulty() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if let assessment = model.lastAssessment, !assessment.correct {
                HStack(spacing: 7) {
                    Button("Explain more simply") { model.requestReteach("more simply") }
                    Button("Use an analogy") { model.requestReteach("with a concrete analogy") }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if let assessment = model.lastAssessment, assessment.correct {
                Button { model.tryTransferProblem() } label: {
                    Label("Try a transfer problem", systemImage: "arrow.up.right")
                }
                .buttonStyle(.borderedProminent)
                .tint(violet)
                .controlSize(.small)
            }
            HStack(spacing: 8) {
                Button { model.practiceShakyAreas() } label: {
                    Label(model.learnerProfile.dueReviews.isEmpty ? "Practice" : "Review due", systemImage: "brain.head.profile")
                }
                Menu {
                    Button("Create reversible scratch work", action: model.createScratchWork)
                    Button("Open zoomable context crop", action: model.openZoomableContext)
                    Button("Preview expression for another app", action: model.previewTyping)
                    Divider()
                    Button("Undo last Aster action", action: model.undoLastAction)
                        .disabled(model.actionHistory.isEmpty)
                    Picker("Action permission", selection: $model.actionPermission) {
                        Text("Ask every time").tag(ActionPermission.askEveryTime)
                        Text("Internal only").tag(ActionPermission.internalOnly)
                        Text("Never").tag(ActionPermission.never)
                    }
                } label: {
                    Label("Agent tools", systemImage: "wand.and.stars")
                }
                Spacer()
                if let last = model.actionHistory.last {
                    Text(last.kind.uppercased()).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 10, weight: .semibold))
            .buttonStyle(.borderless)
            HStack(spacing: 10) {
                Button { model.toggleListening() } label: {
                    Image(systemName: model.isListening ? "stop.fill" : "waveform")
                        .frame(width: 34, height: 34)
                        .background(model.isListening ? Color.red.opacity(0.15) : Color.white, in: Circle())
                }
                TextField(model.phase == .awaitingUnderstanding ? "Answer the mastery check…" : "Ask about the selected context…", text: $model.query, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit { model.submit() }
                Button { model.submit() } label: {
                    Image(systemName: "arrow.up").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 30, height: 30).background(ink, in: Circle())
                }
                .disabled(model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .buttonStyle(.plain)
            .padding(8).background(.white, in: RoundedRectangle(cornerRadius: 17))
            Toggle(isOn: $model.conversationMode) {
                Label("Voice conversation · listen again after each check", systemImage: "waveform.and.mic")
                    .font(.system(size: 9, weight: .medium))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            HStack {
                Text("$\(model.estimatedSpend, specifier: "%.3f") of $5.00")
                Spacer()
                Text("⌥ Space · Context stays on top")
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.tertiary)
        }
        .padding(13).background(.white.opacity(0.45))
    }
}

struct DiagnosticChoiceCard: View {
    let diagnostic: DiagnosticPlan
    let choose: (DiagnosticOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("DIAGNOSE FIRST", systemImage: "scope")
                Spacer()
                Text(diagnostic.conceptTitle).foregroundStyle(.secondary)
            }
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(violet)
            Text(diagnostic.question).font(.system(size: 12, weight: .semibold))
            ForEach(diagnostic.options) { option in
                Button { choose(option) } label: {
                    HStack {
                        Text(option.label)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .padding(.horizontal, 11).padding(.vertical, 9)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
            }
        }
        .padding(13)
        .background(violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            if message.role == .learner { Spacer(minLength: 46) }
            VStack(alignment: .leading, spacing: 6) {
                if message.kind == .insight {
                    Label("KEEP", systemImage: "bookmark.fill").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(violet)
                } else if message.kind == .check {
                    Label("YOUR TURN", systemImage: "arrow.turn.down.right").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Color.green)
                } else if message.kind == .diagnostic {
                    Label("DIAGNOSIS", systemImage: "scope").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(violet)
                } else if message.kind == .assessment {
                    Label("UNDERSTANDING", systemImage: "checkmark.seal.fill").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Color.green)
                } else if message.kind == .memory {
                    Label("REMEMBERED", systemImage: "brain.head.profile").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(violet)
                } else if message.kind == .tool {
                    Label("DEMONSTRATION", systemImage: "play.rectangle.fill").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(violet)
                }
                Text(message.text)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(message.role == .learner ? Color.white : ink)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 13).padding(.vertical, 11)
            .background(background, in: RoundedRectangle(cornerRadius: 16))
            if message.role == .aster { Spacer(minLength: 28) }
        }
    }
    private var background: Color {
        if message.role == .learner { return ink }
        if message.kind == .insight { return violet.opacity(0.1) }
        if message.kind == .check { return mint.opacity(0.34) }
        if message.kind == .diagnostic { return violet.opacity(0.07) }
        if message.kind == .assessment { return mint.opacity(0.28) }
        if message.kind == .memory { return Color.blue.opacity(0.08) }
        if message.kind == .tool { return Color.orange.opacity(0.10) }
        return .white
    }
}
