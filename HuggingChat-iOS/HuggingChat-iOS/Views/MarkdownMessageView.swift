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
            .textSelection(.enabled)
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
