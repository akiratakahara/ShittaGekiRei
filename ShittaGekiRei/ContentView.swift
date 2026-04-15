import SwiftUI

struct ContentView: View {
    @StateObject private var notif   = NotificationManager.shared
    @StateObject private var alarm   = AlarmManager.shared
    @State private var currentMessage = ""
    @State private var currentMode: NotificationMode = .monday
    @State private var isShaking = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MainView(
                currentMessage: $currentMessage,
                currentMode: $currentMode,
                isShaking: $isShaking
            )
            .tabItem { Label("叱咤", systemImage: "flame.fill") }
            .tag(0)

            SettingsView()
            .tabItem { Label("設定", systemImage: "gear") }
            .tag(1)
        }
        .preferredColorScheme(.dark)
        // アラーム鳴動中オーバーレイ
        .overlay {
            if alarm.isRinging {
                RingingOverlay(mode: alarm.ringingMode ?? currentMode, message: alarm.currentSpokenMessage) {
                    alarm.stopRinging()
                }
            }
        }
        .task {
            await notif.checkAuthorization()
            alarm.startPolling()
        }
        .onDisappear { alarm.stopPolling() }
    }
}

// MARK: - Main Tab
struct MainView: View {
    @Binding var currentMessage: String
    @Binding var currentMode: NotificationMode
    @Binding var isShaking: Bool
    @State private var isLoading = false

    private let modes: [NotificationMode] = [.monday, .thursday, .friday]

    var accentColor: Color {
        switch currentMode {
        case .monday:   return Color(hex: "CC0000")
        case .thursday: return Color(hex: "B34400")
        case .friday:   return Color(hex: "007ACC")
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color.clear, accentColor.opacity(0.12)],
                center: .center, startRadius: 100, endRadius: 400
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentMode)

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 4) {
                        Text("── MOTIVATIONAL ASSAULT ──")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(accentColor)
                            .kerning(3)

                        Text(currentMode.displayName)
                            .font(.system(size: 42, weight: .black, design: .serif))
                            .foregroundStyle(
                                LinearGradient(colors: [.white, accentColor.opacity(0.8)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: accentColor.opacity(0.6), radius: 20)
                            .animation(.easeInOut(duration: 0.4), value: currentMode)
                    }
                    .padding(.top, 20)

                    // Countdown cards
                    CountdownRow()

                    // Message display
                    MessageCard(
                        message: currentMessage,
                        isLoading: isLoading,
                        accentColor: accentColor,
                        isShaking: isShaking
                    )

                    // Mode buttons
                    VStack(spacing: 10) {
                        ForEach(modes, id: \.self) { mode in
                            ModeButton(
                                mode: mode,
                                isActive: currentMode == mode,
                                isLoading: isLoading
                            ) {
                                fire(mode: mode)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
            }
        }
    }

    private func fire(mode: NotificationMode) {
        currentMode = mode
        let msg = MessageBank.random(for: mode)
        withAnimation(.interpolatingSpring(stiffness: 400, damping: 8)) {
            isShaking = true
        }
        currentMessage = msg

        // Haptic
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(mode == .friday ? .success : .warning)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isShaking = false
        }
    }
}

// MARK: - Message Card
struct MessageCard: View {
    let message: String
    let isLoading: Bool
    let accentColor: Color
    let isShaking: Bool

    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 12)
                .fill(accentColor.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(message.isEmpty ? Color.white.opacity(0.06) : accentColor.opacity(0.6), lineWidth: 1)
                )

            VStack {
                if isLoading {
                    HStack {
                        Text("▌生成中...")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(accentColor)
                            .opacity(0.8)
                        Spacer()
                    }
                } else if message.isEmpty {
                    Text("ボタンを押せ。今すぐ。")
                        .font(.system(size: 14, design: .serif).italic())
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .multilineTextAlignment(.center)
                } else {
                    Text(message)
                        .font(.system(size: 16, design: .serif))
                        .foregroundColor(.white.opacity(0.92))
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .frame(minHeight: 140)
        .offset(x: shakeOffset)
        .onChange(of: isShaking) { shaking in
            if shaking {
                withAnimation(.interpolatingSpring(stiffness: 600, damping: 5).repeatCount(6, autoreverses: true)) {
                    shakeOffset = 6
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        shakeOffset = 0
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Mode Button
struct ModeButton: View {
    let mode: NotificationMode
    let isActive: Bool
    let isLoading: Bool
    let action: () -> Void

    var modeColor: Color {
        switch mode {
        case .monday:   return Color(hex: "CC0000")
        case .thursday: return Color(hex: "B34400")
        case .friday:   return Color(hex: "007ACC")
        }
    }

    var desc: String { mode.description }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(mode.emoji)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(modeColor.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(modeColor.opacity(isActive ? 0.2 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(modeColor.opacity(isActive ? 0.8 : 0.25), lineWidth: 1)
                    )
            )
        }
        .disabled(isLoading)
        .scaleEffect(isLoading ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isLoading)
    }
}

// MARK: - Countdown Row
struct CountdownRow: View {
    @StateObject private var notif = NotificationManager.shared
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private func modeColor(_ mode: NotificationMode) -> Color {
        switch mode {
        case .monday:   return Color(hex: "CC0000")
        case .thursday: return Color(hex: "B34400")
        case .friday:   return Color(hex: "007ACC")
        }
    }

    var body: some View {
        let enabledSchedules = notif.schedules.filter(\.isEnabled)
        if !enabledSchedules.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(enabledSchedules) { entry in
                        let diff = secondsUntil(entry: entry)
                        let h = diff / 3600
                        let m = (diff % 3600) / 60
                        let s = diff % 60
                        let color = entry.modeEnum.map { modeColor($0) } ?? .gray

                        VStack(spacing: 4) {
                            Text("\(entry.weekdayName) \(entry.modeEnum?.shortName ?? "")")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(color)
                                .kerning(1)
                            Text(String(format: "%02d:%02d:%02d", h, m, s))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                            Text("h  :  m  :  s")
                                .font(.system(size: 9))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .frame(minWidth: 110)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.03))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.25), lineWidth: 1))
                        )
                    }
                }
                .padding(.horizontal)
            }
            .onReceive(timer) { _ in
                withAnimation(.linear(duration: 0.3)) { now = Date() }
            }
        }
    }

    private func secondsUntil(entry: ScheduleEntry) -> Int {
        let cal = Calendar.current
        var components = DateComponents()
        components.weekday = entry.weekday
        components.hour = entry.hour
        components.minute = entry.minute
        components.second = 0
        guard let next = cal.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else { return 0 }
        return max(0, Int(next.timeIntervalSince(now)))
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var notif = NotificationManager.shared
    @State private var showAddSchedule = false
    @State private var editingEntry: ScheduleEntry?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                List {
                    Section {
                        HStack {
                            Text("通知の状態")
                                .foregroundColor(.white)
                            Spacer()
                            Text(notif.isAuthorized ? "許可済み ✓" : "未許可")
                                .foregroundColor(notif.isAuthorized ? Color(hex:"CC0000") : .gray)
                        }
                        if !notif.isAuthorized {
                            Button("通知を許可する") {
                                Task { await notif.requestAuthorization() }
                            }
                            .foregroundColor(Color(hex: "CC0000"))
                        }
                    } header: { Text("通知設定").foregroundColor(.gray) }

                    Section {
                        ForEach(notif.schedules) { entry in
                            ScheduleRow(entry: entry) {
                                editingEntry = entry
                            }
                        }
                        .onDelete { indexSet in
                            let ids = indexSet.map { notif.schedules[$0].id }
                            ids.forEach { notif.removeSchedule(id: $0) }
                        }

                        Button {
                            showAddSchedule = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("スケジュールを追加")
                            }
                            .foregroundColor(Color(hex: "CC0000"))
                        }
                    } header: { Text("定期通知スケジュール").foregroundColor(.gray) } footer: {
                        Text("行をタップで編集、左スワイプで削除")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.6))
                    }

                    Section {
                        Button("通知を再スケジュール") {
                            notif.scheduleAll()
                        }
                        .foregroundColor(Color(hex: "CC0000"))
                        Button("全通知をキャンセル", role: .destructive) {
                            notif.cancelAll()
                        }
                    } header: { Text("操作").foregroundColor(.gray) }

                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("メッセージバンク")
                                .foregroundColor(.white)
                            Text("月曜: \(MessageBank.monday.count)パターン  木曜: \(MessageBank.thursday.count)パターン  金曜: \(MessageBank.friday.count)パターン")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } header: { Text("コンテンツ").foregroundColor(.gray) }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddSchedule) {
                ScheduleEditSheet()
                    .presentationDetents([.medium])
            }
            .sheet(item: $editingEntry) { entry in
                ScheduleEditSheet(editingEntry: entry)
                    .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - Schedule Row
struct ScheduleRow: View {
    let entry: ScheduleEntry
    let onTapEdit: () -> Void
    @StateObject private var notif = NotificationManager.shared

    private var modeColor: Color {
        switch entry.modeEnum {
        case .monday:   return Color(hex: "CC0000")
        case .thursday: return Color(hex: "B34400")
        case .friday:   return Color(hex: "007ACC")
        case .none:     return .gray
        }
    }

    var body: some View {
        HStack {
            Button(action: onTapEdit) {
                HStack {
                    Text(entry.modeEnum?.emoji ?? "📌")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.weekdayName)曜日 \(entry.timeString)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text(entry.modeEnum?.displayName ?? "不明")
                            .font(.system(size: 12))
                            .foregroundColor(modeColor)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(
                get: { entry.isEnabled },
                set: { _ in notif.toggleSchedule(id: entry.id) }
            ))
            .tint(modeColor)
            .labelsHidden()
        }
        .listRowBackground(Color.white.opacity(0.04))
    }
}

// MARK: - Schedule Edit Sheet (新規追加と編集の両方に対応)
struct ScheduleEditSheet: View {
    @StateObject private var notif = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    let editingEntry: ScheduleEntry?  // nil = 新規追加, 値あり = 編集

    @State private var selectedMode: NotificationMode
    @State private var selectedWeekday: Int
    @State private var selectedTime: Date

    private let weekdays = [
        (2, "月曜日"), (3, "火曜日"), (4, "水曜日"),
        (5, "木曜日"), (6, "金曜日"), (7, "土曜日"), (1, "日曜日")
    ]

    init(editingEntry: ScheduleEntry? = nil) {
        self.editingEntry = editingEntry
        if let e = editingEntry {
            _selectedMode = State(initialValue: e.modeEnum ?? .monday)
            _selectedWeekday = State(initialValue: e.weekday)
            var comp = DateComponents()
            comp.hour = e.hour
            comp.minute = e.minute
            _selectedTime = State(initialValue: Calendar.current.date(from: comp) ?? Date())
        } else {
            _selectedMode = State(initialValue: .monday)
            _selectedWeekday = State(initialValue: 2)
            _selectedTime = State(initialValue: Date())
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "111111").ignoresSafeArea()
                VStack(spacing: 20) {
                    Picker("モード", selection: $selectedMode) {
                        ForEach(NotificationMode.allCases, id: \.self) { m in
                            Text("\(m.emoji) \(m.displayName)").tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Picker("曜日", selection: $selectedWeekday) {
                        ForEach(weekdays, id: \.0) { wd in
                            Text(wd.1).tag(wd.0)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)

                    DatePicker("時刻", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .frame(height: 100)

                    Button {
                        let cal = Calendar.current
                        let h = cal.component(.hour, from: selectedTime)
                        let m = cal.component(.minute, from: selectedTime)
                        if let editing = editingEntry {
                            notif.updateSchedule(id: editing.id, mode: selectedMode, weekday: selectedWeekday, hour: h, minute: m)
                        } else {
                            notif.addSchedule(mode: selectedMode, weekday: selectedWeekday, hour: h, minute: m)
                        }
                        dismiss()
                    } label: {
                        Text(editingEntry == nil ? "追加する" : "保存する")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "CC0000"))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle(editingEntry == nil ? "スケジュール追加" : "スケジュール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Ringing Overlay
struct RingingOverlay: View {
    let mode: NotificationMode
    let message: String
    let onDismiss: () -> Void
    @State private var pulse = false

    var color: Color {
        mode == .friday ? Color(hex: "007ACC") : Color(hex: "CC0000")
    }

    var body: some View {
        ZStack {
            color.opacity(0.15).ignoresSafeArea()
                .background(.ultraThinMaterial)
            VStack(spacing: 24) {
                Text(mode.emoji)
                    .font(.system(size: 80))
                    .scaleEffect(pulse ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(), value: pulse)
                    .onAppear { pulse = true }

                Text(mode.notificationTitle)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 16, design: .serif))
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(6)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                }

                Button(action: onDismiss) {
                    Text("止める")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 160, height: 56)
                        .background(color)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .padding()
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let v = Int(hex, radix: 16) ?? 0
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8)  & 0xFF) / 255
        let b = Double(v         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
