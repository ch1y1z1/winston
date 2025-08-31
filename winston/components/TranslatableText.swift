//
//  TranslatableText.swift
//  winston
//
//  Created by Claude Code on 31/08/25.
//

import SwiftUI
import Defaults

struct TranslatableText: View {
    let originalText: String
    let textStyle: ThemeText
    let lineLimit: Int?
    let lineSpacing: CGFloat?
    let isEnabled: Bool
    
    @StateObject private var translationService = TranslationService.shared
    @Default(.translationSettings) private var settings
    
    @State private var translatedText: String?
    @State private var isTranslating = false
    
    init(
        text: String,
        style: ThemeText,
        lineLimit: Int? = nil,
        lineSpacing: CGFloat? = nil,
        isEnabled: Bool = true
    ) {
        self.originalText = text
        self.textStyle = style
        self.lineLimit = lineLimit
        self.lineSpacing = lineSpacing
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Original text
            textView(for: originalText)
            
            // Translated text (if available and enabled)
            if settings.isEnabled && settings.translatePosts && isEnabled, let translated = translatedText {
                textView(for: translated)
                    .opacity(0.8)
                    .padding(.leading, 8)
                    .overlay(
                        Rectangle()
                            .frame(width: 2)
                            .foregroundColor(.secondary.opacity(0.3)),
                        alignment: .leading
                    )
            }
            
            // Translation indicator
            if isTranslating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Translating...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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
        .onChange(of: settings.translatePosts) { _ in
            translateIfNeeded()
        }
    }
    
    @ViewBuilder
    private func textView(for text: String) -> some View {
        let view = Text(text)
            .fontSize(textStyle.size, textStyle.weight.t)
            .foregroundColor(textStyle.color())
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        
        if let lineLimit = lineLimit {
            view.lineLimit(lineLimit)
        } else {
            view
        }
        
        if let lineSpacing = lineSpacing {
            view.lineSpacing(lineSpacing)
        } else {
            view
        }
    }
    
    private func translateIfNeeded() {
        guard settings.isEnabled,
              settings.translatePosts,
              isEnabled,
              !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              translatedText == nil,
              !isTranslating else {
            return
        }
        
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