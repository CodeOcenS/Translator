## Translator - 快速集成多语言国际化

[![Build Status](https://img.shields.io/badge/platforms-iOS%20%7C%20tvOS%20%7C%20macOS%20%7C%20watchOS-green.svg)](https://github.com/Jinxiansen/Translator)
[![Xcode](https://img.shields.io/badge/Xcode-10.0-blue.svg)](https://developer.apple.com/xcode)
[![Xcode](https://img.shields.io/badge/macOS-10.13-blue.svg)](https://developer.apple.com/macOS)
[![MIT](https://img.shields.io/badge/licenses-GPL3.0-red.svg)](https://opensource.org/licenses/GPL-3.0)

[Translator](https://github.com/Jinxiansen/Translator) 可以帮助你快速的将 `.csv` 表格内容转为 **iOS/macOS** 项目中对应国家的 `. lproj` 文件。


## 💻 要求

* 运行在 macOS 10.13 及以上版本。


## ⚒ 安装

从 [Release Page](https://github.com/CodeOcenS/Translator/releases) 下载最新版本。

## 多语言翻译模板

参考`多语言翻译模板`Excel文件，处理英语，给出翻译其他语言。

## 🔑 使用

使用步骤：

- 首先 **设置存储目录** ；
- 然后 **选择 `.csv`** 文件（csv 内容格式请参考 多语言翻译模板excel转换后的 csv）；
- 最后点击 **开始解析** 即可。

增强功能：自动将csv对应的翻译插入到项目对应多语言string文件的某个key下（注意需要配置，且选择后面`自动解析到项目`按钮）

## 📝 预览

- 主界面

<img width="60%" src="Designs/images/app.png"/>

- 预览 csv 格式

> .csv 格式文件也可由 `.xls/.xlsx` 转换得，例如在 mac App Store 搜索 `WPS`。

> 这里的 `Key` 的前半部分作为解析时创建的 `.lproj` 文件夹名称，请确保为对应语言的缩写，例如 **en(英文)** 

<img width="70%" src="Designs/images/csv.png"/>

- 解析结果，根据添加多少种语言，生成对应的 `.lproj` 文件夹。

<img width="80%" src="Designs/images/lproj.png"/>

- 以下常量根据 **.lproj** 生成。

<img width="80%" src="Designs/images/localized.png"/>

`. localized` 是一个 String 的扩展方法，如下所示：

```swift
extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}
```


## ❓ 常见问题
- 打不开“Translator”，因为它来自身份不明的开发者。
<img width="60%" src="Designs/qes/q1.png"/>

> 若遇到这个问题，打开终端，输入： **sudo spctl --master-disable** 

- ...

## TODO


```
// 备注第一行
备注第二行
"Key1" = "value1";
```



## 📄 License	

Translator 遵循 GPL-3.0 协议进行发布。有关详细信息，见 [License](license) 。
