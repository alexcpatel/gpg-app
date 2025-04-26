import SwiftUI
import AppKit

struct ContentView: View {
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var selectedPrivateKey: String = ""
    @State private var selectedPublicKey: String = ""
    @State private var privateKeys: [String] = []
    @State private var publicKeys: [String] = []
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                // Left side - Input
                VStack(alignment: .leading) {
                    Text("Input")
                        .font(.headline)
                        .foregroundColor(.white)
                    NSTextViewWrapper(text: $inputText)
                        .frame(minWidth: 300, minHeight: 200)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                }
                
                // Right side - Output
                VStack(alignment: .leading) {
                    Text("Output")
                        .font(.headline)
                        .foregroundColor(.white)
                    NSTextViewWrapper(text: .constant(outputText), isEditable: false)
                        .frame(minWidth: 300, minHeight: 200)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                }
            }
            .padding()
            
            // Key Selection
            HStack {
                VStack(alignment: .leading) {
                    Text("Your Private Key:")
                        .foregroundColor(.white)
                    NSPopUpButtonWrapper(
                        items: privateKeys,
                        selectedItem: $selectedPrivateKey
                    )
                    .frame(width: 300, height: 30)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Recipient's Public Key:")
                        .foregroundColor(.white)
                    NSPopUpButtonWrapper(
                        items: publicKeys,
                        selectedItem: $selectedPublicKey
                    )
                    .frame(width: 300, height: 30)
                }
            }
            .padding()
            
            // Operation Buttons
            HStack(spacing: 20) {
                Button("Encrypt") {
                    encryptMessage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPublicKey.isEmpty || inputText.isEmpty)
                
                Button("Decrypt") {
                    decryptMessage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPrivateKey.isEmpty || inputText.isEmpty)
                
                Button("Sign") {
                    signMessage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPrivateKey.isEmpty || inputText.isEmpty)
                
                Button("Verify") {
                    verifyMessage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.isEmpty)
            }
            .padding()
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
    
    private func loadKeys() {
        privateKeys = GPGService.shared.listPrivateKeys()
        publicKeys = GPGService.shared.listPublicKeys()
        
        if !privateKeys.isEmpty {
            selectedPrivateKey = privateKeys[0]
        }
        if !publicKeys.isEmpty {
            selectedPublicKey = publicKeys[0]
        }
    }
    
    private func encryptMessage() {
        guard let result = GPGService.shared.encrypt(message: inputText, recipientKey: selectedPublicKey) else {
            errorMessage = "Failed to encrypt message"
            showError = true
            return
        }
        outputText = result
    }
    
    private func decryptMessage() {
        guard let result = GPGService.shared.decrypt(message: inputText, privateKey: selectedPrivateKey) else {
            errorMessage = "Failed to decrypt message"
            showError = true
            return
        }
        outputText = result
    }
    
    private func signMessage() {
        guard let result = GPGService.shared.sign(message: inputText, privateKey: selectedPrivateKey) else {
            errorMessage = "Failed to sign message"
            showError = true
            return
        }
        outputText = result
    }
    
    private func verifyMessage() {
        let isValid = GPGService.shared.verify(message: inputText)
        outputText = isValid ? "Signature is valid" : "Signature is invalid"
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
        textView.textColor = NSColor.textColor
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        
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
