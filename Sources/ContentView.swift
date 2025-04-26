import SwiftUI
import AppKit

// MARK: - Key Selection Menu
struct KeySelectionMenu: View {
    let title: String
    let keys: [String]
    let selectedKey: String
    let onSelect: (String) -> Void
    let onRefreshKeys: () -> Void
    let allowDeselection: Bool
    
    init(title: String, keys: [String], selectedKey: String, onSelect: @escaping (String) -> Void, onRefreshKeys: @escaping () -> Void, allowDeselection: Bool = false) {
        self.title = title
        self.keys = keys
        self.selectedKey = selectedKey
        self.onSelect = onSelect
        self.onRefreshKeys = onRefreshKeys
        self.allowDeselection = allowDeselection
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .foregroundColor(.white)
                    .font(.headline)
                
                Spacer()
                
                // Utility buttons aligned to the right of the title
                HStack(spacing: 8) {
                    Button(action: {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/GPG Keychain.app"))
                    }) {
                        Image(systemName: "key.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open GPG Keychain")
                    
                    Button(action: onRefreshKeys) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh GPG Keys")
                }
            }
            
            Menu {
                if allowDeselection {
                    Button(action: { onSelect("") }) {
                        Text("None")
                            .foregroundColor(.secondary)
                    }
                }
                
                ForEach(keys, id: \.self) { key in
                    Button(action: { onSelect(key) }) {
                        if key == selectedKey {
                            Label(
                                title: { KeyDisplayView(key: key) },
                                icon: { Image(systemName: "checkmark") }
                            )
                        } else {
                            KeyDisplayView(key: key)
                        }
                    }
                }
            } label: {
                HStack {
                    if selectedKey.isEmpty {
                        Text("Select a key")
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "checkmark")
                            .foregroundColor(.primary)
                        KeyDisplayView(key: selectedKey)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Key Display View
struct KeyDisplayView: View {
    let key: String
    
    var body: some View {
        if let bracketRange = key.range(of: " ["),
           let endBracketRange = key.range(of: "]", options: .backwards) {
            HStack(spacing: 4) {
                Text(key[..<bracketRange.lowerBound])
                Text(key[bracketRange.upperBound..<endBracketRange.lowerBound])
                    .font(.system(size: NSFont.smallSystemFontSize, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        } else {
            Text(key)
        }
    }
}

// MARK: - Toast View
struct ToastView: View {
    let message: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
            Text(message)
                .font(.body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(color == .primary ? 
                 Color(NSColor.darkGray) : 
                 color.opacity(0.95))
        .foregroundColor(.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

// MARK: - Message Input/Output View
struct MessageView: View {
    let title: String
    @Binding var text: String
    let isOutput: Bool
    var verificationInfo: (isVerified: Bool, senderInfo: String)?
    var onClear: (() -> Void)?
    var onCopy: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with title, verification badge, and action buttons
            HStack(alignment: .center) {
                // Title
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Verification badge if needed
                if let info = verificationInfo {
                    HStack(spacing: 4) {
                        Image(systemName: info.isVerified ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundColor(info.isVerified ? .green : .red)
                        Text(info.isVerified ? "Verified" : "Not Verified")
                            .foregroundColor(info.isVerified ? .green : .red)
                            .font(.footnote)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(info.isVerified ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .cornerRadius(6)
                }
                
                // Fixed-width container for action buttons
                HStack(spacing: 8) {
                    Spacer()
                    
                    // Clear button - always visible, disabled when empty
                    if !isOutput && onClear != nil {
                        Button(action: {
                            onClear?()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .imageScale(.medium)
                                Text("Clear")
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .disabled(text.isEmpty)
                        .opacity(text.isEmpty ? 0.5 : 1.0)
                        .help("Clear text")
                        .onHover { hovering in
                            if hovering && !text.isEmpty {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                    
                    // Copy button - always visible, disabled when empty
                    if isOutput && onCopy != nil {
                        Button(action: {
                            onCopy?()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .imageScale(.medium)
                                Text("Copy")
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .disabled(text.isEmpty)
                        .opacity(text.isEmpty ? 0.5 : 1.0)
                        .help("Copy to clipboard")
                        .onHover { hovering in
                            if hovering && !text.isEmpty {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
                .frame(width: 90) // Fixed width for button area
            }
            
            // Text area with shadow and better styling
            NSTextViewWrapper(text: $text, isEditable: !isOutput)
                .frame(minWidth: 300, minHeight: 200)
                .background(isOutput ? Color(NSColor.textBackgroundColor).opacity(0.8) : Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isOutput ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            // Sender info at the bottom
            if let info = verificationInfo, info.isVerified && !info.senderInfo.isEmpty {
                Text("Signed by: \(info.senderInfo)")
                    .font(.footnote)
                    .foregroundColor(.green)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Passphrase Dialog
struct PassphraseDialog: View {
    @Binding var isPresented: Bool
    @Binding var passphrase: String
    var onCancel: () -> Void
    var onSubmit: () -> Void
    
    @State private var localPassphrase: String = ""
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Don't dismiss when tapping outside
                }
            
            // Dialog content
            VStack(spacing: 16) {
                Text("Enter Passphrase")
                    .font(.headline)
                    .padding(.top, 16)
                
                Text("Please enter the passphrase for your GPG key")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                SecureField("Passphrase", text: $localPassphrase)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .focused($isFieldFocused)
                    .onSubmit {
                        passphrase = localPassphrase
                        isPresented = false
                        onSubmit()
                    }
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        localPassphrase = ""
                        isPresented = false
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Decrypt") {
                        passphrase = localPassphrase
                        isPresented = false
                        onSubmit()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(localPassphrase.isEmpty)
                }
                .padding(.bottom, 16)
            }
            .frame(width: 350)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 10)
            .onAppear {
                isFieldFocused = true
            }
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    // Separate state for each mode
    @State private var sendMode = ModeState()
    @State private var receiveMode = ModeState()
    @State private var selectedMode: OperationMode = .sendMessage
    
    // Toast state
    @State private var showCopyToast: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    
    // Passphrase state
    @State private var showPassphrasePrompt: Bool = false
    @State private var passphrase: String = ""
    @State private var pendingDecryptionMessage: String = ""
    @State private var pendingDecryptionKey: String = ""
    
    // Shared state
    @State private var privateKeys: [String] = []
    @State private var publicKeys: [String] = []
    
    struct ModeState {
        var inputText: String = ""
        var outputText: String = ""
        var selectedPrivateKey: String = ""
        var selectedPublicKey: String = ""
        var isVerified: Bool = false
        var senderInfo: String = ""
        var expectedSender: String = ""
    }
    
    enum OperationMode: String, CaseIterable, Identifiable {
        case sendMessage = "Send Message"
        case receiveMessage = "Receive Message"
        
        var id: String { self.rawValue }
    }
    
    private var currentMode: Binding<ModeState> {
        selectedMode == .sendMessage ? $sendMode : $receiveMode
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 16) {
                // Mode selector
                Picker("", selection: $selectedMode) {
                    ForEach(OperationMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.top)
                
                // Key Selection - moved up for better flow
                HStack(spacing: 20) {
                    KeySelectionMenu(
                        title: selectedMode == .sendMessage ? "Your Private Key (for signing)" : "Your Private Key (for decryption)",
                        keys: privateKeys,
                        selectedKey: currentMode.selectedPrivateKey.wrappedValue,
                        onSelect: { key in
                            currentMode.selectedPrivateKey.wrappedValue = key
                            currentMode.outputText.wrappedValue = ""
                            currentMode.isVerified.wrappedValue = false
                            currentMode.senderInfo.wrappedValue = ""
                        },
                        onRefreshKeys: loadKeys,
                        allowDeselection: false
                    )
                    
                    if selectedMode == .sendMessage {
                        KeySelectionMenu(
                            title: "Recipient's Public Key (for encryption)",
                            keys: publicKeys,
                            selectedKey: currentMode.selectedPublicKey.wrappedValue,
                            onSelect: { key in
                                currentMode.selectedPublicKey.wrappedValue = key
                                currentMode.outputText.wrappedValue = ""
                            },
                            onRefreshKeys: loadKeys,
                            allowDeselection: false
                        )
                    } else {
                        KeySelectionMenu(
                            title: "Expected Sender (Optional)",
                            keys: publicKeys,
                            selectedKey: currentMode.expectedSender.wrappedValue,
                            onSelect: { key in
                                currentMode.expectedSender.wrappedValue = key
                                currentMode.outputText.wrappedValue = ""
                                currentMode.isVerified.wrappedValue = false
                                currentMode.senderInfo.wrappedValue = ""
                            },
                            onRefreshKeys: loadKeys,
                            allowDeselection: true
                        )
                    }
                }
                
                // Message Views - Use direct binding to the relevant mode
                HStack(spacing: 20) {
                    if selectedMode == .sendMessage {
                        MessageView(
                            title: "Message to Send",
                            text: $sendMode.inputText,
                            isOutput: false,
                            onClear: {
                                sendMode.inputText = ""
                            }
                        )
                    } else {
                        MessageView(
                            title: "Encrypted Message",
                            text: $receiveMode.inputText,
                            isOutput: false,
                            onClear: {
                                receiveMode.inputText = ""
                            }
                        )
                    }
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .padding(.vertical, 8)
                    
                    ZStack(alignment: .topTrailing) {
                        if selectedMode == .sendMessage {
                            MessageView(
                                title: "Encrypted Result",
                                text: $sendMode.outputText,
                                isOutput: true,
                                onCopy: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(sendMode.outputText, forType: .string)
                                    showCopyToast = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation {
                                            showCopyToast = false
                                        }
                                    }
                                }
                            )
                        } else {
                            MessageView(
                                title: "Decrypted Message",
                                text: $receiveMode.outputText,
                                isOutput: true,
                                verificationInfo: !receiveMode.outputText.isEmpty ? 
                                    (isVerified: receiveMode.isVerified, senderInfo: receiveMode.senderInfo) : nil,
                                onCopy: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(receiveMode.outputText, forType: .string)
                                    showCopyToast = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation {
                                            showCopyToast = false
                                        }
                                    }
                                }
                            )
                        }
                        
                        if showCopyToast {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.secondary)
                                Text("Copied to clipboard")
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .offset(x: -80, y: 0)
                            .transition(.opacity)
                            .zIndex(1)
                        }
                    }
                }
                
                // Operation Button - Moved down below text areas
                HStack {
                    Spacer()
                    
                    if selectedMode == .sendMessage {
                        Button(action: {
                            sendMessage()
                        }) {
                            HStack {
                                Image(systemName: "lock.fill")
                                Text("Encrypt & Sign")
                            }
                            .padding(.horizontal)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(
                            currentMode.selectedPrivateKey.wrappedValue.isEmpty || 
                            currentMode.selectedPublicKey.wrappedValue.isEmpty || 
                            currentMode.inputText.wrappedValue.isEmpty
                        )
                    } else {
                        Button(action: {
                            receiveMessage()
                        }) {
                            HStack {
                                Image(systemName: "lock.open.fill")
                                Text("Decrypt & Verify")
                            }
                            .padding(.horizontal)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(false) // Temporarily remove the disabled condition completely
                    }
                    
                    Spacer()
                }
                .padding(.bottom)
            }
            .padding(.horizontal)
            .background(Color(NSColor.windowBackgroundColor))
            .onAppear {
                loadKeys()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            
            // Custom passphrase dialog
            if showPassphrasePrompt {
                PassphraseDialog(
                    isPresented: $showPassphrasePrompt,
                    passphrase: $passphrase,
                    onCancel: {
                        passphrase = ""
                        errorMessage = "Decryption cancelled"
                        showError = true
                    },
                    onSubmit: {
                        decryptWithPassphrase()
                    }
                )
            }
        }
        .onChange(of: receiveMode.inputText) { newValue in
            logDebug("Input text changed: '\(newValue)', isEmpty: \(newValue.isEmpty), trimmed isEmpty: \(newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)")
        }
        .onChange(of: selectedMode) { newMode in
            logInfo("Mode changed to: \(newMode)")
            // Remove the auto-fill functionality
        }
        .onChange(of: receiveMode.selectedPrivateKey) { newValue in
            logDebug("Private key changed to: \(newValue), isEmpty: \(newValue.isEmpty)")
        }
    }
    
    private func loadKeys() {
        logDebug("Loading GPG keys")
        privateKeys = GPGService.shared.listPrivateKeys()
        publicKeys = GPGService.shared.listPublicKeys()
        
        if !privateKeys.isEmpty {
            sendMode.selectedPrivateKey = privateKeys[0]
            receiveMode.selectedPrivateKey = privateKeys[0]
            logInfo("Loaded \(privateKeys.count) private keys")
        } else {
            logWarning("No private keys found")
        }
        if !publicKeys.isEmpty {
            sendMode.selectedPublicKey = publicKeys[0]
            logInfo("Loaded \(publicKeys.count) public keys")
        } else {
            logWarning("No public keys found")
        }
    }
    
    private func sendMessage() {
        logInfo("Encrypting and signing message")
        guard let result = GPGService.shared.encryptAndSign(
            message: sendMode.inputText,
            senderPrivateKey: sendMode.selectedPrivateKey,
            recipientPublicKey: sendMode.selectedPublicKey
        ) else {
            errorMessage = "Failed to encrypt and sign message"
            showError = true
            logError("Failed to encrypt and sign message")
            return
        }
        
        sendMode.outputText = result
        logDebug("Encrypted message output length: \(result.count) characters")
        sendMode.isVerified = false
        sendMode.senderInfo = ""
        logInfo("Message successfully encrypted and signed")
    }
    
    private func receiveMessage() {
        logInfo("Decrypting and verifying message")
        
        // Debug detailed info about the text
        let trimmedInput = receiveMode.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        logDebug("Input text raw length: \(receiveMode.inputText.count)")
        logDebug("Input text trimmed length: \(trimmedInput.count)")
        logDebug("Selected private key: \(receiveMode.selectedPrivateKey)")
        
        // Debug the message format
        if trimmedInput.isEmpty {
            logError("Input text is empty after trimming")
            errorMessage = "Cannot decrypt: Input text is empty"
            showError = true
            return
        }
        
        // Print the first 20 characters (if available) to help debug
        let previewStart = trimmedInput.prefix(min(20, trimmedInput.count))
        logDebug("Message preview start: \"\(previewStart)...\"")
        
        // Check PGP message format
        let hasCorrectHeader = trimmedInput.hasPrefix("-----BEGIN PGP MESSAGE-----")
        let hasCorrectFooter = trimmedInput.hasSuffix("-----END PGP MESSAGE-----")
        
        logDebug("Message format check - starts with correct header: \(hasCorrectHeader)")
        logDebug("Message format check - ends with correct footer: \(hasCorrectFooter)")
        
        if !hasCorrectHeader || !hasCorrectFooter {
            logError("Invalid PGP message format: Missing proper BEGIN/END markers")
            errorMessage = "Invalid PGP message format. Message must start with '-----BEGIN PGP MESSAGE-----' and end with '-----END PGP MESSAGE-----'"
            showError = true
            return
        }
        
        // Store the message and key for potential passphrase prompt
        pendingDecryptionMessage = receiveMode.inputText
        pendingDecryptionKey = receiveMode.selectedPrivateKey
        
        // First try without passphrase
        let result = GPGService.shared.decryptAndVerify(
            message: receiveMode.inputText,
            recipientPrivateKey: receiveMode.selectedPrivateKey
        )
        
        if result.decryptedText == nil {
            // Decryption failed, likely needs passphrase
            logInfo("Initial decryption failed, prompting for passphrase")
            showPassphrasePrompt = true
            return
        }
        
        handleDecryptionResult(result)
    }
    
    private func decryptWithPassphrase() {
        showPassphrasePrompt = false
        
        logInfo("Attempting decryption with passphrase")
        
        let result = GPGService.shared.decryptAndVerify(
            message: pendingDecryptionMessage,
            recipientPrivateKey: pendingDecryptionKey,
            passphrase: passphrase
        )
        
        // Clear passphrase from memory as soon as possible
        passphrase = ""
        
        handleDecryptionResult(result)
    }
    
    private func handleDecryptionResult(_ result: (decryptedText: String?, isVerified: Bool, senderInfo: String?)) {
        guard let decryptedText = result.decryptedText else {
            logError("Decryption failed")
            errorMessage = "Failed to decrypt message"
            showError = true
            return
        }
        
        receiveMode.outputText = decryptedText
        receiveMode.isVerified = result.isVerified
        receiveMode.senderInfo = result.senderInfo ?? ""
        logInfo("Decryption succeeded. Verification status: \(result.isVerified)")
        
        // Add verification against expected sender if specified
        if !receiveMode.expectedSender.isEmpty && result.isVerified {
            if let senderInfo = result.senderInfo {
                // Extract fingerprint from expected sender key string
                let expectedFingerprint = extractFingerprint(from: receiveMode.expectedSender)
                    .uppercased()
                    .replacingOccurrences(of: " ", with: "")
                
                // Extract any potential fingerprint-like data from senderInfo
                // We need to be lenient as GPG might return different formats
                let senderInfoNormalized = senderInfo.uppercased().replacingOccurrences(of: " ", with: "")
                
                // Detailed logging for debugging
                logDebug("Expected sender: \(receiveMode.expectedSender)")
                logDebug("Expected fingerprint (normalized): \(expectedFingerprint)")
                logDebug("Actual sender info: \(senderInfo)")
                logDebug("Sender info (normalized): \(senderInfoNormalized)")
                
                // Very lenient matching - check if any part of the fingerprint is found in the sender info
                // or vice versa, using multiple approaches
                
                // 1. Check if sender info contains the full fingerprint
                let fullMatch = senderInfoNormalized.contains(expectedFingerprint)
                logDebug("Full fingerprint match: \(fullMatch)")
                
                // 2. Check if sender info contains last 16 chars (key ID)
                let keyIdMatch = senderInfoNormalized.contains(expectedFingerprint.suffix(16))
                logDebug("Key ID (16 chars) match: \(keyIdMatch)")
                
                // 3. Check if sender info contains last 8 chars (short key ID)
                let shortKeyIdMatch = senderInfoNormalized.contains(expectedFingerprint.suffix(8))
                logDebug("Short key ID (8 chars) match: \(shortKeyIdMatch)")
                
                // 4. Check if expected fingerprint contains parts of the sender info
                // This handles cases where the sender info might have a partial fingerprint
                var partialMatch = false
                if senderInfoNormalized.count >= 8 {
                    partialMatch = expectedFingerprint.contains(senderInfoNormalized.suffix(min(16, senderInfoNormalized.count)))
                    logDebug("Reverse partial match: \(partialMatch)")
                }
                
                // 5. Email matching (if email is present in both)
                let emailRegex = try? NSRegularExpression(pattern: "<([^>]+)>")
                var emailMatch = false
                
                if let regex = emailRegex {
                    let expectedRange = NSRange(receiveMode.expectedSender.startIndex..<receiveMode.expectedSender.endIndex, in: receiveMode.expectedSender)
                    let senderRange = NSRange(senderInfo.startIndex..<senderInfo.endIndex, in: senderInfo)
                    
                    let expectedMatches = regex.matches(in: receiveMode.expectedSender, range: expectedRange)
                    let senderMatches = regex.matches(in: senderInfo, range: senderRange)
                    
                    if let expectedEmailMatch = expectedMatches.first, 
                       let senderEmailMatch = senderMatches.first,
                       let expectedEmailRange = Range(expectedEmailMatch.range(at: 1), in: receiveMode.expectedSender),
                       let senderEmailRange = Range(senderEmailMatch.range(at: 1), in: senderInfo) {
                        
                        let expectedEmail = String(receiveMode.expectedSender[expectedEmailRange])
                        let senderEmail = String(senderInfo[senderEmailRange])
                        
                        emailMatch = expectedEmail.lowercased() == senderEmail.lowercased()
                        logDebug("Email match: \(emailMatch) (expected: \(expectedEmail), actual: \(senderEmail))")
                    }
                }
                
                // If any of the match strategies succeed, consider it a match
                let isMatch = fullMatch || keyIdMatch || shortKeyIdMatch || partialMatch || emailMatch
                logDebug("Overall match result: \(isMatch)")
                
                if !isMatch {
                    receiveMode.isVerified = false
                    errorMessage = "Message was not signed by the expected sender"
                    showError = true
                    logWarning("Sender mismatch: expected \(expectedFingerprint), got \(senderInfo)")
                } else {
                    logInfo("Sender verification successful")
                }
            } else {
                // Only show this error if verification was requested but no sender info is available
                receiveMode.isVerified = false
                errorMessage = "Could not verify sender identity"
                showError = true
                logWarning("No sender information available for verification")
            }
        }
    }
    
    // Helper function to extract fingerprint from key string
    private func extractFingerprint(from keyString: String) -> String {
        if let range = keyString.range(of: "[", options: .backwards),
           let endRange = keyString.range(of: "]", options: .backwards) {
            let startIndex = range.upperBound
            let endIndex = endRange.lowerBound
            return String(keyString[startIndex..<endIndex])
        }
        return keyString
    }
}

// MARK: - Native Text View Wrapper
struct NSTextViewWrapper: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = isEditable ? NSColor.textColor : NSColor.textColor.withAlphaComponent(0.8)
        textView.drawsBackground = true
        textView.backgroundColor = isEditable ? NSColor.textBackgroundColor : NSColor.textBackgroundColor.withAlphaComponent(0.8)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NSTextViewWrapper
        
        init(_ parent: NSTextViewWrapper) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - Native Popup Button Wrapper
struct NSPopUpButtonWrapper: NSViewRepresentable {
    var items: [String]
    @Binding var selectedItem: String
    
    func makeNSView(context: Context) -> NSPopUpButton {
        let popUpButton = NSPopUpButton(frame: .zero, pullsDown: false)
        popUpButton.target = context.coordinator
        popUpButton.action = #selector(Coordinator.selectionChanged(_:))
        return popUpButton
    }
    
    func updateNSView(_ nsView: NSPopUpButton, context: Context) {
        nsView.removeAllItems()
        
        for item in items {
            nsView.addItem(withTitle: item)
        }
        
        if !selectedItem.isEmpty, let index = items.firstIndex(of: selectedItem) {
            nsView.selectItem(at: index)
        } else if !items.isEmpty {
            nsView.selectItem(at: 0)
            DispatchQueue.main.async {
                self.selectedItem = items[0]
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: NSPopUpButtonWrapper
        
        init(_ parent: NSPopUpButtonWrapper) {
            self.parent = parent
        }
        
        @objc func selectionChanged(_ sender: NSPopUpButton) {
            if sender.indexOfSelectedItem >= 0 && sender.indexOfSelectedItem < parent.items.count {
                parent.selectedItem = parent.items[sender.indexOfSelectedItem]
            }
        }
    }
} 
