import AppKit

struct PanelSizePersistenceCoordinator {
    private let preferencesStore: PanelPreferencesStore

    init(preferencesStore: PanelPreferencesStore = PanelPreferencesStore()) {
        self.preferencesStore = preferencesStore
    }

    func recordUserResize(_ size: NSSize, phase: PanelPhase) {
        guard phase == .response else { return }

        preferencesStore.saveResponsePanelSize(
            ResponsePanelSize(width: size.width, height: size.height)
        )
    }
}
