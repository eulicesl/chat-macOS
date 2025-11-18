//
//  ThemingEngine.swift
//  HuggingChat-iOS
//

import SwiftUI
import Observation

@Observable
class ThemingEngine {
    var currentTheme: Theme

    init() {
        let savedThemeName = UserDefaults.standard.string(forKey: "selectedTheme") ?? "default"
        self.currentTheme = Theme.allThemes.first { $0.name == savedThemeName } ?? .defaultTheme
    }

    func setTheme(_ theme: Theme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.name, forKey: "selectedTheme")
    }
}

struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let colorScheme: ColorScheme?
    let backgroundColor: Color
    let primaryColor: Color
    let secondaryColor: Color
    let textColor: Color
    let accentColor: Color
    let userMessageBackground: Color
    let assistantMessageBackground: Color
    let inputBackground: Color
    let borderColor: Color

    static let defaultTheme = Theme(
        id: "default",
        name: "default",
        displayName: "Default",
        colorScheme: nil,
        backgroundColor: Color(.systemBackground),
        primaryColor: .blue,
        secondaryColor: Color(.secondarySystemBackground),
        textColor: Color(.label),
        accentColor: .blue,
        userMessageBackground: .blue.opacity(0.1),
        assistantMessageBackground: Color(.secondarySystemBackground),
        inputBackground: Color(.tertiarySystemBackground),
        borderColor: Color(.separator)
    )

    static let mcIntoshTheme = Theme(
        id: "mcintosh",
        name: "mcintosh",
        displayName: "McIntosh Classic",
        colorScheme: .light,
        backgroundColor: .white,
        primaryColor: .black,
        secondaryColor: Color(red: 0.95, green: 0.95, blue: 0.95),
        textColor: .black,
        accentColor: .black,
        userMessageBackground: Color(red: 0.9, green: 0.9, blue: 0.9),
        assistantMessageBackground: .white,
        inputBackground: .white,
        borderColor: .black
    )

    static let pixelPalsTheme = Theme(
        id: "pixel",
        name: "pixel",
        displayName: "Pixel Pals",
        colorScheme: .dark,
        backgroundColor: Color(red: 0.1, green: 0.1, blue: 0.15),
        primaryColor: Color(red: 0.4, green: 0.8, blue: 0.4),
        secondaryColor: Color(red: 0.15, green: 0.15, blue: 0.2),
        textColor: Color(red: 0.9, green: 0.9, blue: 0.9),
        accentColor: Color(red: 0.4, green: 0.8, blue: 0.4),
        userMessageBackground: Color(red: 0.2, green: 0.4, blue: 0.6),
        assistantMessageBackground: Color(red: 0.15, green: 0.15, blue: 0.2),
        inputBackground: Color(red: 0.15, green: 0.15, blue: 0.2),
        borderColor: Color(red: 0.4, green: 0.8, blue: 0.4)
    )

    static let theme404 = Theme(
        id: "404",
        name: "404",
        displayName: "404",
        colorScheme: .dark,
        backgroundColor: Color(red: 0.05, green: 0.05, blue: 0.1),
        primaryColor: Color(red: 1.0, green: 0.0, blue: 0.5),
        secondaryColor: Color(red: 0.1, green: 0.1, blue: 0.15),
        textColor: Color(red: 0.95, green: 0.95, blue: 0.95),
        accentColor: Color(red: 1.0, green: 0.0, blue: 0.5),
        userMessageBackground: Color(red: 0.2, green: 0.0, blue: 0.3),
        assistantMessageBackground: Color(red: 0.1, green: 0.1, blue: 0.15),
        inputBackground: Color(red: 0.1, green: 0.1, blue: 0.15),
        borderColor: Color(red: 1.0, green: 0.0, blue: 0.5)
    )

    static let allThemes: [Theme] = [
        defaultTheme,
        mcIntoshTheme,
        pixelPalsTheme,
        theme404
    ]
}
