import Foundation

extension ChatViewModel {
    func sendPrompt() {
        stopVoiceInput()
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = pendingImages
        let files = pendingFiles
        guard !text.isEmpty || !images.isEmpty || !files.isEmpty else {
            return
        }
        deliveryCoordinator.setDeliveryEnabled(!isOffline)
        switch deliveryCoordinator.enqueuePrompt(text, images: images, files: files) {
        case .queued:
            prompt = ""
            pendingImages = []
            pendingFiles = []
            errorMessage = nil
        case .rejected(let message):
            errorMessage = message
        }
    }

    func retryMessage(_ message: ChatMessage) {
        deliveryCoordinator.setDeliveryEnabled(!isOffline)
        if deliveryCoordinator.retryMessage(message) {
            errorMessage = nil
        }
    }

    func flushQueuedMessages() async {
        deliveryCoordinator.setDeliveryEnabled(!isOffline)
        await deliveryCoordinator.flushQueuedMessages()
    }

    func stopActiveResponse() {
        deliveryCoordinator.stopActiveResponse()
    }
}
