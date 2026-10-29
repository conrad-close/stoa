import SwiftUI
import StoaCore

/// Placeholder shell. Milestone 1 replaces this with the sidebar + tab strip + address bar.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.columns")
                .font(.system(size: 48, weight: .light))
            Text("Stoa")
                .font(.largeTitle.weight(.semibold))
            Text("Version \(StoaInfo.version)")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

#Preview {
    ContentView()
}
