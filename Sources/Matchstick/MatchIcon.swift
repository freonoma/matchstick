import AppKit

/// The menu bar icon: an upright match that is unlit, lit, or burning down.
///
/// Two icons are equal when they look the same, so the status item only
/// needs a new image when the value changes.
struct MatchIcon: Equatable {
    /// A timed match burns down in this many steps.
    static let burnSteps = 12

    let isLit: Bool
    /// 0 for a fresh match, `burnSteps` when the time is up.
    let burnStep: Int

    /// - Parameter fractionLeft: The share of a timed session that is left,
    ///   from 1 down to 0. Leave it out for a match that doesn't burn down.
    init(isLit: Bool, fractionLeft: Double? = nil) {
        self.isLit = isLit
        let left = fractionLeft ?? 1
        let burned = left.isNaN ? 0 : 1 - min(max(left, 0), 1)
        burnStep = isLit ? Int(burned * Double(Self.burnSteps)) : 0
    }

    /// A template image, so macOS colors it for light and dark menu bars.
    var image: NSImage {
        let image = NSImage(size: Layout.size, flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            draw(in: context)
            return true
        }
        image.isTemplate = true
        return image
    }
}

// MARK: - Drawing

private extension MatchIcon {
    /// Measurements in points, with y pointing down. Straight edges sit on
    /// half points, which are whole pixels on a Retina display.
    enum Layout {
        static let size = NSSize(width: 18, height: 18)

        /// The match stands upright on this line.
        static let centerX: CGFloat = 9
        /// The bottom end of the stick. It stays put while the match burns.
        static let footY: CGFloat = 17
        /// From the foot to the top of the head on a fresh match. An unlit
        /// match is the same match in the same place, just without the flame.
        static let height: CGFloat = 11

        static let stickWidth: CGFloat = 2
        static let stickCornerRadius: CGFloat = 0.5
        static let headSize = CGSize(width: 4, height: 4)
        static let headCornerRadius: CGFloat = 1

        static let flameSize = CGSize(width: 9, height: 10)
        /// The tip of the flame is this far above the top of the head.
        static let flameRise: CGFloat = 5.5
        /// The tip leans this far left of the middle, which puts it straight
        /// above the left edge of the head.
        static let flameLean: CGFloat = 2
        /// Clear space between the flame and the head.
        static let gap: CGFloat = 1

        /// The head moves this far down the stick with each burn step. A
        /// short stub of stick still shows below the head on the last one.
        static let burnStepLength: CGFloat = 0.5
    }

    /// The flame is a teardrop with a sharp tip that leans left: a straight
    /// edge under the tip, a small bulge on the left and one big round curve
    /// on the right.
    ///
    /// Each point is given as the distance right of the match's center line
    /// and the distance below the tip.
    static func flame(tipY: CGFloat) -> CGPath {
        func point(_ right: CGFloat, _ down: CGFloat) -> CGPoint {
            CGPoint(x: Layout.centerX + right, y: tipY + down)
        }
        let side = Layout.flameSize.width / 2
        let base = Layout.flameSize.height
        let lean = -Layout.flameLean

        let path = CGMutablePath()
        path.move(to: point(lean, 0))
        // Down the round right side, under the head, and up the left side.
        path.addCurve(to: point(side, 6.7),
                      control1: point(1, 0.8), control2: point(side, 3.6))
        path.addCurve(to: point(0, base),
                      control1: point(side, 8.7), control2: point(2.8, base))
        path.addCurve(to: point(-side, 7.15),
                      control1: point(-2.8, base), control2: point(-side, 8.7))
        path.addCurve(to: point(lean, 2.1),
                      control1: point(-side, 4.2), control2: point(lean, 3.8))
        // Closing the path draws the straight edge back up to the tip.
        path.closeSubpath()
        return path
    }

    static func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    func draw(in context: CGContext) {
        let foot = Layout.footY
        let height = Layout.height - CGFloat(burnStep) * Layout.burnStepLength

        let head = CGRect(x: Layout.centerX - Layout.headSize.width / 2, y: foot - height,
                          width: Layout.headSize.width, height: Layout.headSize.height)
        let stick = CGRect(x: Layout.centerX - Layout.stickWidth / 2, y: head.midY,
                           width: Layout.stickWidth, height: foot - head.midY)

        context.setFillColor(.black)
        context.addPath(Self.roundedRect(stick, radius: Layout.stickCornerRadius))
        context.addPath(Self.roundedRect(head, radius: Layout.headCornerRadius))
        context.fillPath()

        guard isLit else { return }

        // The flame wraps around the head. A channel of clear space keeps the
        // head readable inside it. The channel is open at the bottom, because
        // thin ends of flame beside the stick turn to fuzz at this size.
        let gap = Layout.gap
        let channel = CGRect(x: head.minX - gap, y: head.minY - gap,
                             width: head.width + gap * 2, height: Layout.size.height)
        let flame = Self.flame(tipY: head.minY - Layout.flameRise)
            .subtracting(Self.roundedRect(channel, radius: Layout.headCornerRadius + gap))

        context.addPath(flame)
        context.fillPath()
    }
}
