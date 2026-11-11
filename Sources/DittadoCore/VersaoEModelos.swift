import Foundation

/// Utilitário testável que transforma nomes de arquivos de modelos (GGUF/BIN) em rótulos amigáveis.
public enum RotuloModelo {

    public enum StatusLLM: Equatable {
        case carregando
        case indisponivel
        case pronto(String)
    }

    public static func formatar(nomeArquivo: String) -> String {
        let nome = (nomeArquivo as NSString).lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nome.isEmpty else { return "" }
        let lower = nome.lowercased()

        // 1. Modelos Whisper (ggml-*.bin)
        if lower.hasPrefix("ggml-") && lower.hasSuffix(".bin") {
            // Remove prefixo "ggml-"
            var miolo = String(nome.dropFirst(5))
            if miolo.hasSuffix(".bin") {
                miolo = String(miolo.dropLast(4))
            }
            // Procura sufixo de quantização (ex: "-q8_0", "_q8_0", "-q5_0", "-fp16")
            let padraoQuant = #"(?:[-_])(q\d+_\w+|\w+_\d+|fp16|f16|f32)$"#
            var quantStr = ""
            if let regex = try? NSRegularExpression(pattern: padraoQuant, options: .caseInsensitive) {
                let ns = miolo as NSString
                if let match = regex.firstMatch(in: miolo, options: [], range: NSRange(location: 0, length: ns.length)) {
                    quantStr = " (" + ns.substring(with: match.range(at: 1)).uppercased() + ")"
                    miolo = ns.substring(with: NSRange(location: 0, length: match.range.location))
                }
            }
            return "Whisper \(miolo)\(quantStr)"
        }

        // 2. Modelos Qwen (ex: qwen2.5-7b-instruct-q4_k_m.gguf)
        let padraoQwen = #"(?i)^qwen(\d+(?:\.\d+)?)-(\d+(?:\.\d+)?b)(?:-(instruct|chat))?(?:-(q\w+))?\.gguf$"#
        if let regex = try? NSRegularExpression(pattern: padraoQwen, options: []) {
            let ns = nome as NSString
            if let match = regex.firstMatch(in: nome, options: [], range: NSRange(location: 0, length: ns.length)) {
                let versao = ns.substring(with: match.range(at: 1))
                let tamanho = ns.substring(with: match.range(at: 2)).uppercased()
                var partes = ["Qwen\(versao)", tamanho]
                if match.range(at: 3).location != NSNotFound {
                    partes.append(ns.substring(with: match.range(at: 3)).capitalized)
                }
                var sufixoQuant = ""
                if match.range(at: 4).location != NSNotFound {
                    sufixoQuant = " (" + ns.substring(with: match.range(at: 4)).uppercased() + ")"
                }
                return partes.joined(separator: " ") + sufixoQuant
            }
        }

        // 3. Modelos Llama / Phi / outros padronizados em GGUF
        let padraoGenerico = #"(?i)^([A-Za-z]+)(?:-(\d+(?:\.\d+)?))?-(\d+(?:\.\d+)?b)(?:-(instruct|chat))?(?:-(q\w+))?\.gguf$"#
        if let regex = try? NSRegularExpression(pattern: padraoGenerico, options: []) {
            let ns = nome as NSString
            if let match = regex.firstMatch(in: nome, options: [], range: NSRange(location: 0, length: ns.length)) {
                let familia = ns.substring(with: match.range(at: 1)).capitalized
                var partes = [familia]
                if match.range(at: 2).location != NSNotFound {
                    partes[0] += " " + ns.substring(with: match.range(at: 2))
                }
                partes.append(ns.substring(with: match.range(at: 3)).uppercased())
                if match.range(at: 4).location != NSNotFound {
                    partes.append(ns.substring(with: match.range(at: 4)).capitalized)
                }
                var sufixoQuant = ""
                if match.range(at: 5).location != NSNotFound {
                    sufixoQuant = " (" + ns.substring(with: match.range(at: 5)).uppercased() + ")"
                }
                return partes.joined(separator: " ") + sufixoQuant
            }
        }

        // 4. Arquivos desconhecidos: retorna o nome cru do arquivo
        return nome
    }

    public static func rotuloCombinado(whisperArquivo: String?, statusLLM: StatusLLM) -> String {
        let whisperStr: String
        if let w = whisperArquivo, !w.isEmpty {
            whisperStr = formatar(nomeArquivo: w)
        } else {
            whisperStr = "Whisper: carregando…"
        }

        switch statusLLM {
        case .carregando:
            return "\(whisperStr) · LLM: carregando…"
        case .indisponivel:
            return "\(whisperStr) · LLM: indisponível (usando só Whisper)"
        case .pronto(let llmArquivo):
            let llmStr = formatar(nomeArquivo: llmArquivo)
            return "\(whisperStr) · \(llmStr)"
        }
    }
}

/// Acesso seguro e tipado às informações de versão do aplicativo.
public enum InfoApp {
    public static var versao: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0"
    }

    public static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    public static var rotuloVersao: String {
        "v\(versao) (build \(build))"
    }
}
