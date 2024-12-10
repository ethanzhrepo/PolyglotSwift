import XCTest
@testable import PolyglotSwift

final class DeepLTranslatorTests: XCTestCase {
    var translator: DeepLTranslator!
    
    override func setUp() {
        super.setUp()
        translator = DeepLTranslator()
    }
    
    override func tearDown() {
        translator = nil
        super.tearDown()
    }
    
    func testTranslation() async throws {
        // 准备测试数据
        let textToTranslate = "Hello, this is a test."
        let targetLanguage = "ZH"
        
        // 执行翻译
        let translatedText = try await translator.translate(text: textToTranslate, targetLang: targetLanguage)
        
        // 验证结果
        XCTAssertFalse(translatedText.isEmpty, "翻译结果不应为空")
        XCTAssertNotEqual(translatedText, textToTranslate, "翻译结果不应与原文相同")
        
        print("Original text: \(textToTranslate)")
        print("Translated text: \(translatedText)")
    }
    
    func testInvalidAPIKey() async {
        // 测试无效的 API Key
        let textToTranslate = "Test invalid API key"
        let targetLanguage = "ZH"
        
        do {
            _ = try await translator.translate(text: textToTranslate, targetLang: targetLanguage)
            XCTFail("使用无效的 API Key 应该抛出错误")
        } catch {
            XCTAssertNotNil(error, "应该捕获到错误")
        }
    }
    
    func testEmptyText() async {
        // 测试空文本
        let textToTranslate = ""
        let targetLanguage = "ZH"
        
        do {
            let translatedText = try await translator.translate(text: textToTranslate, targetLang: targetLanguage)
            XCTAssertTrue(translatedText.isEmpty, "空文本的翻译结果应该为空")
        } catch {
            XCTFail("翻译空文本不应抛出错误")
        }
    }
} 