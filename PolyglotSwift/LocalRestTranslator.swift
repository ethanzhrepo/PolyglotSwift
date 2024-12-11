import Foundation

struct TranslationRequest: Codable {
    let text: String
    let src_lang: String
    let tgt_lang: String
}

struct TranslationResponse: Codable {
    let translated_text: String
}

class LocalRestTranslator {
    private let baseURL = "http://127.0.0.1:8000/translate/"
    
    func translate(_ text: String, 
                  from sourceLang: String,
                  to targetLang: String) async throws -> String {
        // 创建 URL
        guard let url = URL(string: baseURL) else {
            throw TranslationError.invalidURL
        }
        
        // 准备请求数据
        let request = TranslationRequest(
            text: text,
            src_lang: sourceLang,
            tgt_lang: targetLang
        )
        let jsonData = try JSONEncoder().encode(request)
        
        // 配置请求
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = jsonData
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        // 检查响应状态
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TranslationError.serverError
        }
        
        // 解析响应
        let translationResponse = try JSONDecoder().decode(TranslationResponse.self, from: data)
        return translationResponse.translated_text
    }
}

// 定义可能的错误类型
enum TranslationError: Error {
    case invalidURL
    case serverError
    case invalidResponse
}

// 使用示例
/*
Task {
    let translator = LocalRestTranslator()
    do {
        // 英文翻译成中文
        let translated1 = try await translator.translate("Hello, how are you?",
                                                      from: "en",
                                                      to: "zh")
        print(translated1) // 输出: 你好,你好吗?
        
        // 中文翻译成英文
        let translated2 = try await translator.translate("你好，今天天气真好！",
                                                      from: "zh",
                                                      to: "en")
        print(translated2) // 输出: Hello, the weather is nice today!
    } catch {
        print("Translation error: \(error)")
    }
}
*/ 