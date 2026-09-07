//
//  SettingsView.swift
//  Y1Y
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var availableModels: [String] = []
    @State private var isFetchingModels = false
    @State private var fetchError: String?
    @State private var editingPrompt: CustomPrompt?
    @State private var isModelLibraryPresented = false
    @State private var fetchModelsTask: Task<Void, Never>?
    @State private var fetchGeneration = 0
    @StateObject private var accountViewModel = OpenRouterAccountViewModel()
    private var modelListHeight: CGFloat {
        let rowHeight: CGFloat = 28
        let padding: CGFloat = 8
        return min(CGFloat(settings.favoriteModels.count) * rowHeight + padding, 180)
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("通用", systemImage: "gear") }
            promptsTab
                .tabItem { Label("提示词", systemImage: "text.bubble") }
        }
        .frame(width: 520, height: 460)
        .onDisappear {
            fetchModelsTask?.cancel()
            accountViewModel.cancelRefresh()
        }
        .sheet(item: $editingPrompt) { prompt in
            PromptEditorSheet(
                prompt: prompt,
                onSave: { updated in
                    if let idx = settings.customPrompts.firstIndex(where: { $0.id == updated.id }) {
                        settings.customPrompts[idx] = updated
                    } else {
                        settings.customPrompts.append(updated)
                    }
                    editingPrompt = nil
                },
                onCancel: {
                    editingPrompt = nil
                }
            )
        }
        .sheet(isPresented: $isModelLibraryPresented) {
            ModelLibrarySheet(
                models: availableModels,
                favoriteModels: settings.favoriteModels,
                isLoading: isFetchingModels,
                errorMessage: fetchError,
                onRefresh: fetchModels,
                onAdd: { model in
                    settings.addFavoriteModel(model)
                    if settings.modelName.isEmpty || !settings.favoriteModels.contains(settings.modelName) {
                        settings.modelName = model
                    }
                }
            )
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("API 配置") {
                SecureField("API 密钥", text: $settings.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: settings.apiKey) {
                        invalidateModelLibrary()
                    }

                TextField("API 基础地址", text: $settings.apiBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: settings.apiBaseURL) {
                        invalidateModelLibrary()
                    }

                if OpenRouterEndpointPolicy.isOpenRouter(
                    settings.apiBaseURL
                ) {
                    OpenRouterAccountSection(
                        state: accountViewModel.state,
                        apiKeyIsEmpty: settings.apiKey.isEmpty
                    )
                    .task(id: accountConfigurationID) {
                        accountViewModel.cancelRefresh()
                        if !settings.apiKey.isEmpty {
                            try? await Task.sleep(
                                for: .milliseconds(250)
                            )
                            guard !Task.isCancelled else { return }
                        }
                        accountViewModel.refresh(
                            baseURL: settings.apiBaseURL,
                            apiKey: settings.apiKey
                        )
                    }
                }
            }

            Section("模型") {
                HStack {
                    Text("当前模型")
                    Spacer()
                    Text(settings.modelName.isEmpty ? "未选择" : displayModelName(settings.modelName))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !settings.favoriteModels.isEmpty {
                    List {
                        ForEach(settings.favoriteModels, id: \.self) { model in
                            addedModelRow(for: model)
                        }
                        .onMove { source, destination in
                            settings.moveFavoriteModels(fromOffsets: source, toOffset: destination)
                        }
                    }
                    .frame(height: modelListHeight)
                    .environment(\.defaultMinListRowHeight, 28)
                } else {
                    Text("还没有添加模型。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = fetchError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }

                HStack {
                    Button(action: openModelLibrary) {
                        Label("添加模型", systemImage: "plus")
                    }
                    .disabled(settings.apiKey.isEmpty || settings.apiBaseURL.isEmpty)

                    if isFetchingModels {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }

            Section("快捷键") {
                HStack {
                    Text("全局快捷键：")
                    Spacer()
                    Text("⌘E")
                        .frame(minWidth: 100)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
            }

        }
        .formStyle(.grouped)
    }

    // MARK: - Prompts Tab

    @State private var draggingPrompt: CustomPrompt?

    private var promptsTab: some View {
        VStack(spacing: 0) {
            List {
                ForEach(settings.customPrompts) { prompt in
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(prompt.icon)
                            .frame(width: 20)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prompt.title)
                                .font(.body)
                            Text(prompt.systemPrompt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button(action: {
                            editingPrompt = prompt
                        }) {
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            settings.customPrompts.removeAll { $0.id == prompt.id }
                        }) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
                .onMove { source, destination in
                    settings.customPrompts.move(fromOffsets: source, toOffset: destination)
                }
            }

            Divider()

            HStack {
                Button(action: {
                    editingPrompt = CustomPrompt(icon: "star", title: "", systemPrompt: "{{text}}")
                }) {
                    Label("添加提示词", systemImage: "plus")
                }

                Spacer()

                Button("恢复默认") {
                    settings.customPrompts = CustomPrompt.defaults
                }
                .foregroundStyle(.secondary)
            }
            .padding(12)
        }
    }

    // MARK: - Actions

    private func fetchModels() {
        guard !settings.apiKey.isEmpty, !settings.apiBaseURL.isEmpty else { return }
        fetchModelsTask?.cancel()
        fetchGeneration += 1
        let currentGeneration = fetchGeneration
        isFetchingModels = true
        fetchError = nil

        let baseURL = settings.apiBaseURL
        let apiKey = settings.apiKey
        let normalizedURL = AIService.normalizedBaseURL(baseURL)
        print("[Y1Y] Fetching models from: \(normalizedURL)/models")

        fetchModelsTask = Task {
            do {
                let models = try await AIService.fetchModels(
                    baseURL: baseURL,
                    apiKey: apiKey
                )
                guard !Task.isCancelled else { return }
                print("[Y1Y] Fetched \(models.count) models")
                await MainActor.run {
                    guard currentGeneration == fetchGeneration else { return }
                    availableModels = settings.orderedModels(from: models)
                    isFetchingModels = false
                    if settings.modelName.isEmpty, let firstFavorite = settings.favoriteModels.first {
                        settings.modelName = firstFavorite
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("[Y1Y] Fetch models error: \(error)")
                await MainActor.run {
                    guard currentGeneration == fetchGeneration else { return }
                    fetchError = error.localizedDescription
                    isFetchingModels = false
                }
            }
        }
    }

    private func openModelLibrary() {
        isModelLibraryPresented = true
        fetchModels()
    }

    private func invalidateModelLibrary() {
        availableModels = []
        fetchError = nil
        fetchModelsTask?.cancel()
        isFetchingModels = false
    }

    private func displayModelName(_ model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let slashIndex = trimmed.firstIndex(of: "/") else { return trimmed }
        return String(trimmed[trimmed.index(after: slashIndex)...])
    }

    private var accountConfigurationID: String {
        BalanceCacheStore.scope(
            baseURL: settings.apiBaseURL,
            apiKey: settings.apiKey
        )
    }

    @ViewBuilder
    private func addedModelRow(for model: String) -> some View {
        HStack(spacing: 10) {
            Text(displayModelName(model))
                .lineLimit(1)

            Spacer()

            if settings.modelName == model {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }

            Button(action: {
                settings.removeFavoriteModel(model)
                if settings.modelName == model {
                    settings.modelName = settings.favoriteModels.first ?? ""
                }
            }) {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            settings.modelName = model
        }
    }
}

struct ModelLibrarySheet: View {
    let models: [String]
    let favoriteModels: [String]
    let isLoading: Bool
    let errorMessage: String?
    let onRefresh: () -> Void
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredModels: [String] {
        let normalizedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return models }
        return models.filter {
            $0.localizedCaseInsensitiveContains(normalizedQuery) ||
            displayModelName($0).localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private func displayModelName(_ model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let slashIndex = trimmed.firstIndex(of: "/") else { return trimmed }
        return String(trimmed[trimmed.index(after: slashIndex)...])
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("添加模型")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
            }

            TextField("搜索模型", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isLoading && models.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("正在获取模型列表...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredModels, id: \.self) { model in
                    HStack(spacing: 10) {
                        Text(displayModelName(model))
                            .lineLimit(1)

                        Spacer()

                        if favoriteModels.contains(model) {
                            Label("已添加", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Button("添加") {
                                onAdd(model)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack {
                Button(action: onRefresh) {
                    Label("刷新列表", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)

                Spacer()

                Text("\(models.count) 个模型")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 520, height: 520)
    }
}

// MARK: - Prompt Editor Sheet

struct PromptEditorSheet: View {
    @State var prompt: CustomPrompt
    let onSave: (CustomPrompt) -> Void
    let onCancel: () -> Void



    var body: some View {
        VStack(spacing: 12) {
            Text(prompt.title.isEmpty ? "新建提示词" : "编辑提示词")
                .font(.headline)

            ScrollView {
                Form {
                    Section("基本信息") {
                        HStack {
                            Text("图标")
                            Spacer()
                            TextField("", text: $prompt.icon)
                                .textFieldStyle(.plain)
                                .font(.title)
                                .frame(width: 40, height: 32)
                                .multilineTextAlignment(.center)
                        }

                        TextField("名称", text: $prompt.title)
                            .textFieldStyle(.roundedBorder)

                        VStack(alignment: .leading) {
                            Text("提示词内容（使用 {{text}} 表示选中的文本）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $prompt.systemPrompt)
                                .font(.body)
                                .frame(height: 100)
                                .border(Color.secondary.opacity(0.2))
                        }
                    }


                }
                .formStyle(.grouped)
            }

            HStack {
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    onSave(prompt)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(prompt.title.isEmpty || prompt.systemPrompt.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 420, height: 380)
    }
}
