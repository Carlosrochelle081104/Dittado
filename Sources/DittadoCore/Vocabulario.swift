import Foundation

/// Representa um termo do vocabulário personalizado com suas variantes fonéticas e apelidos.
public struct ItemVocabulario: Codable, Equatable, Hashable, Identifiable {
    public var id: String { termo }
    public var termo: String
    public var variantes: [String]

    public init(termo: String, variantes: [String] = []) {
        self.termo = termo
        self.variantes = variantes
    }
}

/// Gerenciador de Vocabulário Personalizado.
/// Armazena nomes próprios, siglas e termos técnicos que devem ser reconhecidos
/// pelo Whisper (initial_prompt) e preservados estritamente pelo LLM.
public final class GerenciadorVocabulario {
    public static let shared = GerenciadorVocabulario()

    public static let itensPadrao: [ItemVocabulario] = [
        ItemVocabulario(termo: "Claude Code", variantes: ["Cloud Code", "Clod Code"]),
        ItemVocabulario(termo: "Claude", variantes: ["Cloud", "Clod", "Clóde", "Claudi"]),
        ItemVocabulario(termo: "ChatGPT", variantes: ["Chat GPT", "Chat-GPT", "XatGPT"]),
        ItemVocabulario(termo: "WhatsApp", variantes: ["Whattsapp", "Whatapp"]),
        ItemVocabulario(termo: "Antigravity", variantes: ["AntiGravity", "Anti Gravity", "Antigraviti", "Anti-Gravity"]),
        ItemVocabulario(termo: "Dittado", variantes: ["Ditado"]),
        ItemVocabulario(termo: "Google Chrome", variantes: ["Crome"]),
        ItemVocabulario(termo: "prompt", variantes: ["pront", "pronte"])
    ]

    public static var termosPadrao: [String] {
        itensPadrao.map(\.termo)
    }

    private let userDefaults: UserDefaults
    private let chave: String
    private let chaveItens: String
    private let lock = NSLock()

    public init(userDefaults: UserDefaults = .standard, chave: String = "vocabularioPersonalizado") {
        self.userDefaults = userDefaults
        self.chave = chave
        self.chaveItens = "\(chave)_itens_v2"
    }

    /// Lista completa de itens estruturados (termo + variantes).
    public var itens: [ItemVocabulario] {
        get {
            lock.lock(); defer { lock.unlock() }
            if let data = userDefaults.data(forKey: chaveItens),
               let dec = try? JSONDecoder().decode([ItemVocabulario].self, from: data),
               !dec.isEmpty {
                return dec
            }
            // Migração de versões antigas que salvavam só array de strings
            if let array = userDefaults.stringArray(forKey: chave), !array.isEmpty {
                var migrados: [ItemVocabulario] = []
                for t in array {
                    if let padrao = Self.itensPadrao.first(where: { $0.termo.caseInsensitiveCompare(t) == .orderedSame }) {
                        migrados.append(padrao)
                    } else {
                        migrados.append(ItemVocabulario(termo: t))
                    }
                }
                return migrados
            }
            return Self.itensPadrao
        }
        set {
            lock.lock(); defer { lock.unlock() }
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: chaveItens)
            }
            // Atualiza também a chave legada de strings
            userDefaults.set(newValue.map(\.termo), forKey: chave)
        }
    }

    /// Lista de termos armazenados (ordem: mais recentes no início).
    public var termos: [String] {
        get { itens.map(\.termo) }
        set {
            let atuais = itens
            // Atualiza preservando variantes já existentes
            var novosItens: [ItemVocabulario] = []
            for t in newValue {
                if let existente = atuais.first(where: { $0.termo.caseInsensitiveCompare(t) == .orderedSame }) {
                    novosItens.append(existente)
                } else if let padrao = Self.itensPadrao.first(where: { $0.termo.caseInsensitiveCompare(t) == .orderedSame }) {
                    novosItens.append(padrao)
                } else {
                    novosItens.append(ItemVocabulario(termo: t))
                }
            }
            itens = novosItens
        }
    }

    /// Adiciona termo novo com variantes opcionais. Rejeita vazios e duplicados (ignorando caixa).
    @discardableResult
    public func adicionar(_ termo: String, variantes: [String] = []) -> Bool {
        let t = termo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }

        var atuais = itens
        if atuais.contains(where: { $0.termo.caseInsensitiveCompare(t) == .orderedSame }) {
            return false // Duplicado rejeitado
        }

        // Sugere variantes padrão caso seja um termo conhecido
        var varsFinal = variantes
        if varsFinal.isEmpty, let padrao = Self.itensPadrao.first(where: { $0.termo.caseInsensitiveCompare(t) == .orderedSame }) {
            varsFinal = padrao.variantes
        }

        let novoItem = ItemVocabulario(termo: t, variantes: varsFinal)
        atuais.insert(novoItem, at: 0)
        itens = atuais
        return true
    }

    /// Adiciona uma variante a um termo existente.
    @discardableResult
    public func adicionarVariante(aoTermo termo: String, variante: String) -> Bool {
        let v = variante.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return false }

        var atuais = itens
        guard let idx = atuais.firstIndex(where: { $0.termo.caseInsensitiveCompare(termo) == .orderedSame }) else {
            return false
        }

        if atuais[idx].variantes.contains(where: { $0.caseInsensitiveCompare(v) == .orderedSame }) {
            return false // Já possui esta variante
        }

        atuais[idx].variantes.append(v)
        itens = atuais
        return true
    }

    /// Remove variante de um termo pelo índice.
    @discardableResult
    public func removerVariante(doTermo termo: String, noIndice indice: Int) -> Bool {
        var atuais = itens
        guard let idx = atuais.firstIndex(where: { $0.termo.caseInsensitiveCompare(termo) == .orderedSame }) else {
            return false
        }
        guard indice >= 0 && indice < atuais[idx].variantes.count else { return false }
        atuais[idx].variantes.remove(at: indice)
        itens = atuais
        return true
    }

    /// Remove variante de um termo pelo nome.
    @discardableResult
    public func removerVariante(doTermo termo: String, variante: String) -> Bool {
        var atuais = itens
        guard let idx = atuais.firstIndex(where: { $0.termo.caseInsensitiveCompare(termo) == .orderedSame }) else {
            return false
        }
        guard let varIdx = atuais[idx].variantes.firstIndex(where: { $0.caseInsensitiveCompare(variante) == .orderedSame }) else {
            return false
        }
        atuais[idx].variantes.remove(at: varIdx)
        itens = atuais
        return true
    }

    /// Define a lista completa de variantes para um termo.
    @discardableResult
    public func definirVariantes(doTermo termo: String, variantes: [String]) -> Bool {
        var atuais = itens
        guard let idx = atuais.firstIndex(where: { $0.termo.caseInsensitiveCompare(termo) == .orderedSame }) else {
            return false
        }
        let limpas = variantes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        atuais[idx].variantes = limpas
        itens = atuais
        return true
    }

    /// Remove termo pelo índice.
    @discardableResult
    public func remover(noIndice indice: Int) -> Bool {
        var atuais = itens
        guard indice >= 0 && indice < atuais.count else { return false }
        atuais.remove(at: indice)
        itens = atuais
        return true
    }

    /// Remove termo pelo valor (ignorando maiúsculas/minúsculas).
    @discardableResult
    public func remover(_ termo: String) -> Bool {
        var atuais = itens
        guard let idx = atuais.firstIndex(where: { $0.termo.caseInsensitiveCompare(termo) == .orderedSame }) else { return false }
        atuais.remove(at: idx)
        itens = atuais
        return true
    }

    /// Edita termo existente. Rejeita novo valor vazio ou duplicado com outro termo.
    @discardableResult
    public func editar(noIndice indice: Int, novoTermo: String) -> Bool {
        let t = novoTermo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }

        var atuais = itens
        guard indice >= 0 && indice < atuais.count else { return false }

        for i in 0..<atuais.count where i != indice {
            if atuais[i].termo.caseInsensitiveCompare(t) == .orderedSame {
                return false
            }
        }
        atuais[indice].termo = t
        itens = atuais
        return true
    }

    /// Restaura os itens e variantes padrão.
    public func resetarPadroes() {
        itens = Self.itensPadrao
    }

    /// Formata a lista para o `initial_prompt` do Whisper em formato de frase natural com limite de ~224 tokens.
    /// Em português e termos técnicos/nomes próprios, 1 token equivale a ~3.5 caracteres (~780 caracteres totais).
    public func formatarParaWhisper(limiteTokens: Int = 224) -> (prompt: String, excedeuLimite: Bool) {
        let lista = termos
        var termosIncluidos: [String] = []
        let prefixo = "Conversa sobre "
        var caracteresTotal = prefixo.count
        var excedeu = false

        let maxCaracteres = Int(Double(limiteTokens) * 3.5)

        for t in lista {
            let custo = t.count + 2 // ", "
            if caracteresTotal + custo <= maxCaracteres {
                termosIncluidos.append(t)
                caracteresTotal += custo
            } else {
                excedeu = true
            }
        }

        let promptFinal = prefixo + termosIncluidos.joined(separator: ", ") + "."
        return (promptFinal, excedeu)
    }

    /// Formata a lista para injeção no prompt de sistema do LLM,
    /// instruindo o modelo a nunca alterar a grafia desses termos e variantes.
    public func formatarParaLLM() -> String {
        let lista = itens
        guard !lista.isEmpty else { return "" }
        var linhas: [String] = []
        for item in lista {
            if item.variantes.isEmpty {
                linhas.append("- \(item.termo)")
            } else {
                linhas.append("- \(item.termo) (grafias/variantes possíveis: \(item.variantes.joined(separator: ", ")))")
            }
        }
        return "\n\nTERMOS DO VOCABULÁRIO E NOMES PRÓPRIOS (Mantenha rigorosamente esta grafia e NUNCA troque ou altere):\n" + linhas.joined(separator: "\n")
    }
}

// MARK: - Corretor Determinístico de Vocabulário

/// Realiza correções determinísticas em camadas (variantes exatas + similaridade fonética conservadora).
public enum CorretorVocabulario {

    /// Palavras comuns do português que NUNCA devem ser substituídas por aproximação fonética.
    private static let palavrasComunsPortugues: Set<String> = [
        "a", "o", "as", "os", "um", "uma", "uns", "umas",
        "de", "do", "da", "dos", "das", "em", "no", "na", "nos", "nas",
        "por", "para", "com", "sem", "sob", "sobre", "entre", "até",
        "e", "ou", "mas", "porém", "contudo", "todavia", "que", "se", "como",
        "carro", "casa", "nuvem", "dia", "tempo", "ano", "mês", "hora", "vida", "homem",
        "mulher", "coisa", "trabalho", "parte", "lugar", "ponto", "governo", "caso",
        "abrir", "fechar", "bater", "bateu", "fazer", "fez", "feito", "ter", "tem", "teve",
        "ver", "viu", "visto", "ir", "foi", "vir", "veio", "estar", "está", "estava",
        "ser", "era", "sido", "falar", "falou", "dizer", "disse", "dito", "poder", "pode",
        "saber", "soube", "querer", "quis", "dar", "deu", "ficar", "ficou", "passar", "passou",
        "bom", "boa", "bons", "boas", "mau", "má", "grande", "pequeno", "novo", "nova",
        "velho", "velha", "primeiro", "segundo", "terceiro", "tudo", "nada", "muito", "pouco"
    ]

    /// Corrige palavras do texto baseando-se no vocabulário cadastrado e suas variantes.
    public static func corrigir(_ texto: String, itens: [ItemVocabulario] = GerenciadorVocabulario.shared.itens) -> String {
        guard !texto.isEmpty && !itens.isEmpty else { return texto }

        var resultado = texto

        // 1. CAMADA 1: Substituição de Variantes e Apelidos Cadastrados (Expressões maiores primeiro)
        struct RegraVariante {
            let variante: String
            let termoCorreto: String
        }

        var regras: [RegraVariante] = []
        for item in itens {
            for v in item.variantes {
                regras.append(RegraVariante(variante: v, termoCorreto: item.termo))
            }
        }

        // Ordena por tamanho decrescente para priorizar expressões compostas (ex: "Cloud Code" antes de "Cloud")
        regras.sort { $0.variante.count > $1.variante.count }

        for r in regras {
            resultado = substituirVarianteExata(noTexto: resultado, variante: r.variante, por: r.termoCorreto)
        }

        // 2. CAMADA 2: Correção de termos compostos cadastrados grafados com espaços ou variações
        // (ex: "Anti Gravity" -> "Antigravity", "Anti-Gravity" -> "Antigravity")
        for item in itens {
            if item.termo.contains(" ") {
                resultado = substituirExpressao(noTexto: resultado, expressao: item.termo, por: item.termo)
            }
        }

        // 3. CAMADA 3: Similaridade Fonética Conservadora (evitando palavras comuns)
        resultado = aplicarFuzzyConservador(noTexto: resultado, itens: itens)

        return resultado
    }

    /// Substitui variante com proteção contra falsos positivos específicos de contexto (ex: "nuvem cloud").
    private static func substituirVarianteExata(noTexto texto: String, variante: String, por termoCorreto: String) -> String {
        // Proteção especial solicitada: "a nuvem está cloud" não deve trocar para "Claude"
        if variante.caseInsensitiveCompare("Cloud") == .orderedSame {
            let padraoNuvem = #"(?i)\bnuvem\s+(?:est[áa]\s+)?cloud\b"#
            if texto.range(of: padraoNuvem, options: .regularExpression) != nil {
                // Se a frase expressar explicitamente "nuvem cloud" ou "nuvem está cloud", preserva
                return texto
            }
        }

        let esc = NSRegularExpression.escapedPattern(for: variante)
        let padrao = "(?i)\\b\(esc)\\b"
        guard let regex = try? NSRegularExpression(pattern: padrao, options: []) else { return texto }

        let ns = texto as NSString
        let matches = regex.matches(in: texto, options: [], range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return texto }

        var t = texto
        for match in matches.reversed() {
            let trecho = (t as NSString).substring(with: match.range)
            // Se já estiver com a grafia exata, pula
            if trecho == termoCorreto { continue }
            t = (t as NSString).replacingCharacters(in: match.range, with: termoCorreto)
        }
        return t
    }

    private static func substituirExpressao(noTexto texto: String, expressao: String, por termoCorreto: String) -> String {
        let partes = expressao.split { $0.isWhitespace || $0 == "-" }.map { NSRegularExpression.escapedPattern(for: String($0)) }
        guard !partes.isEmpty else { return texto }
        let padrao = "(?i)\\b" + partes.joined(separator: "[\\s\\-]+") + "\\b"
        guard let regex = try? NSRegularExpression(pattern: padrao, options: []) else { return texto }

        let ns = texto as NSString
        let matches = regex.matches(in: texto, options: [], range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return texto }

        var t = texto
        for match in matches.reversed() {
            let trecho = (t as NSString).substring(with: match.range)
            if trecho == termoCorreto { continue }
            t = (t as NSString).replacingCharacters(in: match.range, with: termoCorreto)
        }
        return t
    }

    /// Aplica fuzzy matching conservador palavra a palavra.
    private static func aplicarFuzzyConservador(noTexto texto: String, itens: [ItemVocabulario]) -> String {
        let tokens = texto.components(separatedBy: .whitespacesAndNewlines)
        var substituicoes: [(range: Range<String.Index>, substituto: String)] = []

        // Termos candidatos simples (1 palavra)
        let termosAlvo = itens.map(\.termo).filter { !$0.contains(" ") }

        var searchIndex = texto.startIndex
        for token in tokens {
            let palavraLimpa = token.trimmingCharacters(in: CharacterSet.punctuationCharacters)
            guard palavraLimpa.count >= 3 else { continue }

            // NUNCA altera palavras comuns do português
            if palavrasComunsPortugues.contains(palavraLimpa.lowercased()) {
                continue
            }

            // Procura o termo mais próximo
            for alvo in termosAlvo {
                if palavraLimpa.caseInsensitiveCompare(alvo) == .orderedSame {
                    // Já é o termo com diferença apenas de caixa
                    if palavraLimpa != alvo, let r = texto.range(of: token, range: searchIndex..<texto.endIndex) {
                        let substituido = token.replacingOccurrences(of: palavraLimpa, with: alvo)
                        substituicoes.append((r, substituido))
                        searchIndex = r.upperBound
                    }
                    break
                }

                // Distância de edição normalizada
                let dist = distanciaLevenshtein(palavraLimpa.lowercased(), alvo.lowercased())
                let maxLen = max(palavraLimpa.count, alvo.count)
                let taxaErro = Double(dist) / Double(maxLen)

                // Limiar conservador (máximo 1 erro para 4 letras, 2 erros para 8 letras)
                if taxaErro <= 0.22 && dist <= 2 {
                    if let r = texto.range(of: token, range: searchIndex..<texto.endIndex) {
                        let substituido = token.replacingOccurrences(of: palavraLimpa, with: alvo)
                        substituicoes.append((r, substituido))
                        searchIndex = r.upperBound
                        break
                    }
                }
            }
        }

        var res = texto
        for s in substituicoes.reversed() {
            res.replaceSubrange(s.range, with: s.substituto)
        }
        return res
    }

    /// Distância de Levenshtein entre duas strings.
    public static func distanciaLevenshtein(_ a: String, _ b: String) -> Int {
        let aArr = Array(a)
        let bArr = Array(b)
        let m = aArr.count
        let n = bArr.count
        guard m > 0 else { return n }
        guard n > 0 else { return m }

        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                if aArr[i - 1] == bArr[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = min(
                        dp[i - 1][j] + 1,     // deleção
                        dp[i][j - 1] + 1,     // inserção
                        dp[i - 1][j - 1] + 1 // substituição
                    )
                }
            }
        }
        return dp[m][n]
    }
}
