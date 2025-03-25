import SwiftUI
import WebKit

#if os(macOS)
    typealias PlatformViewRepresentable = NSViewRepresentable
#elseif os(iOS)
    typealias PlatformViewRepresentable = UIViewRepresentable
#endif

#if !os(visionOS)
    @available(macOS 11.0, iOS 14.0, *)
    public struct MarkdownWebView: PlatformViewRepresentable {
        var markdownContent: String
        let customStylesheet: String?
        let linkActivationHandler: ((URL) -> Void)?
        let renderedContentHandler: ((String) -> Void)?
        let enableBenchmarking: Bool

        public init(
            _ markdownContent: String,
            customStylesheet: String? = nil,
            enableBenchmarking: Bool = true
        ) {
            self.markdownContent = markdownContent
            self.customStylesheet = customStylesheet
            self.enableBenchmarking = enableBenchmarking
            linkActivationHandler = nil
            renderedContentHandler = nil
        }

        init(
            _ markdownContent: String,
            customStylesheet: String?,
            linkActivationHandler: ((URL) -> Void)?,
            renderedContentHandler: ((String) -> Void)?,
            enableBenchmarking: Bool
        ) {
            self.markdownContent = markdownContent
            self.customStylesheet = customStylesheet
            self.linkActivationHandler = linkActivationHandler
            self.renderedContentHandler = renderedContentHandler
            self.enableBenchmarking = enableBenchmarking
        }

        public func makeCoordinator() -> Coordinator { .init(parent: self) }

        #if os(macOS)
            public func makeNSView(context: Context) -> CustomWebView {
                context.coordinator.platformView
            }
        #elseif os(iOS)
            public func makeUIView(context: Context) -> CustomWebView {
                context.coordinator.platformView
            }
        #endif

        func updatePlatformView(_ platformView: CustomWebView, context _: Context) {
            guard !platformView.isLoading else { return }
            platformView.updateMarkdownContent(markdownContent)
        }

        #if os(macOS)
            public func updateNSView(_ nsView: CustomWebView, context: Context) {
                updatePlatformView(nsView, context: context)
            }
        #elseif os(iOS)
            public func updateUIView(_ uiView: CustomWebView, context: Context) {
                updatePlatformView(uiView, context: context)
            }
        #endif

        public func onLinkActivation(_ linkActivationHandler: @escaping (URL) -> Void) -> Self {
            .init(
                markdownContent, customStylesheet: customStylesheet,
                linkActivationHandler: linkActivationHandler,
                renderedContentHandler: renderedContentHandler,
                enableBenchmarking: enableBenchmarking)
        }

        public func onRendered(_ renderedContentHandler: @escaping (String) -> Void) -> Self {
            .init(
                markdownContent, customStylesheet: customStylesheet,
                linkActivationHandler: linkActivationHandler,
                renderedContentHandler: renderedContentHandler,
                enableBenchmarking: enableBenchmarking)
        }

        public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
            let parent: MarkdownWebView
            let platformView: CustomWebView
            var startTime: CFAbsoluteTime?
            private var timerStartTimes: [String: Double] = [:]
            private var swiftBenchmarks: [String: CFAbsoluteTime] = [:]

            init(parent: MarkdownWebView) {
                self.parent = parent
                platformView = .init()
                super.init()

                if parent.enableBenchmarking {
                    startTime = CFAbsoluteTimeGetCurrent()
                    swiftBenchmarks["Coordinator Init Start"] = startTime!
                    print("Swift Benchmark - Coordinator Init Start: \(startTime!)s")
                }

                platformView.navigationDelegate = self

                #if DEBUG && os(iOS)
                    if #available(iOS 16.4, *) {
                        self.platformView.isInspectable = true
                    }
                #endif

                platformView.setContentHuggingPriority(.required, for: .vertical)

                #if os(iOS)
                    platformView.scrollView.isScrollEnabled = false
                #endif

                #if os(macOS)
                    platformView.setValue(false, forKey: "drawsBackground")
                #elseif os(iOS)
                    platformView.isOpaque = false
                #endif

                platformView.configuration.userContentController = .init()
                platformView.configuration.userContentController.add(
                    self, name: "sizeChangeHandler")
                platformView.configuration.userContentController.add(
                    self, name: "renderedContentHandler")
                platformView.configuration.userContentController.add(self, name: "copyToPasteboard")
                if parent.enableBenchmarking {
                    platformView.configuration.userContentController.add(
                        self, name: "consoleLogHandler")
                }

                #if os(macOS)
                    let defaultStylesheetFileName = "default-macOS"
                #elseif os(iOS)
                    let defaultStylesheetFileName = "default-iOS"
                #endif
                guard
                    let templateFileURL = Bundle.module.url(
                        forResource: "template", withExtension: ""),
                    let templateString = try? String(contentsOf: templateFileURL),
                    let scriptFileURL = Bundle.module.url(forResource: "script", withExtension: ""),
                    let script = try? String(contentsOf: scriptFileURL),
                    let defaultStylesheetFileURL = Bundle.module.url(
                        forResource: defaultStylesheetFileName, withExtension: ""),
                    let defaultStylesheet = try? String(contentsOf: defaultStylesheetFileURL)
                else {
                    print("Failed to load resources.")
                    return
                }

                let stylesheet: String? = self.parent.customStylesheet.map { str in
                    defaultStylesheet + str
                }

                let htmlString =
                    templateString
                    .replacingOccurrences(of: "PLACEHOLDER_SCRIPT", with: script)
                    .replacingOccurrences(
                        of: "PLACEHOLDER_STYLESHEET", with: stylesheet ?? defaultStylesheet)

                if parent.enableBenchmarking {
                    swiftBenchmarks["Before HTML Load"] = CFAbsoluteTimeGetCurrent()
                    print(
                        "Swift Benchmark - Before HTML Load: \(swiftBenchmarks["Before HTML Load"]! - swiftBenchmarks["Coordinator Init Start"]!)s"
                    )
                }

                platformView.loadHTMLString(htmlString, baseURL: nil)

                if parent.enableBenchmarking {
                    swiftBenchmarks["After HTML Load"] = CFAbsoluteTimeGetCurrent()
                    print(
                        "Swift Benchmark - HTML Load Duration: \(swiftBenchmarks["After HTML Load"]! - swiftBenchmarks["Before HTML Load"]!)s"
                    )
                }
            }

            public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
                if parent.enableBenchmarking {
                    swiftBenchmarks["WebView Did Finish"] = CFAbsoluteTimeGetCurrent()
                    print(
                        "Swift Benchmark - WebView Load Duration: \(swiftBenchmarks["WebView Did Finish"]! - swiftBenchmarks["After HTML Load"]!)s"
                    )
                }
                (webView as! CustomWebView).updateMarkdownContent(parent.markdownContent)
            }

            public func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction)
                async -> WKNavigationActionPolicy
            {
                if navigationAction.navigationType == .linkActivated {
                    guard let url = navigationAction.request.url else { return .cancel }

                    if let linkActivationHandler = parent.linkActivationHandler {
                        linkActivationHandler(url)
                    } else {
                        #if os(macOS)
                            NSWorkspace.shared.open(url)
                        #elseif os(iOS)
                            DispatchQueue.main.async {
                                Task { await UIApplication.shared.open(url) }
                            }
                        #endif
                    }
                    return .cancel
                } else {
                    return .allow
                }
            }

            public func userContentController(
                _: WKUserContentController, didReceive message: WKScriptMessage
            ) {
                switch message.name {
                case "sizeChangeHandler":
                    guard let contentHeight = message.body as? CGFloat,
                        platformView.contentHeight != contentHeight
                    else { return }
                    platformView.contentHeight = contentHeight
                    platformView.invalidateIntrinsicContentSize()

                case "renderedContentHandler":
                    if parent.enableBenchmarking, let startTime = startTime {
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let renderTime = endTime - startTime
                        print("Swift Benchmark - Total Markdown Rendering Time: \(renderTime)s")
                        self.startTime = nil
                    }
                    guard let renderedContentHandler = parent.renderedContentHandler,
                        let renderedContentBase64Encoded = message.body as? String,
                        let renderedContentBase64EncodedData: Data = .init(
                            base64Encoded: renderedContentBase64Encoded),
                        let renderedContent = String(
                            data: renderedContentBase64EncodedData, encoding: .utf8)
                    else { return }
                    renderedContentHandler(renderedContent)

                case "copyToPasteboard":
                    guard let base64EncodedString = message.body as? String else { return }
                    base64EncodedString.trimmingCharacters(in: .whitespacesAndNewlines)
                        .copyToPasteboard()

                case "consoleLogHandler" where parent.enableBenchmarking:
                    if let body = message.body as? [String: Any],
                        let type = body["type"] as? String,
                        let label = body["label"] as? String,
                        let timestamp = body["timestamp"] as? Double
                    {
                        switch type {
                        case "time":
                            timerStartTimes[label] = timestamp
                            print("JS Benchmark - \(label) Started: \(timestamp)ms")
                        case "timeEnd":
                            if let startTime = timerStartTimes[label] {
                                let duration = timestamp - startTime
                                print("JS Benchmark - \(label) Completed: \(duration)ms")
                                timerStartTimes.removeValue(forKey: label)
                            } else {
                                print(
                                    "JS Benchmark - \(label) Ended: \(timestamp)ms (no start time)")
                            }
                        default:
                            break
                        }
                    }

                default:
                    return
                }
            }
        }

        public class CustomWebView: WKWebView {
            var contentHeight: CGFloat = 0

            override public var intrinsicContentSize: CGSize {
                .init(width: super.intrinsicContentSize.width, height: contentHeight)
            }

            #if os(macOS)
                override public func scrollWheel(with event: NSEvent) {
                    super.scrollWheel(with: event)
                    nextResponder?.scrollWheel(with: event)
                }

                override public func willOpenMenu(_ menu: NSMenu, with _: NSEvent) {
                    menu.items.removeAll { $0.identifier == .init("WKMenuItemIdentifierReload") }
                }

                override public func keyDown(with event: NSEvent) {
                    nextResponder?.keyDown(with: event)
                }

                override public func keyUp(with event: NSEvent) {
                    nextResponder?.keyUp(with: event)
                }

                override public func flagsChanged(with event: NSEvent) {
                    nextResponder?.flagsChanged(with: event)
                }
            #elseif os(iOS)
                override public func pressesBegan(
                    _ presses: Set<UIPress>, with event: UIPressesEvent?
                ) {
                    super.pressesBegan(presses, with: event)
                    next?.pressesBegan(presses, with: event)
                }

                override public func pressesEnded(
                    _ presses: Set<UIPress>, with event: UIPressesEvent?
                ) {
                    super.pressesEnded(presses, with: event)
                    next?.pressesEnded(presses, with: event)
                }

                override public func pressesChanged(
                    _ presses: Set<UIPress>, with event: UIPressesEvent?
                ) {
                    super.pressesChanged(presses, with: event)
                    next?.pressesChanged(presses, with: event)
                }
            #endif

            func updateMarkdownContent(_ markdownContent: String) {
                guard
                    let markdownContentBase64Encoded = markdownContent.data(using: .utf8)?
                        .base64EncodedString()
                else { return }
                callAsyncJavaScript(
                    "window.updateWithMarkdownContentBase64Encoded(`\(markdownContentBase64Encoded)`)",
                    in: nil, in: .page, completionHandler: nil)
            }
        }
    }
#endif

extension String {
    func copyToPasteboard() {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(self, forType: .string)
        #else
            UIPasteboard.general.string = self
        #endif
    }
}
