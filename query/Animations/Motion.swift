import SwiftUI

/// Shared animations; always resolve through `animation(_:reduceMotion:)`.
enum Motion {
    static let highlight = Animation.easeOut(duration: 0.12)
    static let reveal = Animation.easeInOut(duration: 0.2)
    static let shimmer = Animation.linear(duration: 1.2).repeatForever(autoreverses: false)

    static let filterBar = AnyTransition.move(edge: .top).combined(with: .opacity)

    /// Startup configuration steps slide in from the trailing edge; a plain fade with Reduce Motion.
    static func stepTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity)
    }

    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
