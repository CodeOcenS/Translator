//
//  CSVHelper.swift
//  Translator
//
//  Created by PandaEye on 2025/3/6.
//  Copyright © 2025 PandaEye. All rights reserved.
//

import Foundation
import CSV

private let keyTitles = ["key","Key","KEY"]
private let keyDesc = "备注"

func handleCSVError(message: String) -> HandleError {
    return HandleError(title: "CSV解析", message: message)
}

extension String {
    /// 移除字符串左右空白
    func removeWhitespace() -> String {
        return self.trimmingCharacters(in: .whitespaces)
    }
}

public struct CSVHelper {
    func csvReader(url: URL) throws -> CSVReader {
        guard let stream = InputStream(url: url) else {
            throw handleCSVError(message: "读取文件流失败")
        }
        let reader = try CSVReader(stream: stream)
        return reader
    }
    /// 从csv流中 转换为对象。
    func parseCSVFile(reader: CSVReader) throws -> (models: [LanguageFileModel], errorInfo: [HandleError])  {
        guard let tempKeyRow = findKeyRow(reader: reader) else {
            throw handleCSVError(message: "未找到包含 Key 的行")
        }
        // 删除中文 （ ）
        let keyRow = tempKeyRow.map({ isIgnoreTitle($0) ? $0 : deleteChinese($0).removeWhitespace()})
        debugPrint("表头数据：\(keyRow)\n")
        // 检查是否包含 Key 列
        guard let keyIndex = keyRow.firstIndex(where: {keyTitles.contains($0.removeWhitespace())}) else {
            throw handleCSVError(message: "不存在 key 列")
        }
        
        // 检查是否有重复title
        var titleDict = [String: Int]()
        keyRow.forEach { item in
            if let titleCount = titleDict[item] {
                titleDict[item] = titleCount + 1
            } else {
                titleDict[item] = 1
            }
        }
        let duplicateDict = titleDict.filter({$0.value > 1 && $0.key != ""})
        guard duplicateDict.count == 0 else {
            throw handleCSVError(message: "存在相同的title, titles:\(duplicateDict.keys)")
        }
        // 备注Index
        let descColumnIndex = keyRow.firstIndex { title in
            return isDescTitle(title)
        };
        var languageFiles: [LanguageFileModel] = keyRow.compactMap { title in
            if isIgnoreTitle(title) {
                return nil
            } else {
                var model = LanguageFileModel()
                let name = deleteChinese(title).removeWhitespace() // 删除空白，删除中文
                model.languageName = name
                return model
            }
        }
        var errors: [HandleError] = []
        // 接着一行一行读取
        while reader.next() != nil {
            var key = ""
            guard let current = reader.currentRow else {
                errors.append(handleCSVError(message: "reader.currentRow 异常"))
                continue
            }
            // 往每个多语言添加 key value 和备注
            //  备注
            var desc = "";
            if let index = descColumnIndex {
                desc = current[index]
            }
            //  key value
            for (index,title) in keyRow.enumerated() {
                if keyTitles.contains(title.removeWhitespace()) {
                    key = current[keyIndex]
                    continue
                }
                guard !isIgnoreTitle(title) else {
                    continue
                }
                let value = current[index]
                
                if key.isEmpty && value.isEmpty {
                    // 空白行
                    continue
                }
                if value.isEmpty {
                    errors.append(handleCSVError(message: "\(key)缺少\(title)翻译"))
                }
                if key.isEmpty {
                    errors.append(handleCSVError(message: "\(value)缺少对应key"))
                }
                let item = LanguageItem(key: key.removeWhitespace(), value: value.removeWhitespace(), desc: desc)
                if let index = languageFiles.firstIndex(where: {$0.languageName == title}) {
                    languageFiles[index].items.append(item)
                } else {
                    errors.append(handleCSVError(message: "\(key)=\(value)未找到对应多语言Model（title:\(title)）"))
                }
                
            }
        }
        return (languageFiles , errors)
    }
}
// MARK: Private Method
private extension CSVHelper {
    /// 是否是备注列
    func isDescTitle(_ title: String) -> Bool {
        let title = title.removeWhitespace();
        guard !title.isEmpty else {
            return false
        }
        return title == keyDesc
    }
    func isIgnoreTitle(_ title:String) -> Bool{
        let title = title.trimmingCharacters(in: .whitespaces);
        guard !title.isEmpty else {
            return true
        }
        guard !isDescTitle(title) else {
            return true;
        }
        var ignoreTitles = ["序号"] //跳过的列
        ignoreTitles.append(contentsOf: keyTitles)
        return ignoreTitles.contains(title)
    }
    /// 查找包含 Key 的行
    /// 注意：执行了 next, 会移动 reader。
    func findKeyRow(reader: CSVReader) -> [String]? {
        var header: [String] = []
        if let headerRow = reader.headerRow {
            header = headerRow
        }
        /// 必须要包含 Key 列
        let keyHeader = header.filter {keyTitles.contains($0.removeWhitespace())}
        guard keyHeader.isEmpty else {
            return keyHeader.map({return $0.removeWhitespace()})
        }
        header = []
        while (reader.next() != nil) {
            guard let current = reader.currentRow else {
                break
            }
            let count = current.filter {keyTitles.contains($0.removeWhitespace())}.count
            if count > 0 {
                return current.map({return $0.removeWhitespace()})
            }
        }
        if header.isEmpty {
            return nil
        } else {
            return header.map({return $0.removeWhitespace()})
        }
    }
    /// 删除String中的中文 和 （ ）
    func deleteChinese(_ string: String) -> String {
        var str = string.replacingOccurrences(of: "\\p{Han}", with: "", options: .regularExpression)
        str = str.replacingOccurrences(of: "（", with: "")
        str = str.replacingOccurrences(of: "）", with: "")
        return str
    }
}
