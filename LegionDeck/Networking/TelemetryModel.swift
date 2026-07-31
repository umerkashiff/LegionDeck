import Foundation

// MARK: - TelemetryModel
/// Decoded from the 1Hz JSON broadcast sent by the Windows daemon.
struct TelemetryModel: Codable, Equatable {
    var cpuUsage:  Int
    var gpuUsage:  Int
    var ramUsage:  Int
    var vramUsage: Int
    var tempCpu:   Int
    var tempGpu:   Int
    var tempIgpu:  Int?      // AMD Radeon 860M iGPU temp (optional)
    var gpuLabel:  String?   // e.g. "NVIDIA GeForce RTX 5070 Laptop GPU"
    var clipboard: String?
    
    var mediaTitle: String?
    var mediaArtist: String?
    var volume: Int?
    
    var timestamp: Int

    enum CodingKeys: String, CodingKey {
        case cpuUsage  = "cpu_usage"
        case gpuUsage  = "gpu_usage"
        case ramUsage  = "ram_usage"
        case vramUsage = "vram_usage"
        case tempCpu   = "temp_cpu"
        case tempGpu   = "temp_gpu"
        case tempIgpu  = "temp_igpu"
        case gpuLabel  = "gpu_label"
        case clipboard
        case mediaTitle = "media_title"
        case mediaArtist = "media_artist"
        case volume
        case timestamp
    }

    static var placeholder: TelemetryModel {
        TelemetryModel(
            cpuUsage: 0, gpuUsage: 0,
            ramUsage: 0, vramUsage: 0,
            tempCpu: 0, tempGpu: 0,
            tempIgpu: nil, gpuLabel: nil,
            clipboard: nil, mediaTitle: nil, mediaArtist: nil, volume: nil, timestamp: 0
        )
    }
}

// MARK: - ConnectionState
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected

    var label: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting:   return "Connecting…"
        case .connected:    return "Connected"
        }
    }

    var color: String {
        switch self {
        case .disconnected: return "red"
        case .connecting:   return "orange"
        case .connected:    return "green"
        }
    }
}
