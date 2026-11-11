import Foundation

/// Protocolo que abstrai o motor de inferência LLM para desacoplar DittadoCore do llama.cpp.
public protocol MotorLLM: AnyObject {
    func reescrever(sistema: String, texto: String) async throws -> String
}

public enum ModoDitado: String, Codable {
    case livre = "Livre"
    case prompt = "Prompt"

    public var nomeExibicao: String {
        switch self {
        case .livre: return "Livre"
        case .prompt: return "Profissional"
        }
    }
}

public enum Pastas {
    public static let suporte: URL = {
        if let env = ProcessInfo.processInfo.environment["DITTADO_SUPPORT_DIR"], !env.isEmpty {
            let custom = URL(fileURLWithPath: env, isDirectory: true)
            try? FileManager.default.createDirectory(at: custom, withIntermediateDirectories: true)
            return custom
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Dittado", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    public static let modelos = suporte.appendingPathComponent("Models", isDirectory: true)
    public static let modeloWhisperPadrao = modelos.appendingPathComponent("ggml-large-v3-turbo-q8_0.bin")

    /// Nome do arquivo do modelo LLM GGUF (configurável via UserDefaults ou variável de ambiente).
    public static var nomeModeloLLM: String {
        if let env = ProcessInfo.processInfo.environment["DITTADO_MODELO_LLM"], !env.isEmpty {
            return env
        }
        if let salvo = UserDefaults.standard.string(forKey: "nomeModeloLLM"), !salvo.isEmpty {
            return salvo
        }
        return "qwen2.5-7b-instruct-q4_k_m.gguf"
    }

    public static var modeloLLMPadrao: URL {
        modelos.appendingPathComponent(nomeModeloLLM)
    }
}

/// Limpeza PROVISÓRIA do modo Prompt (regras simples). Na F3 o LLM local assume esse trabalho.
public enum LimpezaSimples {
    private static let regras: [(String, String)] = [
        // vícios de fala soltos
        (#"(?i)(^|[\s,.])(h[ãa]+|hum+|hmm+|ahn?|uh+|eh+)[,.…]?(?=\s|$)"#, "$1"),
        // "é," / "tipo," / "né," / "então assim," usados como pausa
        (#"(?i)(^|[\s,])(é|tipo|né|então assim|tipo assim|sei lá|olha só|entendeu)[,?…](?=\s|$)"#, "$1"),
        (#"(?i),\s*(né|entendeu)\s*\?"#, "?"),
        // palavra repetida: "pra, pra" / "o o"
        (#"(?i)\b(\p{L}+)(,?\s+\1\b)+"#, "$1"),
        // espaços e pontuação
        (#"\s+([,.?!])"#, "$1"),
        (#",\s*,"#, ","),
        (#"^[\s,.]+"#, ""),
        (#"\s{2,}"#, " "),
    ]

    public static func aplicar(_ texto: String) -> String {
        var t = texto
        for (padrao, troca) in regras {
            t = t.replacingOccurrences(of: padrao, with: troca, options: .regularExpression)
        }
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if let primeira = t.first { t = primeira.uppercased() + t.dropFirst() }
        return t
    }
}
