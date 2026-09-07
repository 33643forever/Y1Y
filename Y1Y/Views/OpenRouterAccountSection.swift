//
//  OpenRouterAccountSection.swift
//  Y1Y
//

import Foundation
import SwiftUI

enum OpenRouterEndpointPolicy {
    static func isOpenRouter(_ baseURL: String) -> Bool {
        guard let host = URL(string: baseURL)?.host?.lowercased()
        else {
            return false
        }
        return host == "openrouter.ai" || host.hasSuffix(".openrouter.ai")
    }
}

enum BalanceRelativeTimeFormatter {
    static func string(from date: Date, relativeTo now: Date = Date()) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))
        if elapsed < 60 {
            return "刚刚"
        }
        if elapsed < 3_600 {
            return "\(max(1, Int(elapsed / 60))) 分钟前"
        }
        if elapsed < 86_400 {
            return "\(max(1, Int(elapsed / 3_600))) 小时前"
        }
        return "\(max(1, Int(elapsed / 86_400))) 天前"
    }
}

struct OpenRouterAccountSection: View {
    let state: OpenRouterAccountState
    let apiKeyIsEmpty: Bool
    var now: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if apiKeyIsEmpty {
                Label("请先配置 API Key", systemImage: "key")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                connectionRow

                if let balance = state.balance {
                    HStack(alignment: .firstTextBaseline) {
                        Text("可用余额")
                        Spacer()
                        Text(formattedAmount(balance.availableAmount))
                            .font(.body.monospacedDigit())
                    }

                    HStack(spacing: 6) {
                        if state.isStale {
                            Text("旧数据")
                                .foregroundStyle(.orange)
                        } else {
                            Text("更新于")
                                .foregroundStyle(.secondary)
                        }
                        Text(
                            BalanceRelativeTimeFormatter.string(
                                from: balance.updatedAt,
                                relativeTo: now
                            )
                        )
                        .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                if case .connected = state.connection,
                   let message = state.balanceErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var connectionRow: some View {
        switch state.connection {
        case .idle:
            Label("等待连接", systemImage: "circle")
                .foregroundStyle(.secondary)
        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("正在连接 OpenRouter…")
            }
            .foregroundStyle(.secondary)
        case .connected:
            Label("OpenRouter 已连接", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .disconnected(let message):
            VStack(alignment: .leading, spacing: 3) {
                Label("OpenRouter 连接失败", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                if !apiKeyIsEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        String(
            format: "$%.2f",
            NSDecimalNumber(decimal: amount).doubleValue
        )
    }
}
