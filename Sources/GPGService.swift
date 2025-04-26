import Foundation

class GPGService {
    static let shared = GPGService()
    private let gpgPath = "/usr/local/bin/gpg"
    
    private init() {
        // Verify GPG is installed and accessible
        guard FileManager.default.fileExists(atPath: gpgPath) else {
            print("Error: GPG not found at \(gpgPath)")
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
            print("GPG Version: \(output)")
        } catch {
            print("Error testing GPG: \(error)")
        }
    }
    
    func listPrivateKeys() -> [String] {
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
                print("Error listing private keys. Status: \(process.terminationStatus)")
                print("Output: \(output)")
                return []
            }
            
            let keys = parseKeys(from: output, isPrivate: true)
            print("Found \(keys.count) private keys")
            return keys
        } catch {
            print("Error listing private keys: \(error)")
            return []
        }
    }
    
    func listPublicKeys() -> [String] {
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
                print("Error listing public keys. Status: \(process.terminationStatus)")
                print("Output: \(output)")
                return []
            }
            
            let keys = parseKeys(from: output, isPrivate: false)
            print("Found \(keys.count) public keys")
            return keys
        } catch {
            print("Error listing public keys: \(error)")
            return []
        }
    }
    
    private func parseKeys(from output: String, isPrivate: Bool) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        var keys: [String] = []
        var currentFingerprint: String?
        var currentUserID: String?
        
        print("Parsing \(lines.count) lines of GPG output")
        
        for line in lines {
            let components = line.components(separatedBy: ":")
            guard components.count >= 10 else { continue }
            
            let recordType = components[0]
            
            switch recordType {
            case "sec" where isPrivate, "pub" where !isPrivate:
                // Key record - get fingerprint
                currentFingerprint = components[4]
                
            case "uid" where currentFingerprint != nil:
                // User ID record
                currentUserID = components[9]
                if let fingerprint = currentFingerprint, let userID = currentUserID {
                    let formattedKey = "\(userID) (\(fingerprint))"
                    keys.append(formattedKey)
                    print("Added key: \(formattedKey)")
                    currentFingerprint = nil
                    currentUserID = nil
                }
            default:
                break
            }
        }
        
        return keys
    }
    
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
            print("Error encrypting: \(error)")
            return nil
        }
    }
    
    func decrypt(message: String, privateKey: String) -> String? {
        // Extract fingerprint from the key string
        let fingerprint = extractFingerprint(from: privateKey)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        process.arguments = ["--decrypt", "--armor", "--local-user", fingerprint]
        
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
            print("Error decrypting: \(error)")
            return nil
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
            print("Error signing: \(error)")
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
            print("Error verifying: \(error)")
            return false
        }
    }
    
    private func extractFingerprint(from keyString: String) -> String {
        // Extract fingerprint from format "Name <email> (fingerprint)"
        if let range = keyString.range(of: "(", options: .backwards),
           let endRange = keyString.range(of: ")", options: .backwards) {
            let startIndex = range.upperBound
            let endIndex = endRange.lowerBound
            return String(keyString[startIndex..<endIndex])
        }
        return keyString
    }
} 
