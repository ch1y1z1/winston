//
//  TranslationService.swift
//  winston
//
//  Created by Claude Code on 31/08/25.
//

import Foundation
import Combine
import Defaults

actor AsyncLimiter {
    private var limit: Int
    private var current: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(limit: Int) { self.limit = max(1, limit) }
    
    func setLimit(_ newLimit: Int) {
        limit = max(1, newLimit)
        resumeWaitersIfPossible()
    }
    
    func acquire() async {
        if current < limit {
            current += 1
            return
        }
        await withCheckedContinuation { cont in
            waiters.append(cont)
        }
    }
    
    func release() {
        if current > 0 { current -= 1 }
        resumeWaitersIfPossible()
    }
    
    private func resumeWaitersIfPossible() {
        while current < limit, !waiters.isEmpty {
            let cont = waiters.removeFirst()
            current += 1
            cont.resume()
        }
    }
}

class TranslationService: ObservableObject {
    static let shared = TranslationService()
    
    @Published private(set) var translationCache: [String: String] = [:]
    @Published private(set) var isTranslating = false
    
    private let session = URLSession.shared
    private let limiter = AsyncLimiter(limit: 3)
    private let maxCacheEntries = 500
    private var cacheOrder: [String] = []
    
    // prevent duplicate in-flight work for same request
    actor Inflight {
        private var tasks: [String: Task<String?, Never>] = [:]
        func run(key: String, _ operation: @escaping () async -> String?) async -> String? {
            if let t = tasks[key] { return await t.value }
            let t = Task<String?, Never> { await operation() }
            tasks[key] = t
            let result = await t.value
            tasks.removeValue(forKey: key)
            return result
        }
    }
    private let inflight = Inflight()
    private var cancellables = Set<AnyCancellable>()
    
    @Default(.translationSettings) private var settings
    
    private init() {
        // initialize concurrency limiter with current settings
        Task { await limiter.setLimit(settings.concurrencyLimit) }
        
        // Update semaphore when concurrency limit changes
        Defaults.publisher(.translationSettings)
            .map { $0.newValue.concurrencyLimit }
            .removeDuplicates()
            .sink { [weak self] newLimit in
                guard let self else { return }
                Task { await self.limiter.setLimit(newLimit) }
            }
            .store(in: &cancellables)

        // Clear cache when model / language / prompt changes
        Defaults.publisher(.translationSettings)
            .map { ($0.oldValue.model, $0.oldValue.targetLanguage, $0.oldValue.customPrompt, $0.newValue.model, $0.newValue.targetLanguage, $0.newValue.customPrompt) }
            .filter { oldModel, oldLang, oldPrompt, newModel, newLang, newPrompt in
                return oldModel != newModel || oldLang != newLang || oldPrompt != newPrompt
            }
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.translationCache.removeAll()
                    self?.cacheOrder.removeAll()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateConcurrencyLimit(_ newLimit: Int) { /* kept for compatibility; no-op */ }
    
    func translateText(_ text: String) async -> String? {
        guard settings.isEnabled,
              !settings.apiKey.isEmpty,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let key = cacheKey(for: text)
        // Check cache first
        if let cachedTranslation = translationCache[key] {
            return cachedTranslation
        }
        
        // De-duplicate in-flight work for identical requests
        let result = await inflight.run(key: key) { [weak self] in
            guard let self else { return nil }
            do {
                let translation = try await self.performTranslation(text)
                let trimmed = translation.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            } catch is CancellationError {
                return nil
            } catch {
                print("Translation error: \(error)")
                return nil
            }
        }
        
        if let translation = result {
            await MainActor.run {
                translationCache[key] = translation
                cacheOrder.append(key)
                if translationCache.count > maxCacheEntries {
                    let overflow = translationCache.count - maxCacheEntries
                    if overflow > 0 && cacheOrder.count >= overflow {
                        let toRemove = cacheOrder.prefix(overflow)
                        toRemove.forEach { translationCache.removeValue(forKey: $0) }
                        cacheOrder.removeFirst(overflow)
                    }
                }
            }
        }
        return result
    }
    
    private func performTranslation(_ text: String) async throws -> String {
        // Cooperative limiting that does not block threads
        await limiter.acquire()
        defer { Task { await limiter.release() } }
        if Task.isCancelled { throw CancellationError() }
        
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
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Simple retry for rate limit / server errors
        var lastError: Error?
        for attempt in 0..<3 {
            if Task.isCancelled { throw CancellationError() }
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw TranslationError.apiError
                }
                switch httpResponse.statusCode {
                case 200:
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        return content.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        throw TranslationError.invalidResponse
                    }
                case 401, 403:
                    throw TranslationError.unauthorized
                case 429, 500...599:
                    // retryable
                    lastError = TranslationError.rateLimited
                default:
                    throw TranslationError.apiError
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
            // backoff before next try
            let delayMs = 500 * (1 << attempt)
            try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
        }
        throw lastError ?? TranslationError.apiError
    }
    
    func clearCache() {
        translationCache.removeAll()
        cacheOrder.removeAll()
    }

    private func cacheKey(for text: String) -> String {
        // Include parameters that affect output to avoid stale cache when settings change
        let prompt = settings.customPrompt
        let lang = settings.targetLanguage
        let model = settings.model
        return "\(model)|\(lang)|\(prompt)|\(text)"
    }

    func testConnection() async -> Result<Void, TranslationError> {
        guard settings.isEnabled, !settings.apiKey.isEmpty else {
            return .failure(.unauthorized)
        }
        do {
            _ = try await performTranslation("Hello")
            return .success(())
        } catch let e as TranslationError {
            return .failure(e)
        } catch is CancellationError {
            return .failure(.apiError)
        } catch {
            return .failure(.apiError)
        }
    }
}

enum TranslationError: Error {
    case invalidEndpoint
    case apiError
    case invalidResponse
    case unauthorized
    case rateLimited
}
