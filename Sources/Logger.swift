import Foundation

/// A lightweight logging system with priority levels and timestamps.
class Logger {
    /// Log level enum to control verbosity
    enum Level: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "🛑"
            }
        }
        
        var color: String {
            switch self {
            case .debug: return "\u{001B}[36m" // Cyan
            case .info: return "\u{001B}[32m"  // Green
            case .warning: return "\u{001B}[33m" // Yellow
            case .error: return "\u{001B}[31m" // Red
            }
        }
        
        var reset: String {
            return "\u{001B}[0m"
        }
    }
    
    /// Current minimum level to log
    static var minimumLevel: Level = .info
    
    /// Whether to show timestamps in logs
    static var showTimestamps: Bool = {
        if let value = ProcessInfo.processInfo.environment["GPGAPP_EXTERNAL_TIMESTAMPS"], !value.isEmpty {
            return false // Disable timestamps when external timestamps are provided
        }
        return true // Default to showing timestamps
    }()
    
    /// Whether to show emoji indicators in logs
    static var showEmoji: Bool = true
    
    /// Whether to use ANSI colors in terminal output
    static var useColors: Bool = true
    
    /// Whether to log to a file
    static var logToFile: Bool = false
    private static let logFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("gpgapp.log")
    
    /// Log a message with the specified level
    static func log(_ message: String, level: Level, file: String = #file, function: String = #function, line: Int = #line) {
        guard level.rawValue >= minimumLevel.rawValue else { return }
        
        // Create log message
        var logComponents: [String] = []
        
        // Add timestamp if enabled
        if showTimestamps {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            logComponents.append("[\(formatter.string(from: Date()))]")
        }
        
        // Add level with optional color and emoji
        if useColors {
            if showEmoji {
                logComponents.append("\(level.color)[\(level.emoji) \(level.rawValue)]\(level.reset)")
            } else {
                logComponents.append("\(level.color)[\(level.rawValue)]\(level.reset)")
            }
        } else {
            if showEmoji {
                logComponents.append("[\(level.emoji) \(level.rawValue)]")
            } else {
                logComponents.append("[\(level.rawValue)]")
            }
        }
        
        // Add file info for debug level
        if level == .debug {
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            logComponents.append("[\(fileName):\(line)]")
        }
        
        // Add message
        logComponents.append(message)
        
        // Combine components
        let fullLogMessage = logComponents.joined(separator: " ")
        
        // Print to console
        print(fullLogMessage)
        
        // Write to file if enabled
        if logToFile {
            // Don't include ANSI codes in log file
            let fileMessage = fullLogMessage
                .replacingOccurrences(of: level.color, with: "")
                .replacingOccurrences(of: level.reset, with: "")
            appendToLogFile(fileMessage)
        }
    }
    
    /// Convenience methods for each log level
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    /// Write log to file
    private static func appendToLogFile(_ message: String) {
        do {
            let logMessage = message + "\n"
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                if let data = logMessage.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                try logMessage.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Error writing to log file: \(error)")
        }
    }
}

// Global convenience functions
func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.debug(message, file: file, function: function, line: line)
}

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.info(message, file: file, function: function, line: line)
}

func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.warning(message, file: file, function: function, line: line)
}

func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.error(message, file: file, function: function, line: line)
} 
