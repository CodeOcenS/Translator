//
//  Log.swift
//  Translator
//
//

import Foundation

struct Log {
    static var shared: Log = Log()
    var logText = ""
    private init() {
        
    }
    mutating func clear() {
        self.logText = "";
    }
    mutating func error(_ text: String) {
        if !logText.isEmpty {
            logText.append("\n")
        }
        logText.append("【Error】\(text)")
    }
    mutating func alert(_ text: String) {
        if !logText.isEmpty {
            logText.append("\n")
        }
        logText.append("【Alert】\(text)")
    }
    func save(basePath:String) {
        let filePath = "\(basePath)/error.log"
        guard !logText.isEmpty else {
            return
        }
       try? logText.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
}
