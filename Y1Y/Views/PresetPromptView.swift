//
//  PresetPromptView.swift
//  Y1Y
//

import SwiftUI

struct PresetPromptView: View {
    let selectedText: String
    @ObservedObject var aiService: AIService
    @ObservedObject private var settings = SettingsManager.shared
    @Binding var pinState: PinState
    let onClose: () -> Void
    let onPhaseChange: (PanelPhase) -> Void

    @State private var activePrompt: CustomPrompt?
    @State private var customInput: String = ""
    @State private var isCustomMode = false
    @StateObject private var markdownRenderStore = MarkdownRenderStore()
    @StateObject private var scrollCoordinator = ResponseScrollCoordinator()
    @State private var isUserScrollingResponse = false
    private var prompts: [CustomPrompt] { settings.customPrompts }
    private var favoriteModels: [String] {
        settings.favoriteModels.filter { !$0.isEmpty }
    }

    private func displayModelName(_ model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let slashIndex = trimmed.firstIndex(of: "/") else { return trimmed }
        return String(trimmed[trimmed.index(after: slashIndex)...])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if activePrompt == nil && !isCustomMode {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Spacer()
                        modelSwitcher
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                    promptList
                }
                .frame(width: 210)
            } else {
                responseView
            }
        }
        .background(Color(red: 28/255, green: 28/255, blue: 30/255))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 58/255, green: 58/255, blue: 60/255), lineWidth: 0.5)
        )
    }

    // MARK: - Compact Prompt List

    private func triggerPrompt(_ prompt: CustomPrompt) {
        prepareForResponse()
        activePrompt = prompt
        onPhaseChange(.response)
        let promptText = prompt.systemPrompt
        if promptText.contains("{{text}}") {
            let userMessage = promptText.replacingOccurrences(of: "{{text}}", with: selectedText)
            aiService.sendRequest(systemPrompt: "", userContent: userMessage)
        } else {
            aiService.sendRequest(systemPrompt: promptText, userContent: selectedText)
        }
    }

    private var promptList: some View {
        VStack(spacing: 0) {
            ForEach(Array(prompts.enumerated()), id: \.element.id) { index, prompt in
                Button(action: { triggerPrompt(prompt) }) {
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .frame(width: 14)
                        Text(prompt.icon)
                            .font(.caption)
                        Text(prompt.title)
                            .font(.callout)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Divider()
                .padding(.vertical, 2)

            HStack(spacing: 8) {
                TextField("输入自定义指令…", text: $customInput)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(Color(red: 232/255, green: 232/255, blue: 236/255))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(red: 44/255, green: 44/255, blue: 46/255))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(red: 58/255, green: 58/255, blue: 60/255), lineWidth: 0.5)
                    )
                    .onSubmit { sendCustomPrompt() }

                Button(action: sendCustomPrompt) {
                    Text("👌")
                        .font(.caption)
                        .frame(width: 32, height: 32)
                        .background(
                            customInput.isEmpty
                                ? Color.clear
                                : Color(red: 100/255, green: 210/255, blue: 255/255).opacity(0.15)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(customInput.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .padding(.vertical, 4)
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear { removeKeyboardMonitor() }
    }

    private func sendCustomPrompt() {
        guard !customInput.isEmpty else { return }
        prepareForResponse()
        isCustomMode = true
        onPhaseChange(.response)
        let userMessage = customInput + "\n\n" + selectedText
        aiService.sendRequest(systemPrompt: "", userContent: userMessage)
    }

    @State private var keyMonitor: Any?

    private func setupKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard activePrompt == nil else { return event }
            guard let char = event.charactersIgnoringModifiers,
                  let digit = Int(char),
                  digit >= 1 && digit <= min(9, prompts.count)
            else { return event }
            triggerPrompt(prompts[digit - 1])
            return nil
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Response View

    @State private var reasoningExpanded = false

    private func prepareForResponse() {
        markdownRenderStore.reset()
        scrollCoordinator.reset()
        isUserScrollingResponse = false
    }

    private var responseView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Left: Back button (icon only, pill size)
                Button(action: {
                    aiService.cancel()
                    prepareForResponse()
                    activePrompt = nil
                    isCustomMode = false
                    onPhaseChange(.promptList)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .foregroundStyle(Color(red: 152/255, green: 152/255, blue: 157/255))
                        .frame(height: 28)
                        .padding(.horizontal, 12)
                        .background(Color(red: 44/255, green: 44/255, blue: 46/255))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 58/255, green: 58/255, blue: 60/255), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                // Model name (display only, subtle, no dropdown)
                Text(displayModelName(settings.modelName))
                    .font(.caption2)
                    .foregroundStyle(Color(red: 99/255, green: 99/255, blue: 102/255))
                    .padding(.leading, 4)

                Spacer()

                // Right: Copy all + Pin
                HStack(spacing: 6) {
                    if !aiService.responseText.isEmpty {
                        Button(action: {
                            ResponseCopyAction.copy(aiService.responseText)
                        }) {
                            Label("复制全部", systemImage: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(Color(red: 152/255, green: 152/255, blue: 157/255))
                                .frame(height: 28)
                                .padding(.horizontal, 12)
                                .background(Color(red: 44/255, green: 44/255, blue: 46/255))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color(red: 58/255, green: 58/255, blue: 60/255), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }

                    PanelPinButton(pinState: $pinState)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if let error = aiService.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.callout)
                        } else {
                            // Reasoning section
                            if !aiService.reasoningText.isEmpty {
                                reasoningSection
                            }

                            // Loading indicator
                            if aiService.isLoading && aiService.responseText.isEmpty && aiService.reasoningText.isEmpty {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("处理中...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // Final result with Markdown
                            if !aiService.responseText.isEmpty {
                                StreamingMarkdownContentView(
                                    snapshot: markdownRenderStore.snapshot,
                                    fallbackSource: aiService.responseText
                                )
                            }
                        }

                        // Scroll anchor
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                }
                .onScrollPhaseChange { _, newPhase in
                    isUserScrollingResponse =
                        newPhase == .tracking
                        || newPhase == .interacting
                        || newPhase == .decelerating
                }
                .onScrollGeometryChange(
                    for: CGFloat.self,
                    of: { geometry in
                        max(
                            0,
                            geometry.contentSize.height
                                - geometry.visibleRect.maxY
                        )
                    },
                    action: { _, distanceFromBottom in
                        guard isUserScrollingResponse else { return }
                        scrollCoordinator.userDidScroll(
                            distanceFromBottom: distanceFromBottom
                        )
                    }
                )
                .onChange(of: aiService.reasoningText) {
                    guard scrollCoordinator.shouldFollowNewContent else { return }
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                .onChange(of: aiService.responseText) { _, newResponse in
                    markdownRenderStore.update(source: newResponse)
                }
                .onChange(of: markdownRenderStore.snapshot) {
                    guard scrollCoordinator.shouldFollowNewContent else { return }
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                .onChange(of: aiService.isLoading) {
                    if !aiService.isLoading {
                        markdownRenderStore.finish(
                            source: aiService.responseText
                        )
                    }
                }
                .onAppear {
                    if !aiService.responseText.isEmpty {
                        markdownRenderStore.update(
                            source: aiService.responseText
                        )
                    }
                }
            }


        }
    }

    // MARK: - Reasoning Section

    private var reasoningSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if aiService.isReasoning {
                // Reasoning in progress - show live
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("思考中...")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text(aiService.reasoningText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                // Reasoning done - collapsed by default
                DisclosureGroup(isExpanded: $reasoningExpanded) {
                    Text(aiService.reasoningText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } label: {
                    Text("思考过程")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(10)
        .background(Color(red: 255/255, green: 159/255, blue: 10/255).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Markdown Rendering

    @ViewBuilder
    private var modelSwitcher: some View {
        if favoriteModels.isEmpty {
            modelChip(settings.modelName)
        } else {
            Menu {
                ForEach(favoriteModels, id: \.self) { model in
                    Button(action: {
                        settings.modelName = model
                    }) {
                        if settings.modelName == model {
                            Label(displayModelName(model), systemImage: "checkmark")
                        } else {
                            Text(displayModelName(model))
                        }
                    }
                }
            } label: {
                modelChip(settings.modelName)
            }
            .menuStyle(.borderlessButton)
        }
    }

    private func modelChip(_ model: String) -> some View {
        Text(displayModelName(model))
        .font(.caption2)
        .foregroundStyle(Color(red: 152/255, green: 152/255, blue: 157/255))
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(red: 255/255, green: 255/255, blue: 255/255).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: 140)
    }

}
