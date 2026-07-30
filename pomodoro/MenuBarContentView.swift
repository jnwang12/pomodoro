//
//  MenuBarContentView.swift
//  pomodoro
//
//  Created by Joy Wang on 7/29/26.
//

import SwiftUI
import Combine

extension Color {
    init?(hex: String) {
        guard hex.hasPrefix("#") else { return nil }
        let start = hex.index(hex.startIndex, offsetBy: 1)
        let hexColor = String(hex[start...])

        let r, g, b, a: Double

        switch hexColor.count {
        case 6:
            // #RRGGBB -> alpha = 0xFF
            guard let hexNumber = UInt64(hexColor, radix: 16) else { return nil }
            r = Double((hexNumber & 0xFF0000) >> 16) / 255.0
            g = Double((hexNumber & 0x00FF00) >> 8) / 255.0
            b = Double(hexNumber & 0x0000FF) / 255.0
            a = 1.0
        default:
            return nil
        }

        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

private struct DigitStepper: View {
    let title: String?
    @Binding var value: Int
    let range: ClosedRange<Int>
    let isEnabled: Bool

    var body: some View {
        VStack(spacing: 2) {
            if let title {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button(action: { if isEnabled { increment() } }) {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)

            Text(String(value))
                .font(.title3.monospacedDigit())
                .frame(minWidth: 16)

            Button(action: { if isEnabled { decrement() } }) {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
        }
        .padding(.horizontal, 4)
    }

    private func increment() {
        let next = value + 1
        if range.contains(next) { value = next }
    }

    private func decrement() {
        let prev = value - 1
        if range.contains(prev) { value = prev }
    }
}

private func twoDigits(_ n: Int) -> String { String(format: "%02d", max(0, min(99, n))) }

struct MenuBarContentView: View {
    enum TimerSelection: Equatable {
        case preset(Int, String)
        case custom
        
        var items: [String] {
            ["chocolatecake", "icecreamcone", "pickle", "swisscheese", "salami", "lollipop", "cherrypie", "sausage", "cupcake", "watermelon"]
        }
    
        var imageName: String {
            switch self {
                case .preset(_, let name):
                    return name
                case .custom:
                    return items.randomElement() ?? "chocolatecake"
            }
        }
    }

    
    let selections: [TimerSelection] = [
        .preset(20, "apple"),
        .preset(25, "pear"),
        .preset(30, "plum"),
        .preset(45, "strawberry"),
        .preset(50, "orange"),
        .preset(90, "leaf"),
        .custom
    ]
    

    @State private var selectionIndex: Int = 2 // default 50
    
    @State private var progress: Double = 0.0
    @State private var inputMinutes: String = "25"
    @State private var inputSeconds: String = "00"
    @State private var isRunning: Bool = false
    @AppStorage("timerEndDate") private var storedEndDate: Double = 0 // timeIntervalSince1970
    @State private var endDate: Date? = nil
    @State private var duration: TimeInterval = 0
    @State private var tick: Date = Date()
    @Environment(\.scenePhase) private var scenePhase

    @State private var mTens: Int = 2
    @State private var mOnes: Int = 5
    @State private var sTens: Int = 0
    @State private var sOnes: Int = 0
    
    // Variables to remember the original custom time before counting down
    @State private var savedCustomMinutes: String = "25"
    @State private var savedCustomSeconds: String = "00"
    
    // Tracks if the timer has reached 0
    @State private var isTimerFinished: Bool = false

    var body: some View {
        let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

        return ZStack{
            Color.white
                .ignoresSafeArea()
            VStack(spacing: 12){
                Text("a very hungry caterpillar!")
                    .foregroundStyle(Color(hex:"#06402B") ?? Color.white)
                
                // Image toggles based on whether timer finished
                Image(isTimerFinished ? "butterfly" : "caterpillar")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 60)

                HStack(alignment: .center, spacing: 16) {
                    // Left Chevron
                    Button(action: {
                        if selectionIndex > 0 { selectionIndex -= 1 }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(selectionIndex == 0 || isRunning)
                    .opacity((selectionIndex == 0 || isRunning) ? 0.3 : 1.0)
                    
                    // Main Timer Display
                    if case .custom = selections[selectionIndex] {
                        HStack(alignment: .center, spacing: 8) {
                            DigitStepper(title: "M", value: $mTens, range: 0...9, isEnabled: !isRunning)
                            DigitStepper(title: nil, value: $mOnes, range: 0...9, isEnabled: !isRunning)

                            Text(":")
                                .font(.title3.monospacedDigit())

                            DigitStepper(title: "S", value: $sTens, range: 0...5, isEnabled: !isRunning)
                            DigitStepper(title: nil, value: $sOnes, range: 0...9, isEnabled: !isRunning)
                        }
                        .frame(minWidth: 120)
                    } else {
                        Text("\(inputMinutes):\(inputSeconds)")
                            .font(.system(size: 32, weight: .medium, design: .monospaced))
                            .frame(minWidth: 120)
                    }

                    // Right Chevron
                    Button(action: {
                        if selectionIndex < selections.count - 1 { selectionIndex += 1 }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(selectionIndex == selections.count - 1 || isRunning)
                    .opacity((selectionIndex == selections.count - 1 || isRunning) ? 0.3 : 1.0)
                }
                .onChange(of: selectionIndex) { old, new in
                    // Reset progress and duration when changing modes while paused
                    progress = 0
                    duration = 0
                    isTimerFinished = false
                    
                    if case let .preset(minutes, _) = selections[new] {
                        inputMinutes = twoDigits(minutes)
                        inputSeconds = "00"
                        syncDigitsFromStrings()
                    } else if case .custom = selections[new] {
                        inputMinutes = savedCustomMinutes
                        inputSeconds = savedCustomSeconds
                        syncDigitsFromStrings()
                    }
                }
                .onChange(of: mTens) { old, new in syncStringsFromDigits() }
                .onChange(of: mOnes) { old, new in syncStringsFromDigits() }
                .onChange(of: sTens) { old, new in syncStringsFromDigits() }
                .onChange(of: sOnes) { old, new in syncStringsFromDigits() }
                .onAppear { syncDigitsFromStrings() }

                //Progress Indicator
                Image(selections[selectionIndex].imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 80) // Set a fixed height for the menu bar item
                    .mask(alignment: .bottom) {
                        Rectangle()
                            // As progress goes from 0 to 1, scale shrinks from 1 to 0 anchored at the bottom
                            .scaleEffect(y: max(0, 1.0 - progress), anchor: .bottom)
                    }

                HStack {
                    Button(isRunning ? "stop" : "start") {
                        if isRunning {
                            // Stop: store remaining by setting endDate to nil but keep storedEndDate cleared
                            isRunning = false
                            endDate = nil
                            storedEndDate = 0
                        } else {
                            startTimer()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("reset") {
                        resetTimer()
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }

                if let end = endDate, isRunning {
                    Text("ends at \(end.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 20)
        }
        .onReceive(timer) { now in
            tick = now
            updateProgress(now: now)
        }
        .onAppear {
            restoreTimer()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Ensure persistence when leaving
            if newPhase != .active {
                persistEndDate()
            }
        }
    }

    private func syncStringsFromDigits() {
        let minutes = mTens * 10 + mOnes
        let secondsRaw = sTens * 10 + sOnes
        let seconds = min(secondsRaw, 59)
        inputMinutes = twoDigits(minutes)
        inputSeconds = twoDigits(seconds)
        
        if !isRunning && progress > 0 {
            // If user manually changes custom time while paused, act as a new timer
            progress = 0
            duration = 0
        }
        
        if progress == 0 && !isRunning {
            // Save the exact digits the user chooses as the "fallback" time for reset
            if case .custom = selections[selectionIndex] {
                savedCustomMinutes = inputMinutes
                savedCustomSeconds = inputSeconds
            }
        }
    }

    private func syncDigitsFromStrings() {
        let mins = max(0, min(99, Int(inputMinutes) ?? 0))
        let secs = max(0, min(59, Int(inputSeconds) ?? 0))
        mTens = mins / 10
        mOnes = mins % 10
        sTens = secs / 10
        sOnes = secs % 10
    }

    private func startTimer() {
        let mins = Double(inputMinutes.trimmingCharacters(in: .whitespaces)) ?? 0
        let secs = Double(inputSeconds.trimmingCharacters(in: .whitespaces)) ?? 0
        let remainingToRun = mins * 60 + secs
        guard remainingToRun > 0 else { return }
        
        // Reset the image logic when starting
        isTimerFinished = false
        
        // Only override 'duration' if starting fresh, to ensure the image
        // doesn't reset its fractional size on stop/start
        if duration == 0 || progress == 0 {
            duration = remainingToRun
            if case .custom = selections[selectionIndex] {
                savedCustomMinutes = inputMinutes
                savedCustomSeconds = inputSeconds
            }
        }
        
        let now = Date()
        let target = now.addingTimeInterval(remainingToRun)
        endDate = target
        storedEndDate = target.timeIntervalSince1970
        isRunning = true
        updateProgress(now: now)
        syncDigitsFromStrings()
    }

    private func resetTimer() {
        isRunning = false
        progress = 0
        endDate = nil
        duration = 0
        storedEndDate = 0
        isTimerFinished = false // Reverts image to caterpillar
        
        // Restore time back to preset OR saved custom time
        if case let .preset(minutes, _) = selections[selectionIndex] {
            inputMinutes = twoDigits(minutes)
            inputSeconds = "00"
        } else if case .custom = selections[selectionIndex] {
            inputMinutes = savedCustomMinutes
            inputSeconds = savedCustomSeconds
        }
        syncDigitsFromStrings()
    }

    private func restoreTimer() {
        guard storedEndDate > 0 else {
            // Nothing stored
            resetTimer()
            return
        }
        let target = Date(timeIntervalSince1970: storedEndDate)
        let now = Date()
        if target > now {
            // Resume
            endDate = target
            isRunning = true
            isTimerFinished = false // Resume means it hasn't finished yet
            // If we don't know original duration, infer from remaining if possible
            if duration == 0 {
                let mins = Double(inputMinutes) ?? 0
                let secs = Double(inputSeconds) ?? 0
                duration = mins * 60 + secs
            }
            updateProgress(now: now)
            syncDigitsFromStrings()
        } else {
            // Already elapsed
            resetTimer()
        }
    }

    private func persistEndDate() {
        if let end = endDate, isRunning {
            storedEndDate = end.timeIntervalSince1970
        } else {
            storedEndDate = 0
        }
    }

    private func updateProgress(now: Date) {
        guard let end = endDate, isRunning else { return }
        let remaining = end.timeIntervalSince(now)
        if remaining <= 0 {
            progress = 1.0
            isRunning = false
            endDate = nil
            storedEndDate = 0
            isTimerFinished = true
            
            // Set digits to 00:00 when timer is done
            inputMinutes = "00"
            inputSeconds = "00"
            syncDigitsFromStrings()
            
            return
        }
        
        // If duration is unknown (e.g., restored), infer from remaining vs input
        if duration == 0 {
            let mins = Double(inputMinutes) ?? 0
            let secs = Double(inputSeconds) ?? 0
            duration = mins * 60 + secs
        }
        
        let elapsed = max(0, duration - remaining)
        progress = min(max(elapsed / max(duration, 1), 0), 1)
        
        // Update input strings and digits to reflect the countdown
        let remainingInt = Int(ceil(remaining))
        let rMins = remainingInt / 60
        let rSecs = remainingInt % 60
        
        inputMinutes = twoDigits(rMins)
        inputSeconds = twoDigits(rSecs)
        syncDigitsFromStrings()
    }

    private func sanitizedTwoDigitNumeric(_ value: String) -> String {
        let digits = value.filter { $0.isNumber }
        let clipped = String(digits.prefix(2))
        if clipped.isEmpty { return "00" }
        // Clamp seconds to 59
        if value == inputSeconds {
            if let n = Int(clipped) {
                return String(format: "%02d", min(n, 59))
            }
        }
        if let n = Int(clipped) {
            return String(format: "%02d", n)
        }
        return "00"
    }
}

#Preview {
    MenuBarContentView()
}
