//
//  TranslationService.swift
//  winston
//
//  Created by Claude Code on 31/08/25.
//

import Foundation
import Combine
import Defaults

class TranslationService: ObservableObject {
    static let shared = TranslationService()
    
    @Published private(set) var translationCache: [String: String] = [:]
    @Published private(set) var isTranslating = false
    
    private let session = URLSession.shared
    private var semaphore: DispatchSemaphore = DispatchSemaphore(value: 3)
    private var cancellables = Set<AnyCancellable>()
    
    @Default(.translationSettings) private var settings
    
    private init() {
        // initialize concurrency limiter with current settings
        self.semaphore = DispatchSemaphore(value: settings.concurrencyLimit)
        
        // Update semaphore when concurrency limit changes
        Defaults.publisher(.translationSettings)
            .map { $0.newValue.concurrencyLimit }
            .removeDuplicates()
            .sink { [weak self] newLimit in
                self?.updateConcurrencyLimit(newLimit)
            }
            .store(in: &cancellables)
    }
    
    private func updateConcurrencyLimit(_ newLimit: Int) {
        // Replace semaphore with a new one using updated limit.
        // Simplified: existing waits continue; new tasks will use new limit.
        self.semaphore = DispatchSemaphore(value: max(1, newLimit))
    }
    
    func translateText(_ text: String) async -> String? {
        guard settings.isEnabled,
              !settings.apiKey.isEmpty,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        // Check cache first
        if let cachedTranslation = translationCache[text] {
            return cachedTranslation
        }
        
        do {
            let translation = try await performTranslation(text)
            
            // Update cache on main thread
            await MainActor.run {
                translationCache[text] = translation
            }
            
            return translation
        } catch {
            print("Translation error: \(error)")
            return nil
        }
    }
    
    private func performTranslation(_ text: String) async throws -> String {
        semaphore.wait()
        defer { semaphore.signal() }
        
        guard let url = URL(string: settings.openAIEndpoint) else {
            throw TranslationError.invalidEndpoint
        }
        
        let prompt = settings.customPrompt
            .replacingOccurrences(of: "{{to}}", with: settings.targetLanguage)
            .replacingOccurrences(of: "{{text}}", with: text)
        
        let requestBody: [String: Any] = [
            "model": settings.model,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.3,
            "max_tokens": 1000
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranslationError.apiError
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw TranslationError.invalidResponse
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func clearCache() {
        translationCache.removeAll()
    }
}

enum TranslationError: Error {
    case invalidEndpoint
    case apiError
    case invalidResponse
}
