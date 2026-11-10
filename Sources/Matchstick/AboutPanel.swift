import AppKit

/// The standard About panel, with a short note and a link to the source.
@MainActor
enum AboutPanel {
    private static let note = """
        There was an app called Caffeine ages ago, and I loved it. There are \
        hundreds of options out there now, but I wanted my own because I had \
        the idea of a matchstick icon. So I built it around that.
        """
    private static let repository = "github.com/freonoma/matchstick"

    static func show() {
        // An app without a Dock icon has to bring itself forward, or the
        // panel opens behind whatever the user was working in.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            // An empty build number leaves just "Version 1.0.0".
            .version: "",
        ])
    }

    private static var credits: NSAttributedString {
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        let style: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: centered,
        ]

        let text = NSMutableAttributedString(string: note + "\n\n", attributes: style)
        let link = NSAttributedString(
            string: repository,
            attributes: style.merging([.link: "https://" + repository]) { $1 }
        )
        text.append(link)
        return text
    }
}
