//
//  TranslatableCommentText.swift
//  winston
//
//  Created by Claude Code on 31/08/25.
//

import SwiftUI
import Defaults
import MarkdownUI

struct TranslatableCommentText: View {
    let text: String
    let style: ThemeText
    let lineLimit: Int?
    let showSpoiler: Bool
    
    var body: some View {
        Text(text.md())
            .lineLimit(lineLimit)
            .fontSize(style.size, style.weight.t)
            .foregroundColor(style.color())
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct TranslatedCommentContent: View {
    let originalText: String
    let style: ThemeText
    let showSpoiler: Bool
    
    @StateObject private var translationService = TranslationService.shared
    @Default(.translationSettings) private var settings
    
    @State private var translatedText: String?
    @State private var isTranslating = false
    
    var body: some View {
        if settings.isEnabled && settings.translateComments {
            VStack(alignment: .leading, spacing: 4) {
                // Translated content
                if let translated = translatedText {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Translation:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        
                        Markdown(MarkdownUtil.formatForMarkdown(translated, showSpoiler: showSpoiler))
                            .markdownTheme(.winstonMarkdown(fontSize: style.size * 0.95, lineSpacing: 1.2, textSelection: false))
                            .opacity(0.85)
                            .padding(.leading, 8)
                            .overlay(
                                Rectangle()
                                    .frame(width: 2)
                                    .foregroundColor(.secondary.opacity(0.3)),
                                alignment: .leading
                            )
                    }
                }
                
                // Translation indicator
                if isTranslating {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Translating comment...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 8)
                }
            }
            .onAppear {
                translateIfNeeded()
            }
            .onChange(of: originalText) { _ in
                translatedText = nil
                translateIfNeeded()
            }
            .onChange(of: settings.isEnabled) { _ in
                translateIfNeeded()
            }
            .onChange(of: settings.translateComments) { _ in
                translateIfNeeded()
            }
        }
    }
    
    private func translateIfNeeded() {
        guard settings.isEnabled,
              settings.translateComments,
              !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              translatedText == nil,
              !isTranslating else {
            return
        }
        
        // Skip translation if text is very short (likely not meaningful content)
        let cleanText = originalText.replacingOccurrences(of: "[deleted]", with: "")
            .replacingOccurrences(of: "[removed]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard cleanText.count > 10 else { return }
        
        isTranslating = true
        
        Task {
            let translation = await translationService.translateText(originalText)
            
            await MainActor.run {
                isTranslating = false
                translatedText = translation
            }
        }
    }
}