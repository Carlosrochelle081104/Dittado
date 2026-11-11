import Foundation
import DittadoCore
import llama

public enum LLMErro: Error, CustomStringConvertible {
    case modeloNaoEncontrado(String)
    case falhaAoCarregarModelo
    case falhaAoCriarContexto
    case falhaNaTokenizacao
    case falhaNaInferência(Int32)
    case tempoEsgotado

    public var description: String {
        switch self {
        case .modeloNaoEncontrado(let p): return "Modelo LLM não encontrado em \(p)"
        case .falhaAoCarregarModelo: return "Falha ao carregar o modelo LLM"
        case .falhaAoCriarContexto: return "Falha ao criar o contexto do LLM"
        case .falhaNaTokenizacao: return "Falha na tokenização do prompt"
        case .falhaNaInferência(let c): return "Falha na inferência do LLM (código \(c))"
        case .tempoEsgotado: return "Tempo limite de inferência excedido (timeout de 8 s)"
        }
    }
}

/// Motor de inferência LLM local baseado em llama.cpp (Metal).
/// Thread-safe: garante uma inferência por vez.
public final class LLMEngine {
    private var model: OpaquePointer?
    private var ctx: OpaquePointer?
    private var cachedTokens: [llama_token] = []
    private let lock = NSLock()

    private static var backendInicializado = false
    private static let lockInicializacao = NSLock()

    public init(modelPath: String) throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw LLMErro.modeloNaoEncontrado(modelPath)
        }

        Self.lockInicializacao.lock()
        if !Self.backendInicializado {
            llama_log_set({ _, _, _ in }, nil)
            llama_backend_init()
            Self.backendInicializado = true
        }
        Self.lockInicializacao.unlock()

        var mparams = llama_model_default_params()
        mparams.n_gpu_layers = 99 // Todas as camadas na GPU Metal

        guard let m = llama_model_load_from_file(modelPath, mparams) else {
            throw LLMErro.falhaAoCarregarModelo
        }
        model = m

        var cparams = llama_context_default_params()
        cparams.n_ctx = 2048
        let threads = Int32(max(1, min(6, ProcessInfo.processInfo.activeProcessorCount - 2)))
        cparams.n_threads = threads
        cparams.n_threads_batch = threads

        guard let c = llama_init_from_model(m, cparams) else {
            llama_model_free(m)
            throw LLMErro.falhaAoCriarContexto
        }
        ctx = c
    }

    public func encerrar() {
        lock.lock()
        defer { lock.unlock() }
        cachedTokens.removeAll()
        if let ctx {
            llama_free(ctx)
            self.ctx = nil
        }
        if let model {
            llama_model_free(model)
            self.model = nil
        }
    }

    deinit {
        encerrar()
    }

    /// Aquece o modelo e o pipeline do Metal com uma inferência curta.
    /// Opcionalmente pré-aquece o KV cache com o prompt de sistema fornecido.
    public func aquecer(sistema: String? = nil) {
        let sys = sistema ?? "Você é um assistente prestativo."
        _ = try? inferirSincrono(sistema: sys, texto: "Oi")
    }

    /// Aplica o chat template do modelo GGUF (ou fallback ChatML/Qwen).
    private func formatarChat(sistema: String, texto: String) -> String {
        guard let model else { return texto }
        let tmpl = llama_model_chat_template(model, nil)

        let cSistema = strdup(sistema)
        let cTexto = strdup(texto)
        let cRoleSys = strdup("system")
        let cRoleUser = strdup("user")
        defer {
            free(cSistema)
            free(cTexto)
            free(cRoleSys)
            free(cRoleUser)
        }

        var msgs = [
            llama_chat_message(role: UnsafePointer(cRoleSys), content: UnsafePointer(cSistema)),
            llama_chat_message(role: UnsafePointer(cRoleUser), content: UnsafePointer(cTexto))
        ]

        let lenNeeded = llama_chat_apply_template(tmpl, &msgs, msgs.count, true, nil, 0)
        if lenNeeded > 0 {
            var buf = [CChar](repeating: 0, count: Int(lenNeeded) + 1)
            let res = llama_chat_apply_template(tmpl, &msgs, msgs.count, true, &buf, Int32(buf.count))
            if res > 0 {
                return String(cString: buf)
            }
        }

        // Fallback para o formato ChatML (padrão Qwen)
        return "<|im_start|>system\n\(sistema)<|im_end|>\n<|im_start|>user\n\(texto)<|im_end|>\n<|im_start|>assistant\n"
    }

    /// Tokeniza uma string usando o vocabulário do modelo.
    private func tokenizar(prompt: String) throws -> [llama_token] {
        guard let model else { throw LLMErro.falhaAoCarregarModelo }
        guard let vocab = llama_model_get_vocab(model) else { throw LLMErro.falhaNaTokenizacao }

        let maxTokens = Int32(prompt.utf8.count) + 64
        var tokens = [llama_token](repeating: 0, count: Int(maxTokens))

        let n = llama_tokenize(vocab, prompt, Int32(prompt.utf8.count), &tokens, maxTokens, true, true)
        if n >= 0 {
            return Array(tokens.prefix(Int(n)))
        } else if n < 0 && n != Int32.min {
            let required = -n
            tokens = [llama_token](repeating: 0, count: Int(required))
            let n2 = llama_tokenize(vocab, prompt, Int32(prompt.utf8.count), &tokens, required, true, true)
            if n2 >= 0 {
                return Array(tokens.prefix(Int(n2)))
            }
        }
        throw LLMErro.falhaNaTokenizacao
    }

    /// Inferência síncrona thread-safe (uma por vez).
    private func inferirSincrono(sistema: String, texto: String) throws -> String {
        lock.lock()
        defer { lock.unlock() }

        guard let model, let ctx else { throw LLMErro.falhaAoCarregarModelo }
        guard let vocab = llama_model_get_vocab(model) else { throw LLMErro.falhaAoCarregarModelo }

        let mem = llama_get_memory(ctx)

        let tokensUsuario = (try? tokenizar(prompt: texto)) ?? []
        let nUsuario = max(1, tokensUsuario.count)
        // Limita tokens de saída proporcionalmente à entrada do usuário para latência sub-1.5s
        let maxNovosTokens = min(384, max(40, Int(Double(nUsuario) * 1.8) + 50))

        let prompt = formatarChat(sistema: sistema, texto: texto)
        let tokens = try tokenizar(prompt: prompt)
        guard !tokens.isEmpty else { return texto }

        // Reaproveita prefixo do prompt (ex: instruções de sistema) já presente no KV cache
        var commonPrefix = 0
        while commonPrefix < cachedTokens.count && commonPrefix < tokens.count && cachedTokens[commonPrefix] == tokens[commonPrefix] {
            commonPrefix += 1
        }

        if commonPrefix < 16 {
            llama_memory_clear(mem, true)
            cachedTokens = []
            commonPrefix = 0
        } else {
            _ = llama_memory_seq_rm(mem, 0, Int32(commonPrefix), -1)
        }

        let nBatch = 512
        var pos = commonPrefix
        while pos < tokens.count {
            if Task.isCancelled {
                llama_memory_clear(mem, true)
                cachedTokens = []
                throw LLMErro.tempoEsgotado
            }
            let count = min(nBatch, tokens.count - pos)
            var chunk = Array(tokens[pos..<(pos + count)])
            let batch = llama_batch_get_one(&chunk, Int32(count))
            let ret = llama_decode(ctx, batch)
            if ret != 0 {
                llama_memory_clear(mem, true)
                cachedTokens = []
                throw LLMErro.falhaNaInferência(ret)
            }
            pos += count
        }

        let sparams = llama_sampler_chain_default_params()
        guard let smpl = llama_sampler_chain_init(sparams) else {
            llama_memory_clear(mem, true)
            cachedTokens = []
            throw LLMErro.falhaAoCriarContexto
        }
        defer { llama_sampler_free(smpl) }

        llama_sampler_chain_add(smpl, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(smpl, llama_sampler_init_temp(0.1))
        llama_sampler_chain_add(smpl, llama_sampler_init_dist(42))

        var outputTokens: [llama_token] = []

        for _ in 0..<maxNovosTokens {
            if Task.isCancelled {
                llama_memory_clear(mem, true)
                cachedTokens = []
                throw LLMErro.tempoEsgotado
            }
            let curToken = llama_sampler_sample(smpl, ctx, -1)
            if llama_vocab_is_eog(vocab, curToken) {
                break
            }
            outputTokens.append(curToken)

            var one = curToken
            let batch = llama_batch_get_one(&one, 1)
            let ret = llama_decode(ctx, batch)
            if ret != 0 {
                break
            }
        }

        // Mantém apenas os tokens do prompt no KV cache para a próxima inferência reaproveitar
        _ = llama_memory_seq_rm(mem, 0, Int32(tokens.count), -1)
        cachedTokens = tokens

        if outputTokens.isEmpty {
            return texto
        }

        let maxBuf = outputTokens.count * 8 + 256
        var textBuf = [CChar](repeating: 0, count: maxBuf)
        let detokLen = llama_detokenize(vocab, outputTokens, Int32(outputTokens.count), &textBuf, Int32(textBuf.count), true, false)
        if detokLen > 0 {
            let res = String(decoding: textBuf.prefix(Int(detokLen)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
            return res.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return texto
    }

    /// API assíncrona com timeout de 8 segundos e temperatura 0.2.
    public func reescrever(sistema: String, texto: String) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { [weak self] in
                guard let self else { throw LLMErro.falhaAoCarregarModelo }
                return try self.inferirSincrono(sistema: sistema, texto: texto)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 8_000_000_000)
                throw LLMErro.tempoEsgotado
            }

            let resultado = try await group.next()!
            group.cancelAll()
            return resultado
        }
    }
}

// Conformidade ao protocolo MotorLLM definido em DittadoCore
extension LLMEngine: MotorLLM {}
