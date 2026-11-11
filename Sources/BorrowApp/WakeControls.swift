import BorrowCore
import SwiftUI

struct WakeModePicker: View {
    @Binding var mode: WakeMode
    let disabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Wake hold", selection: $mode) {
                ForEach(WakeMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .frame(maxWidth: 450)
            .disabled(disabled)
            Text(mode.detail).font(.callout).foregroundStyle(.secondary)
            Text("Closing the window keeps this app instance's recorder running. Quit stops that recorder and waits for cleanup; other recorders keep their own deadlines.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct WakeHoldStatus: View {
    let power: PowerEvidence
    let stale: Bool

    private var label: String {
        if power.cleanup == .nothingHeld { return "No Borrow-owned wake hold was created." }
        if stale { return "Wake hold: last state is stale; current condition is unknown." }
        switch power.state {
        case .requested: return "Wake hold requested; awaiting confirmation."
        case .active: return Date() < power.deadline ? "Borrow's wake hold was confirmed." : "Wake-hold deadline reached; current condition is unknown."
        case .released: return "Borrow's wake hold released. Normal sleep is allowed."
        case .failed: return "Wake hold could not be confirmed or maintained. Review the evidence below."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: power.state == .released ? "moon" : "timer")
                .font(.callout.weight(.medium))
            Text("\(power.mode.title) · Deadline \(power.deadline.formatted(date: .omitted, time: .standard))")
                .font(.caption).foregroundStyle(.secondary)
            if power.mode == .experimentalAC {
                Text("Experimental, AC only. This does not establish closed-lid compatibility.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}
