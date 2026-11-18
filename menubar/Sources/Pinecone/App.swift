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

/// Pinecone's look is pine's (the desktop app in the pine repository): cards that lie on the window, neutral
/// surfaces, one green, and type that does the work. Light and dark follow the system, or the choice in
/// Settings; dark is the poimandres theme. The names and values are those of pine's `desktop/src/styles.css`.
enum Theme {
    static func pair(_ light: UInt32, _ dark: UInt32, _ la: Double = 1, _ da: Double = 1) -> Color {
        func rgb(_ v: UInt32, _ a: Double) -> NSColor {
            NSColor(srgbRed: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255, alpha: a)
        }
        let l = rgb(light, la), d = rgb(dark, da)
        return Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? d : l })
    }
    static let side = pair(0xecede9, 0x13151d, 0.86, 0.88)  // lies on the window's material
    static let window = pair(0xecede9, 0x13151d)  // the same without a material behind it, for pictures
    static let bg = pair(0xfdfdfc, 0x1b1e28)
    static let surface = pair(0xffffff, 0x1e212c)
    static let sunk = pair(0xeff0ed, 0x171922)
    static let press = pair(0x141e18, 0xa6accd, 0.09, 0.12)
    static let hover = pair(0x141e18, 0xa6accd, 0.055, 0.07)
    static let line = pair(0xe1e3de, 0x2b2e3c)
    static let lineSoft = pair(0xecedea, 0x242734)
    static let text = pair(0x1a1d1b, 0xe4f0fb)
    static let muted = pair(0x666e68, 0xa6accd)
    static let faint = pair(0x99a19b, 0x767c9d)
    static let accent = pair(0x1f7a55, 0x5de4c7)
    static let accentSoft = pair(0x1f7a55, 0x5de4c7, 0.1, 0.12)
    static let onAccent = pair(0xffffff, 0x171922)
    static let warn = pair(0xa86a08, 0xfffac2)
    static let bad = pair(0xc2413a, 0xd0679d)
    static let badSoft = pair(0xc2413a, 0xd0679d, 0.1, 0.15)
    /// What is loaded, one colour each in the memory bar. None is the green or the yellow that say a state.
    static let slices: [Color] = [
        pair(0x2a6fc0, 0xadd7ff), pair(0x7c4fd0, 0xd0679d), pair(0x2a8f95, 0x7390aa), pair(0xb8457f, 0xa6accd),
        pair(0x5d6f8a, 0x89ddff), pair(0x8f86c9, 0x5fb3a1), pair(0x4aa3d8, 0x91b4d5), pair(0x99a19b, 0x767c9d),
    ]

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    static let body = font(13)
    static let name = font(13, .medium)
    static let label = font(12.5)
    static let small = font(11.5)
    static let mono = Font.system(size: 11.5, design: .monospaced)
    static let figure = font(17, .semibold)
}

/// A line between two things in a card.
struct Rule: View {
    var color = Theme.lineSoft
    var body: some View { Rectangle().fill(color).frame(height: 1) }
}

/// Pine's small button: a line around a surface. `strong` is the one that does the main thing, `ghost` has no line.
struct SoftButton: ButtonStyle {
    var strong = false
    var ghost = false
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return configuration.label
            .font(Theme.font(12, strong ? .medium : .regular))
            .foregroundStyle(strong ? Theme.onAccent : ghost ? Theme.muted : Theme.text)
            .padding(.horizontal, ghost ? 6 : strong ? 12 : 8)
            .frame(minWidth: 24, minHeight: 24)
            .background(shape.fill(strong ? Theme.accent.opacity(configuration.isPressed ? 0.8 : 1)
                : configuration.isPressed ? Theme.press : ghost ? Color.clear : Theme.surface))
            .overlay(shape.strokeBorder(strong || ghost ? Color.clear : Theme.line, lineWidth: 1))
            .contentShape(Rectangle())
    }
}

struct SectionTitle: View {
    let text: String
    var trailing = ""
    var body: some View {
        HStack {
            Text(text).font(Theme.font(11.5, .semibold)).foregroundStyle(Theme.faint)
            Spacer()
            if !trailing.isEmpty { Text(trailing).font(Theme.small).foregroundStyle(Theme.faint) }
        }
        .padding(.horizontal, 4)
    }
}

struct Panel: View {
    @EnvironmentObject var m: Monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header.padding(.horizontal, 4)
            if m.showSettings {
                SettingsPane()
            } else if m.snapshot {
                overview
            } else {
                ScrollView { overview }.scrollIndicators(.never)
            }
            footer
        }
        .padding(10)
        .frame(width: 400)
        .font(Theme.body).foregroundStyle(Theme.text).tint(Theme.accent)
        // One size for every view of the panel: the menu bar window does not move back under its icon when
        // its content changes height, so a panel that grows and shrinks ends up in the wrong place.
        .frame(height: m.snapshot ? nil : Self.height, alignment: .top)
        .background(m.snapshot ? Color.clear : Theme.side)
    }

    /// As tall as the content usually needs, but never taller than the screen has room for.
    static let height: CGFloat = min(760, (NSScreen.main?.visibleFrame.height ?? 800) - 24)

    @ViewBuilder private var overview: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let s = m.status, m.online {
                if let e = s.config?.error { configProblem(e) }
                Card { memoryBar(s) }
                VStack(alignment: .leading, spacing: 4) {
                    folder("Models", m.models)
                    folder("Services", m.services)
                }
                if !s.queue.isEmpty { queue(s.queue) }
                if let h = s.host { Graphs(host: h) }
                if let e = s.endpoints, !e.isEmpty { endpoints(e) }
                if !s.events.isEmpty { activity(s.events) }
            } else {
                Card {
                    Text(m.problem.isEmpty ? "Connecting…" : m.problem)
                        .font(Theme.label).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle().fill(m.online ? (m.working ? Theme.warn : Theme.accent) : Theme.faint.opacity(0.6)).frame(width: 8, height: 8)
            Text(m.showSettings ? "Settings" : "Pinecone").font(Theme.font(14.5, .semibold))
            if !m.showSettings && !m.isLocal { Text(m.hostLabel).font(Theme.small).foregroundStyle(Theme.faint) }  // only when watching another Mac
            Spacer()
            if !m.showSettings {
                Text(m.serviceBusy ? (m.online ? "Stopping…" : "Starting…") : (m.online ? (m.working ? "Working" : "On") : "Off"))
                    .font(Theme.label).foregroundStyle(Theme.muted)
                if !m.labels.isEmpty {  // starts and stops the scheduler and what belongs to it
                    Toggle("", isOn: Binding(get: { m.online }, set: { on in Task { await m.setServices(running: on) } }))
                        .toggleStyle(Slide()).labelsHidden()
                        .disabled(m.serviceBusy).opacity(m.serviceBusy ? 0.5 : 1)
                        .help(m.online ? "Stop the scheduler and everything it runs" : "Start the scheduler")
                }
            }
        }
    }

    /// One slice of the memory bar: a loaded model or service, or everything else on the Mac.
    struct Slice: Identifiable { let id: String; let gb: Double; let color: Color }
    static let palette = Theme.slices

    private func memoryBar(_ s: Status) -> some View {
        let total = max(s.host?.ram_total_gb ?? s.budget_gb, 1)
        var slices: [Slice] = []
        for (i, r) in m.resources.enumerated() where r.state != "off" {
            // while it loads, what it holds so far, so that its slice grows into the bar
            let holds = r.actual_gb ?? (r.state == "starting" ? 0 : r.memory_gb)
            slices.append(Slice(id: r.name, gb: holds, color: Self.palette[i % Self.palette.count]))
        }
        let ours = slices.reduce(0) { $0 + $1.gb }
        let used = s.host?.ram_used_gb.compactMap { $0 }.last
        if let used, used - ours > 0.5 { slices.append(Slice(id: "system and apps", gb: used - ours, color: Theme.faint.opacity(0.55))) }
        let free = max(0, total - slices.reduce(0) { $0 + $1.gb })
        return VStack(alignment: .leading, spacing: 8) {
            GeometryReader { g in
                HStack(spacing: 1.5) {
                    ForEach(slices) { sl in
                        Rectangle().fill(sl.color).frame(width: max(2, g.size.width * min(1, sl.gb / total)))
                            .transition(.asymmetric(insertion: .identity, removal: .opacity))
                    }
                    Spacer(minLength: 0)
                }
                // The scheduler reports every two seconds; the bar moves between two reports instead of jumping.
                .animation(.easeInOut(duration: 1.8), value: slices.map(\.gb))
            }
            .frame(height: 8)
            .background(GeometryReader { g in
                // the right end is what the scheduler keeps free for the system
                HStack(spacing: 0) {
                    Theme.press
                    Theme.faint.opacity(0.3).frame(width: g.size.width * min(1, max(0, total - s.budget_gb) / total))
                }
            })
            .clipShape(Capsule())
            .help("The darker end is the \(gb(max(0, total - s.budget_gb))) kept for the system")
            // a grid, so the entries wrap onto more lines when several things are loaded
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 3) {
                ForEach(slices) { sl in
                    HStack(spacing: 4) {
                        Circle().fill(sl.color).frame(width: 6, height: 6)
                        Text("\(sl.id) \(gb(sl.gb))").lineLimit(1).contentTransition(.numericText())
                    }
                }
                Text("\(gb(free)) free").foregroundStyle(Theme.faint).lineLimit(1).contentTransition(.numericText())
            }
            .font(Theme.small).monospacedDigit().foregroundStyle(Theme.muted)
            .animation(.easeInOut(duration: 0.6), value: slices.map(\.gb))
        }
    }

    /// Models or services, as pine's side bar has an agent and its conversations: a line that folds the list
    /// away, and the list under it. The line shows work going on in the list, so it is seen when folded too.
    @ViewBuilder private func folder(_ title: String, _ items: [Resource]) -> some View {
        if !items.isEmpty {
            let folded = m.folded.contains(title)
            VStack(alignment: .leading, spacing: 0) {
                Button { m.folded.formSymmetricDifference([title]) } label: {
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: folded ? "chevron.right" : "chevron.down").font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Theme.faint).frame(width: 10, height: 20)
                        Text(String(title.prefix(1))).font(Theme.font(11, .semibold)).foregroundStyle(Theme.muted).frame(width: 20, height: 20)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.press))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(title).font(Theme.font(13, .semibold)).frame(height: 20)
                            Text("\(items.filter { $0.state != "off" }.count) of \(items.count) loaded").font(Theme.small).foregroundStyle(Theme.faint).frame(height: 15)
                        }
                        Spacer(minLength: 4)
                        HStack(spacing: 6) {
                            if items.contains(where: { $0.busy }) { Spinner() }
                            if items.contains(where: { $0.failed }) { Needs() }
                        }
                        .frame(height: 20)
                    }
                    .padding(EdgeInsets(top: 5, leading: 6, bottom: 5, trailing: 8))
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(m.hover == title ? Theme.hover : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { over in if over { m.hover = title } else if m.hover == title { m.hover = "" } }
                .help(folded ? "Show the \(title.lowercased())" : "Hide the \(title.lowercased())")
                if !folded {
                    ForEach(items) { r in
                        Row(r: r, tint: Self.palette[(m.resources.firstIndex { $0.name == r.name } ?? 0) % Self.palette.count])
                    }
                }
            }
        }
    }

    private func queue(_ q: [Waiting]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Waiting")
            Card {
                ForEach(q, id: \.self) { w in
                    if w != q.first { Rule() }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(w.resource): \(ago(w.waiting_s))").font(Theme.label).monospacedDigit()
                        if let why = w.reason { Text(why).font(Theme.small).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true) }
                    }
                }
            }
        }
    }

    /// The addresses to give to clients, each with a button that copies it.
    private func endpoints(_ list: [Endpoint]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Endpoints", trailing: "an access token is the key")
            Card {
                ForEach(list, id: \.self) { e in
                    if e != list.first { Rule() }
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.name).font(Theme.small).foregroundStyle(Theme.muted).lineLimit(1)
                            Text(e.url).font(Theme.mono).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                        }
                        Spacer(minLength: 6)
                        Button(m.copiedURL == e.url ? "Copied" : "Copy") { m.copy(e.url) }.buttonStyle(SoftButton())
                    }
                }
            }
        }
    }

    private func activity(_ events: [Event]) -> some View {
        let shown = Array(events.prefix(m.moreEvents ? 14 : 4))
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Recent activity").font(Theme.font(11.5, .semibold)).foregroundStyle(Theme.faint)
                Spacer()
                if events.count > 4 {
                    Button(m.moreEvents ? "Show less" : "Show more") { m.moreEvents.toggle() }
                        .buttonStyle(.plain).font(Theme.small).foregroundStyle(Theme.faint)
                }
            }
            .padding(.horizontal, 4)
            Card(spacing: 5) {
                ForEach(Array(shown.enumerated()), id: \.offset) { _, e in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(ago(e.ago_s)).font(Theme.small).monospacedDigit().foregroundStyle(Theme.faint).frame(width: 40, alignment: .trailing)
                        Text(e.text).font(Theme.small).foregroundStyle(Theme.muted).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func configProblem(_ e: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("config.json has a mistake. The last good version stays in use.").font(Theme.font(11.5, .semibold)).foregroundStyle(Theme.bad)
            Text(e).font(Theme.small).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.badSoft))
    }

    private var footer: some View {
        HStack(spacing: 2) {
            Spacer()
            Button { m.showSettings.toggle(); if m.showSettings { m.beginSettings() } } label: { Image(systemName: m.showSettings ? "chevron.backward" : "gearshape") }
                .help(m.showSettings ? "Back" : "Settings")
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(SoftButton(ghost: true))
    }
}

extension Resource {
    /// Loading, unloading, or answering a request.
    var busy: Bool { active > 0 || state == "starting" || state == "stopping" }
    /// It did not start, and says why.
    var failed: Bool { state == "off" && error != nil }
}

/// Pine's sign for work going on: a ring with a green quarter that goes round.
struct Spinner: View {
    @EnvironmentObject var m: Monitor
    var size: CGFloat = 11
    var body: some View {
        if m.snapshot {
            ring(60)  // a picture stands still
        } else {
            TimelineView(.animation) { t in ring(t.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.7) / 0.7 * 360) }
        }
    }

    private func ring(_ degrees: Double) -> some View {
        ZStack {
            Circle().strokeBorder(Theme.press, lineWidth: 1.6)
            Circle().inset(by: 0.8).trim(from: 0, to: 0.25).stroke(Theme.accent, lineWidth: 1.6).rotationEffect(.degrees(degrees - 135))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("working")
    }
}

/// Pine's sign for something that needs a look.
struct Needs: View {
    var body: some View {
        Text("!").font(Theme.font(10, .bold)).foregroundStyle(Color(red: 0.1, green: 0.07, blue: 0.02))
            .frame(width: 14, height: 14).background(Circle().fill(Theme.warn))
    }
}

/// One model or service, as a line under its folder.
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Group {
                    if r.failed { Needs() } else if r.busy { Spinner() } else { Circle().fill(off ? Theme.faint.opacity(0.45) : Theme.accent).frame(width: 7, height: 7) }
                }
                .frame(width: 14)
                Text(r.name).foregroundStyle(off ? Theme.muted : Theme.text).lineLimit(1).layoutPriority(1)
                Spacer(minLength: 4)
                if !off { RoundedRectangle(cornerRadius: 1.5).fill(tint).frame(width: 10, height: 6).help("Colour in the memory bar") }
                Text(detail).font(Theme.small).monospacedDigit().foregroundStyle(off ? Theme.faint : Theme.muted).lineLimit(1).fixedSize()
                if r.state == "ready" && r.active == 0 {
                    Button { Task { await m.unload(r.name) } } label: { Image(systemName: "eject.fill").font(.system(size: 9)) }
                        .buttonStyle(SoftButton(ghost: true)).padding(.horizontal, -4)
                        .help("Unload \(r.name)")
                }
            }
            .frame(height: 30)
            if let e = r.error, off {
                Text(e).font(Theme.small).foregroundStyle(Theme.bad).lineLimit(2).padding(.leading, 21).padding(.bottom, 6)
            }
        }
        .padding(.leading, 30).padding(.trailing, 8)
        .help(r.title)
    }
}

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

struct Spark: View {
    let title: String
    let data: [Double?]
    let top: Double
    let unit: String

    var body: some View {
        let points = data.suffix(90).map { $0 ?? 0 }
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Theme.small).foregroundStyle(Theme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(data.last.flatMap { $0 }.map { String(format: "%.0f", $0) } ?? "n/a")
                    .font(Theme.figure).tracking(-0.3).monospacedDigit()
                Text(unit).font(Theme.font(10.5)).foregroundStyle(Theme.faint).lineLimit(1).fixedSize()
            }
            ZStack {
                Sparkline(data: points, top: top, closed: true).fill(Theme.accentSoft)
                Sparkline(data: points, top: top).stroke(Theme.accent, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
            .frame(height: 34)
            .padding(.top, 4)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Card<EmptyView>.shape.fill(Theme.bg))
        .overlay(Card<EmptyView>.shape.strokeBorder(Theme.line, lineWidth: 1))
    }
}

/// A switch with a knob that slides, drawn here so it looks the same everywhere in the panel.
struct Slide: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.label
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule().fill(configuration.isOn ? Theme.accent : Theme.press).frame(width: 34, height: 20)
                Circle().fill(Color.white).shadow(color: .black.opacity(0.25), radius: 1, y: 0.5).frame(width: 16, height: 16).padding(2)
            }
            .animation(.easeOut(duration: 0.15), value: configuration.isOn)
            .contentShape(Rectangle())
            .onTapGesture { configuration.isOn.toggle() }
        }
    }
}

/// A choice between a few words, as pine has them: a sunk strip, and the chosen word raised on it.
struct Segmented: View {
    let options: [(value: String, label: String)]
    @Binding var value: String
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { o in
                let on = o.value == value
                Button { value = o.value } label: {
                    Text(o.label).font(Theme.font(12)).foregroundStyle(on ? Theme.text : Theme.muted)
                        .padding(.horizontal, 9).frame(height: 20)
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(on ? Theme.surface : Color.clear)
                            .shadow(color: .black.opacity(on ? 0.12 : 0), radius: 1, y: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.sunk))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.lineSoft, lineWidth: 1))
    }
}

/// A text field as pine has them: a line around a surface.
struct EditBox: View {
    @EnvironmentObject var m: Monitor
    let hint: String
    @Binding var text: String
    var align: TextAlignment = .leading
    var secret = false
    var body: some View {
        Group {
            if m.snapshot {  // pictures cannot draw real text fields
                Text(text.isEmpty ? hint : text).foregroundStyle(text.isEmpty ? Theme.faint : Theme.text).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: align == .trailing ? .trailing : .leading)
            } else if secret {
                SecureField(hint, text: $text).textFieldStyle(.plain)
            } else {
                TextField(hint, text: $text).textFieldStyle(.plain).multilineTextAlignment(align)
            }
        }
        .font(Theme.font(12)).monospacedDigit()
        .padding(.horizontal, 8).padding(.vertical, 4.5)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }
}

/// A panel of pine: a card of its own on the window, with a line around it.
struct Card<Content: View>: View {
    var spacing: CGFloat = 9
    @ViewBuilder var content: Content
    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 11, style: .continuous) }
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Self.shape.fill(Theme.bg))
            .overlay(Self.shape.strokeBorder(Theme.line, lineWidth: 1))
    }
}

struct SettingsPane: View {
    @EnvironmentObject var m: Monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if m.snapshot { content } else { ScrollView { content }.scrollIndicators(.never) }
            if m.online, m.status != nil, m.isAdmin {  // stays in view while the settings above scroll
                saveBar
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            let admin = m.online && m.status != nil && m.isAdmin
            if admin {
                memory
                scheduler
            }
            app
            if admin {
                tokens
                table("Models", m.models, time: "Keep loaded", field: "keep_alive_s", hint: "300",
                      help: "Seconds a model stays loaded after its last request, even when something else wants the memory")
                table("Services", m.services, time: "Stop when idle", field: "idle_stop_s", hint: "never",
                      help: "Seconds of doing nothing after which the service is stopped; empty means never")
                media
            } else if m.online, m.status != nil {
                Text("This token may use the models. Memory, models and tokens are changed in Pinecone on the Mac that runs the scheduler.")
                    .font(Theme.small).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4)
            }
        }
    }

    private func line<V: View>(_ label: String, help: String = "", @ViewBuilder _ value: () -> V) -> some View {
        HStack(spacing: 10) {
            Text(label).font(Theme.label).lineLimit(1).fixedSize().help(help)
            Spacer(minLength: 8)
            value()
        }
    }

    /// A label with a field for one setting; `unit` follows a short field.
    private func setting(_ label: String, _ path: [String], hint: String = "", unit: String = "", wide: Bool = false, help: String = "") -> some View {
        line(label, help: help) {
            // a wide field takes what the label leaves, so a long label cannot push the panel wider
            EditBox(hint: hint, text: m.field(path), align: wide ? .leading : .trailing).frame(minWidth: wide ? 80 : 64, maxWidth: wide ? 200 : 64)
            if !unit.isEmpty { Text(unit).font(Theme.small).foregroundStyle(Theme.faint).frame(width: 18, alignment: .leading) }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(Theme.small).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
    }

    // ---- the scheduler itself ----
    private var scheduler: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Scheduler")
            Card {
                Toggle(isOn: Binding(get: { !["127.0.0.1", "localhost", "::1"].contains(m.form[m.key(["listen", "host"])] ?? "") },
                                     set: { m.form[m.key(["listen", "host"])] = $0 ? "0.0.0.0" : "127.0.0.1" })) {
                    Text("Reachable from other devices").font(Theme.label).frame(maxWidth: .infinity, alignment: .leading)
                }
                .toggleStyle(Slide()).help("Off: only programs on this Mac can use the scheduler")
                Rule()
                setting("Port", ["listen", "port"], hint: "8080")
                Rule()
                setting("Address for other devices", ["public_url"], hint: "this Mac's network name", wide: true,
                        help: "Shown under Endpoints, for you to give to clients")
                Rule()
                setting("A waiting request goes first after", ["starvation_after_s"], hint: "1800", unit: "s",
                        help: "Once a request has waited this long, nothing new is given to the models in its way")
                note("A change to reachability or port takes effect when the scheduler is started again.")
            }
        }
    }

    // ---- this app ----
    private var app: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "This app")
            Card {
                // Normally the app shows the scheduler on this Mac and there is nothing to set. The address is
                // offered when it finds none there, or when it is used to watch a scheduler on another Mac.
                if m.showAddress || !m.isLocal || !m.online {
                    line("Scheduler to show", help: "The address of a scheduler on another Mac, to watch it from here") {
                        EditBox(hint: "http://127.0.0.1:8080", text: $m.serverURL).frame(minWidth: 80, maxWidth: 200).onSubmit { Task { await m.refresh() } }
                    }
                    if !m.isLocal {
                        Button("Show the scheduler on this Mac again") { m.serverURL = "http://127.0.0.1:8080"; m.showAddress = false; Task { await m.refresh() } }
                            .buttonStyle(.plain).font(Theme.small).foregroundStyle(Theme.faint)
                    }
                    Rule()
                }
                Toggle(isOn: $m.atLogin) { Text("Open at login").font(Theme.label).frame(maxWidth: .infinity, alignment: .leading) }
                    .toggleStyle(Slide())
                    .onChange(of: m.atLogin) { _, on in
                        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; m.note = "" }
                        catch { m.note = "Could not change the login item: \(error.localizedDescription)"; m.atLogin = SMAppService.mainApp.status == .enabled }
                    }
                Rule()
                line("Appearance", help: "Light, dark, or what the Mac is set to") {
                    Segmented(options: [("system", "System"), ("light", "Light"), ("dark", "Dark")], value: $m.appearance)
                }
                if m.unauthorized || (!m.isAdmin && m.online) {
                    Rule()
                    line("Access token") {
                        EditBox(hint: m.hasKeychainKey ? "saved" : "paste a token", text: $m.newKey, secret: true).frame(width: 150)
                        Button("Use") { m.setKey(m.newKey); m.newKey = ""; Task { await m.refresh() } }
                            .buttonStyle(SoftButton()).disabled(m.newKey.isEmpty)
                    }
                }
                if !m.note.isEmpty { Text(m.note).font(Theme.small).foregroundStyle(Theme.bad).fixedSize(horizontal: false, vertical: true) }
                if m.isLocal && m.online && !m.showAddress {
                    Button("Watch a scheduler on another Mac…") { m.showAddress = true }
                        .buttonStyle(.plain).font(Theme.small).foregroundStyle(Theme.faint)
                }
            }
        }
    }

    // ---- access tokens ----
    private var tokens: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Access tokens", trailing: m.tokens.isEmpty ? "none yet" : "\(m.tokens.count)")
            Card {
                Text("A token lets another device or app use the models, as its API key. It cannot change settings.")
                    .font(Theme.small).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                ForEach(m.tokens) { t in
                    Rule()
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill").font(.system(size: 9)).foregroundStyle(Theme.faint)
                        Text(t.name).font(Theme.label).lineLimit(1)
                        Spacer(minLength: 6)
                        Text(t.last_used_ago_s.map { "used \(ago($0)) ago" } ?? "never used").font(Theme.small).monospacedDigit().foregroundStyle(Theme.faint).lineLimit(1).fixedSize()
                        Button("Revoke") { Task { await m.revokeToken(t.id) } }.buttonStyle(SoftButton())
                    }
                }
                Rule()
                HStack(spacing: 8) {
                    EditBox(hint: "Name, for example Laptop", text: $m.tokenName).onSubmit { Task { await m.mintToken() } }
                    Button("Create") { Task { await m.mintToken() } }.buttonStyle(SoftButton())
                        .disabled(m.tokenName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if !m.minted.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Token for \(m.mintedName). Copy it now; it is not shown again.").font(Theme.small).foregroundStyle(Theme.muted)
                        HStack(spacing: 8) {
                            Text(m.minted).font(Theme.mono).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                            Spacer(minLength: 4)
                            Button(m.copied ? "Copied" : "Copy") { m.copyMinted() }.buttonStyle(SoftButton())
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.accentSoft))
                }
                if !m.tokenNote.isEmpty { Text(m.tokenNote).font(Theme.small).foregroundStyle(Theme.bad) }
            }
        }
    }

    // ---- memory split ----
    private var memory: some View {
        let total = max(m.ramTotal, 1), lo = 4.0, hi = (total / 2).rounded(.down)
        func set(_ v: Double) { m.reserve = min(hi, max(lo, v.rounded())) }
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Memory", trailing: "\(gb(total)) in this Mac")
            Card {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(gb(total - m.reserve)).font(Theme.figure).tracking(-0.3).monospacedDigit()
                        Text("for models and services").font(Theme.small).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(plain(m.reserve)) GB").font(Theme.figure).tracking(-0.3).monospacedDigit()
                        Text("kept for the system").font(Theme.small).foregroundStyle(Theme.muted)
                    }
                }
                GeometryReader { g in
                    let x = g.size.width * (1 - m.reserve / total)
                    ZStack(alignment: .leading) {
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Theme.accent).frame(width: max(0, x - 1))
                            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Theme.faint.opacity(0.5))
                        }
                        .frame(height: 10)
                        Capsule().fill(Color.white).frame(width: 5, height: 22).shadow(color: .black.opacity(0.35), radius: 1.5, y: 0.5).offset(x: x - 2.5)
                    }
                    .frame(height: 22)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { v in set(total * (1 - v.location.x / max(g.size.width, 1))) })
                }
                .frame(height: 22)
                HStack(spacing: 6) {
                    Text("Drag the handle, or").font(Theme.small).foregroundStyle(Theme.faint)
                    Button { set(m.reserve - 1) } label: { Image(systemName: "minus") }.buttonStyle(SoftButton()).help("Keep less for the system")
                    Button { set(m.reserve + 1) } label: { Image(systemName: "plus") }.buttonStyle(SoftButton()).help("Keep more for the system")
                    Spacer()
                }
                gpuLine
                Rule()
                Toggle(isOn: m.flag(["manage_gpu_limit"])) {
                    Text("Let the scheduler set the GPU memory limit").font(Theme.label).frame(maxWidth: .infinity, alignment: .leading)
                }
                .toggleStyle(Slide()).help("Off: the limit is left as macOS or you set it")
            }
        }
    }

    @ViewBuilder private var gpuLine: some View {
        if let g = m.status?.gpu_limit {
            if m.gpuNeedsPermission {
                Rule()
                HStack(alignment: .center, spacing: 10) {
                    Text(m.allowNote.isEmpty ? "macOS asks for your password once before the scheduler may set the GPU memory limit." : m.allowNote)
                        .font(Theme.small).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if m.gpuInstaller != nil {
                        Button(m.allowing ? "Waiting…" : "Allow…") { Task { await m.allowGpuLimit() } }.buttonStyle(SoftButton()).disabled(m.allowing)
                    }
                }
            } else if let e = g.error {
                Text("The GPU memory limit could not be set: \(e).").font(Theme.small).foregroundStyle(Theme.warn).fixedSize(horizontal: false, vertical: true)
            } else if g.managed, let mb = g.wanted_mb {
                Text("The scheduler set the GPU memory limit to \(gb(mb / 1024)) and puts the macOS default back when it stops.")
                    .font(Theme.small).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // ---- models and services ----
    private func head(_ text: String, _ unit: String = "", help: String = "") -> some View {
        (Text(text) + Text(unit.isEmpty ? "" : "  \(unit)").foregroundColor(Theme.faint))
            .font(Theme.font(11)).foregroundStyle(Theme.muted).lineLimit(1).fixedSize().help(help)
    }

    private func table(_ title: String, _ items: [Resource], time: String, field: String, hint: String, help: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: title)
            Card {
                HStack(spacing: 10) {
                    head("Name")
                    Spacer(minLength: 0)
                    head("Memory", "GB", help: "How much memory the scheduler plans for it")
                    head(time, "s", help: help).frame(width: 96, alignment: .trailing)
                }
                ForEach(items) { r in
                    Rule()
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.name).font(Theme.name).lineLimit(1)
                            Text(r.title).font(Theme.small).foregroundStyle(Theme.faint).lineLimit(1).truncationMode(.tail).help(r.title)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        EditBox(hint: "", text: m.field(["resources", r.name, "memory_gb"]), align: .trailing).frame(width: 52)
                        EditBox(hint: hint, text: m.field(["resources", r.name, field]), align: .trailing).frame(width: 52).frame(width: 96, alignment: .trailing)
                    }
                }
            }
        }
    }

    // ---- the media server ----
    private var media: some View {
        let info = m.status?.endpoints?.first { $0.tools != nil }
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Media tools", trailing: info.map { "\($0.tools?.count ?? 0) tools" } ?? "not running")
            Card {
                setting("Address for other devices", ["media", "public_url"], hint: "this Mac only", wide: true,
                        help: "Shown under Endpoints, for you to give to clients. Takes effect when the media server is started again")
                Rule()
                setting("Delete results after", ["media", "keep_days"], hint: "7", unit: "d",
                        help: "Pictures and sounds the tools made, and uploaded files, are deleted when they are older than this many days. 0 keeps them for good")
                Rule()
                if let info {
                    Text((info.tools ?? []).joined(separator: ", ")).font(Theme.small).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    ForEach((info.tool_errors ?? [:]).sorted { $0.key < $1.key }, id: \.key) { name, why in
                        Text("\(name) is left out: \(why)").font(Theme.small).foregroundStyle(Theme.bad).fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    note("The media server is not running.")
                }
            }
        }
    }

    private var saveBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button(m.saving ? "Saving…" : "Save") { Task { await m.saveSettings() } }
                    .buttonStyle(SoftButton(strong: true)).help("Writes what you changed into config.json; the scheduler applies it at once")
                    .disabled(!m.dirty || m.saving).opacity(m.dirty ? 1 : 0.45)
                Button("Revert") { m.beginSettings() }.buttonStyle(SoftButton()).disabled(!m.dirty).opacity(m.dirty ? 1 : 0.45)
                Spacer()
                if m.configPath != nil {
                    Button("Open config file") { m.openConfig() }.buttonStyle(SoftButton()).help("Models, services and tools are set up in this file, by you or by an AI agent")
                }
            }
            if !m.saveNote.isEmpty {
                Text(m.saveNote).font(Theme.small).foregroundStyle(m.saveFailed ? Theme.bad : Theme.muted).padding(.horizontal, 4).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
