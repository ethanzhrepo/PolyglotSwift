//
//  ContentView.swift
//  PolyglotSwift
//
//  Created by Ethan on 2024-12-08.
//

import SwiftUI
import CoreData
import AVFoundation
import Speech
import NaturalLanguage
import Translation

class SubtitleWindowManager: ObservableObject {
    private var subtitleWindow: NSWindow?
    private let configuration: TranslationSession.Configuration?
    private lazy var tagger: NSLinguisticTagger = {
        let schemes = [NSLinguisticTagScheme.tokenType]
        return NSLinguisticTagger(tagSchemes: schemes, options: 0)
    }()
    @Published var lastCompleteSentence: String = ""  // 存储上一条完整的句子
    @Published var lastTranslation: String = ""       // 存储上一条句子的翻译
    @Published var lastTwoSentences: [String] = []  // Add this property
    private var translatedSentences: Set<String> = []  // Add this property
    private var selectedInputLanguage: String
    private var selectedOutputLanguage: String
    
    init(configuration: TranslationSession.Configuration?, inputLanguage: String, outputLanguage: String) {
        self.configuration = configuration
        self.selectedInputLanguage = inputLanguage
        self.selectedOutputLanguage = outputLanguage
    }
    
    @Published var subtitleText: String = "" {
        didSet {
            if !subtitleText.isEmpty {
                // 将文本按单词分组
                let words = subtitleText.split(separator: " ")
                let chunks = words.chunked(into: 18)
                if let lastChunk = chunks.last {
                    // 将最后一组单词重新组合成句子
                    lastCompleteSentence = lastChunk.joined(separator: " ")
                }
                // 翻译倒数第二行
                if let secondLastChunk = chunks.dropLast().last {
                    let sentence = secondLastChunk.joined(separator: " ")
                    lastTwoSentences.append(sentence)
                    // 只有未翻译过的句子才进行翻译
                    if !translatedSentences.contains(sentence) {
                        translatedSentences.insert(sentence)
                        translateSegment(sentence)
                    }
                }
            }
        }
    }
    
    private func translateSegment(_ text: String) {
        // languageLangMapping 
        let languageLangMapping = [
            "zh-CN": "cmn",
            "en-US": "eng",
            "fr-FR": "fra",
            "de-DE": "deu",
            "it-IT": "ita",
            "ja-JP": "jpn",
            "ko-KR": "kor",
            "pt-PT": "por",
            "ru-RU": "rus",
            "es-ES": "spa",
            "vi-VN": "vie",
        ]

        let sourceLang = languageLangMapping[selectedInputLanguage] ?? "eng"
        let targetLang = languageLangMapping[selectedOutputLanguage] ?? "cmn"

        Task {
            do {
                let translator = LocalRestTranslator()
                let translatedText = try await translator.translate(text,
                    from: sourceLang,
                    to: targetLang
                )
                DispatchQueue.main.async {
                    self.lastTranslation = translatedText
                }
            } catch {
                print("❌ Translation error: \(error)")
                DispatchQueue.main.async {
                    self.lastTranslation = "Translation failed"
                }
            }
        }
    }
    
    private func updateWindowContent() {
        DispatchQueue.main.async {
            if let hostingView = self.subtitleWindow?.contentView as? NSHostingView<SubtitleView> {
                hostingView.rootView = SubtitleView(
                    subtitleText: .constant(self.subtitleText),
                    configuration: self.configuration,
                    windowManager: self
                )
            }
        }
    }

    func openSubtitleWindow() {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 800, height: 600)
        let windowWidth: CGFloat = screenSize.width * 0.6
        let windowHeight: CGFloat = 180 + 40  // 增加40像素高度
        let windowX = (screenSize.width - windowWidth) / 2
        let windowY = screenSize.height / 4

        let window = NSWindow(
            contentRect: NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered, defer: false)
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        
        let subtitleView = SubtitleView(
            subtitleText: .constant(subtitleText), 
            configuration: configuration,
            windowManager: self
        )
        window.contentView = NSHostingView(rootView: subtitleView)
        window.makeKeyAndOrderFront(nil)
        
        subtitleWindow = window
    }

    func closeSubtitleWindow() {
        subtitleWindow?.close()
        subtitleWindow = nil
    }
}

class SpeechRecognitionManager: ObservableObject {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    weak var windowManager: SubtitleWindowManager?
    weak var statusBarManager: StatusBarManager?
    
    func startSpeechRecognition(outputDevice: String, inputLanguage: String, languages: [String: String?]) {
        print("🎤 Starting speech recognition")
        print("🎤 Output Device: \(outputDevice)")
        print("🎤 Input Language: \(inputLanguage)")
        print("🎤 Languages: \(languages)")
        
        // 1. 设置语音识别器
        guard let languageCode = languages[inputLanguage] as? String,
              let recognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode)) else {
            print("❌ Speech recognition not supported for language: \(inputLanguage)")
            return
        }
        
        self.speechRecognizer = recognizer
        
        // 2. 检查语音识别是否可用
        if !recognizer.isAvailable {
            print("❌ Speech recognition is not available")
            return
        }
        
        do {
            // 4. 配置音频引擎
            let inputNode = audioEngine.inputNode
            
            // 5. 创建识别请求
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                print("❌ Unable to create recognition request")
                return
            }
            recognitionRequest.shouldReportPartialResults = true
            
            // 6. 设置识别任务
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                if let error = error {
                    print("❌ Recognition error: \(error.localizedDescription)")
                    self?.stopRecording()
                    return
                }
                
                if let result = result {
                    DispatchQueue.main.async {
                        self?.windowManager?.subtitleText = result.bestTranscription.formattedString
                    }
                }
                
                if result?.isFinal == true {
                    print("🎤 Recognition segment completed, continuing...")
                    self?.restartRecognition()
                }
            }
            
            // 7. 安装音频 tap 来捕获音频数据
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                // 发送音频数据到识别请求
                self?.recognitionRequest?.append(buffer)
                
                // 计算分贝值
                let channelData = buffer.floatChannelData?[0]
                if let data = channelData {
                    let frames = buffer.frameLength
                    var sum: Float = 0
                    for i in 0..<frames {
                        sum += data[Int(i)] * data[Int(i)]
                    }
                    let rms = sqrt(sum / Float(frames))
                    let db = 20 * log10(rms)
                    
                    // 更新状态栏的分贝值
                    DispatchQueue.main.async {
                        self?.statusBarManager?.currentDB = max(-60, min(db, 0))
                    }
                }
            }
            
            // 8. 动音频引擎
            audioEngine.prepare()
            try audioEngine.start()
            
            print("✅ Speech recognition started successfully")
            
        } catch {
            print("❌ Setup error: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        print("🛑 Stopping recording")
        
        // 1. 停止音频引擎
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // 2. 结束语音识别请求
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // 3. 取消语音识别任务
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 4. 更新UI状态
        DispatchQueue.main.async { [weak self] in
            self?.statusBarManager?.isRecording = false
            self?.statusBarManager?.currentDB = -60  // 重置分贝值
            self?.windowManager?.subtitleText = ""   // 清空字幕
        }
        
        print("✅ Recording stopped successfully")
    }
    
    private func restartRecognition() {
        print("🔄 Starting restartRecognition...")
        
        // 结束当前请求
        print("🔄 Cleaning up current recognition session...")
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 创建新的识别请求
        print("🔄 Creating new recognition request...")
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        
        // 重新开始识别任务
        guard let request = recognitionRequest else {
            print("❌ Failed to create new recognition request")
            return
        }
        
        guard let speechRecognizer = speechRecognizer else {
            print("❌ Speech recognizer is nil")
            return
        }
        
        print("🔄 Starting new recognition task...")
        recognitionTask = speechRecognizer.recognitionTask(with: request, resultHandler: { [weak self] result, error in
            if let error = error {
                print("❌ New recognition task error: \(error.localizedDescription)")
                return
            }
            
            if let result = result {
                print("✅ New recognition result received: \(result.bestTranscription.formattedString)")
                DispatchQueue.main.async {
                    self?.windowManager?.subtitleText = result.bestTranscription.formattedString
                }
            }
            
            if result?.isFinal == true {
                print("🔄 New recognition segment completed, restarting again...")
                self?.restartRecognition()
            }
        })
        
        if recognitionTask != nil {
            print("✅ New recognition task started successfully")
        } else {
            print("❌ Failed to start new recognition task")
        }
    }
}

class StatusBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    @Published var isRecording: Bool = false
    @Published var currentDB: Float = 0.0 {
        didSet {
            updateStatusBarIcon()
        }
    }
    
    init() {
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusBarIcon()
    }
    
    private func updateStatusBarIcon() {
        if isRecording {
            statusItem?.button?.title = String(format: "%.1f dB", currentDB)
        } else {
            statusItem?.button?.title = "Stopped"
        }
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedOutputDevice: String = ""
    @State private var selectedInputLanguage: String = "English"
    @State private var selectedOutputLanguage: String = "简体中文"
    @State private var isRunning: Bool = false
    @StateObject private var windowManager = SubtitleWindowManager(
        configuration: nil, 
        inputLanguage: "en-US", 
        outputLanguage: "zh-CN"
    )
    @StateObject private var speechRecognitionManager = SpeechRecognitionManager()
    @StateObject private var statusBarManager = StatusBarManager()

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    @State private var configuration: TranslationSession.Configuration? = nil

    private var outputDevices: [String] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        ).devices.compactMap { $0.localizedName }
    }

    init() {
        if let blackHoleDevice = outputDevices.first(where: { $0.contains("BlackHole") }) {
            _selectedOutputDevice = State(initialValue: blackHoleDevice)
        } else if let firstDevice = outputDevices.first {
            _selectedOutputDevice = State(initialValue: firstDevice)
        }
    }

    private let inputLanguages = [
        "English": "en-US",
        "French": "fr-FR",
        "German": "de-DE",
        "Italian": "it-IT",
        "Japanese": "ja-JP",
        "Korean": "ko-KR",
        "Portuguese": "pt-PT",
        "Russian": "ru-RU",
        "Spanish": "es-ES",
        "Vietnamese": "vi-VN"
    ]

    private let outputLanguages = ["简体中文", "English", "French", "German", "Italian", "Japanese", "Korean", "Portuguese", "Russian", "Spanish", "Vietnamese"]

    class AudioDelegate: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            // Handle audio buffer here
        }
    }
    
    private let audioDelegate = AudioDelegate()

    var body: some View {
        VStack {
            Picker("Output Device", selection: $selectedOutputDevice) {
                ForEach(outputDevices, id: \.self) { device in
                    Text(device).tag(device)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .disabled(isRunning)

            Picker("Input Language", selection: $selectedInputLanguage) {
                ForEach(inputLanguages.keys.sorted(), id: \.self) { language in
                    Text(language).tag(language)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .disabled(isRunning)
            .onChange(of: selectedInputLanguage) { _ in
                updateConfiguration()
            }

            Picker("Output Language", selection: $selectedOutputLanguage) {
                ForEach(outputLanguages, id: \.self) { language in
                    Text(language).tag(language)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .disabled(isRunning)
            .onChange(of: selectedOutputLanguage) { _ in
                updateConfiguration()
            }

            Button(action: {
                if selectedOutputDevice.contains("BlackHole") {
                    isRunning.toggle()
                    
                    if isRunning {
                        // 先设置状态栏管理器
                        speechRecognitionManager.statusBarManager = statusBarManager
                        speechRecognitionManager.windowManager = windowManager
                        
                        // 然后更新状态并启动
                        statusBarManager.isRecording = true
                        windowManager.openSubtitleWindow()
                        
                        speechRecognitionManager.startSpeechRecognition(
                            outputDevice: selectedOutputDevice,
                            inputLanguage: selectedInputLanguage,
                            languages: inputLanguages
                        )
                    } else {
                        speechRecognitionManager.stopRecording()
                        windowManager.closeSubtitleWindow()
                    }
                } else {
                    print("Error: Please select BlackHole as the output device.")
                }
            }) {
                Text(isRunning ? "Stop" : "Start")
            }
        }
        .frame(width: 250)
        .padding()
    }

    private func updateConfiguration() {
        // var sourceLanguage: Locale.Language?
        // var targetLanguage: Locale.Language?
        let sourceLanguage = Locale.Language(identifier: selectedInputLanguage)
        let targetLanguage = Locale.Language(identifier: selectedOutputLanguage)


        configuration = TranslationSession.Configuration(
            source: sourceLanguage,
                    target: targetLanguage
        )
    }
}

struct SubtitleView: View {
    @Binding var subtitleText: String
    let configuration: TranslationSession.Configuration?
    @ObservedObject var windowManager: SubtitleWindowManager
    
    var body: some View {
        VStack(spacing: 10) {
            // 倒数第二行文本
            if let secondLastSentence = windowManager.lastTwoSentences.last {
                Text(secondLastSentence)
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            
            // 倒数第二行的翻译
            Text(windowManager.lastTranslation)
                .foregroundColor(.yellow)
                .font(.system(size: 20))
            
            // 当前行
            Text(windowManager.lastCompleteSentence)
                .foregroundColor(.gray)
                .font(.system(size: 18))
            
            // Translating提示
            Text("Translating...")
                .foregroundColor(.gray)
                .font(.system(size: 16))
                .italic()
        }
        .padding(.vertical, 30)
        .padding(.horizontal)
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(Color.black.opacity(0.7))
        .cornerRadius(10)
        .padding()
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

func configureAudioSession() -> AVCaptureSession? {
    let captureSession = AVCaptureSession()
    guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
        print("No audio device found.")
        return nil
    }

    do {
        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
        if captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        } else {
            print("Cannot add audio input.")
            return nil
        }
    } catch {
        print("Error setting up audio input: \(error.localizedDescription)")
        return nil
    }

    return captureSession
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
