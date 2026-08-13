import Foundation

extension ChatViewModel {
    func toggleVoiceInput() {
        if voiceInputController.isActive {
            stopVoiceInput()
            return
        }
        guard let conversationID = activeConversationID else {
            errorMessage = "Start a conversation before using voice input."
            return
        }

        errorMessage = nil
        voiceInputController.start(
            promptPrefix: prompt,
            conversationID: conversationID,
            transcriptHandler: { [weak self] targetConversationID, text in
                guard self?.activeConversationID == targetConversationID else {
                    return
                }
                self?.prompt = text
            },
            failureHandler: { [weak self] targetConversationID, message in
                guard self?.activeConversationID == targetConversationID else {
                    return
                }
                self?.errorMessage = message
            }
        )
    }

    func stopVoiceInput() {
        voiceInputController.stop()
    }

    @discardableResult
    func addPendingImage(
        data: Data,
        mimeType: String,
        to conversationID: String? = nil
    ) -> Bool {
        guard let targetConversationID = conversationID ?? activeConversationID,
              conversation(withID: targetConversationID) != nil else {
            errorMessage = "Start a conversation before adding a photo."
            return false
        }
        var images = targetConversationID == activeConversationID
            ? pendingImages
            : imageDraftsByConversationID[targetConversationID] ?? []
        guard images.count < ChatImageAttachment.maximumCount else {
            errorMessage = "You can attach up to \(ChatImageAttachment.maximumCount) photos."
            return false
        }
        guard !data.isEmpty else {
            errorMessage = "That photo could not be loaded."
            return false
        }
        guard data.count <= ChatImageAttachment.maximumByteCount else {
            errorMessage = "That photo is larger than 10 MB."
            return false
        }
        let normalizedMimeType = mimeType.lowercased()
        guard normalizedMimeType.hasPrefix("image/") else {
            errorMessage = "The selected item is not an image."
            return false
        }

        images.append(
            ChatImageAttachment(data: data, mimeType: normalizedMimeType)
        )
        if targetConversationID == activeConversationID {
            pendingImages = images
        } else {
            imageDraftsByConversationID[targetConversationID] = images
        }
        errorMessage = nil
        return true
    }

    func removePendingImage(id: String) {
        pendingImages.removeAll { $0.id == id }
    }

    func reportImageImportFailure(_ error: Error) {
        errorMessage = "Couldn’t load that photo. \(error.localizedDescription)"
    }

    @discardableResult
    func addPendingFile(
        name: String,
        data: Data,
        mimeType: String,
        to conversationID: String? = nil
    ) -> Bool {
        guard let targetConversationID = conversationID ?? activeConversationID,
              conversation(withID: targetConversationID) != nil else {
            errorMessage = "Start a conversation before adding a file."
            return false
        }
        var files = targetConversationID == activeConversationID
            ? pendingFiles
            : fileDraftsByConversationID[targetConversationID] ?? []
        guard files.count < ChatFileAttachment.maximumCount else {
            errorMessage = "You can attach up to \(ChatFileAttachment.maximumCount) files."
            return false
        }
        guard !data.isEmpty else {
            errorMessage = "That file is empty or could not be loaded."
            return false
        }
        guard data.count <= ChatFileAttachment.maximumByteCount else {
            errorMessage = "That file is larger than 10 MB."
            return false
        }
        let safeName = URL(fileURLWithPath: name).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeName.isEmpty else {
            errorMessage = "That file has no valid name."
            return false
        }

        files.append(
            ChatFileAttachment(
                name: safeName,
                data: data,
                mimeType: mimeType.isEmpty ? "application/octet-stream" : mimeType.lowercased()
            )
        )
        if targetConversationID == activeConversationID {
            pendingFiles = files
        } else {
            fileDraftsByConversationID[targetConversationID] = files
        }
        errorMessage = nil
        return true
    }

    func removePendingFile(id: String) {
        pendingFiles.removeAll { $0.id == id }
    }

    func reportFileImportFailure(_ error: Error) {
        errorMessage = "Couldn’t load that file. \(error.localizedDescription)"
    }

    func restorePendingAttachmentDrafts() {
        guard let activeConversationID else {
            pendingImages = []
            pendingFiles = []
            return
        }
        pendingImages = imageDraftsByConversationID[activeConversationID] ?? []
        pendingFiles = fileDraftsByConversationID[activeConversationID] ?? []
    }
}
