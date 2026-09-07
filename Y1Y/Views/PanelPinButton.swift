//
//  PanelPinButton.swift
//  Y1Y
//

import SwiftUI

struct PanelPinButton: View {
    @Binding var pinState: PinState

    var body: some View {
        Button(action: togglePin) {
            Image(systemName: pinState == .pinned ? "pin.fill" : "pin")
                .font(.caption)
                .foregroundStyle(
                    pinState == .pinned
                        ? Color(red: 100/255, green: 210/255, blue: 255/255)
                        : Color(red: 99/255, green: 99/255, blue: 102/255)
                )
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    pinState == .pinned
                        ? Color(red: 100/255, green: 210/255, blue: 255/255).opacity(0.1)
                        : Color(red: 44/255, green: 44/255, blue: 46/255)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(red: 58/255, green: 58/255, blue: 60/255), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help(pinState == .pinned ? "取消固定浮窗" : "固定浮窗")
        .accessibilityLabel(
            pinState == .pinned ? "取消固定浮窗" : "固定浮窗"
        )
        .accessibilityValue(pinState == .pinned ? "已固定" : "未固定")
    }

    private func togglePin() {
        pinState.toggle()
    }
}
