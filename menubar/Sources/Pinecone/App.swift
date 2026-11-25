import ServiceManagement
import SwiftUI

@main
enum Main {
    static func main() {
        // `Pinecone --snapshot out.png [--settings] [--dark]` draws the panel into a picture and quits (for checking the design).
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "--icon"), a.count > i + 1 {  // draws the three menu bar icons, enlarged, for checking
            let big = NSImage(size: NSSize(width: 360, height: 120), flipped: false) { _ in
                NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 360, height: 120).fill()
                for (n, s) in [(false, false), (true, false), (true, true)].enumerated() {
                    menuIcon(on: s.0, working: s.1).draw(in: NSRect(x: 20 + n * 120, y: 20, width: 80, height: 80))
                }
                return true
            }
            if let tiff = big.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) { try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: a[i + 1])) }
            return
        }
        guard let i = a.firstIndex(of: "--snapshot"), a.count > i + 1 else { PineconeApp.main(); return }
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        Task { @MainActor in
            let m = Monitor(poll: false)
            await m.refresh()
            m.snapshot = true
            m.showSettings = a.contains("--settings")
            await m.loadConfig()
            await m.loadTokens()
            let dark = a.contains("--dark")
            // The colours follow the appearance; a picture has no window to take it from, so it is set here.
            app.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            let r = ImageRenderer(content: Panel().environmentObject(m)
                .background(Theme.window)
                .environment(\.colorScheme, dark ? .dark : .light))
            r.scale = 2
            if let tiff = r.nsImage?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: a[i + 1]))
            }
            exit(0)
        }
        app.run()
    }
}

struct PineconeApp: App {
    @StateObject private var monitor = Monitor()

    var body: some Scene {
        MenuBarExtra {
            Panel().environmentObject(monitor)
        } label: {
            // The pmndrs mark. off: faded. working: a dot in its empty corner.
            Image(nsImage: menuIcon(on: monitor.online, working: monitor.working))
        }
        .menuBarExtraStyle(.window)
    }
}

/// The pmndrs logo (github.com/pmndrs/branding, MIT) as a menu bar icon that follows the bar's light or dark look.
func menuIcon(on: Bool, working: Bool) -> NSImage {
    let side: CGFloat = 16
    let img = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
        let k = side / 800  // the mark sits in an 800 x 800 square of the 2000 x 2000 original, starting at 600, 600
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: (x - 600) * k, y: (y - 600) * k, width: w * k, height: h * k) }
        NSColor.black.withAlphaComponent(on ? 1 : 0.4).setFill()
        for r in [box(880, 1160, 240, 240), box(880, 880, 240, 240), box(600, 880, 240, 240), box(880, 600, 520, 240), box(1160, 840, 240, 280)] { r.fill() }
        if working { NSBezierPath(ovalIn: box(630, 630, 180, 180)).fill() }
        return true
    }
    img.isTemplate = true
    return img
}

func gb(_ v: Double) -> String { v >= 10 ? String(format: "%.0f GB", v) : String(format: "%.1f GB", v) }
func ago(_ s: Int) -> String { s < 90 ? "\(s) s" : s < 5400 ? "\(s / 60) min" : "\(s / 3600) h" }

// MARK: - The design

/// Pinecone is drawn as pine's desktop app is (desktop/DESIGN.md in the pine repository): stock shadcn in its
/// `base-nova` style, on pine's colours. pine's page is React, so here every part is drawn in SwiftUI after its
/// shadcn counterpart, at the same sizes, with the same variants, and named after it (Card, Item, Field,
/// Alert, Button...). A view is made of these parts and nothing else draws a frame of its own.
///
/// The colours are pine's roles (desktop/src/index.css), and shadcn's tokens point at them. Dark is pine's
/// default theme, pmndre (github.com/drcmda/poimandres-theme); light is pine's light. Light and dark follow
/// the system, or the choice in Settings.
enum Theme {
    static func pair(_ light: UInt32, _ dark: UInt32, _ la: Double = 1, _ da: Double = 1) -> Color {
        func rgb(_ v: UInt32, _ a: Double) -> NSColor {
            NSColor(srgbRed: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255, alpha: a)
        }
        let l = rgb(light, la), d = rgb(dark, da)
        return Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? d : l })
    }
    // pine's roles
    static let side = pair(0xecede9, 0x13151d, 0.86, 0.88)  // lies on the menu bar window's material
    static let window = pair(0xecede9, 0x13151d)  // the same without a material behind it, for pictures
    static let bg = pair(0xfdfdfc, 0x1b1e28)
    static let surface = pair(0xffffff, 0x1e212c)
    static let sunk = pair(0xeff0ed, 0x171922)
    static let press = pair(0x141e18, 0xa6accd, 0.09, 0.12)
    static let line = pair(0xe1e3de, 0x2b2e3c)
    static let text = pair(0x1a1d1b, 0xe4f0fb)
    static let muted = pair(0x666e68, 0xa6accd)
    static let faint = pair(0x99a19b, 0x767c9d)
    static let brand = pair(0x1f7a55, 0x5de4c7)
    static let onBrand = pair(0xffffff, 0x171922)
    static let warn = pair(0xa86a08, 0xfffac2)
    static let bad = pair(0xc2413a, 0xd0679d)

    // shadcn's tokens, as pine sets them
    static let background = bg
    static let foreground = text
    static let card = surface
    static let mutedBg = sunk  // `bg-muted`
    static let mutedFg = muted  // `text-muted-foreground`
    static let border = line
    static let ring = faint
    static let primary = brand
    static let primaryFg = onBrand
    static let destructive = bad
    static let sidebar = side
    static let sidebarFg = muted
    static let sidebarAccent = press
    /// `ring-foreground/10`, the line around a Card.
    static let cardRing = pair(0x1a1d1b, 0xe4f0fb, 0.1, 0.1)
    /// `bg-input/30` in dark, nothing in light: the inside of a field and of an outline button.
    static let inputFill = pair(0xffffff, 0x2b2e3c, 0, 0.3)
    static let outlineFill = pair(0xfdfdfc, 0x2b2e3c, 1, 0.3)
    static let switchOff = pair(0xe1e3de, 0x2b2e3c, 1, 0.8)
    static let thumbOn = pair(0xfdfdfc, 0x171922)
    static let thumbOff = pair(0xfdfdfc, 0xe4f0fb)

    /// What is loaded, one colour each in the memory bar. None is the green or the yellow that say a state.
    static let slices: [Color] = [
        pair(0x2a6fc0, 0xadd7ff), pair(0x7c4fd0, 0xd0679d), pair(0x2a8f95, 0x7390aa), pair(0xb8457f, 0xa6accd),
        pair(0x5d6f8a, 0x89ddff), pair(0x8f86c9, 0x5fb3a1), pair(0x4aa3d8, 0x91b4d5), pair(0x99a19b, 0x767c9d),
    ]

    // Tailwind's scale on the browser's 16px root, which pine keeps: text-xs, text-sm, text-base, text-xl.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    static let xs = font(12)
    static let sm = font(14)
    static let smMedium = font(14, .medium)
    static let base = font(16, .medium)
    static let mono = Font.system(size: 12, design: .monospaced)

    // Radii: --radius is 10.
    static let radiusMd: CGFloat = 8
    static let radiusLg: CGFloat = 10
    static let radiusXl: CGFloat = 14
}

func rounded(_ r: CGFloat) -> RoundedRectangle { RoundedRectangle(cornerRadius: r, style: .continuous) }

/// A view's own memory of the pointer, for the hover look of a stock part.
final class Hover: ObservableObject { @Published var on = false }

// MARK: - Button

/// shadcn's Button: its variants (default, outline, ghost, link) and sizes (default, sm, xs, icon-xs). A variant
/// says what the button does, as pine has it: default finishes something, outline opens or adds, ghost backs
/// out or takes away.
struct Pine: ButtonStyle {
    enum Variant { case `default`, outline, ghost, link }
    enum Size { case `default`, sm, xs, iconXs }
    var variant = Variant.outline
    var size = Size.default

    func makeBody(configuration: Configuration) -> some View { Look(configuration: configuration, style: self) }

    struct Look: View {
        let configuration: Configuration
        let style: Pine
        @StateObject private var hover = Hover()
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            let (h, pad, fontSize, r): (CGFloat, CGFloat, CGFloat, CGFloat) = switch style.size {
            case .default: (32, 10, 14, Theme.radiusLg)
            case .sm: (28, 10, 12.8, Theme.radiusMd)
            case .xs: (24, 8, 12, Theme.radiusMd)
            case .iconXs: (24, 0, 12, Theme.radiusMd)
            }
            let active = hover.on || configuration.isPressed
            return configuration.label
                .font(Theme.font(fontSize, .medium))
                .labelStyle(GapLabel(gap: style.size == .default ? 6 : 4))
                .foregroundStyle(fg(active))
                .underline(style.variant == .link && active)
                .padding(.horizontal, style.variant == .link ? 0 : pad)
                .frame(minWidth: style.size == .iconXs ? 24 : nil, minHeight: style.variant == .link ? nil : h)
                .background(rounded(r).fill(bg(active)))
                .overlay(rounded(r).strokeBorder(style.variant == .outline ? Theme.border : .clear, lineWidth: 1))
                .contentShape(Rectangle())
                .opacity(enabled ? 1 : 0.5)
                .onHover { hover.on = $0 }
        }

        private func fg(_ active: Bool) -> Color {
            switch style.variant {
            case .default: Theme.primaryFg
            case .link: Theme.primary
            case .ghost where !active: Theme.foreground.opacity(0.92)
            default: Theme.foreground
            }
        }

        private func bg(_ active: Bool) -> Color {
            switch style.variant {
            case .default: Theme.primary.opacity(active && enabled ? 0.8 : 1)
            case .outline: active && enabled ? Theme.mutedBg : Theme.outlineFill
            case .ghost: active && enabled ? Theme.mutedBg : .clear
            case .link: .clear
            }
        }
    }
}

/// An icon and its words, the gap between them shadcn's.
struct GapLabel: LabelStyle {
    var gap: CGFloat = 6
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: gap) { configuration.icon.imageScale(.small); configuration.title }
    }
}

// MARK: - Switch, Slider, ToggleGroup

/// shadcn's Switch (default size): 32 by 18.4, a thumb of 16.
struct PineSwitch: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.label
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule().fill(configuration.isOn ? Theme.primary : Theme.switchOff).frame(width: 32, height: 18.4)
                Circle().fill(configuration.isOn ? Theme.thumbOn : Theme.thumbOff).frame(width: 16, height: 16).padding(.horizontal, 1.2)
            }
            .animation(.easeOut(duration: 0.15), value: configuration.isOn)
            .contentShape(Rectangle())
            .onTapGesture { configuration.isOn.toggle() }
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(configuration.isOn ? "on" : "off")
        }
    }
}

/// shadcn's Slider: a track of 4 in muted, the range in primary, a thumb of 12 with a line in the ring colour.
/// The arrow keys move it by one step when it has the keyboard.
struct PineSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1

    var body: some View {
        GeometryReader { g in
            let span = max(range.upperBound - range.lowerBound, 1)
            let x = g.size.width * (value - range.lowerBound) / span
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.mutedBg).frame(height: 4)
                Capsule().fill(Theme.primary).frame(width: max(0, x), height: 4)
                Circle().fill(Color.white).overlay(Circle().strokeBorder(Theme.ring, lineWidth: 1))
                    .frame(width: 12, height: 12).offset(x: min(max(0, x - 6), g.size.width - 12))
            }
            .frame(height: 16)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in set(range.lowerBound + span * v.location.x / max(g.size.width, 1)) })
        }
        .frame(height: 16)
        .focusable()
        .focusEffectDisabled()
        .onMoveCommand { d in
            if d == .left || d == .down { set(value - step) } else if d == .right || d == .up { set(value + step) }
        }
    }

    private func set(_ v: Double) { value = min(range.upperBound, max(range.lowerBound, (v / step).rounded() * step)) }
}

/// shadcn's ToggleGroup, outline and sm: one choice of a few, the chosen one in muted.
struct ToggleGroup: View {
    let options: [(value: String, label: String)]
    @Binding var value: String
    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.value) { o in
                Button(o.label) { value = o.value }
                    .buttonStyle(Pine(variant: .outline, size: .sm))
                    .background(rounded(Theme.radiusMd).fill(o.value == value ? Theme.mutedBg : .clear))
                    .accessibilityAddTraits(o.value == value ? .isSelected : [])
            }
        }
        .fixedSize()  // a choice keeps its words whole; the label beside it wraps instead
    }
}

// MARK: - Input

/// shadcn's Input: 32 high, a line around, 10 inside. `unit` makes it an InputGroup with the unit as its addon.
struct Input: View {
    @EnvironmentObject var m: Monitor
    var hint = ""
    @Binding var text: String
    var unit = ""
    var trailing = false
    var secret = false

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if m.snapshot {  // pictures cannot draw real text fields
                    Text(text.isEmpty ? hint : text).foregroundStyle(text.isEmpty ? Theme.mutedFg : Theme.foreground).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
                } else if secret {
                    SecureField(hint, text: $text).textFieldStyle(.plain)
                } else {
                    TextField(hint, text: $text).textFieldStyle(.plain).multilineTextAlignment(trailing ? .trailing : .leading)
                }
            }
            .font(Theme.sm).monospacedDigit()
            if !unit.isEmpty { Text(unit).font(Theme.sm).foregroundStyle(Theme.mutedFg) }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(rounded(Theme.radiusLg).fill(Theme.inputFill))
        .overlay(rounded(Theme.radiusLg).strokeBorder(Theme.border, lineWidth: 1))
    }
}

// MARK: - Card, Item, Alert, Separator, Spinner

/// shadcn's Card, sm: rounded-xl on `card`, a ring of foreground/10, 12 inside.
struct Card<Content: View>: View {
    var gap: CGFloat = 12
    var bottom: CGFloat = 12
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: gap) { content }
            .padding(.top, 12).padding(.bottom, bottom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rounded(Theme.radiusXl).fill(Theme.card))
            .overlay(rounded(Theme.radiusXl).strokeBorder(Theme.cardRing, lineWidth: 1))
            .clipShape(rounded(Theme.radiusXl))
    }
}

/// shadcn's Item: what is only read, with its actions at the end. `outline` has a line around; xs and sm are its sizes.
struct Item<Media: View, Content: View, Actions: View>: View {
    var outline = false
    var xs = false
    @ViewBuilder var media: Media
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: xs ? 8 : 10) {
            media
            content.frame(maxWidth: .infinity, alignment: .leading)
            actions
        }
        .padding(.horizontal, xs ? 10 : 12).padding(.vertical, xs ? 8 : 10)
        .overlay(rounded(Theme.radiusLg).strokeBorder(outline ? Theme.border : .clear, lineWidth: 1))
    }
}

extension Item where Media == EmptyView {
    init(outline: Bool = false, xs: Bool = false, @ViewBuilder content: () -> Content, @ViewBuilder actions: () -> Actions) {
        self.init(outline: outline, xs: xs, media: { EmptyView() }, content: content, actions: actions)
    }
}

/// shadcn's Alert: rounded-lg with a line, an icon beside a title and a description. `destructive` is in its colour.
struct Alert<Action: View>: View {
    var destructive = false
    var icon = ""
    var title = ""
    var text: String
    @ViewBuilder var action: Action

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !icon.isEmpty { Image(systemName: icon).font(Theme.font(13)).frame(width: 16, height: 20) }
            VStack(alignment: .leading, spacing: 2) {
                if !title.isEmpty { Text(title).font(Theme.smMedium) }
                Text(text).font(Theme.sm).foregroundStyle(destructive ? Theme.destructive.opacity(0.9) : Theme.mutedFg)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            action
        }
        .foregroundStyle(destructive ? Theme.destructive : Theme.foreground)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(rounded(Theme.radiusLg).fill(Theme.card))
        .overlay(rounded(Theme.radiusLg).strokeBorder(Theme.border, lineWidth: 1))
    }
}

extension Alert where Action == EmptyView {
    init(destructive: Bool = false, icon: String = "", title: String = "", text: String) {
        self.init(destructive: destructive, icon: icon, title: title, text: text, action: { EmptyView() })
    }
}

struct Separator: View {
    var body: some View { Rectangle().fill(Theme.border).frame(height: 1) }
}

/// shadcn's Spinner: lucide's Loader2, an open ring that turns, in the colour of the text around it.
struct Spinner: View {
    @EnvironmentObject var m: Monitor
    var body: some View {
        Group {
            if m.snapshot {
                ring(40)  // a picture stands still
            } else {
                TimelineView(.animation) { t in ring(t.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) * 360) }
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityLabel("working")
    }

    private func ring(_ degrees: Double) -> some View {
        Circle().inset(by: 2).trim(from: 0, to: 0.78)
            .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round)).rotationEffect(.degrees(degrees))
    }
}

/// shadcn's ScrollArea with `scroll-fade`, as pine has its side bar: an end fades where there is more to scroll to.
struct FadingScroll<Content: View>: View {
    @ViewBuilder var content: Content
    @StateObject private var ends = Ends()
    final class Ends: ObservableObject { @Published var top: CGFloat = 0; @Published var bottom: CGFloat = 0; @Published var height: CGFloat = 1 }

    var body: some View {
        ScrollView { content }
            .scrollIndicators(.automatic)
            .onScrollGeometryChange(for: [CGFloat].self) { g in
                [g.contentOffset.y + g.contentInsets.top, g.contentSize.height - g.containerSize.height - g.contentOffset.y - g.contentInsets.top, g.containerSize.height]
            } action: { _, v in
                ends.top = max(0, v[0]); ends.bottom = max(0, v[1]); ends.height = max(1, v[2])
            }
            .mask {
                // the fade grows with how far there is to scroll, up to 12% of the height or 40
                let size = min(40, ends.height * 0.12)
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: min(size, ends.top))
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: min(size, ends.bottom))
                }
            }
    }
}

// MARK: - The side bar

/// shadcn's SidebarGroup: 8 around what it holds, under an optional SidebarGroupLabel (32 high, text-xs, the
/// side bar's text at 70%).
struct SideGroup<Content: View>: View {
    var label = ""
    var trailing = ""
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !label.isEmpty {
                HStack {
                    Text(label)
                    Spacer()
                    if !trailing.isEmpty { Text(trailing).monospacedDigit() }
                }
                .font(Theme.font(12, .medium)).foregroundStyle(Theme.sidebarFg.opacity(0.7))
                .padding(.horizontal, 8).frame(height: 32)
            }
            content
        }
        .padding(8)
    }
}

/// The panel: what the scheduler is doing, or Settings. It is one of pine's side bars, with the inset of pine's
/// tab content: 28 to the edges of the groups, whose own padding takes it on to the text.
struct Panel: View {
    @EnvironmentObject var m: Monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if m.showSettings { SettingsPane() } else { Overview() }
        }
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)
        .frame(width: Self.width)
        .font(Theme.sm).foregroundStyle(Theme.sidebarFg).tint(Theme.primary)
        // One size for every view of the panel: the menu bar window does not move back under its icon when
        // its content changes height, so a panel that grows and shrinks ends up in the wrong place.
        .frame(height: m.snapshot ? nil : Self.height, alignment: .top)
        .background(m.snapshot ? Color.clear : Theme.sidebar)
    }

    static let width: CGFloat = 440
    /// As tall as the content usually needs, but never taller than the screen has room for.
    static let height: CGFloat = min(760, (NSScreen.main?.visibleFrame.height ?? 800) - 24)
}

/// Groups stand 16 apart, so 32 lies between what they hold, as between the sections of a page of pine's.
struct Scrolling<Content: View>: View {
    @EnvironmentObject var m: Monitor
    @ViewBuilder var content: Content
    var body: some View {
        if m.snapshot { content } else { FadingScroll { content } }
    }
}

struct Overview: View {
    @EnvironmentObject var m: Monitor

    var body: some View {
        header
        Scrolling {
            VStack(alignment: .leading, spacing: 16) {
                if let s = m.status, m.online {
                    if let e = s.config?.error {
                        SideGroup { Alert(destructive: true, icon: "exclamationmark.triangle", title: "config.json has a mistake", text: "The last good version stays in use. \(e)") }
                    }
                    MemoryGroup(s: s)
                    SideGroup {  // one group: the two lists follow each other as the agents of pine's side bar do
                        Folder(title: "Models", items: m.models)
                        Folder(title: "Services", items: m.services)
                    }
                    if !s.queue.isEmpty { queue(s.queue) }
                    if let h = s.host { SideGroup(label: "Load") { Graphs(host: h) } }
                    if let e = s.endpoints, !e.isEmpty { endpoints(e) }
                    if !s.events.isEmpty { activity(s.events) }
                } else {
                    offline
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        footer
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Pinecone").font(Theme.smMedium).foregroundStyle(Theme.foreground)
            if !m.isLocal {  // only when watching another Mac: shadcn's Badge, outline
                Text(m.hostLabel).font(Theme.font(12, .medium)).foregroundStyle(Theme.foreground)
                    .padding(.horizontal, 8).frame(height: 20).overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
            }
            Spacer()
            Text(m.serviceBusy ? (m.online ? "Stopping…" : "Starting…") : (m.online ? (m.working ? "Working" : "On") : "Off"))
                .foregroundStyle(Theme.mutedFg)
            if !m.labels.isEmpty {  // starts and stops the scheduler and what belongs to it
                Toggle("", isOn: Binding(get: { m.online }, set: { on in Task { await m.setServices(running: on) } }))
                    .toggleStyle(PineSwitch()).labelsHidden()
                    .disabled(m.serviceBusy).opacity(m.serviceBusy ? 0.5 : 1)
                    .help(m.online ? "Stop the scheduler and everything it runs" : "Start the scheduler")
            }
        }
        .padding(.horizontal, 8).frame(height: 32).padding(8)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Spacer()
            Button { m.showSettings = true; m.beginSettings() } label: { Label("Settings", systemImage: "gearshape") }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(Pine(variant: .ghost, size: .sm))
        .padding(8)
    }

    private func queue(_ q: [Waiting]) -> some View {
        SideGroup(label: "Waiting") {
            VStack(spacing: 10) {
                ForEach(q, id: \.self) { w in
                    Item(outline: true) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(w.resource): \(ago(w.waiting_s))").font(Theme.smMedium).foregroundStyle(Theme.foreground).monospacedDigit()
                            if let why = w.reason { Text(why).foregroundStyle(Theme.mutedFg).fixedSize(horizontal: false, vertical: true) }
                        }
                    } actions: { EmptyView() }
                }
            }
        }
    }

    /// The addresses to give to clients, each with a button that copies it.
    private func endpoints(_ list: [Endpoint]) -> some View {
        SideGroup(label: "Endpoints", trailing: "an access token is the key") {
            VStack(spacing: 10) {
                ForEach(list, id: \.self) { e in
                    Item(outline: true) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(e.name).foregroundStyle(Theme.mutedFg).lineLimit(1)
                            Text(e.url).font(Theme.mono).foregroundStyle(Theme.foreground).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                        }
                    } actions: {
                        Button(m.copiedURL == e.url ? "Copied" : "Copy") { m.copy(e.url) }.buttonStyle(Pine(variant: .outline, size: .sm))
                    }
                }
            }
        }
    }

    private func activity(_ events: [Event]) -> some View {
        SideGroup(label: "Recent activity") {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(events.prefix(m.moreEvents ? 14 : 4).enumerated()), id: \.offset) { _, e in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(ago(e.ago_s)).foregroundStyle(Theme.faint).monospacedDigit().frame(width: 48, alignment: .trailing)
                            Text(e.text).foregroundStyle(Theme.mutedFg).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        }
                        .font(Theme.xs)
                    }
                }
                .padding(.horizontal, 8)
                if events.count > 4 {
                    Button(m.moreEvents ? "Show less" : "Show more") { m.moreEvents.toggle() }.buttonStyle(Pine(variant: .ghost, size: .xs))
                }
            }
        }
    }

    /// shadcn's Empty: no scheduler to show.
    private var offline: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(m.unauthorized ? "An access token is needed" : m.problem.isEmpty ? "Connecting…" : "The scheduler is off")
                    .font(Theme.smMedium).foregroundStyle(Theme.foreground)
                if !m.problem.isEmpty { Text(m.problem).foregroundStyle(Theme.mutedFg).multilineTextAlignment(.center).lineSpacing(3) }
            }
            if m.unauthorized || !m.isLocal {
                Button("Open Settings") { m.showSettings = true; m.beginSettings() }.buttonStyle(Pine(variant: .outline))
            } else if !m.labels.isEmpty && !m.problem.isEmpty {
                Button("Start the scheduler") { Task { await m.setServices(running: true) } }.buttonStyle(Pine(variant: .default)).disabled(m.serviceBusy)
            }
        }
        .frame(maxWidth: .infinity).padding(24).padding(.top, 40)
    }
}

// MARK: - Memory

struct MemoryGroup: View {
    @EnvironmentObject var m: Monitor
    let s: Status

    /// One slice of the memory bar: a loaded model or service, or everything else on the Mac.
    struct Slice: Identifiable { let id: String; let gb: Double; let color: Color }

    var body: some View {
        let total = max(s.host?.ram_total_gb ?? s.budget_gb, 1)
        var slices: [Slice] = []
        for (i, r) in m.resources.enumerated() where r.state != "off" {
            // while it loads, what it holds so far, so that its slice grows into the bar
            slices.append(Slice(id: r.name, gb: r.actual_gb ?? (r.state == "starting" ? 0 : r.memory_gb), color: Theme.slices[i % Theme.slices.count]))
        }
        let ours = slices.reduce(0) { $0 + $1.gb }
        if let used = s.host?.ram_used_gb.compactMap({ $0 }).last, used - ours > 0.5 {
            slices.append(Slice(id: "system and apps", gb: used - ours, color: Theme.faint.opacity(0.5)))
        }
        let free = max(0, total - slices.reduce(0) { $0 + $1.gb })
        let kept = max(0, total - s.budget_gb)
        return SideGroup(label: "Memory", trailing: "\(gb(total)) in this Mac") {
            Card {
                GeometryReader { g in
                    HStack(spacing: 1) {
                        ForEach(slices) { sl in
                            Rectangle().fill(sl.color).frame(width: max(2, g.size.width * min(1, sl.gb / total)))
                                .transition(.asymmetric(insertion: .identity, removal: .opacity))
                        }
                        Spacer(minLength: 0)
                        Theme.faint.opacity(0.25).frame(width: g.size.width * min(1, kept / total))  // kept for the system
                    }
                    // The scheduler reports every two seconds; the bar moves between two reports instead of jumping.
                    .animation(.easeInOut(duration: 1.8), value: slices.map(\.gb))
                }
                .frame(height: 8)
                .background(Theme.mutedBg)
                .clipShape(Capsule())
                .help("The end is the \(gb(kept)) kept for the system")
                .padding(.horizontal, 12)
                FlowLayout(h: 16, v: 4) {
                    ForEach(slices) { sl in
                        HStack(spacing: 6) {
                            Circle().fill(sl.color).frame(width: 8, height: 8)
                            Text("\(sl.id) \(gb(sl.gb))").contentTransition(.numericText())
                        }
                    }
                    Text("\(gb(free)) free").foregroundStyle(Theme.faint).contentTransition(.numericText())
                }
                .font(Theme.xs).monospacedDigit().foregroundStyle(Theme.mutedFg)
                .padding(.horizontal, 12)
            }
        }
    }
}

/// Lines that wrap: what fits on a line goes on it, the rest on the next (flex-wrap).
struct FlowLayout: Layout {
    var h: CGFloat
    var v: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += line + v; line = 0 }
            x += size.width + h; line = max(line, size.height)
        }
        return CGSize(width: width, height: y + line)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += line + v; line = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + h; line = max(line, size.height)
        }
    }
}

// MARK: - Models and services

extension Resource {
    /// Loading, unloading, or answering a request.
    var busy: Bool { active > 0 || state == "starting" || state == "stopping" }
    /// It did not start, and says why.
    var failed: Bool { state == "off" && error != nil }
}

/// Models or services, as pine's side bar has an agent and its conversations: a line that folds the list away
/// (shadcn's collapsible SidebarGroupLabel), and the list under it. The line shows work going on in the list,
/// so it is seen when folded too.
struct Folder: View {
    @EnvironmentObject var m: Monitor
    let title: String
    let items: [Resource]
    @StateObject private var hover = Hover()

    var body: some View {
        if !items.isEmpty {
            // a picture shows the lists, whatever is folded on this Mac
            let open = m.snapshot || !m.folded.contains(title)
            VStack(alignment: .leading, spacing: 0) {
                Button { m.folded.formSymmetricDifference([title]) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right").font(Theme.font(11, .semibold)).rotationEffect(.degrees(open ? 90 : 0)).frame(width: 16)
                        Text(title)
                        Spacer()
                        HStack(spacing: 8) {
                            if items.contains(where: { $0.busy }) { Spinner() }
                            if items.contains(where: { $0.failed }) { Image(systemName: "exclamationmark.circle").foregroundStyle(Theme.warn) }
                            Text("\(items.filter { $0.state != "off" }.count) of \(items.count) loaded").font(Theme.xs).monospacedDigit()
                        }
                    }
                    .font(Theme.sm)
                    .foregroundStyle(hover.on ? Theme.foreground : Theme.sidebarFg)
                    .padding(.horizontal, 8).frame(height: 32)
                    .background(rounded(Theme.radiusMd).fill(hover.on ? Theme.sidebarAccent : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hover.on = $0 }
                .animation(.easeOut(duration: 0.15), value: open)
                .help(open ? "Hide the \(title.lowercased())" : "Show the \(title.lowercased())")
                if open {
                    ForEach(items) { r in
                        Row(r: r, tint: Theme.slices[(m.resources.firstIndex { $0.name == r.name } ?? 0) % Theme.slices.count])
                    }
                }
            }
        }
    }
}

/// One model or service: shadcn's Item, xs.
struct Row: View {
    @EnvironmentObject var m: Monitor
    let r: Resource
    let tint: Color

    private var detail: String {
        switch r.state {
        case "ready":
            let use = r.actual_gb.map { gb($0) } ?? "\(gb(r.memory_gb)) reserved"
            if r.active > 0 { return "\(use) · working" + (r.active > 1 ? " on \(r.active)" : "") }
            return use + (r.idle_s.map { " · idle \(ago($0))" } ?? "")
        case "starting": return "loading…"
        case "stopping": return "unloading…"
        default: return r.whole == true ? "needs the whole Mac" : "needs \(gb(r.memory_gb))"
        }
    }

    var body: some View {
        let off = r.state == "off"
        Item(xs: true) {
            Group {
                if r.failed { Image(systemName: "exclamationmark.circle").foregroundStyle(Theme.warn) }
                else if r.busy { Spinner().foregroundStyle(Theme.mutedFg) }
                else { Circle().fill(off ? Theme.faint.opacity(0.5) : Theme.primary).frame(width: 8, height: 8) }
            }
            .frame(width: 16, height: 16)
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                Text(r.name).font(off ? Theme.sm : Theme.smMedium).foregroundStyle(off ? Theme.mutedFg : Theme.foreground).lineLimit(1)
                if let e = r.error, off { Text(e).font(Theme.xs).foregroundStyle(Theme.mutedFg).lineLimit(2).textSelection(.enabled) }
            }
        } actions: {
            HStack(spacing: 8) {
                if !off { RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 10, height: 6).help("Its colour in the memory bar") }
                Text(detail).font(Theme.xs).monospacedDigit().foregroundStyle(Theme.mutedFg).lineLimit(1).fixedSize()
                if r.state == "ready" && r.active == 0 {
                    Button { Task { await m.unload(r.name) } } label: { Image(systemName: "eject") }
                        .buttonStyle(Pine(variant: .ghost, size: .iconXs)).padding(.vertical, -4)
                        .help("Unload \(r.name)")
                }
            }
        }
        .help(r.title)
    }
}

// MARK: - The Mac's load

struct Sparkline: Shape {
    let data: [Double]
    let top: Double
    var closed = false
    func path(in r: CGRect) -> Path {
        var p = Path()
        guard data.count > 1 else { return p }
        let slots = 89.0, n = data.count
        let box = r.insetBy(dx: 0, dy: 1)
        let pts = data.enumerated().map { i, v in
            CGPoint(x: box.minX + box.width * (slots - Double(n - 1 - i)) / slots,
                    y: box.maxY - box.height * min(max(v / max(top, 1), 0), 1))
        }
        p.move(to: pts[0])
        pts.dropFirst().forEach { p.addLine(to: $0) }
        if closed {
            p.addLine(to: CGPoint(x: pts[n - 1].x, y: r.maxY))
            p.addLine(to: CGPoint(x: pts[0].x, y: r.maxY))
            p.closeSubpath()
        }
        return p
    }
}

struct Graphs: View {
    let host: Host
    var body: some View {
        HStack(spacing: 8) {
            Spark(title: "CPU", data: host.cpu_pct, top: 100, unit: "%")
            Spark(title: "GPU", data: host.gpu_pct, top: 100, unit: "%")
            Spark(title: "Memory", data: host.ram_used_gb, top: host.ram_total_gb, unit: "of \(String(format: "%.0f", host.ram_total_gb)) GB")
        }
    }
}

/// One measure of the Mac over the last three minutes: a Card, sm, with a chart along its bottom.
struct Spark: View {
    let title: String
    let data: [Double?]
    let top: Double
    let unit: String

    var body: some View {
        let points = data.suffix(90).map { $0 ?? 0 }
        Card(gap: 8, bottom: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(Theme.mutedFg)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(data.last.flatMap { $0 }.map { String(format: "%.0f", $0) } ?? "n/a").font(Theme.smMedium).foregroundStyle(Theme.foreground).monospacedDigit()
                    Text(unit).font(Theme.xs).foregroundStyle(Theme.mutedFg).lineLimit(1).fixedSize()
                }
            }
            .padding(.horizontal, 12)
            ZStack {
                Sparkline(data: points, top: top, closed: true).fill(Theme.primary.opacity(0.12))
                Sparkline(data: points, top: top).stroke(Theme.primary, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
            .frame(height: 40)
        }
    }
}

// MARK: - Settings

/// Settings, as a settings page of pine's: shadcn's FieldGroup of FieldSets with a FieldSeparator between them.
/// A FieldSet has its legend, a line on what it is for, and its Fields: a label (and a description) with the
/// control at the end of the line, or under it where it is wide.
struct SettingsPane: View {
    @EnvironmentObject var m: Monitor

    var body: some View {
        let admin = m.online && m.status != nil && m.isAdmin
        VStack(alignment: .leading, spacing: 4) {
            Button { m.showSettings = false } label: { Label("Pinecone", systemImage: "chevron.left") }
                .buttonStyle(Pine(variant: .ghost, size: .sm)).foregroundStyle(Theme.mutedFg).padding(.leading, -10)
            Text("Settings").font(Theme.font(20, .semibold)).tracking(-0.4).foregroundStyle(Theme.foreground)
        }
        .padding(.horizontal, 8).padding(8)
        Scrolling {
            VStack(alignment: .leading, spacing: 0) {
                if admin {
                    sets([AnyView(memory), AnyView(scheduler), AnyView(app), AnyView(tokens),
                          AnyView(table("Models", m.models, field: "keep_alive_s", hint: "300",
                                        about: "The memory the scheduler plans for each, and the seconds it stays loaded after its last request, even when something else wants the memory.")),
                          AnyView(table("Services", m.services, field: "idle_stop_s", hint: "never",
                                        about: "The memory the scheduler plans for each, and the seconds of doing nothing after which it is stopped. Empty: never.")),
                          AnyView(media)])
                } else {
                    sets([AnyView(app)])
                    if m.online, m.status != nil {
                        Alert(text: "This token may use the models. Memory, models and tokens are changed in Pinecone on the Mac that runs the scheduler.").padding(.top, 20)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .foregroundStyle(Theme.foreground)
        }
        if admin { saveBar }
    }

    /// FieldSets 20 apart, with a FieldSeparator between each two.
    private func sets(_ list: [AnyView]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(list.indices, id: \.self) { i in
                if i > 0 { Separator().padding(.vertical, 22) }
                list[i]
            }
        }
    }

    private func fieldSet<C: View>(_ legend: String, _ about: String = "", @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text(legend).font(Theme.base)
                if !about.isEmpty { Text(about).foregroundStyle(Theme.mutedFg).fixedSize(horizontal: false, vertical: true) }
            }
            VStack(alignment: .leading, spacing: 20) { content() }
        }
    }

    /// A Field, horizontal: its label and description, and the control at the end.
    private func field<C: View>(_ label: String, _ about: String = "", help: String = "", @ViewBuilder _ control: () -> C) -> some View {
        HStack(alignment: about.isEmpty ? .center : .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(Theme.smMedium)
                if !about.isEmpty { Text(about).foregroundStyle(Theme.mutedFg).fixedSize(horizontal: false, vertical: true) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(help)
            control()
        }
    }

    /// A Field, vertical: the label, the control under it, and its description.
    private func wide<C: View>(_ label: String, _ about: String = "", @ViewBuilder _ control: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(Theme.smMedium)
            control()
            if !about.isEmpty { Text(about).foregroundStyle(Theme.mutedFg).fixedSize(horizontal: false, vertical: true) }
        }
    }

    private func amount(_ path: [String], unit: String, hint: String = "") -> some View {
        Input(hint: hint, text: m.field(path), unit: unit, trailing: true).frame(width: 96)
    }

    // ---- memory split ----
    private var memory: some View {
        let total = max(m.ramTotal, 1), lo = 4.0, hi = (total / 2).rounded(.down)
        return fieldSet("Memory", "How the \(gb(total)) of this Mac are split between models and services and the rest of the system.") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(gb(total - m.reserve)) for models and services").font(Theme.smMedium).lineLimit(1)
                    Spacer()
                    Text("\(plain(m.reserve)) GB for the system").foregroundStyle(Theme.mutedFg)
                }
                .monospacedDigit()
                PineSlider(value: Binding(get: { total - m.reserve }, set: { m.reserve = total - $0 }), range: (total - hi)...(total - lo))
                    .accessibilityLabel("Memory for models and services")
            }
            gpuNote
            field("Let the scheduler set the GPU memory limit", "Off: the limit is left as macOS or you set it.") {
                Toggle("", isOn: m.flag(["manage_gpu_limit"])).toggleStyle(PineSwitch()).labelsHidden()
            }
        }
    }

    @ViewBuilder private var gpuNote: some View {
        if let g = m.status?.gpu_limit {
            if m.gpuNeedsPermission {
                Alert(text: m.allowNote.isEmpty ? "macOS asks for your password once before the scheduler may set the GPU memory limit." : m.allowNote) {
                    if m.gpuInstaller != nil {
                        Button(m.allowing ? "Waiting…" : "Allow…") { Task { await m.allowGpuLimit() } }
                            .buttonStyle(Pine(variant: .outline, size: .sm)).disabled(m.allowing)
                    }
                }
            } else if let e = g.error {
                Alert(destructive: true, icon: "exclamationmark.triangle", text: "The GPU memory limit could not be set: \(e).")
            } else if g.managed, let mb = g.wanted_mb {
                Text("The scheduler set the GPU memory limit to \(gb(mb / 1024)) and puts the macOS default back when it stops.")
                    .foregroundStyle(Theme.mutedFg).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // ---- the scheduler itself ----
    private var scheduler: some View {
        fieldSet("Scheduler", "A change to reachability or port takes effect when the scheduler is started again.") {
            field("Reachable from other devices", "Off: only programs on this Mac can use the scheduler.") {
                Toggle("", isOn: Binding(get: { !["127.0.0.1", "localhost", "::1"].contains(m.form[m.key(["listen", "host"])] ?? "") },
                                         set: { m.form[m.key(["listen", "host"])] = $0 ? "0.0.0.0" : "127.0.0.1" }))
                    .toggleStyle(PineSwitch()).labelsHidden()
            }
            field("Port") { Input(hint: "8080", text: m.field(["listen", "port"]), trailing: true).frame(width: 96) }
            wide("Address for other devices", "Shown under Endpoints, for you to give to clients.") {
                Input(hint: "this Mac's network name", text: m.field(["public_url"]))
            }
            field("A waiting request goes first after", "Then nothing new is given to the models in its way.") {
                amount(["starvation_after_s"], unit: "s", hint: "1800")
            }
        }
    }

    // ---- this app ----
    private var app: some View {
        fieldSet("This app", "Kept on this Mac, not in config.json.") {
            // Normally the app shows the scheduler on this Mac and there is nothing to set. The address is offered
            // when it finds none there, or when it is used to watch a scheduler on another Mac.
            if m.showAddress || !m.isLocal || !m.online {
                VStack(alignment: .leading, spacing: 8) {
                    wide("Scheduler to show", "The address of a scheduler on another Mac, to watch it from here.") {
                        HStack(spacing: 8) {
                            Input(hint: "http://127.0.0.1:8080", text: $m.serverURL).onSubmit { Task { await m.refresh() } }
                            Button("Show") { Task { await m.refresh() } }.buttonStyle(Pine(variant: .outline))
                        }
                    }
                    if !m.isLocal {
                        Button("Show the scheduler on this Mac again") { m.serverURL = "http://127.0.0.1:8080"; m.showAddress = false; Task { await m.refresh() } }
                            .buttonStyle(Pine(variant: .link))
                    }
                }
            }
            if m.unauthorized || (!m.isAdmin && m.online) {
                wide("Access token") {
                    HStack(spacing: 8) {
                        Input(hint: m.hasKeychainKey ? "saved" : "paste a token", text: $m.newKey, secret: true)
                        Button("Use") { m.setKey(m.newKey); m.newKey = ""; Task { await m.refresh() } }
                            .buttonStyle(Pine(variant: .outline)).disabled(m.newKey.isEmpty)
                    }
                }
            }
            field("Open at login") {
                Toggle("", isOn: $m.atLogin).toggleStyle(PineSwitch()).labelsHidden()
                    .onChange(of: m.atLogin) { _, on in
                        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; m.note = "" }
                        catch { m.note = "Could not change the login item: \(error.localizedDescription)"; m.atLogin = SMAppService.mainApp.status == .enabled }
                    }
            }
            field("Appearance", "Light, dark, or what the Mac is set to.") {
                ToggleGroup(options: [("system", "System"), ("light", "Light"), ("dark", "Dark")], value: $m.appearance)
            }
            if !m.note.isEmpty { Text(m.note).foregroundStyle(Theme.destructive).fixedSize(horizontal: false, vertical: true) }
            if m.isLocal && m.online && !m.showAddress {
                Button("Watch a scheduler on another Mac…") { m.showAddress = true }.buttonStyle(Pine(variant: .link))
            }
        }
    }

    // ---- access tokens ----
    private var tokens: some View {
        fieldSet("Access tokens", "A token lets another device or app use the models, as its API key. It cannot change settings.") {
            if !m.tokens.isEmpty {
                VStack(spacing: 10) {
                    ForEach(m.tokens) { t in
                        Item(outline: true) {
                            Image(systemName: "key").foregroundStyle(Theme.foreground).frame(width: 16)
                        } content: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.name).font(Theme.smMedium).lineLimit(1)
                                Text(t.last_used_ago_s.map { "used \(ago($0)) ago" } ?? "never used").foregroundStyle(Theme.mutedFg).monospacedDigit()
                            }
                        } actions: {
                            Button("Revoke") { Task { await m.revokeToken(t.id) } }.buttonStyle(Pine(variant: .ghost, size: .sm))
                        }
                    }
                }
            }
            wide("New token") {
                HStack(spacing: 8) {
                    Input(hint: "Name, for example Laptop", text: $m.tokenName).onSubmit { Task { await m.mintToken() } }
                    Button("Create") { Task { await m.mintToken() } }.buttonStyle(Pine(variant: .outline))
                        .disabled(m.tokenName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if !m.tokenNote.isEmpty { Text(m.tokenNote).foregroundStyle(Theme.destructive) }
            if !m.minted.isEmpty {
                Alert(icon: "key", title: "Token for \(m.mintedName)", text: "Copy it now; it is not shown again.\n\(m.minted)") {
                    Button(m.copied ? "Copied" : "Copy") { m.copyMinted() }.buttonStyle(Pine(variant: .outline, size: .sm))
                }
            }
        }
    }

    // ---- models and services ----
    private func table(_ title: String, _ items: [Resource], field key: String, hint: String, about: String) -> some View {
        fieldSet(title, about) {
            ForEach(items) { r in
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.name).font(Theme.smMedium).lineLimit(1)
                        Text(r.title).foregroundStyle(Theme.mutedFg).lineLimit(1).truncationMode(.tail).help(r.title)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    amount(["resources", r.name, "memory_gb"], unit: "GB")
                    amount(["resources", r.name, key], unit: "s", hint: hint)
                }
            }
        }
    }

    // ---- the media server ----
    private var media: some View {
        let info = m.status?.endpoints?.first { $0.tools != nil }
        return fieldSet("Media tools", info.map { ($0.tools ?? []).joined(separator: ", ") } ?? "The media server is not running.") {
            ForEach((info?.tool_errors ?? [:]).sorted { $0.key < $1.key }, id: \.key) { name, why in
                Alert(destructive: true, icon: "exclamationmark.triangle", title: "\(name) is left out", text: why)
            }
            wide("Address for other devices", "Shown under Endpoints. Takes effect when the media server is started again.") {
                Input(hint: "this Mac only", text: m.field(["media", "public_url"]))
            }
            field("Delete results after", "Pictures, sounds and uploads older than this. 0 keeps them for good.") {
                amount(["media", "keep_days"], unit: "days", hint: "7")
            }
        }
    }

    private var saveBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(m.saving ? "Saving…" : "Save changes") { Task { await m.saveSettings() } }
                    .buttonStyle(Pine(variant: .default)).disabled(!m.dirty || m.saving)
                    .help("Writes what you changed into config.json; the scheduler applies it at once")
                Button("Discard") { m.beginSettings() }.buttonStyle(Pine(variant: .ghost)).disabled(!m.dirty)
                Spacer()
                if m.configPath != nil {
                    Button("Open config file") { m.openConfig() }.buttonStyle(Pine(variant: .outline))
                        .help("Models, services and tools are set up in this file, by you or by an AI agent")
                }
            }
            if !m.saveNote.isEmpty {
                Text(m.saveNote).foregroundStyle(m.saveFailed ? Theme.destructive : Theme.mutedFg).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 8).padding(8)
    }
}
