import ActivityKit
import SwiftUI

// MARK: - LegionActivityAttributes
/// Shared between main app target AND LegionActivityWidget extension.
/// ⚠️ In Xcode: File Inspector → Target Membership → check BOTH targets.
struct LegionActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var cpuUsage:  Int
        var gpuUsage:  Int
        var ramUsage:  Int
        var vramUsage: Int
        var tempCpu:   Int
        var tempGpu:   Int
        
        var mediaTitle: String?
        var mediaArtist: String?
        var volume: Int?
        
        var isAuthRequested: Bool = false
    }

    /// Static context: PC name, set once when activity starts.
    var pcName: String
}
