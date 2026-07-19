import AppKit
import AVKit
import Foundation
import WebKit

@MainActor
final class ToolActionService {
    private var desmosWindow: NSWindow?
    private var previewWindow: NSWindow?
    private var scratchWindow: NSWindow?
    private var undoStack: [() -> Void] = []
    var onAction: ((TutorActionRecord) -> Void)?

    func openDesmos(payload: ToolPayload) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 980, height: 680), configuration: configuration)
        webView.loadHTMLString(Self.desmosHTML(payload: payload), baseURL: URL(string: "https://www.desmos.com"))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Aster · Desmos teaching sandbox"
        window.contentView = webView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        desmosWindow = window
        record(kind: "desmos", summary: "Opened reversible Desmos sandbox") { [weak window] in window?.close() }
    }

    func showManimPreview(movie: URL, template: String, caption: String, onNarration: @escaping (String) -> Void) {
        let player = AVPlayer(url: movie)
        let playerView = AVPlayerView(frame: NSRect(x: 0, y: 0, width: 920, height: 560))
        playerView.player = player
        playerView.controlsStyle = .floating
        let window = NSWindow(
            contentRect: playerView.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Aster animation preview · \(caption)"
        window.contentView = playerView
        window.center()
        window.makeKeyAndOrderFront(nil)
        previewWindow = window
        player.play()
        let cues = Self.narrationCues(template: template, caption: caption)
        for (index, cue) in cues.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 2.2) { [weak window] in
                if window?.isVisible == true { onNarration(cue) }
            }
        }
        record(kind: "manim", summary: "Played bounded Manim preview") { [weak window] in window?.close() }
    }

    private static func narrationCues(template: String, caption: String) -> [String] {
        let stage: String
        switch template {
        case "circuit": stage = "Now follow the conserved flow as it splits between the branches."
        case "field": stage = "Watch how the local arrows determine the path through the field."
        case "geometry": stage = "The shape moves, but the structural relationship remains invariant."
        case "wave": stage = "Track one phase point: the pattern travels while its shape repeats."
        case "molecule": stage = "Focus on the bonds first, then on the molecule’s overall orientation."
        case "limit": stage = "The approaching values agree even though the highlighted point is missing."
        case "matrix": stage = "Compare the basis directions before and after the transformation."
        case "vector": stage = "The dashed components reconstruct the same resultant vector."
        default: stage = "As the two points meet, the secant becomes the local tangent."
        }
        return [caption, stage]
    }

    func openScratchpad(text: String) {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 680, height: 460))
        let editor = NSTextView(frame: scroll.bounds)
        editor.string = text
        editor.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        editor.textContainerInset = NSSize(width: 24, height: 24)
        scroll.documentView = editor
        scroll.hasVerticalScroller = true
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Aster · reversible scratch work"
        window.contentView = scroll
        window.center(); window.makeKeyAndOrderFront(nil)
        scratchWindow = window
        record(kind: "scratchpad", summary: "Created editable local scratch work") { [weak window] in window?.close() }
    }

    func openZoomableContext(jpeg: Data) {
        guard let image = NSImage(data: jpeg) else { return }
        let imageView = NSImageView(frame: NSRect(origin: .zero, size: image.size))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 900, height: 620))
        scroll.documentView = imageView
        scroll.allowsMagnification = true
        scroll.minMagnification = 0.5
        scroll.maxMagnification = 5
        scroll.magnification = 1
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Aster · zoomable context sandbox"
        window.contentView = scroll
        window.center(); window.makeKeyAndOrderFront(nil)
        record(kind: "zoom", summary: "Opened a zoomable local crop") { [weak window] in window?.close() }
    }

    func previewTyping(_ text: String, targetApp: String) {
        let alert = NSAlert()
        alert.messageText = "Preview for \(targetApp.isEmpty ? "another app" : targetApp)"
        alert.informativeText = String(text.prefix(500))
        alert.addButton(withTitle: "Copy for me to paste")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let previous = NSPasteboard.general.string(forType: .string)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(String(text.prefix(500)), forType: .string)
            record(kind: "typing-preview", summary: "Copied approved preview; did not type automatically") {
                NSPasteboard.general.clearContents()
                if let previous { NSPasteboard.general.setString(previous, forType: .string) }
            }
        }
    }

    func undoLast() {
        undoStack.popLast()?()
        onAction?(TutorActionRecord(id: UUID(), date: Date(), kind: "undo", summary: "Undid the last Aster action", reversible: false))
    }

    private func record(kind: String, summary: String, undo: @escaping () -> Void) {
        undoStack.append(undo)
        onAction?(TutorActionRecord(id: UUID(), date: Date(), kind: kind, summary: summary, reversible: true))
    }

    func renderManim(payload: ToolPayload, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let executable = Self.manimExecutable else {
            completion(.failure(ToolActionError.manimNotInstalled))
            return
        }

        do {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Aster/Manim/\(UUID().uuidString)", isDirectory: true)
            let media = base.appendingPathComponent("media", isDirectory: true)
            let script = base.appendingPathComponent("aster_scene.py")
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            try Self.manimSource(template: payload.manimTemplate, caption: payload.conceptCaption)
                .write(to: script, atomically: true, encoding: .utf8)

            let process = Process()
            process.executableURL = executable
            process.arguments = ["-ql", "--disable_caching", "--media_dir", media.path, script.path, "AsterScene"]
            process.currentDirectoryURL = base
            let errorPipe = Pipe()
            process.standardError = errorPipe
            process.standardOutput = Pipe()
            process.terminationHandler = { process in
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: errorData, encoding: .utf8) ?? ""
                let movie = Self.firstMovie(in: media)
                Task { @MainActor in
                    if process.terminationStatus == 0, let movie {
                        completion(.success(movie))
                    } else {
                        completion(.failure(ToolActionError.renderFailed(errorText)))
                    }
                }
            }
            try process.run()
            DispatchQueue.global().asyncAfter(deadline: .now() + 30) {
                if process.isRunning { process.terminate() }
            }
        } catch {
            completion(.failure(error))
        }
    }

    private static var manimExecutable: URL? {
        let candidates = [
            "/opt/homebrew/bin/manim",
            "/usr/local/bin/manim",
            "/usr/bin/manim"
        ]
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map(URL.init(fileURLWithPath:))
    }

    nonisolated private static func firstMovie(in directory: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { return nil }
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "mp4" { return url }
        return nil
    }

    private static func jsonString(_ value: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: value)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }

    private static func desmosHTML(payload: ToolPayload) -> String {
        let primary = jsonString(payload.primaryExpression.isEmpty ? "y=(x-2)^2+3" : payload.primaryExpression)
        let comparison = jsonString(payload.comparisonExpression.isEmpty ? "y=x^2" : payload.comparisonExpression)
        let caption = jsonString(payload.conceptCaption.isEmpty ? "Compare one change at a time." : payload.conceptCaption)
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
        *{box-sizing:border-box}body{margin:0;background:#f4f3ec;color:#101114;font-family:-apple-system,BlinkMacSystemFont,sans-serif}
        header{height:72px;display:flex;align-items:center;gap:14px;padding:0 24px;border-bottom:1px solid #d9d6cd;background:#faf9f4}
        .mark{width:36px;height:36px;color:#ef5b35}.mark svg{width:100%;height:100%;display:block}.mark .ray{stroke:currentColor;stroke-width:3.1;stroke-linecap:round}.mark .cursor,.mark circle{fill:currentColor}
        h1{margin:0;font-size:16px}p{margin:3px 0 0;color:#6e6e68;font-size:12px}.badge{margin-left:auto;padding:8px 11px;border-radius:9px;background:#ffe3da;color:#a9341d;font-size:10px;font-weight:700}
        #calculator{width:100%;height:calc(100vh - 72px)}
        </style>
        <script src="https://www.desmos.com/api/v1.11/calculator.js?apiKey=desmos"></script></head>
        <body><header><div class="mark"><svg viewBox="0 0 32 32"><path class="cursor" d="M3 3L6.2 15.2L9 11.9L14.2 17.1L16.7 14.6L11.5 9.4L15.2 6.3Z"/><path class="ray" d="M23 13L29 7M23 23L29 28M18 24L18 30M13 19L3 19"/><circle cx="18" cy="19" r="2.8"/></svg></div><div><h1>Aster demonstration sandbox</h1><p id="caption"></p></div><div class="badge">LEARNER-CONTROLLED</div></header><div id="calculator"></div>
        <script>
        document.getElementById('caption').textContent=\(caption);
        const calculator=Desmos.GraphingCalculator(document.getElementById('calculator'),{expressions:true,settingsMenu:false,zoomButtons:true});
        calculator.setExpression({id:'comparison',latex:\(comparison),color:'#777777',lineOpacity:0.55});
        calculator.setExpression({id:'lesson',latex:\(primary),color:'#ef5b35',lineWidth:4});
        calculator.setExpression({id:'h',latex:'h=2',sliderBounds:{min:-5,max:5,step:1}});
        calculator.setExpression({id:'k',latex:'k=3',sliderBounds:{min:-5,max:5,step:1}});
        </script></body></html>
        """
    }

    private static func manimSource(template: String, caption: String) -> String {
        let safeCaption = caption
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
        let body: String
        switch template {
        case "vector":
            body = """
                plane = NumberPlane()
                vector = Arrow(ORIGIN, [3, 2, 0], buff=0, color="#EF5B35")
                components = VGroup(DashedLine(ORIGIN, [3,0,0], color=GREEN), DashedLine([3,0,0], [3,2,0], color=GREEN))
                self.play(Create(plane), GrowArrow(vector))
                self.play(Create(components))
            """
        case "matrix":
            body = """
                plane = NumberPlane()
                square = Square(side_length=2, color="#EF5B35").set_fill("#EF5B35", opacity=.15)
                self.play(Create(plane), Create(square))
                self.play(square.animate.apply_matrix([[1.5, .7], [.2, 1]]), run_time=2)
            """
        case "circuit":
            body = """
                left = Dot(LEFT*3, color="#EF5B35"); node = Dot(ORIGIN, color=CORAL); top = Dot(RIGHT*3+UP, color=GREEN); bottom = Dot(RIGHT*3+DOWN, color=GREEN)
                wires = VGroup(Line(left,node), Line(node,top), Line(node,bottom))
                self.play(Create(wires), FadeIn(left,node,top,bottom))
                for target in [top,bottom]: self.play(MoveAlongPath(Dot(color=YELLOW), VGroup(Line(left,node),Line(node,target))), run_time=1.2)
            """
        case "limit":
            body = """
                axes = Axes(x_range=[-3,3,1], y_range=[-1,5,1])
                graph = axes.plot(lambda x: (x*x-1)/(x-1) if abs(x-1)>.05 else 2, discontinuities=[1], color="#EF5B35")
                hole = Circle(radius=.09, color=YELLOW).move_to(axes.c2p(1,2))
                self.play(Create(axes), Create(graph), Create(hole))
                self.play(Indicate(hole), run_time=2)
            """
        case "field":
            body = """
                field = ArrowVectorField(lambda p: np.array([-p[1], p[0], 0]), x_range=[-4,4,1], y_range=[-2,2,1])
                dot = Dot([2,0,0], color=YELLOW)
                self.play(Create(field), FadeIn(dot))
                self.play(Rotate(dot, angle=TAU, about_point=ORIGIN), run_time=4)
            """
        case "geometry":
            body = """
                triangle = Triangle(color="#EF5B35").scale(2)
                altitude = DashedLine(triangle.get_top(), triangle.get_bottom(), color=GREEN)
                self.play(Create(triangle)); self.play(Create(altitude)); self.play(triangle.animate.rotate(PI/5), run_time=2)
            """
        case "wave":
            body = """
                axes = Axes(x_range=[-5,5,1], y_range=[-2,2,1])
                phase = ValueTracker(0)
                wave = always_redraw(lambda: axes.plot(lambda x: np.sin(x-phase.get_value()), color="#EF5B35"))
                self.play(Create(axes), Create(wave)); self.play(phase.animate.set_value(TAU), run_time=4, rate_func=linear)
            """
        case "molecule":
            body = """
                atoms = VGroup(Circle(.45,color=BLUE), Circle(.32,color=WHITE).shift(LEFT*.8+DOWN*.5), Circle(.32,color=WHITE).shift(RIGHT*.8+DOWN*.5))
                bonds = VGroup(Line(LEFT*.55+DOWN*.3, ORIGIN), Line(RIGHT*.55+DOWN*.3, ORIGIN))
                self.play(Create(bonds), FadeIn(atoms)); self.play(atoms.animate.rotate(TAU), run_time=3)
            """
        default:
            body = """
                axes = Axes(x_range=[-3,3,1], y_range=[-1,9,1])
                graph = axes.plot(lambda x: x*x, color="#EF5B35")
                point = ValueTracker(2.4)
                secant = always_redraw(lambda: axes.get_secant_slope_group(point.get_value(), graph, dx=.7, secant_line_color=GREEN))
                self.play(Create(axes), Create(graph), Create(secant))
                self.play(point.animate.set_value(.3), run_time=3)
            """
        }
        return """
        from manim import *
        class AsterScene(Scene):
            def construct(self):
                caption = Text("\(safeCaption)", font_size=26).to_edge(UP)
                self.play(Write(caption))
        \(body)
                self.wait(1)
        """
    }
}

enum ToolActionError: LocalizedError {
    case manimNotInstalled
    case renderFailed(String)

    var errorDescription: String? {
        switch self {
        case .manimNotInstalled:
            return "Manim is not installed. Install the local Manim CLI to render this template; Aster never runs model-authored Python."
        case .renderFailed(let detail):
            return "The Manim preview could not render. \(detail.prefix(180))"
        }
    }
}
