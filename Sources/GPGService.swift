import Foundation

class GPGService {
    static let shared = GPGService()
    private let gpgPath = "/usr/local/bin/gpg"
    
    private init() {}
    
    func listPrivateKeys() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        process.arguments = ["--list-secret-keys", "--with-colons", "--with-fingerprint"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return parseKeys(from: output, isPrivate: true)
        } catch {
            print("Error listing private keys: \(error)")
            return []
        }
    }
    
    func listPublicKeys() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpgPath)
        process.arguments = ["--list-keys", "--with-colons", "--with-fingerprint"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return parseKeys(from: output, isPrivate: false)
        } catch {
            print("Error listing public keys: \(error)")
            return []
        }
    }
    
    private func parseKeys(from output: String, isPrivate: Bool) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        var keys: [String] = []
        var currentKey: (type: String, fingerprint: String, userID: String)? = nil
        
        for line in lines {
            let components = line.components(separatedBy: ":")
            if components.count > 9 {
                let type = components[0]
                let fingerprint = components[4]
                let userID = components[9]
                
                if (isPrivate && type == "sec") || (!isPrivate && type == "pub") {
                    currentKey = (type: type, fingerprint: fingerprint, userID: userID)
                } else if type == "fpr" && currentKey?.fingerprint == fingerprint {
                    // Format: "Name <email> (fingerprint)"
                    let name = currentKey?.userID ?? "Unknown"
                    let formattedKey = "\(name) (\(fingerprint))"
                    keys.append(formattedKey)
                    currentKey = nil
                }
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
