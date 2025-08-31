//
//  TranslatableTitle.swift
//  winston
//
//  Created by Claude Code on 31/08/25.
//

import SwiftUI
import Defaults

struct TranslatableTitle: View, Equatable {
    static func == (lhs: TranslatableTitle, rhs: TranslatableTitle) -> Bool {
        lhs.label == rhs.label && 
        lhs.theme == rhs.theme && 
        lhs.size == rhs.size && 
        (lhs.attrString?.isEqual(to: rhs.attrString ?? NSAttributedString()) ?? false)
    }
    
    let attrString: NSAttributedString?
    let label: String
    let theme: ThemeText
    let size: CGSize
    let tags: [PrependTag]
    
    @StateObject private var translationService = TranslationService.shared
    @Default(.translationSettings) private var settings
    
    @State private var translatedTitle: String?
    @State private var isTranslating = false
    
    init(attrString: NSAttributedString? = nil, label: String, theme: ThemeText, size: CGSize, nsfw: Bool = false, flair: String? = nil) {
        self.label = label
        self.theme = theme
        self.size = size
        self.attrString = attrString
        self.tags = []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Original title
            if let attrString = attrString {
                Prepend(attrString: attrString, title: label, fontSize: theme.size, fontWeight: theme.weight.ut, color: theme.color.uiColor(), tags: tags, size: size)
                    .equatable()
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Translated title (if available and enabled)
            if settings.isEnabled && settings.translatePosts, 
               let translated = translatedTitle, 
               !translated.isEmpty {
                Text(translated)
                    .fontSize(theme.size, theme.weight.t)
                    .foregroundColor(theme.color().opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
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
                        .scaleEffect(0.6)
                    Text("Translating title...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 8)
            }
        }
        .onAppear {
            translateIfNeeded()
        }
        .onChange(of: label) { _ in
            translatedTitle = nil
            translateIfNeeded()
        }
        .onChange(of: settings.isEnabled) { _ in
            translateIfNeeded()
        }
        .onChange(of: settings.translatePosts) { _ in
            translateIfNeeded()
        }
    }
    
    private func translateIfNeeded() {
        guard settings.isEnabled,
              settings.translatePosts,
              !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              translatedTitle == nil,
              !isTranslating else {
            return
        }
        
        isTranslating = true
        
        Task {
            let translation = await translationService.translateText(label)
            
            await MainActor.run {
                isTranslating = false
                translatedTitle = translation
            }
        }
    }
}