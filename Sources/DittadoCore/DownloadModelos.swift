// =========================================================================================
// AUDITORIA DE REDE DO DITTADO (Open Source / 100% Local)
//
// 1. O Dittado foi concebido para processar áudio e texto 100% offline neste Mac.
// 2. Durante a operação normal (gravação, transcrição Whisper, formatação LLM),
//    o aplicativo realiza ZERO requisições de rede. Nenhum byte de telemetria, áudio ou
//    texto transcrito jamais sai da máquina.
// 3. Este módulo (DownloadModelos.swift) contém a ÚNICA funcionalidade de rede de todo
//    o aplicativo: o download inicial e opcional de arquivos de modelos de IA (GGUF e BIN).
// 4. Toda e qualquer requisição de rede:
//    - É disparada EXCLUSIVAMENTE por ação explícita e consciente do usuário no Onboarding
//      ou no painel "Gerenciar Modelos".
//    - Conecta-se apenas a URLs fixas e canônicas da Hugging Face (huggingface.co).
//    - Suporta download retomável via cabeçalho HTTP 'Range: bytes=X-'.
//    - Valida o checksum SHA-256 localmente antes de aceitar o arquivo baixado.
//    - Não envia tokens de rastreio, identificadores de usuário ou cabeçalhos proprietários.
// =========================================================================================

import CryptoKit
import Foundation

// MARK: - Catálogo de Modelos Oficiais

public enum CatalogoModelos {

    public struct ModeloInfo: Identifiable, Equatable, Hashable {
        public let id: String
        public let nomeExibicao: String
        public let nomeArquivo: String
        public let url: URL
        public let tamanhoBytes: Int64
        public let tamanhoExibicao: String
        public let sha256: String
        public let licenca: String
        public let ehWhisper: Bool
        public let memoriaMinimaRecomendadaGB: Int
        public let descricao: String

        public init(
            id: String,
            nomeExibicao: String,
            nomeArquivo: String,
            url: URL,
            tamanhoBytes: Int64,
            tamanhoExibicao: String,
            sha256: String,
            licenca: String,
            ehWhisper: Bool,
            memoriaMinimaRecomendadaGB: Int,
            descricao: String
        ) {
            self.id = id
            self.nomeExibicao = nomeExibicao
            self.nomeArquivo = nomeArquivo
            self.url = url
            self.tamanhoBytes = tamanhoBytes
            self.tamanhoExibicao = tamanhoExibicao
            self.sha256 = sha256
            self.licenca = licenca
            self.ehWhisper = ehWhisper
            self.memoriaMinimaRecomendadaGB = memoriaMinimaRecomendadaGB
            self.descricao = descricao
        }
    }

    /// Modelo Whisper oficial obrigatório para transcrição de voz.
    public static let whisperLargeV3Turbo = ModeloInfo(
        id: "whisper-turbo",
        nomeExibicao: "Whisper large-v3-turbo (Q8_0)",
        nomeArquivo: "ggml-large-v3-turbo-q8_0.bin",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin")!,
        tamanhoBytes: 874_188_075,
        tamanhoExibicao: "874 MB",
        sha256: "317eb69c11673c9de1e1f0d459b253999804ec71ac4c23c17ecf5fbe24e259a1",
        licenca: "MIT",
        ehWhisper: true,
        memoriaMinimaRecomendadaGB: 8,
        descricao: "Reconhecimento de fala ultrarrápido em português e multilíngue."
    )

    /// Modelo LLM recomendado para Macs com 16 GB ou mais de memória RAM.
    public static let qwen7B = ModeloInfo(
        id: "qwen-7b",
        nomeExibicao: "Qwen2.5 7B Instruct (Q4_K_M)",
        nomeArquivo: "qwen2.5-7b-instruct-q4_k_m.gguf",
        url: URL(string: "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf")!,
        tamanhoBytes: 4_683_074_240,
        tamanhoExibicao: "4,68 GB",
        sha256: "65b8fcd92af6b4fefa935c625d1ac27ea29dcb6ee14589c55a8f115ceaaa1423",
        licenca: "Apache-2.0",
        ehWhisper: false,
        memoriaMinimaRecomendadaGB: 16,
        descricao: "Formatação de texto e e-mails de alta fidelidade para Macs com 16 GB+ de RAM."
    )

    /// Modelo LLM leve recomendado para Macs com 8 GB a 15 GB de memória RAM.
    public static let qwen1_5B = ModeloInfo(
        id: "qwen-1.5b",
        nomeExibicao: "Qwen2.5 1.5B Instruct (Q4_K_M)",
        nomeArquivo: "qwen2.5-1.5b-instruct-q4_k_m.gguf",
        url: URL(string: "https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf")!,
        tamanhoBytes: 986_048_768,
        tamanhoExibicao: "986 MB",
        sha256: "1adf0b11065d8ad2e8123ea110d1ec956dab4ab038eab665614adba04b6c3370",
        licenca: "Apache-2.0",
        ehWhisper: false,
        memoriaMinimaRecomendadaGB: 8,
        descricao: "Modelo superleve para Macs com 8 GB de RAM."
    )

    public static let todosLLMs: [ModeloInfo] = [qwen7B, qwen1_5B]

    /// Recomenda o modelo LLM com base na memória RAM do Mac:
    /// - >= 16 GB -> Qwen2.5-7B-Instruct Q4_K_M
    /// - 8 a 15 GB -> Qwen2.5-1.5B-Instruct Q4_K_M
    public static func recomendarLLM(memoriaRAMBytes: UInt64 = ProcessInfo.processInfo.physicalMemory) -> ModeloInfo {
        let ramGB = Double(memoriaRAMBytes) / (1024.0 * 1024.0 * 1024.0)
        if ramGB >= 15.5 {
            return qwen7B
        } else {
            return qwen1_5B
        }
    }
}

// MARK: - Verificação de Espaço em Disco

public enum VerificadorDisco {

    public static func espacoLivreEmBytes(em pasta: URL = Pastas.modelos) -> Int64 {
        var urlVerificar = pasta
        while !FileManager.default.fileExists(atPath: urlVerificar.path) && urlVerificar.pathComponents.count > 1 {
            urlVerificar.deleteLastPathComponent()
        }
        if let valores = try? urlVerificar.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let espaco = valores.volumeAvailableCapacityForImportantUsage {
            return espaco
        }
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: urlVerificar.path),
           let livre = attrs[.systemFreeSize] as? Int64 {
            return livre
        }
        return 0
    }

    public static func formatarBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    public static func espacoSuficiente(
        necessario: Int64,
        em pasta: URL = Pastas.modelos,
        margemSeguranca: Int64 = 500_000_000
    ) -> Bool {
        let livre = espacoLivreEmBytes(em: pasta)
        return livre >= (necessario + margemSeguranca)
    }
}

// MARK: - Cálculo e Verificação de Hash SHA-256

public enum VerificadorHash {

    public static func calcularSHA256(arquivoURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: arquivoURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1024 * 1024)
            guard !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func verificarSHA256(arquivoURL: URL, hashEsperado: String) -> Bool {
        guard let hash = try? calcularSHA256(arquivoURL: arquivoURL) else { return false }
        return hash.lowercased() == hashEsperado.lowercased()
    }
}

// MARK: - Gerenciador de Download Retomável (URLSession)

public final class GerenciadorDownload: NSObject, ObservableObject, URLSessionDataDelegate {

    public enum Estado: Equatable {
        case parado
        case baixando(progresso: Double, velocidade: Double, tempoRestante: TimeInterval?)
        case pausado(progresso: Double)
        case verificandoHash
        case concluido(URL)
        case erro(String)

        public static func == (lhs: Estado, rhs: Estado) -> Bool {
            switch (lhs, rhs) {
            case (.parado, .parado): return true
            case (.verificandoHash, .verificandoHash): return true
            case (.concluido(let a), .concluido(let b)): return a == b
            case (.erro(let a), .erro(let b)): return a == b
            case (.pausado(let a), .pausado(let b)): return abs(a - b) < 0.0001
            case (.baixando(let p1, let v1, _), .baixando(let p2, let v2, _)):
                return abs(p1 - p2) < 0.0001 && abs(v1 - v2) < 0.0001
            default: return false
            }
        }
    }

    @Published public private(set) var estado: Estado = .parado
    @Published public private(set) var bytesRecebidos: Int64 = 0
    @Published public private(set) var tamanhoTotal: Int64 = 0
    @Published public private(set) var progresso: Double = 0.0
    @Published public private(set) var velocidadeBytesPorSegundo: Double = 0.0
    @Published public private(set) var tempoRestanteSegundos: TimeInterval? = nil
    @Published public private(set) var mensagemErro: String? = nil

    public let modelo: CatalogoModelos.ModeloInfo
    public let destinoPasta: URL
    private let urlOverride: URL?
    private let hashEsperadoOverride: String?

    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var fileHandle: FileHandle?
    private var ultimoTimestamp: Date = Date()
    private var bytesUltimoIntervalo: Int64 = 0

    public var arquivoFinal: URL {
        destinoPasta.appendingPathComponent(modelo.nomeArquivo)
    }

    public var arquivoPart: URL {
        destinoPasta.appendingPathComponent(modelo.nomeArquivo + ".part")
    }

    public var estaInstalado: Bool {
        FileManager.default.fileExists(atPath: arquivoFinal.path)
    }

    public init(
        modelo: CatalogoModelos.ModeloInfo,
        destinoPasta: URL = Pastas.modelos,
        urlOverride: URL? = nil,
        hashEsperadoOverride: String? = nil
    ) {
        self.modelo = modelo
        self.destinoPasta = destinoPasta
        self.urlOverride = urlOverride
        self.hashEsperadoOverride = hashEsperadoOverride
        super.init()

        self.tamanhoTotal = modelo.tamanhoBytes
        try? FileManager.default.createDirectory(at: destinoPasta, withIntermediateDirectories: true)

        if estaInstalado {
            self.bytesRecebidos = modelo.tamanhoBytes
            self.progresso = 1.0
            self.estado = .concluido(arquivoFinal)
        } else if FileManager.default.fileExists(atPath: arquivoPart.path),
                  let tam = (try? FileManager.default.attributesOfItem(atPath: arquivoPart.path)[.size] as? Int64),
                  tam > 0 {
            self.bytesRecebidos = tam
            self.progresso = min(1.0, Double(tam) / Double(max(1, modelo.tamanhoBytes)))
            self.estado = .pausado(progresso: self.progresso)
        }
    }

    public func iniciarOuRetomar() {
        if estaInstalado {
            self.estado = .concluido(arquivoFinal)
            return
        }

        // Verifica espaço livre em disco
        let espacoNecessario = max(0, modelo.tamanhoBytes - bytesRecebidos)
        if !VerificadorDisco.espacoSuficiente(necessario: espacoNecessario, em: destinoPasta) {
            let msg = "Espaço insuficiente em disco para baixar \(modelo.nomeExibicao)."
            self.mensagemErro = msg
            self.estado = .erro(msg)
            return
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600
        let s = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = s

        let downloadURL = urlOverride ?? modelo.url
        var request = URLRequest(url: downloadURL)

        // Verifica existência de .part prévio para retomar com Range
        var offsetBytes: Int64 = 0
        if FileManager.default.fileExists(atPath: arquivoPart.path),
           let tamPart = try? FileManager.default.attributesOfItem(atPath: arquivoPart.path)[.size] as? Int64,
           tamPart > 0 {
            offsetBytes = tamPart
            request.setValue("bytes=\(offsetBytes)-", forHTTPHeaderField: "Range")
        }

        self.bytesRecebidos = offsetBytes
        self.bytesUltimoIntervalo = 0
        self.ultimoTimestamp = Date()

        do {
            if !FileManager.default.fileExists(atPath: arquivoPart.path) {
                FileManager.default.createFile(atPath: arquivoPart.path, contents: nil)
            }
            let fh = try FileHandle(forWritingTo: arquivoPart)
            fh.seekToEndOfFile()
            self.fileHandle = fh
        } catch {
            let msg = "Erro ao criar arquivo temporário: \(error.localizedDescription)"
            self.mensagemErro = msg
            self.estado = .erro(msg)
            return
        }

        let task = s.dataTask(with: request)
        self.dataTask = task
        self.estado = .baixando(progresso: progresso, velocidade: 0, tempoRestante: nil)
        task.resume()
    }

    public func pausar() {
        dataTask?.cancel()
        dataTask = nil
        try? fileHandle?.close()
        fileHandle = nil
        session?.invalidateAndCancel()
        session = nil
        self.velocidadeBytesPorSegundo = 0
        self.tempoRestanteSegundos = nil
        self.estado = .pausado(progresso: progresso)
    }

    public func cancelar() {
        dataTask?.cancel()
        dataTask = nil
        try? fileHandle?.close()
        fileHandle = nil
        session?.invalidateAndCancel()
        session = nil
        try? FileManager.default.removeItem(at: arquivoPart)
        self.bytesRecebidos = 0
        self.progresso = 0.0
        self.velocidadeBytesPorSegundo = 0
        self.tempoRestanteSegundos = nil
        self.mensagemErro = nil
        self.estado = .parado
    }

    public func apagarInstalado() throws {
        if estaInstalado {
            try FileManager.default.removeItem(at: arquivoFinal)
        }
        cancelar()
    }

    // MARK: - URLSessionDataDelegate

    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 416 {
                // Range inválido (arquivo já completo ou servidor rejeitou Range): recomeça do 0
                try? fileHandle?.truncate(atOffset: 0)
                bytesRecebidos = 0
            } else if http.statusCode == 200 && bytesRecebidos > 0 {
                // Servidor não suportou Range e enviou 200 OK do início: trunca arquivo
                try? fileHandle?.truncate(atOffset: 0)
                bytesRecebidos = 0
            } else if http.statusCode >= 400 {
                let msg = "Falha no servidor ao baixar o modelo (HTTP \(http.statusCode))."
                DispatchQueue.main.async {
                    self.mensagemErro = msg
                    self.estado = .erro(msg)
                }
                completionHandler(.cancel)
                return
            }

            if let totalStr = http.value(forHTTPHeaderField: "Content-Length"),
               let length = Int64(totalStr) {
                if http.statusCode == 206 {
                    tamanhoTotal = bytesRecebidos + length
                } else if http.statusCode == 200 {
                    tamanhoTotal = length
                }
            }
        }
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let fh = fileHandle else { return }
        fh.write(data)
        bytesRecebidos += Int64(data.count)
        bytesUltimoIntervalo += Int64(data.count)

        let agora = Date()
        let dt = agora.timeIntervalSince(ultimoTimestamp)
        if dt >= 0.5 {
            let vel = Double(bytesUltimoIntervalo) / dt
            self.velocidadeBytesPorSegundo = vel
            self.bytesUltimoIntervalo = 0
            self.ultimoTimestamp = agora

            let total = max(1, tamanhoTotal)
            let prog = min(1.0, Double(bytesRecebidos) / Double(total))
            self.progresso = prog

            let restantesBytes = max(0, total - bytesRecebidos)
            if vel > 0 {
                self.tempoRestanteSegundos = Double(restantesBytes) / vel
            }

            DispatchQueue.main.async {
                self.estado = .baixando(
                    progresso: prog,
                    velocidade: vel,
                    tempoRestante: self.tempoRestanteSegundos
                )
            }
        }
    }

    private func atualizarNoMain(_ bloco: @escaping () -> Void) {
        if Thread.isMainThread {
            bloco()
        } else {
            DispatchQueue.main.async(execute: bloco)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        try? fileHandle?.close()
        fileHandle = nil

        if let error = error as NSError? {
            if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                // Cancelamento ou pausa intencional; estado já tratado
                return
            }
            let msg = "Erro de conexão: \(error.localizedDescription)"
            atualizarNoMain {
                self.mensagemErro = msg
                self.estado = .erro(msg)
            }
            return
        }

        // Download concluído: executa validação estrita de SHA-256
        atualizarNoMain {
            self.estado = .verificandoHash
        }

        let hashEsperado = hashEsperadoOverride ?? modelo.sha256
        let hashCorreto = VerificadorHash.verificarSHA256(arquivoURL: arquivoPart, hashEsperado: hashEsperado)

        if hashCorreto {
            do {
                if FileManager.default.fileExists(atPath: arquivoFinal.path) {
                    try FileManager.default.removeItem(at: arquivoFinal)
                }
                try FileManager.default.moveItem(at: arquivoPart, to: arquivoFinal)
                atualizarNoMain {
                    self.progresso = 1.0
                    self.estado = .concluido(self.arquivoFinal)
                }
            } catch {
                let msg = "Falha ao salvar arquivo final: \(error.localizedDescription)"
                atualizarNoMain {
                    self.mensagemErro = msg
                    self.estado = .erro(msg)
                }
            }
        } else {
            // Arquivo corrompido: apagado e reportado
            try? FileManager.default.removeItem(at: arquivoPart)
            let msg = "Arquivo corrompido: o checksum SHA-256 não confere com o valor esperado."
            atualizarNoMain {
                self.mensagemErro = msg
                self.estado = .erro(msg)
            }
        }
    }
}
