//
//  PanelPreferencesStore.swift
//  Y1Y
//

import CoreGraphics
import Foundation

struct PanelPreferencesStore {
    private enum Keys {
        static let responsePanelWidth = "responsePanelWidth"
        static let responsePanelHeight = "responsePanelHeight"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadResponsePanelSize() -> ResponsePanelSize {
        let width = defaults.double(forKey: Keys.responsePanelWidth)
        let height = defaults.double(forKey: Keys.responsePanelHeight)

        guard width.isFinite,
              height.isFinite,
              width > 0,
              height > 0
        else {
            return .defaultSize
        }

        return ResponsePanelSize(width: width, height: height)
    }

    func saveResponsePanelSize(_ size: ResponsePanelSize) {
        guard size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0
        else {
            return
        }

        defaults.set(Double(size.width), forKey: Keys.responsePanelWidth)
        defaults.set(Double(size.height), forKey: Keys.responsePanelHeight)
    }
}
