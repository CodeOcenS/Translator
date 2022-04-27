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
    func testPloceholder() {
        let givenString = """
        value\\\"key\"引号"
        """
        let replacedString = HomeController.replaceSpecial(givenString)
        XCTAssertTrue(replacedString == #"value\"key\"引号\""#)
    }
}