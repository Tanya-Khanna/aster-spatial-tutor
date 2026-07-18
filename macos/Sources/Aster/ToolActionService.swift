import AppKit
import Foundation
import WebKit

@MainActor
final class ToolActionService {
    private var desmosWindow: NSWindow?

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
        .mark{width:34px;height:34px;display:grid;place-items:center;border-radius:11px;background:#7650fa;color:white;font-size:20px}
        h1{margin:0;font-size:16px}p{margin:3px 0 0;color:#6e6e68;font-size:12px}.badge{margin-left:auto;padding:8px 11px;border-radius:9px;background:#e9e5fb;color:#5932dd;font-size:10px;font-weight:700}
        #calculator{width:100%;height:calc(100vh - 72px)}
        </style>
        <script src="https://www.desmos.com/api/v1.11/calculator.js?apiKey=desmos"></script></head>
        <body><header><div class="mark">✦</div><div><h1>Aster demonstration sandbox</h1><p id="caption"></p></div><div class="badge">LEARNER-CONTROLLED</div></header><div id="calculator"></div>
        <script>
        document.getElementById('caption').textContent=\(caption);
        const calculator=Desmos.GraphingCalculator(document.getElementById('calculator'),{expressions:true,settingsMenu:false,zoomButtons:true});
        calculator.setExpression({id:'comparison',latex:\(comparison),color:'#777777',lineOpacity:0.55});
        calculator.setExpression({id:'lesson',latex:\(primary),color:'#7650fa',lineWidth:4});
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
                vector = Arrow(ORIGIN, [3, 2, 0], buff=0, color=PURPLE)
                components = VGroup(DashedLine(ORIGIN, [3,0,0], color=GREEN), DashedLine([3,0,0], [3,2,0], color=GREEN))
                self.play(Create(plane), GrowArrow(vector))
                self.play(Create(components))
            """
        case "matrix":
            body = """
                plane = NumberPlane()
                square = Square(side_length=2, color=PURPLE).set_fill(PURPLE, opacity=.15)
                self.play(Create(plane), Create(square))
                self.play(square.animate.apply_matrix([[1.5, .7], [.2, 1]]), run_time=2)
            """
        case "circuit":
            body = """
                left = Dot(LEFT*3, color=PURPLE); node = Dot(ORIGIN, color=CORAL); top = Dot(RIGHT*3+UP, color=GREEN); bottom = Dot(RIGHT*3+DOWN, color=GREEN)
                wires = VGroup(Line(left,node), Line(node,top), Line(node,bottom))
                self.play(Create(wires), FadeIn(left,node,top,bottom))
                for target in [top,bottom]: self.play(MoveAlongPath(Dot(color=YELLOW), VGroup(Line(left,node),Line(node,target))), run_time=1.2)
            """
        default:
            body = """
                axes = Axes(x_range=[-3,3,1], y_range=[-1,9,1])
                graph = axes.plot(lambda x: x*x, color=PURPLE)
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
