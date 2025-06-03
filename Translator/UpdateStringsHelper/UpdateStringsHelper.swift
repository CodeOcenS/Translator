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
    ///   - csvFileModel: csvFileModel 解析 csv 文件 model
    ///   - filePath: strings 文件
    ///   - key: 插入某个 key 后面
    ///   - scopeComment: 整块注释
    /// - Returns: 处理错误日志，没有错误，为 nil
    @available(macOS 13.0, *)
    func insertOtherStrings(_ csvFileModel:LanguageFileModel, to filePath:String, after key:String, scopeComment:String?) -> HandleError? {
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
            var willInsertText = "\n"
            if var comment = scopeComment, !comment.isEmpty {
                comment.replace("\n", with: "\n// ")
                willInsertText += "\n// \(comment)"
            }
            var insertError = ""
            for item in csvFileModel.items {
                let stringsText = Self.stringsText(item: item)
                if let errogMsg = stringsText.errorMsg {
                    insertError += errogMsg
                } else {
                    willInsertText += stringsText.text
                }
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
                    return handleUpdateStringsError(message:"自动插入，部分插入存在问题：\n\(insertError)")
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
           errorMsg = "存在空字符串\nkey:\(key)\nvalue:\(value) \n"
        } else {
            text += "\n\"\(key)\" = \"\(value)\";"
        }
        return (errorMsg, text)
    }
}
