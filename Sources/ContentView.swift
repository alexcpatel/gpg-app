import SwiftUI
import AppKit

// MARK: - Key Selection Menu
struct KeySelectionMenu: View {
    let title: String
    let keys: [String]
    let selectedKey: String
    let onSelect: (String) -> Void
    let onRefreshKeys: () -> Void
    
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
                Picker("Mode", selection: $selectedMode) {
                    ForEach(OperationMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
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
                        onRefreshKeys: loadKeys
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
                            onRefreshKeys: loadKeys
                        )
                    }
                }
                .padding(.horizontal)
                
                // Message Views
                HStack(spacing: 20) {
                    MessageView(
                        title: selectedMode == .sendMessage ? "Message to Send" : "Encrypted Message",
                        text: currentMode.inputText,
                        isOutput: false,
                        onClear: {
                            currentMode.inputText.wrappedValue = ""
                        }
                    )
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .padding(.vertical, 8)
                    
                    ZStack(alignment: .topTrailing) {
                        MessageView(
                            title: selectedMode == .sendMessage ? "Encrypted Result" : "Decrypted Message",
                            text: currentMode.outputText,
                            isOutput: true,
                            verificationInfo: selectedMode == .receiveMessage && !currentMode.outputText.wrappedValue.isEmpty ? 
                                (isVerified: currentMode.isVerified.wrappedValue, senderInfo: currentMode.senderInfo.wrappedValue) : nil,
                            onCopy: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(currentMode.outputText.wrappedValue, forType: .string)
                                withAnimation {
                                    showCopyToast = true
                                    // Dismiss after 1.5 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation {
                                            showCopyToast = false
                                        }
                                    }
                                }
                            }
                        )
                        
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
                .padding(.horizontal)
                
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
                        .disabled(
                            currentMode.selectedPrivateKey.wrappedValue.isEmpty || 
                            currentMode.inputText.wrappedValue.isEmpty
                        )
                    }
                    
                    Spacer()
                }
                .padding(.bottom)
            }
            .background(Color(NSColor.windowBackgroundColor))
            .onAppear {
                loadKeys()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadKeys() {
        privateKeys = GPGService.shared.listPrivateKeys()
        publicKeys = GPGService.shared.listPublicKeys()
        
        if !privateKeys.isEmpty {
            sendMode.selectedPrivateKey = privateKeys[0]
            receiveMode.selectedPrivateKey = privateKeys[0]
        }
        if !publicKeys.isEmpty {
            sendMode.selectedPublicKey = publicKeys[0]
        }
    }
    
    private func sendMessage() {
        guard let result = GPGService.shared.encryptAndSign(
            message: sendMode.inputText,
            senderPrivateKey: sendMode.selectedPrivateKey,
            recipientPublicKey: sendMode.selectedPublicKey
        ) else {
            errorMessage = "Failed to encrypt and sign message"
            showError = true
            return
        }
        
        sendMode.outputText = result
        sendMode.isVerified = false
        sendMode.senderInfo = ""
    }
    
    private func receiveMessage() {
        let result = GPGService.shared.decryptAndVerify(
            message: receiveMode.inputText,
            recipientPrivateKey: receiveMode.selectedPrivateKey
        )
        
        guard let decryptedText = result.decryptedText else {
            errorMessage = "Failed to decrypt message"
            showError = true
            return
        }
        
        receiveMode.outputText = decryptedText
        receiveMode.isVerified = result.isVerified
        receiveMode.senderInfo = result.senderInfo ?? ""
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
