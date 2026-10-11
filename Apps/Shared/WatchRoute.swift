import Foundation

enum WatchRoute: Equatable {
    case home, progress, hatch

    init?(url: URL) {
        guard url.scheme?.lowercased() == "batwalk", url.path.isEmpty else { return nil }
        switch url.host?.lowercased() {
        case "home": self = .home
        case "progress": self = .progress
        case "hatch": self = .hatch
        default: return nil
        }
    }
}
