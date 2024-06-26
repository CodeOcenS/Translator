//
//  TranslatorTests.swift
//  TranslatorTests
//
//  Created by PandaEye on 2022/4/26.
//

import XCTest
@testable import Translator

class TranslatorTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}

extension TranslatorTests {
    ///  测试value含有引号问题，需要统一处理为\"
    func testPlaceholder() {
        let givenString = "value\\\"key\"引号\""
        let replacedString = HomeController.replaceSpecial(givenString)
        XCTAssertTrue(replacedString == #"value\"key\"引号\""#)
        
        let givenString1 = "我有%s元"
        let replacedString2 = HomeController.replaceSpecial(givenString1)
        XCTAssertTrue(replacedString2 == #"我有%@元"#)
        let givenString3 = "{0}替换{11}"
        let replacedString3 = HomeController.replaceSpecial(givenString3)
        XCTAssertTrue(replacedString3 == "%@替换%@")
    }
    
    func testQuanjiao() {
        let givenString3 = "全角％＠替换｛11｝"
        let replacedString3 = HomeController.replaceSpecial(givenString3)
        XCTAssertTrue(replacedString3 == "全角%@替换%@")
    }
    
    
    
}
