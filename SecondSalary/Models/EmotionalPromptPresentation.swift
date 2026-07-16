import Foundation

struct EmotionalPromptPresentation: Equatable, Identifiable, Sendable {
    let id: UUID
    let prompt: EmotionalPrompt
    let message: String
    let triggeredAt: Date

    init(
        id: UUID = UUID(),
        prompt: EmotionalPrompt,
        message: String,
        triggeredAt: Date
    ) {
        self.id = id
        self.prompt = prompt
        self.message = message
        self.triggeredAt = triggeredAt
    }
}
