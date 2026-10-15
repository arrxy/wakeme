import CoreMotion
import SwiftUI

/// Signature is fixed. Replace the body only.
struct ShakeMissionView: View {
    var targetCount: Int
    var strength: ShakeStrength
    var label: String
    var timeText: String
    var snoozeEnabled: Bool
    var isPreview: Bool
    var onFinish: () -> Void
    var onSnooze: () -> Void

    @State private var counter = ShakeCounter(target: 0, threshold: 0)
    @State private var configured = false
    @State private var didFinish = false
    @State private var motionUnavailable = false
    @State private var motion = ShakeMotion()

    var body: some View {
        ZStack {
            WakeTheme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 28) {
                header
                VStack(alignment: .leading, spacing: 6) {
                    Text("SHAKE MISSION")
                        .font(.caption.weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(WakeTheme.secondary)
                    Text("Keep shaking.")
                        .font(.system(size: 40, weight: .regular, design: .serif))
                        .foregroundStyle(.white)
                }
                progress
                    .frame(maxWidth: .infinity)
                strengthRow
                Text("Stop for 5 seconds and the count starts dropping.")
                    .font(.subheadline)
                    .foregroundStyle(WakeTheme.secondary)
                if motionUnavailable {
                    Text("Motion unavailable")
                        .font(.footnote)
                        .foregroundStyle(WakeTheme.tertiary)
                }
                Spacer(minLength: 0)
                if snoozeEnabled {
                    Button(action: onSnooze) {
                        Text("Snooze · 9 min")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(WakeTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(24)
        }
        .onAppear(perform: start)
        .onDisappear { motion.stop() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(isPreview ? "PREVIEW" : "RINGING · \(timeText)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isPreview ? WakeTheme.secondary : WakeTheme.snooze)
            Spacer(minLength: 12)
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }

    private var progress: some View {
        let fraction = targetCount > 0 ? min(Double(counter.count) / Double(targetCount), 1) : 0
        return ZStack {
            Circle()
                .stroke(WakeTheme.elevated, lineWidth: 12)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                Text("\(counter.count) / \(targetCount)")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(counter.remaining) to go")
                    .font(.subheadline)
                    .foregroundStyle(WakeTheme.secondary)
            }
        }
        .frame(width: 220, height: 220)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(counter.count) of \(targetCount), \(counter.remaining) to go")
    }

    private var strengthRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("STRENGTH")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(WakeTheme.secondary)
                Spacer()
                Text(strength.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            HStack(spacing: 8) {
                ForEach(ShakeStrength.allCases, id: \.self) { level in
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(level == strength ? Color.white : WakeTheme.elevated)
                        if level == strength {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    private func start() {
        if !configured {
            counter = ShakeCounter(target: targetCount, threshold: strength.threshold)
            configured = true
        }
        guard motion.available else {
            motionUnavailable = true
            return
        }
        motion.start { magnitude, time in
            guard !didFinish else { return }
            counter.addSample(magnitude: magnitude, at: time)
            counter.decay(at: time)
            guard counter.isComplete else { return }
            didFinish = true
            motion.stop()
            onFinish()
        }
    }
}

private final class ShakeMotion {
    private let manager = CMMotionManager()

    var available: Bool { manager.isDeviceMotionAvailable }

    func start(_ handler: @escaping (Double, Date) -> Void) {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            let acceleration = motion.userAcceleration
            let magnitude = (acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z).squareRoot()
            handler(magnitude, Date())
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
