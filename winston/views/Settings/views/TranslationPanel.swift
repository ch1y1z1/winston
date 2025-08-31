//
//  TranslationPanel.swift
//  winston
//
//  Created by Claude Code on 31/08/25.
//

import SwiftUI
import Defaults

struct TranslationPanel: View {
  @Default(.translationSettings) private var settings
  @StateObject private var translationService = TranslationService.shared
  @Environment(\.useTheme) private var theme
  
  @State private var isTestingConnection = false
  @State private var testResult: TestResult?
  
  enum TestResult { case success(String), failure(String) }
  
  var body: some View {
    List {
      Group {
        Section("Translation") {
          Toggle("Enable Translation", isOn: $settings.isEnabled)
          Text("Automatically translate posts and comments using OpenAI API")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        
        if settings.isEnabled {
          Section("API Configuration") {
            LabeledTextField("OpenAI Endpoint", $settings.openAIEndpoint)
            LabeledTextField("API Key", $settings.apiKey)
            LabeledTextField("Model", $settings.model)
            LabeledTextField("Target Language", $settings.targetLanguage)
          }
          
          Section("Translation Options") {
            Toggle("Translate Posts", isOn: $settings.translatePosts)
            Toggle("Translate Comments", isOn: $settings.translateComments)
            VStack(alignment: .leading, spacing: 8) {
              Text("Custom Prompt")
                .font(.subheadline)
                .fontWeight(.medium)
              TextEditor(text: $settings.customPrompt)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
              Text("Use {{to}} for target language and {{text}} for content")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          
          Section("Performance") {
            HStack {
              Text("Concurrency Limit")
              Spacer()
              Text("\(settings.concurrencyLimit)").foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { Double(settings.concurrencyLimit) }, set: { settings.concurrencyLimit = Int($0) }), in: 1...10, step: 1)
            Text("Number of simultaneous translation requests")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          
          Section("Test Connection") {
            Button(action: testConnection) {
              HStack {
                if isTestingConnection { ProgressView().scaleEffect(0.8) }
                Text(isTestingConnection ? "Testing..." : "Test Connection")
              }
            }
            .disabled(isTestingConnection || settings.apiKey.isEmpty)
            
            if let result = testResult {
              switch result {
              case .success(let message):
                Text(message).font(.caption).foregroundStyle(.green)
              case .failure(let error):
                Text(error).font(.caption).foregroundStyle(.red)
              }
            }
          }
          
          Section("Cache Management") {
            HStack {
              Text("Cached Translations")
              Spacer()
              Text("\(translationService.translationCache.count)").foregroundStyle(.secondary)
            }
            Button("Clear Cache") { translationService.clearCache() }
              .foregroundColor(.red)
          }
        }
      }
      .themedListSection()
    }
    .themedListBG(theme.lists.bg)
    .navigationTitle("Translation")
    .navigationBarTitleDisplayMode(.inline)
  }
  
  private func testConnection() {
    guard !settings.apiKey.isEmpty else { return }
    isTestingConnection = true
    testResult = nil
    Task {
      let result = await translationService.translateText("Hello, world!")
      await MainActor.run {
        isTestingConnection = false
        testResult = result != nil ? .success("✅ Connection successful!") : .failure("❌ Connection failed. Please check your settings.")
      }
    }
  }
}
