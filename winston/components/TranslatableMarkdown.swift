//
//  TranslatableMarkdown.swift
//  winston
//
//  Renders original Markdown content and, when enabled, a translated
//  Markdown version underneath with subdued styling.
//

import SwiftUI
import Defaults
import MarkdownUI

struct TranslatableMarkdown: View {
  let originalText: String
  let style: ThemeText
  let lineSpacing: CGFloat?
  let showSpoiler: Bool
  let isEnabled: Bool

  @StateObject private var translationService = TranslationService.shared
  @Default(.translationSettings) private var settings

  @State private var translatedText: String?
  @State private var isTranslating = false

  init(
    text: String,
    style: ThemeText,
    lineSpacing: CGFloat? = nil,
    showSpoiler: Bool = false,
    isEnabled: Bool = true
  ) {
    self.originalText = text
    self.style = style
    self.lineSpacing = lineSpacing
    self.showSpoiler = showSpoiler
    self.isEnabled = isEnabled
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Original markdown
      Markdown(MarkdownUtil.formatForMarkdown(originalText, showSpoiler: showSpoiler))
        .markdownTheme(.winstonMarkdown(fontSize: style.size, lineSpacing: lineSpacing ?? 1.2, textSelection: false))

      // Translated markdown (if available and enabled)
      if settings.isEnabled && isEnabled, let translated = translatedText, !translated.isEmpty {
        Markdown(MarkdownUtil.formatForMarkdown(translated, showSpoiler: showSpoiler))
          .markdownTheme(.winstonMarkdown(fontSize: style.size * 0.95, lineSpacing: (lineSpacing ?? 1.2), textSelection: false))
          .opacity(0.85)
          .padding(.leading, 8)
          .overlay(
            Rectangle()
              .frame(width: 2)
              .foregroundColor(.secondary.opacity(0.3)),
            alignment: .leading
          )
      }

      if isTranslating {
        HStack(spacing: 6) {
          ProgressView().scaleEffect(0.7)
          Text("Translating...")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }
    }
    .task(id: cacheKey) {
      await translateIfNeeded()
    }
  }

  private var cacheKey: String {
    "\(originalText)|\(style.size)|\(settings.isEnabled)|\(settings.translatePosts)|\(settings.model)|\(settings.targetLanguage)"
  }

  private func translateIfNeeded() async {
    guard settings.isEnabled,
          settings.translatePosts,
          isEnabled,
          !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          translatedText == nil,
          !isTranslating else { return }

    isTranslating = true
    let translation = await translationService.translateText(originalText)
    await MainActor.run {
      isTranslating = false
      translatedText = translation
    }
  }
}

