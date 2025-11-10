//
//  WebAuthView.swift
//  HuggingChat-Mac
//
//  Created by Claude Code on production readiness improvements
//

import SwiftUI
import WebKit

/// Secure in-app OAuth authentication view using WKWebView
struct WebAuthView: NSViewRepresentable {
    let url: URL
    let onCallback: (String, String) -> Void
    let onError: (Error) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent() // Don't persist cookies

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = UserAgentBuilder.userAgent

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        nsView.load(request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebAuthView

        init(parent: WebAuthView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Check if this is the callback URL
            if let url = navigationAction.request.url,
               url.scheme == "huggingchat",
               url.host == "login" || url.path.contains("callback") {

                // Parse the callback URL parameters
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let queryItems = components.queryItems {

                    let code = queryItems.first(where: { $0.name == "code" })?.value ?? ""
                    let state = queryItems.first(where: { $0.name == "state" })?.value ?? ""

                    if !code.isEmpty && !state.isEmpty {
                        parent.onCallback(code, state)
                    }
                }

                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.onError(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.onError(error)
        }
    }
}

/// Container view for presenting the WebAuthView in a window
struct WebAuthContainerView: View {
    let url: URL
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(CoordinatorModel.self) private var coordinator
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sign in to HuggingChat")
                    .font(.headline)
                Spacer()
                Button(action: {
                    dismissWindow()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            // WebView
            WebAuthView(
                url: url,
                onCallback: { code, state in
                    coordinator.validateSignup(code: code, state: state)
                    dismissWindow()
                },
                onError: { error in
                    errorMessage = error.localizedDescription
                    showError = true
                }
            )
            .frame(minWidth: 600, minHeight: 700)
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
}

#Preview {
    if let url = URL(string: "https://huggingface.co/chat/login") {
        WebAuthContainerView(url: url)
            .environment(CoordinatorModel())
            .frame(width: 600, height: 700)
    }
}
