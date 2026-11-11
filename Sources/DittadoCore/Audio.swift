import AVFoundation
import CoreMedia
import CoreAudio
import Foundation

public let formatoWhisper = AVAudioFormat(
    commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

public enum ErroMicrofone: Error, CustomStringConvertible {
    case semMicrofone
    public var description: String { "Nenhum microfone disponível" }
}

/// Qual microfone usar.
public enum PoliticaMicrofone: String, CaseIterable, Codable {
    /// Fone com fio → microfone do fone; Bluetooth (AirPods, iPhone) ou nada → microfone do MacBook.
    case automatico
    case sempreMacBook
    case padraoDoSistema
}

/// Grava o microfone em 16 kHz mono float (formato do Whisper) com AVCaptureSession.
/// - AirPods ficam fora: no modo chamada perdem o começo da fala e derrubavam o AVAudioEngine.
/// - Conectar/desconectar fone deixa a entrada antiga "muda": a sessão é refeita nesses casos,
///   e um vigia refaz e religa se nenhum som chegar logo depois de começar.
public final class GravadorDeAudio: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private var sessao: AVCaptureSession?
    private var idMicrofone: String?
    private var precisaRecriar = true
    private var amostras: [Float] = []
    private var recebeuAudio = false
    private let fila = DispatchQueue(label: "dittado.gravador")
    private(set) public var gravando = false
    /// Nome do microfone da gravação atual (para o log e o painel).
    private(set) public var descricao = ""

    public var politica: PoliticaMicrofone = .automatico

    /// Nível (RMS) de cada bloco, para o indicador na tela. Chamado fora da main thread.
    public var aoMudarNivel: ((Float) -> Void)?
    /// Avisos para o log do app (troca de microfone, religação).
    public var aoRegistrar: ((String) -> Void)?

    public override init() {
        super.init()
        let nc = NotificationCenter.default
        for nome in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification,
                     AVCaptureSession.runtimeErrorNotification, AVCaptureSession.wasInterruptedNotification] {
            nc.addObserver(forName: nome, object: nil, queue: nil) { [weak self] n in
                self?.precisaRecriar = true
                self?.aoRegistrar?("Áudio mudou (\(n.name.rawValue)); microfone será reconectado")
            }
        }
    }

    // MARK: Escolha do microfone

    private static let idMacBook = "BuiltInMicrophoneDevice"

    private static func microfones() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external], mediaType: .audio,
                                         position: .unspecified).devices
    }

    private static func ehMacBook(_ d: AVCaptureDevice) -> Bool {
        d.uniqueID == idMacBook
            || (d.transportType == Int32(bitPattern: kAudioDeviceTransportTypeBuiltIn) && !d.uniqueID.contains("Headphone"))
    }

    private static func ehSemFio(_ d: AVCaptureDevice) -> Bool {
        let t = UInt32(bitPattern: d.transportType)
        return t == kAudioDeviceTransportTypeBluetooth || t == kAudioDeviceTransportTypeBluetoothLE
            || t == kAudioDeviceTransportTypeContinuityCaptureWired || t == kAudioDeviceTransportTypeContinuityCaptureWireless
            || d.localizedName.localizedCaseInsensitiveContains("iPhone")
    }

    public func microfoneEscolhido() -> AVCaptureDevice? {
        let todos = Self.microfones()
        let macbook = todos.first(where: Self.ehMacBook)
        let padrao = AVCaptureDevice.default(for: .audio)
        switch politica {
        case .sempreMacBook: return macbook ?? padrao
        case .padraoDoSistema: return padrao ?? macbook
        case .automatico:
            guard let padrao else { return macbook }
            return Self.ehSemFio(padrao) ? (macbook ?? padrao) : padrao
        }
    }

    // MARK: Sessão

    private func montarSessao(_ mic: AVCaptureDevice) throws -> AVCaptureSession {
        let nova = AVCaptureSession()
        nova.beginConfiguration()
        let entrada = try AVCaptureDeviceInput(device: mic)
        guard nova.canAddInput(entrada) else { throw ErroMicrofone.semMicrofone }
        nova.addInput(entrada)
        let saida = AVCaptureAudioDataOutput()
        saida.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
        ]
        saida.setSampleBufferDelegate(self, queue: fila)
        guard nova.canAddOutput(saida) else { throw ErroMicrofone.semMicrofone }
        nova.addOutput(saida)
        nova.commitConfiguration()
        return nova
    }

    public func iniciar() throws {
        guard !gravando else { return }
        guard let mic = microfoneEscolhido() else { throw ErroMicrofone.semMicrofone }
        if precisaRecriar || sessao == nil || idMicrofone != mic.uniqueID {
            sessao?.stopRunning()
            sessao = try montarSessao(mic)
            idMicrofone = mic.uniqueID
            precisaRecriar = false
        }
        descricao = mic.localizedName
        fila.sync { amostras.removeAll(keepingCapacity: true); recebeuAudio = false }
        gravando = true
        sessao?.startRunning()
        vigiar(tentativa: 1)
    }

    /// Se nenhum som chegar logo após começar, refaz a sessão e grava de novo.
    private func vigiar(tentativa: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, self.gravando, !self.fila.sync(execute: { self.recebeuAudio }) else { return }
            self.aoRegistrar?("Microfone \(self.descricao) mudo após 0,8 s (tentativa \(tentativa)); reconectando")
            self.sessao?.stopRunning()
            self.sessao = nil
            if tentativa >= 2 { self.politica = .sempreMacBook }  // último recurso: microfone do Mac
            guard let mic = self.microfoneEscolhido(), let nova = try? self.montarSessao(mic) else { return }
            self.sessao = nova
            self.idMicrofone = mic.uniqueID
            self.descricao = mic.localizedName
            nova.startRunning()
            if tentativa < 2 { self.vigiar(tentativa: tentativa + 1) }
        }
    }

    /// Para e devolve o áudio gravado.
    public func parar() -> [Float] {
        guard gravando else { return [] }
        sessao?.stopRunning()
        gravando = false
        let a = fila.sync { amostras }
        if a.isEmpty { precisaRecriar = true }
        return a
    }

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        guard gravando, let bloco = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var tamanho = 0
        var ponteiro: UnsafeMutablePointer<CChar>?
        guard CMBlockBufferGetDataPointer(bloco, atOffset: 0, lengthAtOffsetOut: nil,
                                          totalLengthOut: &tamanho, dataPointerOut: &ponteiro) == kCMBlockBufferNoErr,
              let ponteiro else { return }
        let n = tamanho / MemoryLayout<Float>.size
        let novos = ponteiro.withMemoryRebound(to: Float.self, capacity: n) { Array(UnsafeBufferPointer(start: $0, count: n)) }
        amostras.append(contentsOf: novos)  // já estamos na fila do gravador
        recebeuAudio = true
        aoMudarNivel?(nivelRMS(novos))
    }
}

func converter(_ buf: AVAudioPCMBuffer, com conversor: AVAudioConverter) -> [Float]? {
    let razao = formatoWhisper.sampleRate / buf.format.sampleRate
    let capacidade = AVAudioFrameCount(Double(buf.frameLength) * razao + 64)
    guard let saida = AVAudioPCMBuffer(pcmFormat: formatoWhisper, frameCapacity: capacidade) else { return nil }
    var entregue = false
    var erro: NSError?
    conversor.convert(to: saida, error: &erro) { _, status in
        if entregue { status.pointee = .noDataNow; return nil }
        entregue = true
        status.pointee = .haveData
        return buf
    }
    guard erro == nil, saida.frameLength > 0, let canal = saida.floatChannelData?[0] else { return nil }
    return Array(UnsafeBufferPointer(start: canal, count: Int(saida.frameLength)))
}

public func nivelRMS(_ a: [Float]) -> Float {
    guard !a.isEmpty else { return 0 }
    var soma: Float = 0
    for v in a { soma += v * v }
    return (soma / Float(a.count)).squareRoot()
}

/// Lê qualquer arquivo de áudio e devolve 16 kHz mono.
public func carregarAudio(_ url: URL) throws -> [Float] {
    let arquivo = try AVAudioFile(forReading: url)
    let formato = arquivo.processingFormat
    guard let buf = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: AVAudioFrameCount(arquivo.length)),
          let conversor = AVAudioConverter(from: formato, to: formatoWhisper) else { return [] }
    try arquivo.read(into: buf)
    return converter(buf, com: conversor) ?? []
}

/// Salva áudio 16 kHz mono em WAV (usado só no modo de teste).
public func salvarWAV(_ amostras: [Float], em url: URL) throws {
    let arquivo = try AVAudioFile(forWriting: url, settings: formatoWhisper.settings,
                                  commonFormat: .pcmFormatFloat32, interleaved: false)
    guard let buf = AVAudioPCMBuffer(pcmFormat: formatoWhisper, frameCapacity: AVAudioFrameCount(amostras.count)) else { return }
    buf.frameLength = AVAudioFrameCount(amostras.count)
    amostras.withUnsafeBufferPointer { src in
        buf.floatChannelData![0].update(from: src.baseAddress!, count: amostras.count)
    }
    try arquivo.write(from: buf)
}
