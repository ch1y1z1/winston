//
//  TranslationSettings.swift
//  winston
//
//  Created by Claude Code on 31/08/25.
//

import Foundation
import Defaults

struct TranslationSettings: Codable, Defaults.Serializable {
    var isEnabled: Bool = false
    var openAIEndpoint: String = "https://api.openai.com/v1/chat/completions"
    var apiKey: String = ""
    var model: String = "gpt-3.5-turbo"
    var targetLanguage: String = "中文"
    var customPrompt: String = "Translate to {{to}} (output translation only):\n\n{{text}}"
    var concurrencyLimit: Int = 3
    var translatePosts: Bool = true
    var translateComments: Bool = true
}

extension Defaults.Keys {
    static let translationSettings = Key<TranslationSettings>("translationSettings", default: TranslationSettings())
}