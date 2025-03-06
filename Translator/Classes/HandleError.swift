//
//  HandleError.swift
//  Translator
//
//  Created by PandaEye on 2025/2/28.
//  Copyright © 2025 PandaEye. All rights reserved.
//

import Foundation
struct HandleError: Error {
    let title: String?
    let message: String
    init(title: String?, message: String) {
        self.title = title
        self.message = message
    }
    init(message: String) {
        self.title = nil
        self.message = message
    }
}
