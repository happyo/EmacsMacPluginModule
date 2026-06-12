//
//  Created by belyenochi on 2026/06/12.
//
//  Live Markdown preview rendered as a WKWebView pinned to the right edge of
//  the Emacs window's content view.
//
//  Emacs streams the current buffer's markdown text into Swift; we render it
//  to HTML with Down (cmark-gfm) and push it into the web view. Refreshes go
//  through `evaluateJavaScript` so the scroll position is preserved instead of
//  reloading the whole page on every keystroke.
//
//  The web view is added as a subview of the Emacs content view (like the
//  cursor layer), pinned to the right edge with an autoresizing mask, so it
//  follows window moves, resizes and native fullscreen automatically with no
//  extra window or observers. Emacs reserves an equally wide blank side window
//  on the right so buffer text never hides underneath the preview. The color
//  theme is an explicit "dark"/"light" choice driven from Emacs.

import AppKit
import WebKit
import Down
import EmacsSwiftModule

final class MarkdownPreviewPlugin: BasePlugin {
    // MARK: - Theme

    enum Theme: String {
        case light
        case dark
    }

    // MARK: - State

    private var webView: WKWebView?
    private weak var hostView: NSView?
    /// True once the shell HTML (CSS + empty body) has finished loading and it
    /// is safe to push content via JavaScript.
    private var shellLoaded = false
    /// Latest markdown awaiting render — set while the shell is still loading,
    /// flushed in `webView(_:didFinish:)`.
    private var pendingMarkdown: String?
    private var theme: Theme = .dark
    /// Width of the preview pane in points.
    private var preferredWidth: CGFloat = 600
    private var navigationDelegate: PreviewNavigationDelegate?

    // MARK: - Function registration

    public override func initFunctions(_ env: Environment) throws {
        try env.defun(
            "swift-markdown-preview-open",
            with: "Open (or focus) the live Markdown preview pane and render MARKDOWN."
        ) { (env: Environment, markdown: String) in
            self.openPreview(markdown: markdown)
        }

        try env.defun(
            "swift-markdown-preview-update",
            with: "Render MARKDOWN into the existing preview, preserving scroll position."
        ) { (env: Environment, markdown: String) in
            self.updateMarkdown(markdown)
        }

        try env.defun(
            "swift-markdown-preview-close",
            with: "Close the Markdown preview pane and release its resources."
        ) { (env: Environment) in
            self.closePreview()
        }

        try env.defun(
            "swift-markdown-preview-set-width",
            with: "Set the preview pane width in points."
        ) { (env: Environment, width: Double) in
            self.preferredWidth = CGFloat(max(200, width))
            self.layoutWebView()
        }

        try env.defun(
            "swift-markdown-preview-set-theme",
            with: "Set the preview color theme: \"light\" or \"dark\"."
        ) { (env: Environment, themeName: String) in
            self.setTheme(Theme(rawValue: themeName) ?? .dark)
        }

        try env.defun(
            "swift-markdown-preview-scroll",
            with: "Scroll the preview to FRACTION (0.0–1.0) of the document height."
        ) { (env: Environment, fraction: Double) in
            self.scroll(toFraction: fraction)
        }
    }

    // MARK: - Public actions (always hop to main thread)

    private func openPreview(markdown: String) {
        runOnMain {
            self.ensureWebView()
            self.layoutWebView()
            self.render(markdown: markdown)
        }
    }

    private func updateMarkdown(_ markdown: String) {
        runOnMain {
            // No web view yet means the user never opened a preview; ignore.
            guard self.webView != nil else { return }
            self.render(markdown: markdown)
        }
    }

    private func closePreview() {
        runOnMain {
            self.webView?.removeFromSuperview()
            self.webView = nil
            self.hostView = nil
            self.navigationDelegate = nil
            self.shellLoaded = false
            self.pendingMarkdown = nil
        }
    }

    private func setTheme(_ theme: Theme) {
        runOnMain {
            self.theme = theme
            // Rebuild the shell so the CSS variables update; re-render the
            // current content once it reloads.
            guard let webView = self.webView else { return }
            self.shellLoaded = false
            webView.loadHTMLString(self.shellHTML(), baseURL: nil)
        }
    }

    /// Scroll the preview to a fraction (0–1) of its scrollable height, so it
    /// roughly follows the position the user is viewing on the Emacs side.
    private func scroll(toFraction fraction: Double) {
        runOnMain {
            guard let webView = self.webView, self.shellLoaded else { return }
            let f = min(max(fraction, 0), 1)
            let js = """
            (function () {
              var max = document.documentElement.scrollHeight - window.innerHeight;
              window.scrollTo({ top: max * \(f), behavior: 'smooth' });
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    // MARK: - View lifecycle

    private func ensureWebView() {
        guard let contentView = NSApp.mainWindow?.contentView
                ?? NSApp.windows.first(where: { $0.isVisible })?.contentView else {
            return
        }

        // Already attached to the current content view.
        if let webView = webView, hostView === contentView, webView.superview === contentView {
            return
        }

        webView?.removeFromSuperview()

        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        let delegate = PreviewNavigationDelegate(plugin: self)
        webView.navigationDelegate = delegate
        // Pin to the right edge, full height: flexible left margin + flexible
        // height keep it docked right and filling vertically as Emacs resizes
        // or enters fullscreen.
        webView.autoresizingMask = [.minXMargin, .height]
        // Rounded corners so the pane reads as a distinct floating panel.
        webView.wantsLayer = true
        webView.layer?.cornerRadius = 12
        webView.layer?.masksToBounds = true
        contentView.addSubview(webView)

        self.webView = webView
        self.hostView = contentView
        self.navigationDelegate = delegate

        shellLoaded = false
        webView.loadHTMLString(shellHTML(), baseURL: nil)
    }

    /// Pin the web view to the right edge of the content view, full height.
    private func layoutWebView() {
        guard let webView = webView, let host = hostView else { return }
        let bounds = host.bounds
        webView.frame = NSRect(
            x: bounds.width - preferredWidth,
            y: 0,
            width: preferredWidth,
            height: bounds.height
        )
    }

    // MARK: - Rendering

    private func render(markdown: String) {
        let html = renderHTMLBody(from: markdown)

        guard let webView = webView else { return }
        guard shellLoaded else {
            // Shell still loading; remember the latest markdown and flush later.
            pendingMarkdown = markdown
            return
        }

        let escaped = jsStringLiteral(html)
        webView.evaluateJavaScript("window.__setContent(\(escaped));", completionHandler: nil)
    }

    /// Convert markdown to an HTML fragment with Down. On failure, fall back to
    /// showing the raw text so the user still sees something.
    private func renderHTMLBody(from markdown: String) -> String {
        let down = Down(markdownString: markdown)
        let options: DownOptions = [.safe, .smart]
        if let html = try? down.toHTML(options) {
            return html
        }
        return "<pre>\(htmlEscape(markdown))</pre>"
    }

    // MARK: - Shell HTML / CSS

    /// The shell page: theme CSS plus a `__setContent` hook that swaps the
    /// article body while keeping the current scroll offset.
    private func shellHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: \(theme == .dark ? "dark" : "light"); }
        \(css(for: theme))
        </style>
        </head>
        <body>
        <article id="content" class="markdown-body"></article>
        <script>
        window.__setContent = function (html) {
          var x = window.scrollX, y = window.scrollY;
          document.getElementById('content').innerHTML = html;
          window.scrollTo(x, y);
        };
        </script>
        </body>
        </html>
        """
    }

    /// GitHub-style markdown CSS in either the light or dark palette.
    private func css(for theme: Theme) -> String {
        let vars: String
        switch theme {
        case .light:
            vars = """
            --fg: #1f2328;
            --bg: #ffffff;
            --muted: #59636e;
            --border: #d1d9e0;
            --code-bg: #f6f8fa;
            --link: #0969da;
            """
        case .dark:
            vars = """
            --fg: #e6edf3;
            --bg: #0d1117;
            --muted: #8d96a0;
            --border: #30363d;
            --code-bg: #161b22;
            --link: #4493f8;
            """
        }

        return """
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
          font-size: 15px;
          line-height: 1.6;
          margin: 0;
          padding: 20px 24px;
          \(vars)
          color: var(--fg);
          background: var(--bg);
          -webkit-font-smoothing: antialiased;
        }
        .markdown-body { max-width: 100%; }
        h1, h2, h3, h4, h5, h6 { font-weight: 600; line-height: 1.25; margin: 24px 0 16px; }
        h1 { font-size: 1.9em; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
        h2 { font-size: 1.5em; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
        h3 { font-size: 1.25em; }
        p { margin: 0 0 16px; }
        a { color: var(--link); text-decoration: none; }
        a:hover { text-decoration: underline; }
        code {
          font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace;
          font-size: 85%;
          background: var(--code-bg);
          padding: .2em .4em;
          border-radius: 6px;
        }
        pre {
          background: var(--code-bg);
          padding: 16px;
          border-radius: 6px;
          overflow: auto;
        }
        pre code { background: none; padding: 0; font-size: 85%; }
        blockquote {
          margin: 0 0 16px;
          padding: 0 1em;
          color: var(--muted);
          border-left: .25em solid var(--border);
        }
        table { border-collapse: collapse; margin: 0 0 16px; display: block; overflow: auto; }
        th, td { border: 1px solid var(--border); padding: 6px 13px; }
        th { font-weight: 600; background: var(--code-bg); }
        tr:nth-child(2n) { background: var(--code-bg); }
        img { max-width: 100%; }
        hr { height: 1px; border: none; background: var(--border); margin: 24px 0; }
        ul, ol { margin: 0 0 16px; padding-left: 2em; }
        li { margin: .25em 0; }
        li.task-list-item { list-style: none; }
        li.task-list-item input { margin: 0 .5em .25em -1.4em; }
        ::-webkit-scrollbar { width: 10px; height: 10px; }
        ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 5px; }
        ::-webkit-scrollbar-track { background: transparent; }
        """
    }

    // MARK: - Helpers

    fileprivate func shellDidLoad() {
        shellLoaded = true
        if let pending = pendingMarkdown {
            pendingMarkdown = nil
            render(markdown: pending)
        }
    }

    /// Escape a string for safe embedding in an HTML text node.
    private func htmlEscape(_ s: String) -> String {
        var out = s
        out = out.replacingOccurrences(of: "&", with: "&amp;")
        out = out.replacingOccurrences(of: "<", with: "&lt;")
        out = out.replacingOccurrences(of: ">", with: "&gt;")
        return out
    }

    /// Encode a Swift string as a JavaScript string literal (including quotes)
    /// via JSONSerialization, which handles quotes, backslashes, newlines and
    /// control characters correctly.
    private func jsStringLiteral(_ s: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: [s], options: []),
           let json = String(data: data, encoding: .utf8) {
            // json looks like ["...escaped..."]; strip the array brackets.
            let trimmed = json.dropFirst().dropLast()
            return String(trimmed)
        }
        return "\"\""
    }

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

// MARK: - Navigation delegate

/// Marks the shell as loaded once the initial HTML finishes, and opens any
/// clicked links in the user's default browser instead of navigating the
/// preview away from its shell.
private final class PreviewNavigationDelegate: NSObject, WKNavigationDelegate {
    private weak var plugin: MarkdownPreviewPlugin?

    init(plugin: MarkdownPreviewPlugin) {
        self.plugin = plugin
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        plugin?.shellDidLoad()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
