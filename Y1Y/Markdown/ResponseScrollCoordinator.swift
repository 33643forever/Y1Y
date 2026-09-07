import Combine
import CoreGraphics

enum AutoScrollState: Equatable, Sendable {
    case followingBottom
    case userBrowsing
}

@MainActor
final class ResponseScrollCoordinator: ObservableObject {
    @Published private(set) var state: AutoScrollState = .followingBottom

    let pauseThreshold: CGFloat
    let resumeThreshold: CGFloat

    init(
        pauseThreshold: CGFloat = 24,
        resumeThreshold: CGFloat = 8
    ) {
        precondition(pauseThreshold > resumeThreshold)
        precondition(resumeThreshold >= 0)
        self.pauseThreshold = pauseThreshold
        self.resumeThreshold = resumeThreshold
    }

    var shouldFollowNewContent: Bool {
        state == .followingBottom
    }

    func userDidScroll(distanceFromBottom: CGFloat) {
        let distance = normalized(distanceFromBottom)

        switch state {
        case .followingBottom where distance >= pauseThreshold:
            state = .userBrowsing
        case .userBrowsing where distance <= resumeThreshold:
            state = .followingBottom
        default:
            break
        }
    }

    func reset() {
        state = .followingBottom
    }

    private func normalized(_ distance: CGFloat) -> CGFloat {
        guard distance.isFinite else { return .greatestFiniteMagnitude }
        return max(0, distance)
    }
}
