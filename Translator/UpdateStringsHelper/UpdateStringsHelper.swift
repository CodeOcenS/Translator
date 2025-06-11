//
//  UpdateStringsHelper.swift
//  Translator
//
//  Created by PandaEye on 2025/3/6.
//  Copyright © 2025 PandaEye. All rights reserved.
//

import Foundation
import LocalizableStringsTools

private func handleUpdateStringsError(message: String) -> HandleError {
    return HandleError(title: "自动插入或更新 Strings", message: message)
}

struct UpdateStringsHelper{
    /// 插入新增 strings
    /// - Parameters:
    ///   - csvFileModel: 解析 csv 文件 某个语种 model
    ///   - enFileModel: 解析 csv 文件 英语语种 model
    ///   - filePath: strings 文件
    ///   - key: 插入某个 key 后面
    ///   - scopeComment: 整块注释
    /// - Returns: 处理错误日志，没有错误，为 nil
    @available(macOS 13.0, *)
    func insertOtherStrings(_ csvFileModel:LanguageFileModel, enFileMode:LanguageFileModel?, to filePath:String, after key:String, scopeComment:String?) -> HandleError? {
        guard !csvFileModel.items.isEmpty, !filePath.isEmpty, !key.isEmpty else {
            return handleUpdateStringsError(message: "csv解析异常，未解析到item、文件路径为空或者带插入某个key后为空\n fileMode.Items:\(csvFileModel.items) \nfilePath:\(filePath)\nkey:\(key)")
        }
        // 插入指定位置
        guard let text = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return handleUpdateStringsError(message:"自动插入，读取文件失败")
        }
        // 从路径读取 strings 文件并解析
        let result = LocalizableStringsParser.parse(string: text, locale: filePath)
        let filter = result.localizableStrings.filter { $0.key == key }
        guard filter.count == 1, let first = filter.first else {
            return handleUpdateStringsError(message:"自动插入，找不到插入key:\(key),或者找到多个key， keyCount:\(filter.count)")
        }
        // 检查是否包含这个 key,
        var stringsHaveKeys: [String] = []
        for item in csvFileModel.items {
            let key = item.key
            let filterKey = result.localizableStrings.filter({$0.key == key})
            if !filterKey.isEmpty {
                stringsHaveKeys.append(filterKey.first!.key)
            }
        }
        if (!stringsHaveKeys.isEmpty) {
            return handleUpdateStringsError(message:"自动插入，将要插入的文件已经包含该 相同的key \(stringsHaveKeys)")
        }
        // 找到原来strings 匹配的 的key value 组合值, 必须要按照这个格式才能匹配。
        let subStr = "\"\(first.key)\" = \"\(first.value)\";"
        // 找到插入位置
        do {
            let indexResult = try LocalizableStringsUtils.findInsertIndex(allStrings:text , subStr: subStr)
            // 替换到指定位置之后 \n + 需要插入的内容。
            guard let index = indexResult.index else {
                return handleUpdateStringsError(message:"自动插入，找不到插入点")
            }
            let insertIndexHave2EmptyLine = indexResult.insertIndexHave2EmptyLine
            var willInsertText = ""
            var insertError = ""
            if let en = enFileMode, !checkKeyEqual(enFileModelItems: en.items, otherFileModelItems: csvFileModel.items) {
                insertError += "自动插入，\(en.languageName)和\(csvFileModel.languageName)语言的key不一致，请检查:\n\(en.languageName):\n\(en.items)\n\(csvFileModel.languageName):\n\(csvFileModel.items)"
            }
            // 检查占位符个数是否相等
            if let en = enFileMode,
               let errorMsg = checkPlaceholderCountEqual(enFileModel: en, otherFileModel: csvFileModel),
               !errorMsg.isEmpty
            {
                insertError += errorMsg
            }
            if insertError.isEmpty {
                for item in csvFileModel.items {
                    let stringsText = Self.stringsText(item: item)
                    if let errorMsg = stringsText.errorMsg {
                        insertError += errorMsg
                    }else {
                        willInsertText += stringsText.text
                    }
                }
            }
            guard !willInsertText.isEmpty else {
                return handleUpdateStringsError(message:"自动插入，没有任何key value插入：\n\(addComment(insertError))")
            }
            
            // 有值处理头和尾部
            if var comment = scopeComment, !comment.isEmpty {
                comment.replace("\n", with: "\n// ")
                willInsertText += "\n// \(comment)"
                willInsertText.insert(contentsOf: "\n// \(comment)", at: willInsertText.startIndex)
            }
            if !insertIndexHave2EmptyLine {
                willInsertText = willInsertText + "\n\n"
            }
            
            var allStrings = text
            allStrings.insert(contentsOf: willInsertText, at: index)
            // 删除文件，重新写入, git跟踪不会引入文件变化，只有文本改动变化。
            do {
                try FileManager.default.removeItem(atPath: filePath)
                try allStrings.write(toFile: filePath, atomically: true, encoding: .utf8)
                if insertError.isEmpty {
                    return nil;
                } else {
                    return handleUpdateStringsError(message:"自动插入，部分插入存在问题：\n\(addComment(insertError))")
                }
            } catch let error {
                return handleUpdateStringsError(message:"自动插入，文件删除或者写入失败：\(error)")
            }
        } catch let error as LocalizableStringsFindInsertIndexError {
            var msg = ""
            switch error {
            case .multipleMatches:
                msg = "自动插入，匹配到多个，无法自动插入 subxStr:\(subStr)"
            case .noMatch:
                msg = "自动插入，找不到匹配项，无法自动插入 subxStr:\(subStr)"
            case .multiLineComment:
                msg = "自动插入，插入点后存在多行注释\\* \n */，无法自动插入 subxStr:\(subStr)"
            }
            return handleUpdateStringsError(message:msg)
        } catch {
            return handleUpdateStringsError(message:"自动插入异常 error\(error)")
        }
    }
    
    /// 更新 key 对应value
    func updateStrings(csvFile:LanguageFileModel) -> HandleError {
        // TODO: - LWF:  待完善
        return HandleError(message: "暂未实现")
    }
}

extension UpdateStringsHelper {
    /// 将mode 生成为Strings 文本
    static func stringsText(item: LanguageItem) -> (errorMsg:String? , text:String) {
        var text = ""
        var errorMsg: String? = nil
        if var desc = item.desc, !desc.isEmpty {
            desc = desc.replacingOccurrences(of: "\n", with: "\n// ")
            text += "\n// \(desc)"
        }
        let key = LocalizableStringsUtils.replaceSpecial(item.key.removeWhitespace())
        let value = LocalizableStringsUtils.replaceSpecial(item.value.removeWhitespace())
        if key.isEmpty || value.isEmpty {
           errorMsg = "存在空字符串:\"\(key)\" = \"\(value)\"\n"
        } else if LocalizableStringsAvailableCheck.isSpecialExcelErrorValue(cellValue: value) {
            errorMsg = "存在异常excel错误码:\"\(key)\" = \"\(value)\"\n"
        }
        else {
            text += "\n\"\(key)\" = \"\(value)\";"
        }
        return (errorMsg, text)
    }
    /// 检查英语和其他语言的key 是否一致
    func checkKeyEqual(enFileModelItems: [LanguageItem], otherFileModelItems: [LanguageItem]) -> Bool {
        guard enFileModelItems.count == otherFileModelItems.count else {
            return false
        }
        let enKeys = Set(enFileModelItems.map { $0.key })
        let otherKeys = Set(otherFileModelItems.map { $0.key })
        return enKeys == otherKeys
    }
    /// 检查占位符个数是否一致
    func checkPlaceholderCountEqual(enFileModel: LanguageFileModel, otherFileModel: LanguageFileModel) -> String? {
        let enFileModelItems: [LanguageItem] = enFileModel.items
        let otherFileModelItems: [LanguageItem] = otherFileModel.items
        var errorMsg: String? = nil
        for item in enFileModelItems {
            let enKey = item.key
            let enValue = item.value
            let enPlaceholderCheckResult = LocalizableStringsUtils.checkPlaceholderCount(string: enValue)
            if enPlaceholderCheckResult.0 {
                if let otherValue = otherFileModelItems.first(where: { $0.key == enKey })?.value {
                    let otherPlaceholderCheckResult = LocalizableStringsUtils.checkPlaceholderCount(string: otherValue)
                    if !otherPlaceholderCheckResult.0 {
                        errorMsg = "\(otherFileModel.languageName)占位符不合法，请检查：key:\(enKey), value:\(otherValue) \n"
                    } else if enPlaceholderCheckResult.1 != otherPlaceholderCheckResult.1 {
                        errorMsg = "\(enFileModel.languageName)和\(otherFileModel.languageName)占位符个数不相等，请检查：key:\(enKey), value:\(otherValue) \n"
                    }
                }
            } else {
                errorMsg = "\(enFileModel.languageName)占位符不合法，请检查：key:\(enKey), value:\(enValue) \n"
            }
        }
        return errorMsg
    }
    
    // 自动添加注释
    func addComment(_ string:String) -> String {
        guard !string.isEmpty else {
            return string
        }
        var text = string
        text = text.replacingOccurrences(of: "\n", with: "\n// ")
        text = text.replacingOccurrences(of: "\n////", with: "\n//")
        if !text.hasPrefix("//") {
            text = "// \(text)"
        }
        return text;
    }
}
