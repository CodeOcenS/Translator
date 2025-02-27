//
//  LanguageFileModel.swift
//  Translator
//
//  Created by PandaEye on 2025/2/27.
//  Copyright © 2025 PandaEye. All rights reserved.
//

import Foundation
struct LanguageFileModel: Codable {
    /// 语言名称，比如 en、ja
    var languageName: String = ""
    /// 所有的语言 key value
    var items: [LanguageItem] = []
}
