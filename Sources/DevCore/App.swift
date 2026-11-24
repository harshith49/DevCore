import SwiftUI
import Charts
#if canImport(DevCoreCore)
import DevCoreCore
#endif

@MainActor
final class DevCoreModel: ObservableObject {
    @Published var snapshot: SystemSnapshot?
    @Published var history: [CPUSample] = []
    @Published var ports: [ListeningPort] = []
    @Published var systemError: String?
    @Published var portError: String?
    @Published var loadingPorts = false
    @Published var lastPortRefresh: Date?
    private let monitor = SystemMonitor()
    func refreshSystem() {
        do {
            let value = try monitor.sample()
            snapshot = value
            systemError = nil
            if let cpu = value.cpu {
                history.append(CPUSample(date: Date(), percent: cpu * 100))
                history = Array(history.suffix(60))
            }
        } catch { systemError = error.localizedDescription }
    }
    func refreshPorts() async {
        guard !loadingPorts else { return }
        loadingPorts = true
        defer { loadingPorts = false }
        do {
            ports = try await Task.detached(priority: .utility) { try PortInspector.inspect() }.value
            lastPortRefresh = Date()
            portError = nil
        } catch { portError = error.localizedDescription }
    }
}
struct CPUSample: Identifiable { let id = UUID(); let date: Date; let percent: Double }
enum Page: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard", ports = "Port Manager"
    var id: String { rawValue }
    var icon: String { self == .dashboard ? "chart.xyaxis.line" : "network" }
}
@main
struct DevCoreApp: App {
    @StateObject private var model = DevCoreModel()
    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .tint(.mint)
                .frame(minWidth: 850, minHeight: 570)
        }
        .commands { SidebarCommands() }
        Settings { Text("DevCore follows your macOS appearance. All monitoring stays on this Mac.").padding(24).frame(width: 350) }
    }
}
struct ContentView: View {
    @ObservedObject var model: DevCoreModel
    @State private var selection: Page? = .dashboard
    @State private var search = ""
    @FocusState private var searchFocused: Bool
    var filteredPorts: [ListeningPort] {
        model.ports.filter { search.isEmpty || "\($0.process) \($0.pid) \($0.endpoint)".localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 20) {
                Label("DevCore", systemImage: "square.stack.3d.up.fill").font(.title2.bold()).foregroundStyle(.mint).padding(.horizontal)
                List(selection: $selection) {
                    ForEach(Page.allCases.filter { search.isEmpty || $0.rawValue.localizedCaseInsensitiveContains(search) }) { page in Label(page.rawValue, systemImage: page.icon).tag(page) }
                }
                Text("LOCAL • PRIVATE • FREE").font(.caption2).foregroundStyle(.secondary).padding()
            }.padding(.top, 16).navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text((selection ?? .dashboard).rawValue).font(.largeTitle.bold())
                        Text(selection == .ports ? "TCP listeners visible to your macOS account" : "A live view of your Mac").foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("Search modules, ports, PIDs", text: $search).textFieldStyle(.roundedBorder).frame(width: 240).focused($searchFocused)
                }
                if selection == .ports { portsView } else { dashboard }
            }.padding(28).background(.background)
            .toolbar {
                Button { Task { model.refreshSystem(); await model.refreshPorts() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }.keyboardShortcut("r")
                Button { searchFocused = true } label: { Label("Search", systemImage: "magnifyingglass") }.keyboardShortcut("k")
            }
        }
        .task {
            model.refreshSystem()
            await model.refreshPorts()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(2)) } catch { break }
                model.refreshSystem()
            }
        }
    }
    var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let error = model.systemError { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                if let s = model.snapshot {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210))], spacing: 16) {
                        metric("CPU", value: s.cpu.map { String(format: "%.1f%%", $0 * 100) } ?? "Sampling…", detail: "Across all logical cores", icon: "cpu")
                        metric("Memory", value: bytes(Int64(s.memoryUsed)), detail: "of \(bytes(Int64(s.memoryTotal))) • resident + compressed estimate", icon: "memorychip")
                        metric("Storage", value: bytes(s.storageFree), detail: "Available of \(bytes(s.storageTotal)) on home volume", icon: "internaldrive")
                        metric("Battery", value: s.batteryPercent.map { "\($0)%" } ?? "—", detail: s.batteryState, icon: "battery.100percent")
                    }
                }
                VStack(alignment: .leading, spacing: 16) {
                    Text("CPU activity").font(.headline)
                    Chart(model.history) { point in
                        AreaMark(x: .value("Time", point.date), y: .value("CPU %", point.percent)).foregroundStyle(.mint.opacity(0.12))
                        LineMark(x: .value("Time", point.date), y: .value("CPU %", point.percent)).foregroundStyle(.mint).interpolationMethod(.monotone)
                    }.chartYScale(domain: 0...100).chartXSelection(value: $selectedTime).frame(height: 210)
                    if let selectedTime, let point = model.history.min(by: { abs($0.date.timeIntervalSince(selectedTime)) < abs($1.date.timeIntervalSince(selectedTime)) }) {
                        Text("\(point.date.formatted(date: .omitted, time: .standard)): \(point.percent, specifier: "%.1f")% CPU").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                Text("Updates every 2 seconds. Memory includes reclaimable inactive pages; values can differ from Activity Monitor. No elevated permissions required.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    @State private var selectedTime: Date?
    var portsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(filteredPorts.count) listeners").font(.headline)
                Spacer()
                if model.loadingPorts { ProgressView().controlSize(.small) }
                if let date = model.lastPortRefresh { Text("Updated \(date.formatted(date: .omitted, time: .standard))").foregroundStyle(.secondary).font(.caption) }
            }
            if let error = model.portError { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            Table(filteredPorts) {
                TableColumn("Process", value: \.process)
                TableColumn("PID") { Text(String($0.pid)).monospacedDigit() }.width(80)
                TableColumn("Port") { Text($0.port.map(String.init) ?? "—").monospacedDigit() }.width(80)
                TableColumn("Listening address", value: \.endpoint)
            }.overlay {
                if filteredPorts.isEmpty && !model.loadingPorts { ContentUnavailableView("No visible listeners", systemImage: "network", description: Text("Refresh or adjust your search. Some processes are hidden by macOS permissions.")) }
            }
            Text("Read-only inspection using /usr/sbin/lsof. TCP only. DevCore never elevates privileges or terminates a process. Press ⌘R to refresh.").font(.caption).foregroundStyle(.secondary)
        }
    }
    func metric(_ title: String, value: String, detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).foregroundStyle(.secondary)
            Text(value).font(.system(size: 29, weight: .semibold, design: .rounded)).contentTransition(.numericText())
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, minHeight: 120, alignment: .leading).padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
    func bytes(_ value: Int64) -> String { ByteCountFormatter.string(fromByteCount: value, countStyle: .binary) }
}
