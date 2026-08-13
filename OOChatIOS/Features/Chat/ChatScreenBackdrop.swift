import SwiftUI
import UIKit

struct ChatScreenBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ChatSurfacePalette.backgroundBase

            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        ChatSurfacePalette.darkTopWash,
                        ChatSurfacePalette.darkMidnight,
                        ChatSurfacePalette.darkLowerInk
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        AppTheme.primary.opacity(0.14),
                        AppTheme.primary.opacity(0.05),
                        AppTheme.primary.opacity(0)
                    ],
                    center: UnitPoint(x: 0.50, y: 0.40),
                    startRadius: 18,
                    endRadius: 320
                )
                .blendMode(.screen)

                RadialGradient(
                    colors: [
                        ChatSurfacePalette.darkWarmLift,
                        ChatSurfacePalette.darkWarmLift.opacity(0)
                    ],
                    center: UnitPoint(x: 0.18, y: 0.16),
                    startRadius: 10,
                    endRadius: 260
                )
                .blendMode(.screen)
            }
        }
    }
}

/// Dark-mode chat surfaces. The greys were faintly violet and the lift behind the
/// transcript was an explicit violet glow — the third copy of a brand colour in
/// this app. The greys are now genuinely neutral, and the lift carries the same
/// weight in brand green, so the one colour in the product is the one colour on
/// screen.
enum ChatSurfacePalette {
    static let backgroundBase = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 8.0 / 255.0, green: 8.0 / 255.0, blue: 8.0 / 255.0, alpha: 1)
        } else {
            return .systemBackground
        }
    })

    static let darkTopWash = Color(red: 14.0 / 255.0, green: 14.0 / 255.0, blue: 14.0 / 255.0)
    static let darkMidnight = Color(red: 6.0 / 255.0, green: 6.0 / 255.0, blue: 6.0 / 255.0)
    static let darkLowerInk = Color(red: 3.0 / 255.0, green: 3.0 / 255.0, blue: 3.0 / 255.0)
    // brand-600, at the same 0.07 the violet lift used.
    static let darkWarmLift = Color(red: 22.0 / 255.0, green: 163.0 / 255.0, blue: 74.0 / 255.0)
        .opacity(0.07)
}
