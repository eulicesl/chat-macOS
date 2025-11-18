//
//  MarkdownMessageView.swift
//  HuggingChat-iOS
//
//  Enhanced markdown rendering with code syntax highlighting
//

import SwiftUI
import MarkdownUI

struct MarkdownMessageView: View {
    let content: String
    @Environment(ThemingEngine.self) private var themingEngine

    var body: some View {
        Markdown(content)
            .markdownTheme(.gitHub)
            .markdownCodeSyntaxHighlighter(.splash(theme: splashTheme))
            .textSelection(.enabled)
    }

    private var splashTheme: Splash.Theme {
        themingEngine.currentTheme.colorScheme == .dark ? .sunset(withFont: .init(size: 14)) : .presentation(withFont: .init(size: 14))
    }
}

// Code block theme configuration
extension Theme {
    struct CodeSyntaxHighlighter {
        @FrozencodeSyntaxHighlighter {
            CodeSyntaxHighlighter { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.25))
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.85))
                    }
                    .padding(16)
            }
        }
    }
}

#Preview {
    VStack {
        MarkdownMessageView(content: """
        # Hello World

        This is **bold** and this is *italic*.

        ## Code Example

        ```swift
        func greet(name: String) -> String {
            return "Hello, \\(name)!"
        }
        ```

        - Item 1
        - Item 2
        - Item 3
        """)
        .padding()
    }
    .environment(ThemingEngine())
}
