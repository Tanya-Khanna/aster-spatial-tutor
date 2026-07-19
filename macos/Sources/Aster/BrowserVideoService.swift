import AppKit

/// A deliberately narrow bridge for the active HTML5 video in Safari or Chrome.
/// It never navigates, clicks ads, submits forms, or controls unrelated apps.
final class BrowserVideoService {
    private let separator = "\u{241E}"

    func snapshot(appName: String = "") -> VideoContext? {
        guard let result = run(javaScript: """
        (() => {
          const v = document.querySelector('video');
          if (!v) return '';
          const captions = [...document.querySelectorAll('.ytp-caption-segment,[class*=caption]')]
            .map(x => x.innerText).filter(Boolean).slice(-4).join(' ');
          return [document.title, v.currentTime, v.paused ? '1' : '0', captions].join('\(separator)');
        })()
        """, appName: appName) else { return nil }
        let values = result.components(separatedBy: separator)
        guard values.count >= 4 else { return nil }
        return VideoContext(
            sourceTitle: values[0],
            currentTime: Double(values[1]) ?? 0,
            isPaused: values[2] == "1",
            captions: String(values[3].prefix(1_200))
        )
    }

    @discardableResult
    func pause(appName: String = "") -> Bool {
        run(javaScript: "const v=document.querySelector('video'); if(v){v.pause(); 'paused'}else{''}", appName: appName) == "paused"
    }

    @discardableResult
    func resume(appName: String = "") -> Bool {
        run(javaScript: "const v=document.querySelector('video'); if(v){v.play(); 'playing'}else{''}", appName: appName) == "playing"
    }

    private func run(javaScript: String, appName: String) -> String? {
        let app = NSWorkspace.shared.frontmostApplication
        let escaped = javaScript
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
        let source: String
        let identifier = appName.isEmpty ? app?.bundleIdentifier ?? "" : appName.lowercased()
        switch identifier {
        case "com.apple.Safari", "safari":
            source = "tell application \"Safari\" to do JavaScript \"\(escaped)\" in current tab of front window"
        case "com.google.Chrome", "com.google.Chrome.canary", "google chrome", "chrome":
            source = "tell application \"Google Chrome\" to execute active tab of front window javascript \"\(escaped)\""
        default:
            return nil
        }
        var error: NSDictionary?
        let output = NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return output?.stringValue
    }
}
