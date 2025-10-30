//
//  AppTheme.swift
//  Lead4Tomorrow Calendar App
//
//  Created by Varun Hittuvalli on 10/29/25.
//


import SwiftUI

// MARK: - App Theme

enum AppTheme {
    // MARK: Fonts
    static func heading(_ size: CGFloat = 28, weight: Font.Weight = .bold) -> Font {
        // "Prompt" for headings; fallback = system
        Font.custom("Prompt-Bold", size: size, relativeTo: .title)
            .weight(weight)
    }
    static func body(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font {
        // "Quattrocento Sans" for body; fallback = system
        Font.custom("QuattrocentoSans-Regular", size: size, relativeTo: .body)
            .weight(weight)
    }

    // MARK: Palette
    static let green        = Color(hex: "#0d4f4e")  // primary brand green
    static let brown        = Color(hex: "#834715")
    static let rose         = Color(hex: "#af3b3b")  // error/alert
    static let brightGreen  = Color(hex: "#0e820f")  // call-to-action
    static let blueGreen    = Color(hex: "#026d81")  // accent/links
    static let black        = Color(hex: "#000000")

    // Semantic tokens
    static let backgroundCard  = blueGreen.opacity(0.10)
    static let backgroundSoft  = green.opacity(0.06)
    static let textPrimary     = black
    static let textSecondary   = Color.black.opacity(0.6)
    static let link            = blueGreen
    static let accent          = blueGreen
    static let errorBG         = rose
    static let errorText       = Color.white
}

// MARK: - Utilities

extension Color {
    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

struct ThemedCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.backgroundCard)
            .cornerRadius(12)
    }
}

struct ThemedSectionTitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.heading(20, weight: .semibold))
            .foregroundColor(AppTheme.green)
    }
}
