import Foundation

/// Parser determinístico geral de enumerações (2 a 20 itens).
public enum ParserEnumeracao {

    private static let ordinaisMapeados: [String: Int] = [
        "primeiro": 1, "primeira": 1, "1º": 1, "1ª": 1, "1o": 1, "1a": 1,
        "segundo": 2, "segunda": 2, "2º": 2, "2ª": 2, "2o": 2, "2a": 2,
        "terceiro": 3, "terceira": 3, "3º": 3, "3ª": 3, "3o": 3, "3a": 3,
        "quarto": 4, "quarta": 4, "4º": 4, "4ª": 4, "4o": 4, "4a": 4,
        "quinto": 5, "quinta": 5, "5º": 5, "5ª": 5, "5o": 5, "5a": 5,
        "sexto": 6, "sexta": 6, "6º": 6, "6ª": 6, "6o": 6, "6a": 6,
        "sétimo": 7, "sétima": 7, "setimo": 7, "setima": 7, "7º": 7, "7ª": 7,
        "oitavo": 8, "oitava": 8, "8º": 8, "8ª": 8, "8o": 8, "8a": 8,
        "nono": 9, "nona": 9, "9º": 9, "9ª": 9, "9o": 9, "9a": 9,
        "décimo": 10, "décima": 10, "decimo": 10, "decima": 10, "10º": 10, "10ª": 10,
        "décimo primeiro": 11, "décima primeira": 11, "11º": 11, "11ª": 11,
        "décimo segundo": 12, "décima segunda": 12, "12º": 12, "12ª": 12,
        "décimo terceiro": 13, "décima terceira": 13, "13º": 13, "13ª": 13,
        "décimo quarto": 14, "décima quarta": 14, "14º": 14, "14ª": 14,
        "décimo quinto": 15, "décima quinta": 15, "15º": 15, "15ª": 15,
        "décimo sexto": 16, "décima sexta": 16, "16º": 16, "16ª": 16,
        "décimo sétimo": 17, "décima sétima": 17, "17º": 17, "17ª": 17,
        "décimo oitavo": 18, "décima oitava": 18, "18º": 18, "18ª": 18,
        "décimo nono": 19, "décima nona": 19, "19º": 19, "19ª": 19,
        "vigésimo": 20, "vigésima": 20, "vigesimo": 20, "vigesima": 20, "20º": 20, "20ª": 20
    ]

    private static let cardinaisMapeados: [String: Int] = [
        "um": 1, "uma": 1,
        "dois": 2, "duas": 2,
        "três": 3, "tres": 3,
        "quatro": 4,
        "cinco": 5,
        "seis": 6,
        "sete": 7,
        "oito": 8,
        "nove": 9,
        "dez": 10
    ]

    /// Substantivos que, quando precedidos imediatamente por um ordinal, caracterizam
    /// sintagmas nominais comuns (ex: "primeiro passo", "segundo lugar", "primeiro tempo")
    /// e NÃO marcadores de enumeração.
    private static let substantivosModificados: Set<String> = [
        "passo", "passos",
        "lugar", "lugares",
        "semestre", "semestres",
        "trimestre", "trimestres",
        "bimestre", "bimestres",
        "mundo", "mundos",
        "grau", "graus",
        "turno", "turnos",
        "tempo", "tempos",
        "plano", "planos",
        "capítulo", "capitulo", "capítulos", "capitulos",
        "andar", "andares",
        "dia", "dias",
        "ano", "anos",
        "mês", "mes", "meses",
        "mandato", "mandatos",
        "momento", "momentos",
        "fase", "fases",
        "etapa", "etapas",
        "parte", "partes",
        "vez", "vezes",
        "rodada", "rodadas",
        "instância", "instancia", "instâncias", "instancias",
        "andar", "andares",
        "episódio", "episodio", "episódios", "episodios",
        "versão", "versao", "versões", "versoes",
        "período", "periodo", "períodos", "periodos",
        "nível", "nivel", "níveis", "niveis",
        "bloco", "blocos"
    ]

    private struct MarcadorDetectado {
        let indice: Int
        let rangeMarcador: NSRange
        let fimMarcador: Int
    }

    /// Formata uma enumeração em lista numerada se detectada sequência válida.
    public static func formatarSeHouver(_ texto: String) -> String {
        let t = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return texto }

        // Se já contiver lista numerada formatada no início da linha, retorna
        if t.range(of: #"(?m)^\s*1\.\s+"#, options: .regularExpression) != nil {
            return texto
        }

        // Tenta sequência ordinal (primeiro..vigésimo, item 1..20)
        if let marcadores = extrairSequenciaOrdinais(t), marcadores.count >= 2 {
            return formatarComMarcadores(t, marcadores: marcadores)
        }

        // Tenta sequência cardinal (um, dois, três... requer ao menos 3 marcadores consecutivos)
        if let marcadoresCardinais = extrairSequenciaCardinais(t), marcadoresCardinais.count >= 3 {
            return formatarComMarcadores(t, marcadores: marcadoresCardinais)
        }

        return texto
    }

    // MARK: - Extração de Sequências

    private static func extrairSequenciaOrdinais(_ texto: String) -> [MarcadorDetectado]? {
        let ns = texto as NSString

        // Regex para marcadores ordinais ou itens:
        // Suporta: "primeiro", "e segundo", "item 1", "número 2", "1º", "por último"
        let padrao = #"(?i)(?:^|(?<=[\s,.;:!?\n]))(?:(e\s+)?(por\s+[úu]ltimo|por\s+fim|finalmente)|(e\s+)?(?:item|n[úu]mero|nº|ponto)\s+(\d+|um|uma|dois|duas|tr[êe]s|tres|quatro|cinco|seis|sete|oito|nove|dez)|(e\s+)?(\d+)[ºªoa]|(e\s+)?(d[ée]cim[oa]\s+(?:primeir[oa]|segund[oa]|terceir[oa]|quart[oa]|quint[oa]|sext[oa]|s[ée]tim[oa]|setim[oa]|oitav[oa]|non[oa])|primeir[oa]|segund[oa]|terceir[oa]|quart[oa]|quint[oa]|sext[oa]|s[ée]tim[oa]|setim[oa]|oitav[oa]|non[oa]|d[ée]cim[oa]|decim[oa]|vig[ée]sim[oa]|vigesim[oa]))(?:\s*[:,\-.]\s*|\s+)"#

        guard let regex = try? NSRegularExpression(pattern: padrao, options: []) else { return nil }
        let matches = regex.matches(in: texto, options: [], range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return nil }

        // Filtra matches inválidos:
        // 1. Precedidos por artigo ou preposição (ex: "o segundo", "um segundo", "no primeiro")
        // 2. Seguidos imediatamente por substantivos modificados (ex: "primeiro passo", "segundo lugar")
        var matchesValidos: [NSTextCheckingResult] = []
        for m in matches {
            let prefixoRange = NSRange(location: 0, length: m.range.location)
            let prefixo = ns.substring(with: prefixoRange)
            let padraoArtigoPreposicao = #"(?i)\b(?:o|a|os|as|um|uma|uns|umas|do|da|dos|das|no|na|nos|nas|ao|à|aos|às|pelo|pela|pelos|pelas|num|numa|nuns|numas|deste|desta|desse|dessa|daquele|daquela|neste|nesta|nesse|nessa|naquele|naquela|este|esta|esse|essa|aquele|aquela|cada|outro|outra)\s+(?:e\s+)?$"#
            if prefixo.range(of: padraoArtigoPreposicao, options: .regularExpression) != nil {
                continue
            }

            let posDepois = m.range.location + m.range.length
            if posDepois < ns.length {
                let resto = ns.substring(with: NSRange(location: posDepois, length: ns.length - posDepois))
                let palavrasSeguintes = resto.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n,.:;-"))
                                             .components(separatedBy: CharacterSet.alphanumerics.inverted)
                                             .filter { !$0.isEmpty }
                if let primeiraPalavra = palavrasSeguintes.first?.lowercased() {
                    if substantivosModificados.contains(primeiraPalavra) {
                        continue
                    }
                }
            }

            matchesValidos.append(m)
        }

        guard !matchesValidos.isEmpty else { return nil }

        // Localiza candidato a item 1
        var melhorSequencia: [MarcadorDetectado] = []

        for startIndex in 0..<matchesValidos.count {
            let m1 = matchesValidos[startIndex]
            let textoM1 = ns.substring(with: m1.range).lowercased()
            guard let idx1 = identificarIndiceOrdinal(textoM1), idx1 == 1 else { continue }

            var sequenciaAtual: [MarcadorDetectado] = [
                MarcadorDetectado(indice: 1, rangeMarcador: m1.range, fimMarcador: m1.range.location + m1.range.length)
            ]
            var proximoEsperado = 2

            for i in (startIndex + 1)..<matchesValidos.count {
                let m = matchesValidos[i]
                let textoM = ns.substring(with: m.range).lowercased()

                if let idx = identificarIndiceOrdinal(textoM) {
                    if idx == proximoEsperado {
                        sequenciaAtual.append(MarcadorDetectado(indice: idx, rangeMarcador: m.range, fimMarcador: m.range.location + m.range.length))
                        proximoEsperado += 1
                        continue
                    }
                }

                // Permite 'por último' ou 'finalmente' como marcador do último item se já temos ao menos 2 itens
                if proximoEsperado >= 3 && (textoM.contains("último") || textoM.contains("ultimo") || textoM.contains("fim") || textoM.contains("finalmente")) {
                    sequenciaAtual.append(MarcadorDetectado(indice: proximoEsperado, rangeMarcador: m.range, fimMarcador: m.range.location + m.range.length))
                    break
                }
            }

            if sequenciaAtual.count > melhorSequencia.count {
                melhorSequencia = sequenciaAtual
            }
        }

        return melhorSequencia.count >= 2 ? melhorSequencia : nil
    }

    private static func identificarIndiceOrdinal(_ raw: String) -> Int? {
        let t = raw.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n,.:;-"))
                   .lowercased()
        let semE = t.hasPrefix("e ") ? String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces) : t

        // Caso: "item 1", "item um", "número 2"
        let padraoItem = #"(?i)^(?:item|n[úu]mero|nº|ponto)\s+(\d+|um|uma|dois|duas|tr[êe]s|tres|quatro|cinco|seis|sete|oito|nove|dez)"#
        if let regexItem = try? NSRegularExpression(pattern: padraoItem, options: []) {
            let ns = semE as NSString
            if let match = regexItem.firstMatch(in: semE, options: [], range: NSRange(location: 0, length: ns.length)) {
                let val = ns.substring(with: match.range(at: 1))
                if let n = Int(val), n >= 1 && n <= 20 { return n }
                if let n = cardinaisMapeados[val] { return n }
            }
        }

        // Caso: "1º", "2ª", "3o"
        let padraoNumOrdinal = #"^(\d+)[ºªoa]$"#
        if let regexNum = try? NSRegularExpression(pattern: padraoNumOrdinal, options: []) {
            let ns = semE as NSString
            if let match = regexNum.firstMatch(in: semE, options: [], range: NSRange(location: 0, length: ns.length)) {
                let val = ns.substring(with: match.range(at: 1))
                if let n = Int(val), n >= 1 && n <= 20 { return n }
            }
        }

        // Caso palavras ordinais: "primeiro", "décimo segundo", etc.
        for (palavra, valor) in ordinaisMapeados {
            if semE == palavra || semE.hasPrefix(palavra) {
                return valor
            }
        }

        return nil
    }

    private static func extrairSequenciaCardinais(_ texto: String) -> [MarcadorDetectado]? {
        let ns = texto as NSString
        let padrao = #"(?i)(?:^|(?<=[\s,.;:!?\n]))(e\s+)?(um|uma|dois|duas|tr[êe]s|tres|quatro|cinco|seis|sete|oito|nove|dez)(?:\s*[:,\-.]\s*|\s+)"#

        guard let regex = try? NSRegularExpression(pattern: padrao, options: []) else { return nil }
        let matches = regex.matches(in: texto, options: [], range: NSRange(location: 0, length: ns.length))
        guard matches.count >= 3 else { return nil }

        // Filtra matches inválidos (artigos/preposições antes ou unidades/substantivos depois)
        var matchesValidos: [NSTextCheckingResult] = []
        let unidadesOuMedidas: Set<String> = [
            "itens", "item", "coisas", "coisa", "reais", "dólares", "dolares", "euros",
            "horas", "hora", "minutos", "minuto", "segundos", "segundo", "dias", "dia",
            "meses", "mês", "mes", "anos", "ano", "quilos", "quilo", "kg", "gramas",
            "metros", "metro", "litros", "litro", "vezes", "vez", "pontos", "ponto",
            "pessoas", "pessoa", "páginas", "paginas", "linhas", "linha", "palavras"
        ]

        for m in matches {
            let prefixoRange = NSRange(location: 0, length: m.range.location)
            let prefixo = ns.substring(with: prefixoRange)
            let padraoArtigoPreposicao = #"(?i)\b(?:o|a|os|as|um|uma|uns|umas|do|da|dos|das|no|na|nos|nas|ao|à|aos|às|pelo|pela|pelos|pelas|num|numa|nuns|numas|deste|desta|desse|dessa|daquele|daquela|neste|nesta|nesse|nessa|naquele|naquela|este|esta|esse|essa|aquele|aquela|cada|outro|outra)\s+(?:e\s+)?$"#
            if prefixo.range(of: padraoArtigoPreposicao, options: .regularExpression) != nil {
                continue
            }

            let posDepois = m.range.location + m.range.length
            if posDepois < ns.length {
                let resto = ns.substring(with: NSRange(location: posDepois, length: ns.length - posDepois))
                let palavrasSeguintes = resto.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n,.:;-"))
                                             .components(separatedBy: CharacterSet.alphanumerics.inverted)
                                             .filter { !$0.isEmpty }
                if let primeiraPalavra = palavrasSeguintes.first?.lowercased() {
                    if substantivosModificados.contains(primeiraPalavra) || unidadesOuMedidas.contains(primeiraPalavra) {
                        continue
                    }
                }
            }

            matchesValidos.append(m)
        }

        guard matchesValidos.count >= 3 else { return nil }

        for startIndex in 0..<matchesValidos.count {
            let m1 = matchesValidos[startIndex]
            let t1 = ns.substring(with: m1.range).lowercased()
            guard let idx1 = identificarIndiceCardinal(t1), idx1 == 1 else { continue }

            var sequencia: [MarcadorDetectado] = [
                MarcadorDetectado(indice: 1, rangeMarcador: m1.range, fimMarcador: m1.range.location + m1.range.length)
            ]
            var esperado = 2

            for i in (startIndex + 1)..<matchesValidos.count {
                let m = matchesValidos[i]
                let tm = ns.substring(with: m.range).lowercased()
                if let idx = identificarIndiceCardinal(tm), idx == esperado {
                    // Garante que haja texto entre o marcador anterior e este
                    let dist = m.range.location - sequencia.last!.fimMarcador
                    if dist >= 1 {
                        sequencia.append(MarcadorDetectado(indice: idx, rangeMarcador: m.range, fimMarcador: m.range.location + m.range.length))
                        esperado += 1
                    }
                }
            }

            if sequencia.count >= 3 {
                return sequencia
            }
        }

        return nil
    }

    private static func identificarIndiceCardinal(_ raw: String) -> Int? {
        let t = raw.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n,.:;-")).lowercased()
        let semE = t.hasPrefix("e ") ? String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces) : t
        return cardinaisMapeados[semE]
    }

    // MARK: - Formatação com os Marcadores Encontrados

    private static func formatarComMarcadores(_ texto: String, marcadores: [MarcadorDetectado]) -> String {
        let ns = texto as NSString

        // 1. Introdução antes do 1º marcador
        let introRaw = ns.substring(with: NSRange(location: 0, length: marcadores[0].rangeMarcador.location))
        var intro = introRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !intro.isEmpty {
            if intro.hasSuffix(".") {
                intro = String(intro.dropLast()).trimmingCharacters(in: .whitespaces) + ":"
            } else if !intro.hasSuffix(":") {
                intro += ":"
            }
            intro = capitalizarPrimeiraLetra(intro)
        }

        // 2. Itens intermediários
        var itensFormatados: [String] = []
        for i in 0..<(marcadores.count - 1) {
            let inicio = marcadores[i].fimMarcador
            let fim = marcadores[i + 1].rangeMarcador.location
            let itemRaw = ns.substring(with: NSRange(location: inicio, length: fim - inicio))
            let itemLimpo = limparItem(itemRaw)
            itensFormatados.append("\(i + 1). \(itemLimpo)")
        }

        // 3. Último item e possível pós-lista
        let inicioUltimo = marcadores[marcadores.count - 1].fimMarcador
        let restoRaw = ns.substring(with: NSRange(location: inicioUltimo, length: ns.length - inicioUltimo))

        var itemUltimoRaw = restoRaw
        var posListaRaw = ""

        // Corte no último item só se houver 'novo parágrafo', 'pula linha' ou quebra dupla
        let padraoQuebraFinal = #"(?i)\s*[,.]?\s*(?:(?:novo|outro)\s+par[áa]grafo|pula(?:r)?\s+linha)\s*[,.]?\s*|\n{2,}"#
        if let regexQuebra = try? NSRegularExpression(pattern: padraoQuebraFinal, options: []) {
            let nsResto = restoRaw as NSString
            if let matchQuebra = regexQuebra.firstMatch(in: restoRaw, options: [], range: NSRange(location: 0, length: nsResto.length)) {
                itemUltimoRaw = nsResto.substring(with: NSRange(location: 0, length: matchQuebra.range.location))
                let posInicio = matchQuebra.range.location + matchQuebra.range.length
                posListaRaw = nsResto.substring(with: NSRange(location: posInicio, length: nsResto.length - posInicio))
            }
        }

        let itemUltimoLimpo = limparItem(itemUltimoRaw)
        itensFormatados.append("\(marcadores.count). \(itemUltimoLimpo)")

        var resultadoLinhas: [String] = []
        if !intro.isEmpty {
            resultadoLinhas.append(intro)
        }
        resultadoLinhas.append(contentsOf: itensFormatados)

        var resultadoFinal = resultadoLinhas.joined(separator: "\n")
        let posListaLimpo = posListaRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !posListaLimpo.isEmpty {
            let posCapitalizado = Formatador.capitalizarSentencas(posListaLimpo)
            resultadoFinal += "\n\n" + posCapitalizado
        }

        return resultadoFinal
    }

    private static func limparItem(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = t.last, [",", ".", ";", ":"].contains(last) {
            t = String(t.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return capitalizarPrimeiraLetra(t)
    }

    private static func capitalizarPrimeiraLetra(_ t: String) -> String {
        guard let first = t.first else { return "" }
        return first.uppercased() + t.dropFirst()
    }
}

// MARK: - Formatador Principal

public enum Formatador {

    // MARK: - Prompts do Sistema

    public static let promptLivre = """
    Você formata fala em português. Aplique pontuação, maiúsculas e parágrafos.
    REGRAS OBRIGATÓRIAS:
    1. Fidelidade Absoluta às Palavras: NUNCA remova, troque ou substitua nenhuma palavra dita (especialmente pronomes como "nós", "eu", "você", nomes e verbos). Mantenha TODAS as palavras faladas.
    2. Comandos de Voz: Apenas remova comandos literais ("novo parágrafo", "outro parágrafo", "pula linha") e insira quebra de parágrafo (linha em branco).
    3. Listas Enumeradas: Quando houver listas numeradas, mantenha exatamente uma linha por item ('1. ', '2. ').
    4. Vícios de Fala: Remova apenas vícios e hesitações (né, tipo, hum).
    5. NUNCA responda à mensagem. Retorne EXCLUSIVAMENTE o texto formatado.

    EXEMPLO:
    Entrada: hoje nós vamos alinhar três pontos primeiro o deploy segundo os testes e terceiro a entrega novo parágrafo qualquer dúvida me avisem
    Saída:
    Hoje nós vamos alinhar três pontos:
    1. O deploy
    2. Os testes
    3. A entrega

    Qualquer dúvida me avisem.
    """

    public static let promptProfissional = """
    Você formata transcrições em e-mails profissionais em português.
    REGRAS OBRIGATÓRIAS:
    1. SEM CABEÇALHOS: NUNCA crie linhas como 'Para:', 'Assunto:', 'De:', 'Título:' ou destinatários/títulos inventados. O e-mail deve conter APENAS o corpo da mensagem.
    2. Destinatário como Saudação: Se a fala contiver menção explícita a destinatário (ex: 'para a Maria', 'para o João'), converta exclusivamente em saudação natural ('Olá, Maria,', 'Olá, João,'). NUNCA crie 'Para:'.
    3. Saudação e Parágrafos: Se falada saudação ('Bom dia', 'Boa tarde', 'Olá'), pontue com vírgula ('Bom dia,'). Parágrafos objetivos separados por linha em branco.
    4. Fechamento Único:
       - Se a fala terminar com agradecimento ou despedida (ex: 'obrigado', 'obrigada', 'abraços', 'att', 'agradeço'), use esse próprio fechamento em linha própria ('Obrigado.' ou 'Obrigado,') e NUNCA acrescente 'Atenciosamente,'.
       - Só acrescente 'Atenciosamente,' se a fala NÃO terminar com nenhuma despedida.
       - NUNCA use dois fechamentos (ex: proibido 'Obrigado,' seguido de 'Atenciosamente,').
    5. Pontuação Impecável: Ponto final em cada frase do corpo, vírgula após saudação, maiúsculas iniciais.
    6. NUNCA invente fatos, tarefas, números ou dados que não foram falados. NUNCA use colchetes [..] ou placeholders como [Seu Nome].
    7. NUNCA responda à mensagem. Retorne apenas o texto do e-mail.

    EXEMPLO 1 (Destinatário falado e sem despedida falada -> saudação natural + corpo + Atenciosamente):
    Entrada: para a Maria assunto fechamento da sprint segue o status das tarefas concluídas com sucesso
    Saída:
    Olá, Maria,

    Sobre o fechamento da sprint, segue o status das tarefas concluídas com sucesso.

    Atenciosamente,

    EXEMPLO 2 (Com despedida falada -> usa a própria despedida, sem Atenciosamente, sem cabeçalhos):
    Entrada: para o fornecedor assunto formalização da compra do item 345 bom dia segue o e-mail formalizando a compra do item 345 do orçamento 53 obrigado
    Saída:
    Bom dia,

    Segue o e-mail formalizando a compra do item 345 do orçamento 53.

    Obrigado.

    EXEMPLO 3 (Texto técnico direto):
    Entrada: venho por este e-mail retratar a flexão da viga V405 ela sofreu flexão de no máximo 5 mm não será necessário reforço estrutural obrigado
    Saída:
    Venho por este e-mail retratar a flexão da viga V405.

    Ela sofreu flexão de no máximo 5 mm, ou seja, não será necessário reforço estrutural.

    Obrigado.
    """

    // MARK: - Pipeline Principal

    public struct ResultadoFormatacao: Equatable, Sendable {
        public let texto: String
        public let duracaoParser: TimeInterval
        public let duracaoLLM: TimeInterval

        public init(texto: String, duracaoParser: TimeInterval, duracaoLLM: TimeInterval) {
            self.texto = texto
            self.duracaoParser = duracaoParser
            self.duracaoLLM = duracaoLLM
        }
    }

    public static func formatar(
        texto: String,
        modo: ModoDitado,
        motor: MotorLLM?
    ) async -> String {
        let res = await formatarComMetricas(texto: texto, modo: modo, motor: motor)
        return res.texto
    }

    public static func formatarComMetricas(
        texto: String,
        modo: ModoDitado,
        motor: MotorLLM?
    ) async -> ResultadoFormatacao {
        let t0 = Date()
        let textoLimpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textoLimpo.isEmpty else {
            return ResultadoFormatacao(texto: "", duracaoParser: 0, duracaoLLM: 0)
        }

        // 1. Pós-correção determinística de Vocabulário (Camada 1: variantes e fuzzy)
        let textoComVocabulario = CorretorVocabulario.corrigir(textoLimpo)

        // 2. Remoção de vícios de fala e pré-processamento de comandos de voz
        let textoPreprocessado = preProcessarComandosDeVoz(removerViciosDeFala(textoComVocabulario))
        let despedidaFalada = (modo == .prompt) ? detectarDespedidaFalada(textoPreprocessado) : nil

        // 3. No modo Livre: lista detectada ou texto já pontuado que não necessita de LLM
        if modo == .livre {
            let resultadoLista = ParserEnumeracao.formatarSeHouver(textoPreprocessado)
            if resultadoLista != textoPreprocessado {
                // Lista detectada e estruturada com perfeição determinística
                let final = CorretorVocabulario.corrigir(resultadoLista)
                let dtParser = Date().timeIntervalSince(t0)
                return ResultadoFormatacao(texto: final, duracaoParser: dtParser, duracaoLLM: 0)
            }

            if !precisaDeLLM(texto: textoPreprocessado, modo: modo) {
                let formatado = capitalizarSentencas(textoPreprocessado)
                let final = CorretorVocabulario.corrigir(ParserEnumeracao.formatarSeHouver(formatado))
                let dtParser = Date().timeIntervalSince(t0)
                return ResultadoFormatacao(texto: final, duracaoParser: dtParser, duracaoLLM: 0)
            }
        }

        // Se o modelo LLM não estiver carregado, aplica fallback determinístico
        guard let motor else {
            let formatado = CorretorVocabulario.corrigir(fallbackSemLLM(texto: textoPreprocessado, modo: modo))
            let dtParser = Date().timeIntervalSince(t0)
            return ResultadoFormatacao(texto: formatado, duracaoParser: dtParser, duracaoLLM: 0)
        }

        let sistemaBase = (modo == .prompt) ? promptProfissional : promptLivre
        let sistema = sistemaBase + GerenciadorVocabulario.shared.formatarParaLLM()

        var dtParser = Date().timeIntervalSince(t0)
        let tLLM = Date()
        do {
            let resultado = try await motor.reescrever(sistema: sistema, texto: textoPreprocessado)
            let dtLLM = Date().timeIntervalSince(tLLM)
            let tPos = Date()
            let sanitizado = sanitizarResposta(resultado, modo: modo)

            let textoFinal: String
            if validarSaida(original: textoPreprocessado, formatado: sanitizado, modo: modo) {
                if modo == .livre {
                    textoFinal = CorretorVocabulario.corrigir(ParserEnumeracao.formatarSeHouver(sanitizado))
                } else {
                    textoFinal = CorretorVocabulario.corrigir(polirEmail(sanitizado, despedidaForcada: despedidaFalada))
                }
            } else {
                textoFinal = CorretorVocabulario.corrigir(fallbackSemLLM(texto: textoPreprocessado, modo: modo))
            }
            dtParser += Date().timeIntervalSince(tPos)
            return ResultadoFormatacao(texto: textoFinal, duracaoParser: dtParser, duracaoLLM: dtLLM)
        } catch {
            let dtLLM = Date().timeIntervalSince(tLLM)
            let tPos = Date()
            let formatado = CorretorVocabulario.corrigir(fallbackSemLLM(texto: textoPreprocessado, modo: modo))
            dtParser += Date().timeIntervalSince(tPos)
            return ResultadoFormatacao(texto: formatado, duracaoParser: dtParser, duracaoLLM: dtLLM)
        }
    }

    /// Avalia se a transcrição realmente necessita do modelo LLM para pontuação.
    public static func precisaDeLLM(texto: String, modo: ModoDitado) -> Bool {
        if modo == .prompt { return true } // Modo profissional refina o estilo do e-mail

        let palavras = texto.split { $0.isWhitespace }
        if palavras.count < 6 { return false } // Bypass para textos curtos

        // Verifica se o texto do Whisper já veio com pontuação saudável
        let temPontuacaoFinal = texto.contains(".") || texto.contains("?") || texto.contains("!")
        guard temPontuacaoFinal else { return true } // Sem pontuação precisa do LLM

        // Conta frases terminadas
        let terminadores = texto.filter { [".", "!", "?"].contains($0) }.count
        let razao = Double(palavras.count) / Double(max(1, terminadores))

        // Se cada frase tem em média menos de 22 palavras
        if razao <= 22.0 && terminadores >= 1 {
            // Ditados longos (> 35 palavras) já pontuados pelo Whisper dispensam o LLM
            // para evitar a lentidão de 7.8s registrada no log
            if palavras.count >= 35 {
                return false
            }
            // Ditados médios sem comandos de voz pendentes também dispensam o LLM
            let temComandos = texto.range(of: #"(?i)\b(?:novo|outro)\s+par[áa]grafo\b|\bpula(?:r)?\s+linha\b"#, options: .regularExpression) != nil
            if !temComandos {
                return false
            }
        }

        return true
    }

    /// Remove vícios e hesitações comuns da fala (né, tipo assim, hum, hã, ahn, uh).
    public static func removerViciosDeFala(_ texto: String) -> String {
        var t = texto
        let padroes = [
            #"(?i),?\s*\b(?:n[ée]|hum+|h[ãa]+|ahn?|uh+)\b[,.]?\s*"#,
            #"(?i),?\s*\btipo\s+assim\b[,.]?\s*"#,
            #"(?i),\s*\btipo\b\s*,?\s*"#,
            #"(?i)^tipo,\s*"#
        ]
        for p in padroes {
            t = t.replacingOccurrences(of: p, with: " ", options: .regularExpression)
        }
        return t.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Pré e Pós-Processamento

    public static func preProcessarComandosDeVoz(_ texto: String) -> String {
        var t = texto
        let padroes = [
            #"(?i)\s*[,.]?\s*(?:novo|outro)\s+par[áa]grafo[,.]?\s*"#,
            #"(?i)\s*[,.]?\s*pula(?:r)?\s+linha[,.]?\s*"#
        ]
        for p in padroes {
            t = t.replacingOccurrences(of: p, with: "\n\n", options: .regularExpression)
        }
        return t
    }

    public static func sanitizarResposta(_ resposta: String, modo: ModoDitado = .livre) -> String {
        var t = resposta.trimmingCharacters(in: .whitespacesAndNewlines)

        if t.hasPrefix("```") {
            let linhas = t.components(separatedBy: "\n")
            if linhas.count >= 2 {
                let semPrimeira = linhas.dropFirst()
                if semPrimeira.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
                    t = semPrimeira.dropLast().joined(separator: "\n")
                } else {
                    t = semPrimeira.joined(separator: "\n")
                }
            }
        }

        t = t.replacingOccurrences(of: #"(?i)<\|im_start\|>(?:system|assistant|user)?\s*"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "<|im_end|>", with: "")
        t = t.replacingOccurrences(of: "<|im_start|>", with: "")

        t = t.replacingOccurrences(of: #"(?i)\[(?:seu\s+nome|nome|destinat[áa]rio|empresa|data|assunto)\]"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\[[A-Za-zÀ-ÿ\s]{2,20}\]"#, with: "", options: .regularExpression)

        t = preProcessarComandosDeVoz(t)
        t = t.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)

        if modo == .livre {
            t = ParserEnumeracao.formatarSeHouver(t)
            t = capitalizarSentencas(t)
        } else {
            t = polirEmail(t)
        }

        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func capitalizarSentencas(_ texto: String) -> String {
        var linhas = texto.components(separatedBy: "\n")
        for i in 0..<linhas.count {
            var l = linhas[i].trimmingCharacters(in: .whitespaces)
            guard !l.isEmpty else { continue }

            if let rangeNum = l.range(of: #"^\d+\.\s*"#, options: .regularExpression) {
                let prefixo = String(l[rangeNum])
                let resto = String(l[rangeNum.upperBound...])
                if let primeiroChar = resto.first {
                    l = prefixo + primeiroChar.uppercased() + resto.dropFirst()
                }
            } else {
                if let primeiroChar = l.first {
                    l = primeiroChar.uppercased() + l.dropFirst()
                }
            }

            // Capitaliza após ponto final, exclamação ou interrogação seguido de espaços
            let padraoFimSentenca = #"(?<=[.!?]\s+)([a-zà-ÿ])"#
            if let regexPonto = try? NSRegularExpression(pattern: padraoFimSentenca, options: []) {
                let ns = l as NSString
                let matches = regexPonto.matches(in: l, options: [], range: NSRange(location: 0, length: ns.length))
                for m in matches.reversed() {
                    let charUpper = ns.substring(with: m.range).uppercased()
                    l = (l as NSString).replacingCharacters(in: m.range, with: charUpper)
                }
            }

            linhas[i] = l
        }
        return linhas.joined(separator: "\n")
    }

    // MARK: - Acabamento e Polimento do Modo Profissional (E-mail)

    /// Detecta se um texto termina com agradecimento ou despedida falada (ex: obrigado, obrigada, abraços, att, agradeço).
    public static func detectarDespedidaFalada(_ texto: String) -> String? {
        // Primeiro procura despedida específica (obrigado, abraços, att, agradeço),
        // mesmo se houver um "Atenciosamente," residual gerado pelo LLM depois dela.
        let padraoEspecifico = #"(?i)(?:^|[\s,.\n])(muito\s+obrigad[oa]|obrigad[oa]|desde\s+j[áa]\s+agrade[çc]o|desde\s+j[áa]\s+obrigad[oa]|agrade[çc]o|abra[çc]os?|um\s+abra[çc]o|att\.?|grato|grata|valeu)(?:\s*[,.]?\s*(?:\n+Atenciosamente[,.]?|\s+atenciosamente[,.]?)?|\s*)$"#
        if let regexEsp = try? NSRegularExpression(pattern: padraoEspecifico, options: []) {
            let ns = texto as NSString
            if let match = regexEsp.firstMatch(in: texto, options: [], range: NSRange(location: 0, length: ns.length)) {
                let raw = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces).lowercased()
                if raw.hasPrefix("obrigad") || raw.hasPrefix("muito obrigad") {
                    let cap = raw.prefix(1).uppercased() + raw.dropFirst()
                    return "\(cap)."
                } else if raw.hasPrefix("abraço") || raw.hasPrefix("um abraço") {
                    let cap = raw.prefix(1).uppercased() + raw.dropFirst()
                    return "\(cap),"
                } else if raw.hasPrefix("att") {
                    return "Att."
                } else if raw.hasPrefix("agradeço") || raw.hasPrefix("desde já") || raw.hasPrefix("grato") || raw.hasPrefix("grata") || raw.hasPrefix("valeu") {
                    let cap = raw.prefix(1).uppercased() + raw.dropFirst()
                    return "\(cap)."
                }
            }
        }

        // Se não achou despedida específica, verifica atenciosamente / cordialmente no final
        let padraoGeral = #"(?i)(?:^|[\s,.\n])(atenciosamente|cordialmente)[,.]?\s*$"#
        if let regexGeral = try? NSRegularExpression(pattern: padraoGeral, options: []) {
            let ns = texto as NSString
            if let match = regexGeral.firstMatch(in: texto, options: [], range: NSRange(location: 0, length: ns.length)) {
                let raw = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces).lowercased()
                let cap = raw.prefix(1).uppercased() + raw.dropFirst()
                return "\(cap),"
            }
        }

        return nil
    }

    public static func polirEmail(_ texto: String, despedidaForcada: String? = nil) -> String {
        var t = texto.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Remove cabeçalhos indevidos (Para:, Assunto:, De:, Título:, Destinatário:)
        let linhasFiltradas = t.components(separatedBy: "\n").filter { linha in
            let l = linha.trimmingCharacters(in: .whitespaces)
            let ehCabecalho = l.range(of: #"^(?i)(?:para|assunto|de|t[íi]tulo|destinat[áa]rio)\s*:"#, options: .regularExpression) != nil
            return !ehCabecalho
        }
        t = linhasFiltradas.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // Se a fala começou com "para o João ...", converte em saudação natural "Olá, João," se não houver outra saudação
        let padraoParaInicial = #"(?i)^para\s+(?:o|a)?\s*([A-Za-zÀ-ÿ0-9\s]+?)(?:,\s*|\s*:\s*|\s+que\b|\s+segue\b|\s*\n\n|\s*$)"#
        if let regexPara = try? NSRegularExpression(pattern: padraoParaInicial, options: []) {
            let ns = t as NSString
            if let match = regexPara.firstMatch(in: t, options: [], range: NSRange(location: 0, length: min(ns.length, 60))) {
                let dest = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let resto = ns.substring(from: match.range.location + match.range.length).trimmingCharacters(in: .whitespacesAndNewlines)
                if !resto.lowercased().hasPrefix("bom dia") && !resto.lowercased().hasPrefix("olá") && !dest.isEmpty {
                    t = "Olá, \(capitalizarSentencas(dest)),\n\n\(resto)"
                } else {
                    t = resto
                }
            }
        }

        // 2. Remove múltiplos espaços internos e espaços no fim de linha
        let linhas = t.components(separatedBy: "\n").map { linha -> String in
            let l = linha.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            return l.trimmingCharacters(in: .whitespaces)
        }
        t = linhas.joined(separator: "\n")

        // 3. Garante pontuação adequada antes de conjunções adversativas (mas, porém, contudo)
        t = t.replacingOccurrences(
            of: #"(?<=[^\s,.;:!?\n])\s+(mas|por[ée]m|contudo|todavia|no\s+entanto)\b"#,
            with: ", $1",
            options: .regularExpression
        )

        // 4. Determina se há despedida falada (passada explicitamente ou detectada no final do texto)
        let padraoDespedidaFinal = #"(?i)\s*(?:atenciosamente|cordialmente|abra[çc]os?|um\s+abra[çc]o|att\.?|muito\s+obrigad[oa]|obrigad[oa]|agrade[çc]o|desde\s+j[áa]\s+agrade[çc]o|grato|grata)[,.]?\s*$"#

        let despedidaFinal: String
        let temDespedida: Bool

        if let forcada = despedidaForcada {
            despedidaFinal = forcada
            temDespedida = true
        } else if let detectada = detectarDespedidaFalada(t) {
            despedidaFinal = detectada
            temDespedida = true
        } else {
            despedidaFinal = "Atenciosamente,"
            temDespedida = false
        }

        // Remove quaisquer fechamentos que já estejam no final de t para reconstruir de forma limpa
        var tSemFechamento = t
        if let regexFim = try? NSRegularExpression(pattern: padraoDespedidaFinal, options: []) {
            while true {
                let ns = tSemFechamento as NSString
                if let match = regexFim.firstMatch(in: tSemFechamento, options: [], range: NSRange(location: 0, length: ns.length)) {
                    tSemFechamento = ns.substring(with: NSRange(location: 0, length: match.range.location)).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    break
                }
            }
        }
        t = tSemFechamento

        // Se houve despedida falada, remove também caso tenha ficado colada no final do parágrafo
        // (ex: "do orçamento 53. Obrigado.") para que fique isolada em sua própria linha
        if temDespedida {
            let padraoDespedidaNoFimDaFrase = #"(?i)(?<=[.!?]|\b)\s*(?:muito\s+)?obrigad[oa][,.]?\s*$"#
            t = t.replacingOccurrences(of: padraoDespedidaNoFimDaFrase, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 5. Normaliza vírgula na saudação inicial
        // Caso 1: Saudação com nome de pessoa (ex: "Olá, Maria," ou "Bom dia, João,")
        let padraoSaudacaoComNome = #"(?i)^(bom\s+dia|boa\s+tarde|boa\s+noite|ol[áa]|prezad[oa]s?)(?:[,\s]+)([A-ZÀ-ÿ][a-zà-ÿ]+(?:\s+[A-ZÀ-ÿ][a-zà-ÿ]+)*)(?:\s*[,.:;]?\s*(?:\n+|$|\s+))"#
        // Caso 2: Saudação simples (ex: "Bom dia segue o e-mail" ou "Olá, segue...")
        let padraoSaudacaoSimples = #"(?i)^(bom\s+dia|boa\s+tarde|boa\s+noite|ol[áa]|prezad[oa]s?)(?:\s*[,.:;]?\s*(?:\n+|$|\s+))"#

        let nsSaud = t as NSString
        if let regexComNome = try? NSRegularExpression(pattern: padraoSaudacaoComNome, options: []),
           let match = regexComNome.firstMatch(in: t, options: [], range: NSRange(location: 0, length: min(nsSaud.length, 80))) {
            let saudTipo = nsSaud.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            let nome = nsSaud.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
            let saudCapitalizada = saudTipo.prefix(1).uppercased() + saudTipo.dropFirst().lowercased()
            let saudacaoNormalizada = "\(saudCapitalizada), \(nome),\n\n"
            t = nsSaud.replacingCharacters(in: match.range, with: saudacaoNormalizada)
        } else if let regexSimples = try? NSRegularExpression(pattern: padraoSaudacaoSimples, options: []),
                  let match = regexSimples.firstMatch(in: t, options: [], range: NSRange(location: 0, length: min(nsSaud.length, 30))) {
            let saudTipo = nsSaud.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            let saudCapitalizada = saudTipo.prefix(1).uppercased() + saudTipo.dropFirst().lowercased()
            let saudacaoNormalizada = "\(saudCapitalizada),\n\n"
            t = nsSaud.replacingCharacters(in: match.range, with: saudacaoNormalizada)
        }

        // 6. Garante que TODAS as frases do corpo terminem com ponto final antes do fechamento
        let paragrafos = t.components(separatedBy: "\n\n")
        var paragrafosAjustados: [String] = []
        for p in paragrafos {
            var trimP = p.trimmingCharacters(in: .whitespacesAndNewlines)
            let isSaudacao = trimP.hasSuffix(",") && (trimP.lowercased().hasPrefix("bom dia") || trimP.lowercased().hasPrefix("olá") || trimP.lowercased().hasPrefix("boa") || trimP.lowercased().hasPrefix("prezado") || trimP.lowercased().hasPrefix("prezada"))

            if !isSaudacao && !trimP.isEmpty {
                if let ultimo = trimP.last, ![".", "!", "?", ":"].contains(ultimo) {
                    trimP.append(".")
                }
            }
            paragrafosAjustados.append(trimP)
        }
        t = paragrafosAjustados.joined(separator: "\n\n")

        // 7. Anexa EXCLUSIVAMENTE o fechamento único determinado em linha própria
        t += "\n\n" + despedidaFinal

        // Limpa quebras múltiplas
        t = t.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)

        return capitalizarSentencas(t)
    }

    // MARK: - Validação de Saída e Anti-Invenção

    public static func validarSaida(original: String, formatado: String, modo: ModoDitado) -> Bool {
        guard !formatado.isEmpty else { return false }

        let origLen = original.count
        let formLen = formatado.count

        if modo == .livre {
            let minLen = max(1, Int(Double(origLen) * 0.35))
            let maxLen = max(60, Int(Double(origLen) * 2.8))
            guard formLen >= minLen && formLen <= maxLen else { return false }
            return validarPreservacaoDePalavras(original: original, formatado: formatado)
        } else {
            let minLen = max(1, Int(Double(origLen) * 0.35))
            let maxLen = max(120, Int(Double(origLen) * 3.5) + 160)
            guard formLen >= minLen && formLen <= maxLen else { return false }
            return validarAntiInvencaoEmail(original: original, formatado: formatado)
        }
    }

    public static func validarPreservacaoDePalavras(original: String, formatado: String) -> Bool {
        let palavrasIgnoradas: Set<String> = [
            "novo", "outro", "parágrafo", "paragrafo", "pula", "linha", "pular",
            "né", "tipo", "hum", "hã", "ahn", "é", "eh", "uh", "então", "assim",
            "primeiro", "segundo", "terceiro", "quarto", "quinto", "item", "pontos", "ponto", "e"
        ]

        func extrairPalavras(_ t: String) -> [String] {
            t.lowercased()
             .components(separatedBy: CharacterSet.alphanumerics.inverted)
             .filter { !$0.isEmpty }
        }

        let origPalavras = extrairPalavras(original)
        let formPalavras = Set(extrairPalavras(formatado))

        for palavra in origPalavras {
            if palavrasIgnoradas.contains(palavra) { continue }
            if !formPalavras.contains(palavra) {
                return false
            }
        }
        return true
    }

    public static func validarAntiInvencaoEmail(original: String, formatado: String) -> Bool {
        if formatado.contains("[") || formatado.contains("]") {
            return false
        }

        // PROIBIDO CABEÇALHOS NO MODO PROFISSIONAL
        if formatado.range(of: #"(?i)^(?:para|assunto|de|t[íi]tulo)\s*:"#, options: .regularExpression) != nil ||
           formatado.contains("\nPara:") || formatado.contains("\nAssunto:") || formatado.contains("\nDe:") {
            return false
        }

        let regexFalsaTarefa = #"(?i)\btarefa\s+\d+\b"#
        if formatado.range(of: regexFalsaTarefa, options: .regularExpression) != nil &&
           original.range(of: regexFalsaTarefa, options: .regularExpression) == nil {
            return false
        }

        let numerosNaSaida = extrairNumeros(formatado)
        let numerosNaEntrada = extrairNumeros(original)
        for num in numerosNaSaida {
            if !numerosNaEntrada.contains(num) {
                return false
            }
        }

        return true
    }

    private static func extrairNumeros(_ texto: String) -> Set<String> {
        let regex = try? NSRegularExpression(pattern: #"\b\d+\b"#, options: [])
        let ns = texto as NSString
        let matches = regex?.matches(in: texto, options: [], range: NSRange(location: 0, length: ns.length)) ?? []
        let numeros = matches.map { ns.substring(with: $0.range) }
        return Set(numeros)
    }

    public static func fallbackSemLLM(texto: String, modo: ModoDitado) -> String {
        var t = preProcessarComandosDeVoz(texto)
        if modo == .prompt {
            t = formatarEmailFallback(t)
        } else {
            t = ParserEnumeracao.formatarSeHouver(t)
        }
        return capitalizarSentencas(t)
    }

    public static func formatarEmailFallback(_ texto: String) -> String {
        let despedida = detectarDespedidaFalada(texto)
        var t = LimpezaSimples.aplicar(texto)
        t = removerViciosDeFala(t)

        // Se o usuário falou destinatário ("para o João assunto compra..."), converte em saudação natural
        let padraoCabecalhoFalado = #"(?i)^(?:para\s+o|para\s+a|para)\s+([A-Za-zÀ-ÿ0-9\s]+?)(?:\s+(?:assunto|sobre)\s+([A-Za-zÀ-ÿ0-9\s]+?))?(?=[,.]?\s*(?:\s+segue\b|\s+que\b|\s+bom\s+dia\b|\s+boa\s+tarde\b|\s+boa\s+noite\b|\s+ol[áa]\b|\n|$))"#
        if let regex = try? NSRegularExpression(pattern: padraoCabecalhoFalado, options: []) {
            let ns = t as NSString
            if let match = regex.firstMatch(in: t, options: [], range: NSRange(location: 0, length: ns.length)) {
                let dest = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let resto = ns.substring(from: match.range.location + match.range.length).trimmingCharacters(in: .whitespacesAndNewlines)

                let temSaudacaoDepois = resto.range(of: #"(?i)^(?:bom\s+dia|boa\s+tarde|boa\s+noite|ol[áa])\b"#, options: .regularExpression) != nil
                if temSaudacaoDepois {
                    t = resto
                } else if !dest.isEmpty {
                    t = "Olá, \(capitalizarSentencas(dest)),\n\n\(resto)"
                } else {
                    t = resto
                }
            }
        }

        t = capitalizarSentencas(t.trimmingCharacters(in: .whitespacesAndNewlines))
        return polirEmail(t, despedidaForcada: despedida)
    }
}
