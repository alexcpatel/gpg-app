import Foundation

class GPGService {
    static let shared = GPGService()
    private let gpgPath = "/usr/local/bin/gpg"
    
    private init() {
        // Verify GPG is installed and accessible
        guard FileManager.default.fileExists(atPath: gpgPath) else {
            logError("GPG not found at \(gpgPath)")
            return
        }
        
        // Test GPG connection
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        process.arguments = ["--version"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            logInfo("GPG Version: \(output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n").first ?? "Unknown")")
        } catch {
            logError("Error testing GPG: \(error)")
        }
    }
    
    func listPrivateKeys() -> [String] {
        logDebug("Listing private keys")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        process.arguments = ["--list-secret-keys", "--with-colons"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus != 0 {
                logError("Error listing private keys. Status: \(process.terminationStatus)")
                logDebug("GPG Output: \(output)")
                return []
            }
            
            let keys = parseKeys(from: output, isPrivate: true)
            logInfo("Found \(keys.count) private keys")
            return keys
        } catch {
            logError("Error listing private keys: \(error)")
            return []
        }
    }
    
    func listPublicKeys() -> [String] {
        logDebug("Listing public keys")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        process.arguments = ["--list-keys", "--with-colons"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus != 0 {
                logError("Error listing public keys. Status: \(process.terminationStatus)")
                logDebug("GPG Output: \(output)")
                return []
            }
            
            let keys = parseKeys(from: output, isPrivate: false)
            logInfo("Found \(keys.count) public keys")
            return keys
        } catch {
            logError("Error listing public keys: \(error)")
            return []
        }
    }
    
    private func parseKeys(from output: String, isPrivate: Bool) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        var keys: [String] = []
        var currentFingerprint: String?
        var currentUserID: String?
        
        logDebug("Parsing \(lines.count) lines of GPG output")
        
        for line in lines {
            let components = line.components(separatedBy: ":")
            guard components.count >= 10 else { continue }
            
            let recordType = components[0]
            
            switch recordType {
            case "sec" where isPrivate, "pub" where !isPrivate:
                // Key record - get full fingerprint
                currentFingerprint = components[4]
                
            case "uid" where currentFingerprint != nil:
                // User ID record
                currentUserID = components[9]
                if let fingerprint = currentFingerprint, let userID = currentUserID {
                    // Format: "Name <email> [FULL_FINGERPRINT]"
                    let formattedKey = "\(userID) [\(fingerprint)]"
                    keys.append(formattedKey)
                    logDebug("Added key: \(formattedKey)")
                    currentFingerprint = nil
                    currentUserID = nil
                }
            default:
                break
            }
        }
        
        return keys
    }
    
    // MARK: - Combined operations
    
    /// Send message: Encrypt and sign a message with the recipient's public key and sender's private key
    func encryptAndSign(message: String, senderPrivateKey: String, recipientPublicKey: String) -> String? {
        // Extract fingerprints from the key strings
        let senderFingerprint = extractFingerprint(from: senderPrivateKey)
        let recipientFingerprint = extractFingerprint(from: recipientPublicKey)
        
        logInfo("Encrypting and signing message")
        logDebug("Sender fingerprint: \(senderFingerprint)")
        logDebug("Recipient fingerprint: \(recipientFingerprint)")
        
        // First verify the recipient's public key is valid and trusted
        let verifyProcess = Process()
        verifyProcess.executableURL = URL(fileURLWithPath: gpgPath)
        verifyProcess.arguments = ["--list-keys", "--with-colons", recipientFingerprint]
        
        let verifyPipe = Pipe()
        verifyProcess.standardOutput = verifyPipe
        verifyProcess.standardError = verifyPipe
        
        do {
            try verifyProcess.run()
            verifyProcess.waitUntilExit()
            
            let verifyData = verifyPipe.fileHandleForReading.readDataToEndOfFile()
            let verifyOutput = String(data: verifyData, encoding: .utf8) ?? ""
            logDebug("Key verification output: \(verifyOutput)")
            
            if verifyProcess.terminationStatus != 0 {
                logError("Unable to verify recipient's public key")
                return nil
            }
        } catch {
            logError("Error verifying recipient's key: \(error)")
            return nil
        }
        
        // Now attempt the encryption
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        process.arguments = [
            "--encrypt",
            "--sign",
            "--armor",
            "--local-user", senderFingerprint,
            "--recipient", recipientFingerprint,
            "--trust-model", "always",  // Add this to bypass trust requirements
            "--verbose"  // Add verbose output
        ]
        
        logDebug("Running GPG command: \(process.arguments?.joined(separator: " ") ?? "")")
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            
            let inputData = message.data(using: .utf8)!
            try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
            try inputPipe.fileHandleForWriting.close()
            
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                logError("GPG encryption failed with status \(process.terminationStatus)")
                logDebug("GPG Error Output: \(errorMessage)")
                return nil
            }
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            logInfo("Message successfully encrypted and signed")
            return String(data: data, encoding: .utf8)
        } catch {
            logError("Error encrypting and signing: \(error)")
            logDebug("Process error details: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Receive message: Decrypt and verify a message with the recipient's private key
    func decryptAndVerify(message: String, recipientPrivateKey: String, passphrase: String? = nil) -> (decryptedText: String?, isVerified: Bool, senderInfo: String?) {
        // Extract fingerprint from the key string
        let recipientFingerprint = extractFingerprint(from: recipientPrivateKey)
        
        logInfo("Attempting to decrypt and verify message")
        logDebug("Using fingerprint: \(recipientFingerprint)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        var arguments = [
            "--decrypt",
            "--armor",
            "--local-user", recipientFingerprint,
            "--status-fd", "2",  // Output status to stderr
            "--verbose"  // Add verbose output
        ]
        
        // Add pinentry-mode loopback if passphrase is provided
        if passphrase != nil {
            arguments.append(contentsOf: ["--pinentry-mode", "loopback", "--batch", "--yes"])
        }
        
        process.arguments = arguments
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Set up environment for passphrase handling
        if let passphrase = passphrase {
            process.environment = ["GPG_TTY": "/dev/null"]
            
            // Create a temporary file for the passphrase
            let passTempFile = FileManager.default.temporaryDirectory.appendingPathComponent("gpg_pass_\(UUID().uuidString)")
            do {
                try passphrase.write(to: passTempFile, atomically: true, encoding: .utf8)
                arguments.append("--passphrase-file")
                arguments.append(passTempFile.path)
                process.arguments = arguments
                
                // Execute code within a do block to scope the cleanup
                do {
                    // Use try-finally pattern instead of defer at end of scope
                    defer {
                        try? FileManager.default.removeItem(at: passTempFile)
                    }
                    
                    try process.run()
                    
                    let inputData = message.data(using: .utf8)!
                    try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
                    try inputPipe.fileHandleForWriting.close()
                    
                    process.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let decryptedText = String(data: outputData, encoding: .utf8)
                    let statusOutput = String(data: errorData, encoding: .utf8) ?? ""
                    
                    logDebug("GPG decrypt status: \(process.terminationStatus)")
                    logDebug("GPG status output: \(statusOutput)")
                    
                    if process.terminationStatus != 0 {
                        logError("Decryption failed with status \(process.terminationStatus)")
                        logError("Error details: \(statusOutput)")
                        
                        // Print the actual command that was run
                        let cmdLine = ([gpgPath] + arguments).joined(separator: " ")
                        logError("Command used: \(cmdLine)")
                        
                        // Log input message format
                        logDebug("Message format check - starts with correct header: \(message.hasPrefix("-----BEGIN PGP MESSAGE-----"))")
                        logDebug("Message format check - ends with correct footer: \(message.hasSuffix("-----END PGP MESSAGE-----"))")
                        
                        return (nil, false, nil)
                    }
                    
                    // If we got here but have no decrypted text, that's strange
                    if decryptedText == nil || decryptedText?.isEmpty == true {
                        logError("Decryption completed but no output was produced")
                        logError("Error details: \(statusOutput)")
                        return (nil, false, nil)
                    }
                    
                    // Parse status output for signature verification
                    let isVerified = statusOutput.contains("[GNUPG:] GOODSIG")
                    
                    // Extract sender info
                    var senderInfo: String? = nil
                    if let range = statusOutput.range(of: "[GNUPG:] GOODSIG") {
                        let substr = statusOutput[range.upperBound...]
                        if let endRange = substr.range(of: "\n") {
                            let sigLine = String(substr[..<endRange.lowerBound])
                            let components = sigLine.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
                            if components.count >= 2 {
                                senderInfo = components.dropFirst(2).joined(separator: " ")
                            }
                        }
                    }
                    
                    logInfo("Message successfully decrypted, verification status: \(isVerified)")
                    return (decryptedText, isVerified, senderInfo)
                }
            } catch {
                logError("Failed to create passphrase file: \(error)")
                return (nil, false, nil)
            }
        } else {
            do {
                try process.run()
                
                let inputData = message.data(using: .utf8)!
                try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
                try inputPipe.fileHandleForWriting.close()
                
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let decryptedText = String(data: outputData, encoding: .utf8)
                let statusOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                logDebug("GPG decrypt status: \(process.terminationStatus)")
                logDebug("GPG status output: \(statusOutput)")
                
                if process.terminationStatus != 0 {
                    logError("Decryption failed with status \(process.terminationStatus)")
                    logError("Error details: \(statusOutput)")
                    
                    // Print the actual command that was run
                    let cmdLine = ([gpgPath] + arguments).joined(separator: " ")
                    logError("Command used: \(cmdLine)")
                    
                    // Log input message format
                    logDebug("Message format check - starts with correct header: \(message.hasPrefix("-----BEGIN PGP MESSAGE-----"))")
                    logDebug("Message format check - ends with correct footer: \(message.hasSuffix("-----END PGP MESSAGE-----"))")
                    
                    return (nil, false, nil)
                }
                
                // If we got here but have no decrypted text, that's strange
                if decryptedText == nil || decryptedText?.isEmpty == true {
                    logError("Decryption completed but no output was produced")
                    logError("Error details: \(statusOutput)")
                    return (nil, false, nil)
                }
                
                // Parse status output for signature verification
                let isVerified = statusOutput.contains("[GNUPG:] GOODSIG")
                
                // Extract sender info
                var senderInfo: String? = nil
                if let range = statusOutput.range(of: "[GNUPG:] GOODSIG") {
                    let substr = statusOutput[range.upperBound...]
                    if let endRange = substr.range(of: "\n") {
                        let sigLine = String(substr[..<endRange.lowerBound])
                        let components = sigLine.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
                        if components.count >= 2 {
                            senderInfo = components.dropFirst(2).joined(separator: " ")
                        }
                    }
                }
                
                logInfo("Message successfully decrypted, verification status: \(isVerified)")
                return (decryptedText, isVerified, senderInfo)
            } catch {
                logError("Error decrypting and verifying: \(error)")
                return (nil, false, nil)
            }
        }
    }
    
    // MARK: - Legacy operations (kept for backward compatibility)
    
    func encrypt(message: String, recipientKey: String) -> String? {
        // Extract fingerprint from the key string
        let fingerprint = extractFingerprint(from: recipientKey)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        process.arguments = ["--encrypt", "--armor", "--recipient", fingerprint]
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        
        do {
            try process.run()
            
            let inputData = message.data(using: .utf8)!
            try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
            try inputPipe.fileHandleForWriting.close()
            
            process.waitUntilExit()
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            logError("Error encrypting: \(error)")
            return nil
        }
    }
    
    func decrypt(message: String, privateKey: String, passphrase: String? = nil) -> String? {
        // Extract fingerprint from the key string
        let fingerprint = extractFingerprint(from: privateKey)
        
        logInfo("Attempting to decrypt message with legacy method")
        logDebug("Using fingerprint: \(fingerprint)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        var arguments = ["--decrypt", "--armor", "--local-user", fingerprint, "--verbose"]
        
        // Add pinentry-mode loopback if passphrase is provided
        if passphrase != nil {
            arguments.append(contentsOf: ["--pinentry-mode", "loopback", "--batch", "--yes"])
        }
        
        // Set up environment for passphrase handling
        if let passphrase = passphrase {
            process.environment = ["GPG_TTY": "/dev/null"]
            
            // Create a temporary file for the passphrase
            let passTempFile = FileManager.default.temporaryDirectory.appendingPathComponent("gpg_pass_\(UUID().uuidString)")
            do {
                try passphrase.write(to: passTempFile, atomically: true, encoding: .utf8)
                arguments.append("--passphrase-file")
                arguments.append(passTempFile.path)
                
                // Set arguments before running
                process.arguments = arguments
                
                // Execute within a do block to properly scope the defer statement
                do {
                    // Use defer at beginning of scope to ensure cleanup
                    defer {
                        try? FileManager.default.removeItem(at: passTempFile)
                    }
                    
                    let inputPipe = Pipe()
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    
                    process.standardInput = inputPipe
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe
                    
                    try process.run()
                    
                    let inputData = message.data(using: .utf8)!
                    try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
                    try inputPipe.fileHandleForWriting.close()
                    
                    process.waitUntilExit()
                    
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    
                    logDebug("GPG decrypt status: \(process.terminationStatus)")
                    logDebug("GPG error output: \(errorOutput)")
                    
                    if process.terminationStatus != 0 {
                        logError("Decryption failed with status \(process.terminationStatus)")
                        logDebug("Error output: \(errorOutput)")
                        return nil
                    }
                    
                    let decryptedText = String(data: data, encoding: .utf8)
                    
                    if decryptedText == nil || decryptedText?.isEmpty == true {
                        logError("Decryption completed but no output was produced")
                        logDebug("Error details: \(errorOutput)")
                        return nil
                    }
                    
                    logInfo("Message successfully decrypted")
                    return decryptedText
                }
            } catch {
                logError("Failed to create passphrase file: \(error)")
                return nil
            }
        } else {
            process.arguments = arguments
            
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                
                let inputData = message.data(using: .utf8)!
                try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
                try inputPipe.fileHandleForWriting.close()
                
                process.waitUntilExit()
                
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                logDebug("GPG decrypt status: \(process.terminationStatus)")
                logDebug("GPG error output: \(errorOutput)")
                
                if process.terminationStatus != 0 {
                    logError("Decryption failed with status \(process.terminationStatus)")
                    logDebug("Error output: \(errorOutput)")
                    return nil
                }
                
                let decryptedText = String(data: data, encoding: .utf8)
                
                if decryptedText == nil || decryptedText?.isEmpty == true {
                    logError("Decryption completed but no output was produced")
                    logDebug("Error details: \(errorOutput)")
                    return nil
                }
                
                logInfo("Message successfully decrypted")
                return decryptedText
            } catch {
                logError("Error decrypting: \(error)")
                return nil
            }
        }
    }
    
    func sign(message: String, privateKey: String) -> String? {
        // Extract fingerprint from the key string
        let fingerprint = extractFingerprint(from: privateKey)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        process.arguments = ["--sign", "--armor", "--local-user", fingerprint]
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        
        do {
            try process.run()
            
            let inputData = message.data(using: .utf8)!
            try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
            try inputPipe.fileHandleForWriting.close()
            
            process.waitUntilExit()
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            logError("Error signing: \(error)")
            return nil
        }
    }
    
    func verify(message: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        process.arguments = ["--verify"]
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        
        do {
            try process.run()
            
            let inputData = message.data(using: .utf8)!
            try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
            try inputPipe.fileHandleForWriting.close()
            
            process.waitUntilExit()
            
            return process.terminationStatus == 0
        } catch {
            logError("Error verifying: \(error)")
            return false
        }
    }
    
    private func extractFingerprint(from keyString: String) -> String {
        // Extract fingerprint from format "Name <email> [fingerprint]"
        if let range = keyString.range(of: "[", options: .backwards),
           let endRange = keyString.range(of: "]", options: .backwards) {
            let startIndex = range.upperBound
            let endIndex = endRange.lowerBound
            return String(keyString[startIndex..<endIndex])
        }
        return keyString // Return as-is if no brackets found
    }
} 
