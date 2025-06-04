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

private let stringsFileParentSuffix = ".lproj";

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
    
    /// 本地地址，存 error.log, strings的
    var localPath: URL?
    let csvHelper: CSVHelper = CSVHelper()
    /// 自动插入或者更新 strings
    let updateStringsHelper: UpdateStringsHelper = UpdateStringsHelper()
    
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
    

    
    func updateView(with url: URL?) {
        guard let url = url else { return }
        
        localPath = url
        savePathField.stringValue = url.absoluteString.urlDecoded().removeFileHeader()
    }
    @IBAction func parseAutoInsertButtonTapped(_ sender: NSButton) {
        // 检查合法性
        let insertKey = self.insertKeyTextField.stringValue.removeWhitespace()
        guard !insertKey.isEmpty else {
            showAlert(title: "请填写插入key")
            return
        }
        guard localPath != nil else {
            showAlert(title: Localized.pleaseSetTheStorageDirectoryFirst)
            return }
        guard openPanel.url != nil else {
            showAlert(title: Localized.failedToOpenFile)
            return
        }
        // 解析 excel 自动插入到对应语种的 strings 文件中
        do {
            let stringsFilePaths = try findLanguagePaths()
            // 开始对其他语言插入
            _ = self.autoInsertStrings(paths: stringsFilePaths, after: insertKey)
        } catch let error as HandleError {
            let msg = error.message
            Log.shared.error(msg)
            if let path = localPath {
                Log.shared.save(basePath: path.absoluteString.urlDecoded().removeFileHeader())
                let result = showAlert(title: "自动导入异常",msg: msg, doneTitle: "去检查错误日志")
                if (result) {
                    NSWorkspace.shared.open(path)
                } else {
                    debugPrint("打开失败：\(path.absoluteString)")
                }
            } else {
                showAlert(title: "自动导入异常",msg: msg);
            }
        } catch {
            
        }
    }
    @IBAction func TestButtonTapped(_ sender: NSButton) {
        // 测试
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
                    var result = "\"\(LocalizableStringsUtils.replaceSpecial(key))\" = \"\(LocalizableStringsUtils.replaceSpecial(value))\";"
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
// MARK: 额外增加方法  （等待删除部分方法）
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
            let pathStr = item.replacingOccurrences(of: "/\(localizableFileName)", with: "")
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
    func findLanguagePaths() throws -> [Path] {
        let projectPath = projectTextField.stringValue.trimmingCharacters(in: .whitespaces)
        let stringsFileName = stringsFileNameTextField.stringValue.trimmingCharacters(in: .whitespaces)
        let path = Path(projectPath)
        
        if projectPath.isEmpty || !path.exists {
            throw HandleError(message: "路径不能为空，或者不存在，请检查多语言目录地址");
        }
        let stringsFilePaths = path.children().compactMap { item in
            if item.fileName.contains(stringsFileParentSuffix)  { // 判断是否是 lproj 文件夹, 但是要除开 en,
                let filterFiles = item.children().filter { path in
                    // 不是目录，且包含指定问价名
                    !path.isDirectoryFile && path.fileName.contains(stringsFileName)
                }
                return filterFiles.first
            } else {
                return nil
            }
        }
        if stringsFileName.isEmpty {
            throw HandleError(message: "strings文件名不能为空");
        }
        if stringsFilePaths.isEmpty {
            throw HandleError(message: "找不xx.lproj目标文件");
        }
        return stringsFilePaths
    }
    /// 自动插入翻译到 strings 文件，返回的是插入成功的。
    func autoInsertStrings(paths:[Path], after key:String ) -> [Path] {
        guard let url = openPanel.url else {
            showAlert(title: Localized.failedToOpenFile)
            return []
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
                if #available(macOS 13.0, *) {
                    var successPath:[Path] = []
                    var errorMsg = "自动解析插入失败\n"
                    // 先创建 LocalizableAll.strings 文件，记录每个语言结果，如果全部成功，则删除。
                    var textFile: TextFile!
                    if let localizalbleAllFileURL = localPath?.appending(component: "AutoInsertLocalizableResult.strings"),
                       let path = Path(url: localizalbleAllFileURL) {
                        if path.exists {
                            try path.deleteFile()
                        }
                        try? path.createFile()
                        textFile = TextFile(path: path)
                        try "// 自动插入多语言处理结果\n" |>> textFile
                    }
                    // 真正插入
                    let keyEn = "en";
                    var isContainEn = false
                    // 将en调整到第一个
                    var sortPaths = paths;
                    if let enIndex =  paths.firstIndex(where: {$0.parent.fileNameWithoutExtension.lowercased() == keyEn}) {
                        isContainEn = true
                        let enPath = sortPaths.remove(at: enIndex)
                        sortPaths.insert(enPath, at: 0)
                    }
                    let enFileModel: LanguageFileModel? = result.models.first(where: {$0.languageName.lowercased() == keyEn.lowercased()})
                    for path in sortPaths {
                        let languageName = path.parent.fileNameWithoutExtension
                        var stringsFileText = "\n\n// MARK: - \(languageName)";
                        if let aimFileModel = result.models.first(where: {$0.languageName.lowercased() == languageName.lowercased()}) {
                            // 如果为en, 直接写入Resutl.strings，方便复制对比，不用插入。
                            if languageName.lowercased() == keyEn {
                                stringsFileText += "\n// en原文，不会自动插入，请手动复制更新，对比版本差异："
                                // 检查占位符个数是否相等
                                if let msg = updateStringsHelper.checkPlaceholderCountEqual(enFileModel: aimFileModel, otherFileModel: aimFileModel),
                                        !msg.isEmpty
                                {
                                    stringsFileText += "\n// 注意，英语原文有如下错误❌️，请核对:\n //" + msg
                                }
                                var stringsText = ""
                                for item in aimFileModel.items {
                                    let result = UpdateStringsHelper.stringsText(item: item)
                                    stringsText += result.text;
                                    if let msg = result.errorMsg {
                                        stringsFileText += "\n //" +  msg
                                    }
                                }
                                stringsFileText += "\n\(stringsText)"
                            } else {
                                // 其他语种，插入。
                                if let error = updateStringsHelper.insertOtherStrings(aimFileModel, enFileMode: enFileModel, to: path.rawValue, after: key, scopeComment: self.commentsTextField.stringValue.removeWhitespace()) {
                                    errorMsg += error.message + "\n"
                                    stringsFileText += "\n// 自动插入失败❌️：\n// \(error.message)\n"
                                    let stringsText = stringsText(aimFileModel)
                                    stringsFileText += "\n\(stringsText)"
                                } else {
                                    successPath.append(path)
                                    stringsFileText += "\n// 自动插入成功✅, 请前往 git 版本控制检查。"
                                }
                            }
                        } else {
                            // 没有找到对应多语言列
                            let msg = "在csv 中没有找到对应语种\(languageName)翻译\n"
                            errorMsg += msg
                            stringsFileText += "\n// 自动插入失败❌️：\(msg)"
                        }
                        try stringsFileText |>> textFile
                    }
                    var shouldOpenFile = false;
                    if successPath.isEmpty {
                        shouldOpenFile = showAlert(title: "所有多语言插入失败，请手动处理", msg: "请前往AutoInsertLocalizableResult.strings文件查看", doneTitle: "去处理")
                    } else if successPath.count == (isContainEn ? paths.count - 1 : paths.count) {
                        // 所有都成功
                        shouldOpenFile = showAlert(title: "所有多语言插入成功", doneTitle: "确定")
                    } else {
                        shouldOpenFile = showAlert(title: "多语言插入部分成功，部分失败，请手动处理", msg: "请前往AutoInsertLocalizableResult.strings文件查看", doneTitle: "去处理");
                    }
                    if shouldOpenFile, let path = localPath {
                        NSWorkspace.shared.open(path)
                    }
                    return successPath
                } else {
                    showAlert(title: "系统版本应该大于 macOS 13.0")
                }
            }
        } catch let error as HandleError {
            showAlert(title: "读取CSV文件失败 error:\(error.message)")
        } catch {
            showAlert(title: "读取CSV文件失败 error:\(error.localizedDescription)")
        }
        return []
    }
    func stringsText(_ fileModel: LanguageFileModel) -> String {
        let strings = fileModel.items.map { item in
            return UpdateStringsHelper.stringsText(item: item).text
        }
        return strings.joined(separator: "")
    }
}
extension HomeController {
    
    /// 展示弹窗
    /// - Parameters:
    ///   - title: 标题
    ///   - msg: 文本
    ///   - doneTitle: 其他按钮标题，如果为 nil,则只展示取消按钮。
    /// - Returns: 返回是否选中了其他按钮。 
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
