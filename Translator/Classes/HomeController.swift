//
//  HomeController.swift
//  Translator
//
//

import Cocoa
import CSV
import FileKit
import UniformTypeIdentifiers
import LocalizableStringsTools

private let localizableFileName = "Localizable.strings"
private let keyTitles = ["key","Key","KEY"]
private let keyBeiZhu = "备注"

class HomeController: NSViewController {
    
    @IBOutlet weak var savePathField: NSTextField!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var commentsTextField: NSTextField!
    @IBOutlet weak var selectCSVButton: NSButton!
    @IBOutlet weak var setStorageButton: NSButton!
    
    @IBOutlet weak var parseButton: NSButton!
    
    // 自动插入
    
    @IBOutlet weak var projectTextField: NSTextField!
    
    @IBOutlet weak var stringsFileNameTextField: NSTextField!
    @IBOutlet weak var insertKeyTextField: NSTextField!
    
    
    var localPath: URL?
    let csvHelper: CSVHelper = CSVHelper()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setLocalizedTitles()
        let url = UserDefaults.standard.url(forKey: Keys.savePath)
        updateView(with: url)
        
    }
    
    func setLocalizedTitles() {
        
        title = Localized.translator
        titleLabel.stringValue = Localized.appDesc
        savePathField.placeholderString = Localized.pleaseSetTheStorageDirectoryFirst
        parseButton.title = Localized.startParsing
        setStorageButton.title = Localized.setStorageDirectory
        selectCSVButton.title = Localized.selectTheCsvFile
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.title = Localized.translator
    }
    
    override var representedObject: Any? {
        didSet {
        }
    }
    
    @IBAction func openButtonTapped(_ sender: NSButton) {
        
        let response = openPanel.runModal()
        guard response == .OK,let _ = openPanel.url else {
            //            showAlert(title: "\(Localized.failedToOpenFile)：\(response)")
            return }
    }
    
    
    @IBAction func saveButton(_ sender: NSButton) {
        savePanel.begin { response in
            guard response == .OK, let url = self.savePanel.urls.first else { return }
            self.updateView(with: url)
            UserDefaults.standard.set(url, forKey: Keys.savePath)
        }
    }
    
    @IBAction func parseButtonTapped(_ sender: NSButton) {
        Log.shared.clear();
        guard let path = localPath else {
            showAlert(title: Localized.pleaseSetTheStorageDirectoryFirst)
            return }
        
        guard let url = openPanel.url else {
            showAlert(title: Localized.failedToOpenFile)
            return }
        
        guard let stream = InputStream(url: url) else {
            showAlert(title: Localized.pleaseSelectTheCsvFileFirst)
            return
        }
        
        self.parseCSVFile(stream: stream,savePath: path)
    }
    
    
    @IBAction func previewButtonTapped(_ sender: NSButton) {
        previewCSV()
    }
    
    func updateView(with url: URL?) {
        guard let url = url else { return }
        
        localPath = url
        savePathField.stringValue = url.absoluteString.urlDecoded().removeFileHeader()
    }
    @IBAction func parseAutoInsertButtonTapped(_ sender: NSButton) {
        // 解析 excel 自动插入到对应语种的 strings 文件中
        do {
            let stringsFilePaths = try findPaths()
            
        } catch let error as HandleError {
            showAlert(title: "自动导入异常",msg: error.message)
        } catch {
            
        }
    }
    @IBAction func TestButtonTapped(_ sender: NSButton) {
        // 临时测试
        let path = "/Users/pandaeye/Documents/SupportFramwork/Translator/Translator/Resources/en.lproj/Test.strings"
        let key = "key4";
        guard let url = openPanel.url else {
            showAlert(title: Localized.failedToOpenFile)
            return
        }
        do {
            let csvReader = try csvHelper.csvReader(url: url)
            let result = try csvHelper.parseCSVFile(reader: csvReader)
            if !result.errorInfo.isEmpty {
                Log.shared.error(result.errorInfo.writable.componentsJoined(by: "\n"))
            }
            if result.models.isEmpty {
                showAlert(title: "读取CSV成功，但未解析都符合数据")
            } else {
                // TODO: 匹配对应语种
                let isSuccess = insertOtherStrings(result.models.last!, to: path, after: key)
            }
        } catch let error as HandleError {
            showAlert(title: "读取CSV文件失败 error:\(error.message)")
        } catch {
            showAlert(title: "读取CSV文件失败")
        }
        
    }
    func insertOtherStrings(_ stringsFileModel:LanguageFileModel, to filePath:String, after key:String) -> Bool {
        guard !stringsFileModel.items.isEmpty, !filePath.isEmpty, !key.isEmpty else {
            return false
        }
        // 插入指定位置
        guard let text = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            Log.shared.error("自动插入，读取文件失败")
            return false
        }
        // 从路径读取 strings 文件并解析
        let result = LocalizableStringsParser.parse(string: text, locale: filePath)
        let filter = result.localizableStrings.filter { $0.key == key }
        guard filter.count == 1, let first = filter.first else {
            Log.shared.error("自动插入，找不到key,或者找到多个key， keyCount:\(filter.count)")
            return false
        }
        // 检查是否包含这个 key,
        var textHaveKey = false
        for item in stringsFileModel.items {
            let key = item.key
            let filterKey = result.localizableStrings.filter { temp in
                temp.key == key
            }
            if filterKey.isEmpty {
                textHaveKey = true
            }
        }
        if (textHaveKey) {
            Log.shared.error("自动插入，将要插入的文件已经包含该 相同的key \(stringsFileModel.items)")
            return false
        }
        // 找到原来strings 匹配的 的key value 组合值, 必须要按照这个格式才能匹配。
        let subStr = "\"\(first.key)\" = \"\(first.value)\";"
        // 找到插入位置
        
        if #available(macOS 13.0, *) {
            do {
                let indexResult = try LocalizableStringsUtils.findInsertIndex(allStrings:text , subStr: subStr)
                // 替换到指定位置之后 \n + 需要插入的内容。
                guard let index = indexResult.index else {
                    Log.shared.error("自动插入，找不到插入点")
                    return false
                }
                let insertIndexHave2EmptyLine = indexResult.insertIndexHave2EmptyLine
                var willInsertText = "\n"
                for item in stringsFileModel.items {
                    if let desc = item.desc, !desc.isEmpty {
                        willInsertText += "\n// \(desc)"
                    }
                    willInsertText += "\n\"\(item.key)\" = \"\(item.value)\";"
                }
                if !insertIndexHave2EmptyLine {
                    willInsertText = willInsertText + "\n\n"
                }
                var allStrings = text
                allStrings.insert(contentsOf: willInsertText, at: index)
                // 删除文件，重新写入
                do {
                    try FileManager.default.removeItem(atPath: filePath)
                    try allStrings.write(toFile: filePath, atomically: true, encoding: .utf8)
                    return true
                } catch let error {
                    Log.shared.error("自动插入，文件删除或者写入失败：\(error)")
                    return false
                }
            } catch let error as LocalizableStringsFindInsertIndexError {
                switch error {
                case .multipleMatches:
                    Log.shared.error("自动插入，匹配到多个，无法自动插入 subxStr:\(subStr)")
                case .noMatch:
                    Log.shared.error("自动插入，找不到匹配项，无法自动插入 subxStr:\(subStr)")
                case .multiLineComment:
                    Log.shared.error("自动插入，插入点后存在多行注释\\* \n */，无法自动插入 subxStr:\(subStr)")
                }
                return false
            } catch {
                return false
            }
        } else {
            Log.shared.error("自动插入，macOS 版本不支持, 应该大于 13.0")
            return false
        }
    }
    
    /// MARK: - Lazy
    lazy var openPanel: NSOpenPanel = {
        
        let panel = NSOpenPanel()
        panel.title = Localized.selectTheCsvFile
        //panel.allowedFileTypes = ["csv"]
        if let csvType = UTType("public.comma-separated-values-text") {
            panel.allowedContentTypes = [csvType];
        }
        panel.isExtensionHidden = false
        panel.allowsMultipleSelection = false
        
        return panel
    }()
    
    lazy var savePanel: NSOpenPanel = {
        let panel = NSOpenPanel()
        panel.title = Localized.selectStorageDirectory
        panel.defaultButtonCell?.title = Localized.storedInThisDirectory
        panel.defaultButtonCell?.alternateTitle = Localized.choose
        panel.showsResizeIndicator = true;
        panel.canChooseDirectories = true;
        panel.canChooseFiles = false;
        panel.allowsMultipleSelection = false;
        panel.canCreateDirectories = true;
        
        return panel
    }()
}


// MARK: - Parse CSV
extension HomeController {
    
    func parseCSVFile(stream: InputStream,savePath: URL)  {
        
        do {
            let csv = try CSVReader(stream: stream, hasHeaderRow: true)
            
            guard let header = findTitles(csv: csv) else {
                return
            }
            debugPrint("表头数据：\(header)\n")
            let keyIndex = header.firstIndex { title in
                keyTitles.contains(title)
            }
            guard let keyIndex = keyIndex else {
                Log.shared.error("不存在 key 列")
                return
            }
            // 备注Index
            let descrColumnIndex = header.firstIndex { title in
                return isDescrTitle(title)
            };
            var paths = [String]()
            let textPath = savePath.absoluteString.removeFileHeader().urlDecoded() + "localized.swift"
            try Path(textPath).createFile()
            let swiftFile = TextFile(path: Path(textPath))
            
            for title in header { //
                guard !title.isEmpty else {
                    continue
                }
                guard !isIgnoreTitle(title) else {
                    continue
                }
                
                let fileName = (title.removeBraces() ?? "").lowercased() + ".lproj"
                let directoryPath = savePath.appendingPathComponent(fileName, isDirectory: true).absoluteString.removeFileHeader().urlDecoded()
                let localizablePath = directoryPath + localizableFileName.urlDecoded()
                
                do {
                    try Path(directoryPath).createDirectory(withIntermediateDirectories: true)
                    try Path(localizablePath).createFile()
                } catch {
                    showAlert(title: "\(Localized.lprojFolderCreationFailed)：\(error.localizedDescription)")
                    return
                }
                paths.append(localizablePath)
                var fileModel = LanguageFileModel()
                fileModel.languageName = title.removeBraces() ?? ""
            }
            
            try "struct Localized {\n" |>> swiftFile
            while csv.next() != nil {
                
                var key = ""
                var isAllow = true // 不论多少国际化语言，对于 localizedTitles.swift 文件每行只写一次。
                guard let current = csv.currentRow else {
                    Log.shared.error("\(key)后缺少行数据")
                    return
                }
                // 往每个多语言添加 key value
                var nextPathIndex = 0
                var descr = "";
                if let index = descrColumnIndex {
                    descr = current[index]
                }
                for (index,title) in header.enumerated() {
                    if keyTitles.contains(title) {
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
                        Log.shared.error("\(key)缺少\(title)翻译")
                    }
                    if key.isEmpty {
                        Log.shared.error("\(value)缺少对应key")
                    }
                    var result = "\"\(key)\" = \"\(Self.replaceSpecial(value))\";"
                    if (descr.count > 0) {
                        let describeArray = descr.components(separatedBy: "\n")
                        var describe = ""
                        for (index, item) in describeArray.enumerated() {
                            describe.append("// \(item)\(index == describeArray.count - 1 ? "" : "\n")")
                        }
                        result = "\(describe)\n" + result
                    }
                    let path = paths[nextPathIndex]
                    nextPathIndex += 1
                    if path.isEmpty {
                        Log.shared.error("逻辑错误")
                        assertionFailure("逻辑错误")
                        return
                    }
                    let readFile = TextFile(path: Path(path))
                    do {
                        try result |>> readFile
                        if isAllow {
                            let locString = "   static let \(key.localizedFormat) = \"\(key)\".localized"
                            try locString |>> swiftFile
                            isAllow = false
                        }
                    } catch {
                        showAlert(title: "\(Localized.writeFailed)：\(error)")
                        return
                    }
                }
            }
            try "}" |>> swiftFile
            
            debugPrint("---------------------------\n")
            
            stream.close()
            mergeAllLanguageToOneFile(paths: paths, save: savePath)
            deleteSingleLanguageFile(paths: paths)
            DispatchQueue.main.async {
                
                let path = savePath.absoluteString.urlDecoded().removeFileHeader()
                Log.shared.save(basePath: path)
                var msg = "\(Localized.filePath)： \(path)"
                if !Log.shared.logText.isEmpty {
                    msg.append("\n⚠️注意检查日志文件error.log，可能存在转换问题")
                }
                let result = self.showAlert(title: Localized.completed,
                                            msg: msg,
                                            doneTitle: Localized.open)
                if (result) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    //NSWorkspace.shared.openFile(path)
                } else {
                    debugPrint("打开失败：\(savePath.absoluteString)")
                }
            }
        } catch {
            debugPrint(error)
            let path = savePath.absoluteString.urlDecoded().removeFileHeader()
            Log.shared.save(basePath: path)
            showAlert(title: error.localizedDescription)
        }
    }

}
// MARK: 额外增加方法
extension HomeController {
    /// 是否是备注列
    func isDescrTitle(_ title: String) -> Bool {
        let title = title.trimmingCharacters(in: .whitespaces);
        guard !title.isEmpty else {
            return false
        }
       return title == keyBeiZhu
    }
    func isIgnoreTitle(_ title:String) -> Bool{
        let title = title.trimmingCharacters(in: .whitespaces);
        guard !title.isEmpty else {
            return true
        }
        guard !isDescrTitle(title) else {
            return true;
        }
        var ignoreTitles = ["序号"] //跳过的列
        ignoreTitles.append(contentsOf: keyTitles)
        return ignoreTitles.contains(title)
    }
    func findTitles(csv: CSVReader) -> [String]? {
        guard let header = csv.headerRow else {
            Log.shared.error("excel 文件 header不存在")
            return nil
        }
        let count = header.filter {keyTitles.contains($0)}.count
        if count > 0 {
            return header
        }
        while csv.next() != nil {
            guard let current = csv.currentRow else {
                Log.shared.error("excel 文件 找不到目标 header")
                return nil
            }
            let count = current.filter {keyTitles.contains($0)}.count
            if count > 0 {
                return current
            }
        }
        return nil
    }
    /// 替换特殊字符 1. %s -> %@  2. " -> \"
    public static func replaceSpecial(_ text: String) -> String {
        var result: String = text
        // 将全角符号替换为半角
        result = result.replacingOccurrences(of: "％", with: "%")
        result = result.replacingOccurrences(of: "＠", with: "@")
        result = result.replacingOccurrences(of: "｛", with: "{")
        result = result.replacingOccurrences(of: "｝", with: "}")
        
        //let replacingStr = text.replacingOccurrences(of: "%s", with: "%@") // 处理日语 百分号
        // %s 替换为 %@
        result = result.replacingOccurrences(of: "%s", with: "%@")
        // 处理value 中有引号问题
        guard let regularExpression = try? NSRegularExpression(pattern: #"(?<!\\)""#) else {
            return result
        }
        result = regularExpression.stringByReplacingMatches(in: result, range: NSRange(location: 0, length: result.count), withTemplate: #"\\\""#)
        // 处理 {数字} 为 %@ (保留{数组}格式2024.8.13)
//        let pattern2 = #"\{\d{1,2}\}"#
//        guard let regex2 = try? NSRegularExpression(pattern: pattern2) else {
//            return result
//        }
//        result = regex2.stringByReplacingMatches(in: result, range: NSRange(location: 0, length: result.count), withTemplate: #"%@"#)
        return result
    }
    
    /// 将所有语言 string 合并到一个文件夹
    private func mergeAllLanguageToOneFile(paths: [String], save: URL) {
        var text = ""
        for item in paths {
            //let readFile = TextFile(path: Path(item))
            let readFile = File<String>.init(path: Path(item))
            let readText = try? readFile.read()
            let components = readFile.path.components
            let filter = components.filter{ $0.rawValue.contains(".lproj")}
            let title = filter.first?.rawValue ?? item
            var prefix = "\n\n// MARK: \(title)\n"
            if (!commentsTextField.stringValue.isEmpty) {
                prefix += "\n// \(commentsTextField.stringValue)"
            }
            //let header
            text.append(contentsOf: prefix + (readText ?? ""))
        }
        
        do {
            let textPath = save.absoluteString.removeFileHeader().urlDecoded() + "LocalizableAll.strings"
            try Path(textPath).createFile()
            let allFile = TextFile(path: Path(textPath))
            try text |>> allFile
        } catch {
            debugPrint(error)
            showAlert(title: error.localizedDescription)
        }
    }
    /// 删除单个语言文件
    private func deleteSingleLanguageFile(paths:[String]) {
        for item in paths {
            var pathStr = item
            if #available(macOS 13.0, *) {
                pathStr = item.replacing("/\(localizableFileName)", with: "", maxReplacements: 1)
            } else {
                showAlert(title: "macOS 版本过低，应该大于 13.0")
            }
            guard !pathStr.isEmpty else {
                return
            }
            let path = Path(pathStr);
           
            do {
                try path.deleteFile()
            } catch let error {
                showAlert(title: error.localizedDescription)
            }
        }
    }
}
// 自动插入
extension HomeController  {
    func findPaths() throws -> [Path] {
        let projectPath = projectTextField.stringValue.trimmingCharacters(in: .whitespaces)
        let stringsFileName = stringsFileNameTextField.stringValue.trimmingCharacters(in: .whitespaces)
        let path = Path(projectPath)
        let stringsFilePaths = path.children().compactMap { item in
            if item.fileName.contains(".lproj")  { // 判断是否是 lproj 文件夹
                let filterFiles = item.children().filter { path in
                    // 不是目录，且包含指定问价名
                    !path.isDirectoryFile && path.fileName.contains(stringsFileName);
                }
                return filterFiles.first
            } else {
                return nil
            }
        }
        if projectPath.isEmpty {
            throw HandleError(message: "路径不能为空");
        }
        if stringsFileName.isEmpty {
            throw HandleError(message: "strings文件名不能为空");
        }
        if stringsFilePaths.isEmpty {
            throw HandleError(message: "找不目标文件");
        }
        return stringsFilePaths
    }
}

extension HomeController {
    
    func previewCSV() {
        let csvPath = NSTemporaryDirectory() + "example.csv"
        debugPrint("Save path: \(csvPath)")
        let stream = OutputStream(toFileAtPath: csvPath, append: false)!
        
        do {
            try Path(csvPath).createFile()
            
            let csv = try CSVWriter(stream: stream)
            
            try csv.write(row: ["Key","en","zh-Hant","ko","ja"])
            try csv.write(row: ["app.key1","EN 1","CN 1","KO 1","JA 1"])
            try csv.write(row: ["app.key2","EN 2","CN 2","KO 2","JA 2"])
            try csv.write(row: ["app.key3","EN 3","CN 3","KO 3","JA 3"])
            
            csv.stream.close()
            
            debugPrint("\(Localized.createdSuccessfully)")
            
            DispatchQueue.main.async {
                let csvUrl = URL(fileURLWithPath: csvPath)
                NSWorkspace.shared.open(csvUrl)
            }
        } catch {
            showAlert(title: "\(Localized.creationFailed)：\(error)")
        }
    }
    
}

extension HomeController {
    
    @discardableResult
    func showAlert(title:String, msg:String? = nil, doneTitle: String? = nil) -> Bool {
        let alert = NSAlert.init()
        alert.messageText = title
        
        if let msg = msg {
            alert.informativeText = msg
        }
        if let done = doneTitle {
            alert.addButton(withTitle: done)
        }
        alert.addButton(withTitle: Localized.cancel)
        return alert.runModal() == .alertFirstButtonReturn
    }
}
