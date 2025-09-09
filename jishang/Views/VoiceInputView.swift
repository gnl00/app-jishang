//
//  VoiceInputView.swift
//  jishang
//
//  Created by Gnl on 2025/9/9.
//

import SwiftUI
import Speech
import AVFoundation

struct VoiceInputView: View {
    @Binding var isPresented: Bool
    let transactionType: TransactionType
    let onVoiceResult: (String) -> Void
    
    @StateObject private var voiceRecognizer = VoiceRecognizer()
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // 标题
                Text(transactionType == .income ? "语音记录收入" : "语音记录支出")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // 录音状态指示器
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .scaleEffect(isRecording ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)
                        
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 40))
                            .foregroundColor(isRecording ? .red : .gray)
                    }
                    
                    if isRecording {
                        Text(String(format: "%.1f秒", recordingTime))
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 识别结果
                if !voiceRecognizer.recognizedText.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("识别结果:")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(voiceRecognizer.recognizedText)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        // 添加解析结果显示用于调试
                        if let parsedResult = parseVoiceTextForDebug(voiceRecognizer.recognizedText) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("解析结果 (调试):")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                Text("结果: \(voiceRecognizer.recognizedText)")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("金额: ¥\(String(format: "%.2f", parsedResult.amount))")
                                    Text("类型: \(parsedResult.type == .income ? "收入" : "支出")")
                                    Text("类别: \(parsedResult.category ?? "无")")
                                    Text("描述: \(parsedResult.description)")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 提示文本
                if !isRecording && voiceRecognizer.recognizedText.isEmpty {
                    Text("长按开始录音，说出您的记账信息\n例如: \"午饭花了30元\" 或 \"工资收入5000元\"")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // 录音按钮
                VStack(spacing: 16) {
                    Button(action: {}) {
                        Circle()
                            .fill(isRecording ? Color.red : transactionType == .income ? Color.blue.opacity(0.7) : Color.red.opacity(0.7))
                            .frame(width: 80, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: isRecording ? 12 : 40)
                                    .fill(Color.white)
                                    .frame(width: isRecording ? 24 : 30, height: isRecording ? 24 : 30)
                                    .animation(.easeInOut(duration: 0.2), value: isRecording)
                            )
                    }
                    .scaleEffect(isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
                    .onLongPressGesture(minimumDuration: 0.1, maximumDistance: .infinity, perform: {
                        stopRecording()
                    }, onPressingChanged: { pressing in
                        if pressing {
                            startRecording()
                        } else {
                            stopRecording()
                        }
                    })
                    
                    Text(isRecording ? "松开结束录音" : "长按开始录音")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 操作按钮
                HStack(spacing: 20) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    
                    Button("确认") {
                        onVoiceResult(voiceRecognizer.recognizedText)
                        isPresented = false
                    }
                    .disabled(voiceRecognizer.recognizedText.isEmpty)
                    .foregroundColor(voiceRecognizer.recognizedText.isEmpty ? .secondary : .blue)
                    .fontWeight(.semibold)
                }
                .padding(.bottom)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .onAppear {
            voiceRecognizer.requestPermission()
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    // 调试用的解析函数
    private func parseVoiceTextForDebug(_ text: String) -> ParsedTransaction? {
        let parser = VoiceTransactionParser()
        return parser.parseVoiceText(text, expectedType: transactionType)
    }
    
    private func startRecording() {
        guard !isRecording else { return }
        
        isRecording = true
        recordingTime = 0
        
        // 震动反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 开始录音
        voiceRecognizer.startRecording()
        
        // 开始计时
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
        }
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        
        isRecording = false
        timer?.invalidate()
        timer = nil
        
        // 震动反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // 停止录音
        voiceRecognizer.stopRecording()
        
        // 调试打印
        print("🎤 录音停止，识别到的文本: \(voiceRecognizer.recognizedText)")
        if let parsed = parseVoiceTextForDebug(voiceRecognizer.recognizedText) {
            print("🧠 解析结果: 金额=¥\(parsed.amount), 类型=\(parsed.type), 类别=\(parsed.category ?? "无"), 描述=\(parsed.description)")
        } else {
            print("❌ 解析失败")
        }
    }
}

class VoiceRecognizer: NSObject, ObservableObject {
    @Published var recognizedText = ""
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                // 处理权限状态
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { _ in
            // 处理录音权限
        }
    }
    
    func startRecording() {
        // 重置之前的识别结果
        recognizedText = ""
        
        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("音频会话配置失败: \(error)")
            return
        }
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        // 获取音频输入节点
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 安装音频tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // 准备和启动音频引擎
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("音频引擎启动失败: \(error)")
            return
        }
        
        // 开始识别
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                    print("🔄 实时识别: \(self.recognizedText)")
                }
                
                if let error = error {
                    print("❌ 语音识别错误: \(error)")
                }
                
                if error != nil || result?.isFinal == true {
                    if result?.isFinal == true {
                        print("✅ 语音识别完成: \(self.recognizedText)")
                    }
                    self.stopRecording()
                }
            }
        }
    }
    
    func stopRecording() {
        recognitionRequest?.endAudio()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 恢复音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("音频会话恢复失败: \(error)")
        }
    }
}

#Preview {
    VoiceInputView(
        isPresented: .constant(true),
        transactionType: .expense,
        onVoiceResult: { result in
            print("Voice result: \(result)")
        }
    )
}
