import Foundation
import DittadoCore
import whisper

public enum DittadoErro: Error, CustomStringConvertible {
    case modeloNaoEncontrado(String)
    case falhaAoCarregarModelo
    case falhaNaTranscricao(Int32)

    public var description: String {
        switch self {
        case .modeloNaoEncontrado(let p): return "Modelo não encontrado em \(p)"
        case .falhaAoCarregarModelo: return "Falha ao carregar o modelo Whisper"
        case .falhaNaTranscricao(let c): return "Falha na transcrição (código \(c))"
        }
    }
}

/// Transcrição voz → texto com whisper.cpp (Metal). Thread-safe: uma transcrição por vez.
public final class WhisperEngine {
    public static let amostrasPorSegundo = 16_000

    private let ctx: OpaquePointer
    private let lock = NSLock()

    private var vocabularioCustomizado: String?

    /// Nomes e termos que o Whisper deve reconhecer bem (vai como contexto inicial).
    /// Por padrão, reflete dinamicamente o GerenciadorVocabulario.shared formatado para o Whisper.
    public var vocabulario: String {
        get { vocabularioCustomizado ?? GerenciadorVocabulario.shared.formatarParaWhisper().prompt }
        set { vocabularioCustomizado = newValue }
    }

    public init(modelPath: String) throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw DittadoErro.modeloNaoEncontrado(modelPath)
        }
        whisper_log_set({ _, _, _ in }, nil)
        var cparams = whisper_context_default_params()
        cparams.use_gpu = true
        cparams.flash_attn = true
        guard let c = whisper_init_from_file_with_params(modelPath, cparams) else {
            throw DittadoErro.falhaAoCarregarModelo
        }
        ctx = c
    }

    deinit { whisper_free(ctx) }

    public func transcrever(_ amostras: [Float], idioma: String = "pt") throws -> String {
        lock.lock(); defer { lock.unlock() }

        // whisper.cpp precisa de pelo menos 1 s de áudio
        var audio = amostras
        let minimo = Self.amostrasPorSegundo + Self.amostrasPorSegundo / 10
        if audio.count < minimo { audio += [Float](repeating: 0, count: minimo - audio.count) }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(max(1, min(6, ProcessInfo.processInfo.activeProcessorCount - 2)))
        params.no_timestamps = true
        params.print_progress = false
        params.print_realtime = false
        params.print_special = false
        params.print_timestamps = false
        params.suppress_blank = true
        params.no_context = true

        let lang = strdup(idioma)
        let prompt = strdup(vocabulario)
        defer { free(lang); free(prompt) }
        params.language = UnsafePointer(lang)
        params.initial_prompt = UnsafePointer(prompt)

        let ret = audio.withUnsafeBufferPointer { buf in
            whisper_full(ctx, params, buf.baseAddress, Int32(buf.count))
        }
        guard ret == 0 else { throw DittadoErro.falhaNaTranscricao(ret) }

        var texto = ""
        for i in 0..<whisper_full_n_segments(ctx) {
            if let s = whisper_full_get_segment_text(ctx, i) { texto += String(cString: s) }
        }
        return Self.limparAlucinacoes(texto.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Frases que o Whisper costuma "inventar" em silêncio ou ruído.
    private static let alucinacoes = [
        "legendas pela comunidade amara.org", "obrigado por assistir", "obrigada por assistir",
        "inscreva-se no canal", "tchau, tchau", "tchau tchau", "legendado por",
    ]

    static func limparAlucinacoes(_ texto: String) -> String {
        let t = texto.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " .!,"))
        if t.isEmpty { return "" }
        if alucinacoes.contains(where: { t == $0 || t.hasPrefix($0) }) { return "" }
        if texto.hasPrefix("[") && texto.hasSuffix("]") { return "" }  // [Música], [BLANK_AUDIO]
        return texto
    }
}
