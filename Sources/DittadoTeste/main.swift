import DittadoCore
import DittadoWhisper
import DittadoLLM
import Foundation

// Uso:
//   DittadoTeste --testes                -> Executa a suíte unificada de testes automatizados
//   DittadoTeste <arquivo.wav ...>      -> Transcreve áudio com Whisper
//   DittadoTeste --gravar N             -> Grava do microfone e testa nível

var args = Array(CommandLine.arguments.dropFirst())
var modelo = Pastas.modeloWhisperPadrao.path
var modoPrompt = false

if let i = args.firstIndex(of: "--modelo"), i + 1 < args.count {
    modelo = args[i + 1]
    args.removeSubrange(i...i + 1)
}
if let i = args.firstIndex(of: "--prompt") {
    modoPrompt = true
    args.remove(at: i)
}

if let idx = args.firstIndex(of: "--avaliar-llm"), idx + 1 < args.count {
    let caminhoLLM = args[idx + 1]
    print("\n=== AVALIAÇÃO DE QUALIDADE E LATÊNCIA DE LLM ===")
    print("Modelo: \(caminhoLLM)")
    do {
        let t0 = Date()
        let llm = try LLMEngine(modelPath: caminhoLLM)
        print(String(format: "Tempo de carregamento: %.2f s", Date().timeIntervalSince(t0)))

        let tW = Date()
        let promptAquecimento = Formatador.promptProfissional + GerenciadorVocabulario.shared.formatarParaLLM()
        llm.aquecer(sistema: promptAquecimento)
        print(String(format: "Tempo de aquecimento KV cache: %.2f s", Date().timeIntervalSince(tW)))

        // 1. Caso E-mail Profissional (com 'obrigado' e números)
        let emailEntrada = "para o fornecedor assunto formalização da compra do item 345 bom dia segue o e-mail formalizando a compra do item 345 do orçamento 53 obrigado"
        let tE = Date()
        let saidaEmail = runSync { await Formatador.formatar(texto: emailEntrada, modo: .prompt, motor: llm) }
        let dtE = Date().timeIntervalSince(tE)
        print("\n[Caso 1 - E-mail Profissional] (latência: \(String(format: "%.2f s", dtE)))")
        print("Saída:\n---\n\(saidaEmail)\n---")

        // 2. Caso E-mail sem fechamento falado (deve ter Atenciosamente, e Olá, Maria,)
        let emailEntrada2 = "para a Maria assunto fechamento da sprint segue o status das tarefas concluídas com sucesso"
        let tE2 = Date()
        let saidaEmail2 = runSync { await Formatador.formatar(texto: emailEntrada2, modo: .prompt, motor: llm) }
        let dtE2 = Date().timeIntervalSince(tE2)
        print("\n[Caso 2 - E-mail Sem Fechamento] (latência: \(String(format: "%.2f s", dtE2)))")
        print("Saída:\n---\n\(saidaEmail2)\n---")

        // 3. Caso Preservação de Palavras ('nós') e Anti-Invenção
        let textoNos = "hoje nós vamos alinhar três pontos importantes para a equipe"
        let tNos = Date()
        let saidaNos = runSync { await Formatador.formatar(texto: textoNos, modo: .livre, motor: llm) }
        let dtNos = Date().timeIntervalSince(tNos)
        print("\n[Caso 3 - Preservação de 'nós'] (latência: \(String(format: "%.2f s", dtNos)))")
        print("Saída:\n---\n\(saidaNos)\n---")

        // 4. Caso Anti-Invenção (texto curto de vendas)
        let textoVendas = "segue o relatório de vendas de hoje"
        let tV = Date()
        let saidaVendas = runSync { await Formatador.formatar(texto: textoVendas, modo: .prompt, motor: llm) }
        let dtV = Date().timeIntervalSince(tV)
        print("\n[Caso 4 - Anti-Invenção] (latência: \(String(format: "%.2f s", dtV)))")
        print("Saída:\n---\n\(saidaVendas)\n---")

        // 5. Caso Vocabulário / Nomes Próprios
        let textoVocab = "abri o claude code e mandei mensagem no whatsapp"
        let tVocab = Date()
        let saidaVocab = runSync { await Formatador.formatar(texto: textoVocab, modo: .livre, motor: llm) }
        let dtVocab = Date().timeIntervalSince(tVocab)
        print("\n[Caso 5 - Vocabulário] (latência: \(String(format: "%.2f s", dtVocab)))")
        print("Saída:\n---\n\(saidaVocab)\n---")

        llm.encerrar()
        exit(0)
    } catch {
        print("Erro ao carregar ou avaliar LLM: \(error)")
        exit(1)
    }
}

if args.contains("--testes") || args.isEmpty {
    print("=== Iniciando Suíte Completa Unificada de Testes (Dittado T1-T5) ===")

    // =========================================================================
    // SEÇÃO 1: Sanitização de Resposta do LLM, Fences e Placeholders
    // =========================================================================
    print("\n[1/13] Testando sanitização de resposta, fences e placeholders...")
    let comMarkdown = "```markdown\nTexto formatado aqui\n```"
    assert(Formatador.sanitizarResposta(comMarkdown) == "Texto formatado aqui", "Falha na remoção de markdown fence")

    let comTags = "<|im_start|>system\nTexto com tags<|im_end|>"
    assert(Formatador.sanitizarResposta(comTags) == "Texto com tags" || Formatador.sanitizarResposta(comTags) == "system\nTexto com tags", "Falha na remoção de tags de template")

    let comPlaceholders = "Atenciosamente,\n[Seu Nome]\n[Empresa]"
    let semPlaceholders = Formatador.sanitizarResposta(comPlaceholders, modo: .prompt)
    assert(!semPlaceholders.contains("[Seu Nome]") && !semPlaceholders.contains("[Empresa]"), "Placeholders entre colchetes não podem permanecer no texto final")
    assert(semPlaceholders.contains("Atenciosamente,"), "Deve restar o fechamento limpo")
    print("✓ Sanitização e eliminação de tags/placeholders aprovadas.")

    // =========================================================================
    // SEÇÃO 2: Pré-processamento Determinístico (Comandos de Voz)
    // =========================================================================
    print("\n[2/13] Testando pré-processamento de comandos de voz (parágrafos e quebras)...")
    let falaComandos = "primeiro parágrafo novo parágrafo segundo parágrafo pula linha terceiro parágrafo"
    let processadoComandos = Formatador.preProcessarComandosDeVoz(falaComandos)
    assert(!processadoComandos.contains("novo parágrafo"), "Comando 'novo parágrafo' deve ser removido")
    assert(!processadoComandos.contains("pula linha"), "Comando 'pula linha' deve ser removido")
    assert(processadoComandos.contains("\n\n"), "Deve conter quebra de parágrafo dupla")
    print("✓ Pré-processamento de comandos de voz aprovado.")

    // =========================================================================
    // SEÇÃO 3: Validação de Proporção, Preservação de Palavras ('nós') e Anti-Invenção
    // =========================================================================
    print("\n[3/13] Testando validação de proporção, preservação de palavras ('nós') e anti-invenção...")
    let fraseOriginal = "hoje nós vamos alinhar três pontos importantes para a equipe"
    assert(Formatador.validarSaida(original: fraseOriginal, formatado: "Hoje nós vamos alinhar três pontos importantes para a equipe.", modo: .livre), "Deveria ser válido com preservação total")
    assert(!Formatador.validarSaida(original: fraseOriginal, formatado: "", modo: .livre), "Saída vazia deve ser inválida")
    assert(!Formatador.validarSaida(original: fraseOriginal, formatado: "Hoje.", modo: .livre), "Saída excessivamente curta deve ser inválida")

    // Teste estrito de preservação de pronomes/palavras essenciais ('nós')
    let textoComNos = "hoje nós vamos alinhar três pontos"
    let textoSemNos = "Hoje vamos alinhar três pontos"
    assert(Formatador.validarPreservacaoDePalavras(original: textoComNos, formatado: "Hoje nós vamos alinhar três pontos"), "Deveria aprovar com a palavra 'nós' preservada")
    assert(!Formatador.validarPreservacaoDePalavras(original: textoComNos, formatado: textoSemNos), "Deve REJEITAR quando a palavra 'nós' for omitida pelo modelo")

    // Anti-invenção no e-mail (números inexistentes ou falsas tarefas)
    let emailOrig = "segue o relatório de vendas de hoje"
    let emailAlucinado = "Segue o relatório de vendas. Tarefa 1 concluída com 99 itens."
    assert(!Formatador.validarSaida(original: emailOrig, formatado: emailAlucinado, modo: .prompt), "Deve REJEITAR e-mail com tarefas/números inventados")
    print("✓ Validação de proporção, preservação estrita de 'nós' e anti-invenção aprovadas.")

    // =========================================================================
    // SEÇÃO 4: Bypass de Textos Curtos (< 6 palavras) e Fallbacks
    // =========================================================================
    print("\n[4/13] Testando bypass de textos curtos (< 6 palavras) e fallbacks...")
    let curto = "olá mundo teste rápido"
    let taskCurto = Task {
        await Formatador.formatar(texto: curto, modo: .livre, motor: nil)
    }
    let resCurto = runSync { await taskCurto.value }
    assert(resCurto.lowercased() == curto.lowercased(), "Textos com menos de 6 palavras devem retornar rapidamente sem LLM")

    let fallbackEmail = Formatador.fallbackSemLLM(texto: "para o João assunto reunião né tipo hum segue pauta", modo: .prompt)
    assert(!fallbackEmail.contains("Para:") && !fallbackEmail.contains("Assunto:"), "Fallback de e-mail NÃO deve conter linhas Para: ou Assunto:")
    assert(fallbackEmail.contains("Olá, João,") || fallbackEmail.contains("João,"), "Fallback de e-mail deve converter 'para o João' em saudação natural")
    assert(!fallbackEmail.contains("hum") && !fallbackEmail.contains("né"), "Fallback deve remover vícios de fala")
    assert(fallbackEmail.contains("Atenciosamente,"), "Fallback de e-mail sem despedida falada deve incluir Atenciosamente,")
    print("✓ Fallbacks e bypass de textos curtos aprovados.")

    // =========================================================================
    // SEÇÃO 5: Nomenclatura e Compatibilidade dos Modos (T3)
    // =========================================================================
    print("\n[5/13] Testando nomes de exibição dos modos e compatibilidade...")
    assert(ModoDitado.livre.nomeExibicao == "Livre", "Modo livre deve exibir Livre")
    assert(ModoDitado.prompt.nomeExibicao == "Profissional", "Modo prompt deve exibir Profissional")
    assert(ModoDitado.prompt.rawValue == "Prompt", "rawValue deve permanecer 'Prompt' para compatibilidade com configs e histórico gravado")
    print("✓ Nomenclatura de modos e compatibilidade aprovadas.")

    // =========================================================================
    // SEÇÃO 6: Parser Determinístico de Enumeração (Casos Positivos e String Exata)
    // =========================================================================
    print("\n[6/13] Testando Parser Determinístico de Enumeração (Casos Positivos)...")

    // Caso 1: 5 itens ordinais
    let entrada5Itens = "Quero comprar 5 itens para minha lista. Primeiro, memória RAM. Segundo, lâmpada. Terceiro, fogão. Quarto, TV de 53 polegadas. Quinto, corda."
    let esperado5Itens = """
    Quero comprar 5 itens para minha lista:
    1. Memória RAM
    2. Lâmpada
    3. Fogão
    4. TV de 53 polegadas
    5. Corda
    """
    let saida5Itens = ParserEnumeracao.formatarSeHouver(entrada5Itens)
    assert(saida5Itens == esperado5Itens, "ERRO no Caso 1 (5 itens ordinais).\nEsperado:\n\(esperado5Itens)\nObtido:\n\(saida5Itens)")
    print("  ✓ Caso 1 (5 itens ordinais) aprovado com correspondência exata!")

    // Caso 2: 3 itens com 'e terceiro'
    let entrada3Itens = "tenho três recados primeiro chegar cedo segundo trazer o crachá e terceiro assinar a lista"
    let esperado3Itens = """
    Tenho três recados:
    1. Chegar cedo
    2. Trazer o crachá
    3. Assinar a lista
    """
    let saida3Itens = ParserEnumeracao.formatarSeHouver(entrada3Itens)
    assert(saida3Itens == esperado3Itens, "ERRO no Caso 2.\nEsperado:\n\(esperado3Itens)\nObtido:\n\(saida3Itens)")
    print("  ✓ Caso 2 (3 itens com 'e terceiro') aprovado!")

    // Caso 3: 2 itens sem introdução
    let entrada2Itens = "Primeiro, verificar o cabo. Segundo, ligar a chave."
    let esperado2Itens = """
    1. Verificar o cabo
    2. Ligar a chave
    """
    let saida2Itens = ParserEnumeracao.formatarSeHouver(entrada2Itens)
    assert(saida2Itens == esperado2Itens, "ERRO no Caso 3.\nEsperado:\n\(esperado2Itens)\nObtido:\n\(saida2Itens)")
    print("  ✓ Caso 3 ('Primeiro... Segundo...' sem intro) aprovado!")

    // Caso 4: Lista seguida de 'novo parágrafo qualquer dúvida'
    let entradaComParagrafo = "temos duas tarefas primeiro fazer o deploy segundo rodar os testes novo parágrafo qualquer dúvida me avisem"
    let esperadoComParagrafo = """
    Temos duas tarefas:
    1. Fazer o deploy
    2. Rodar os testes

    Qualquer dúvida me avisem
    """
    let saidaComParagrafo = ParserEnumeracao.formatarSeHouver(entradaComParagrafo)
    assert(saidaComParagrafo == esperadoComParagrafo, "ERRO no Caso 4.\nEsperado:\n\(esperadoComParagrafo)\nObtido:\n\(saidaComParagrafo)")
    print("  ✓ Caso 4 (lista com 'novo parágrafo') aprovado!")

    // Caso 5: Cardinais 'um X dois Y três Z'
    let entradaCardinais = "precisamos comprar um maçã dois banana três laranja"
    let esperadoCardinais = """
    Precisamos comprar:
    1. Maçã
    2. Banana
    3. Laranja
    """
    let saidaCardinais = ParserEnumeracao.formatarSeHouver(entradaCardinais)
    assert(saidaCardinais == esperadoCardinais, "ERRO no Caso 5.\nEsperado:\n\(esperadoCardinais)\nObtido:\n\(saidaCardinais)")
    print("  ✓ Caso 5 (cardinais 'um X dois Y três Z') aprovado!")

    // =========================================================================
    // SEÇÃO 7: Casos Negativos de Ordinais (Ponto 1 - Sem Falsos Positivos)
    // =========================================================================
    print("\n[7/13] Testando Casos Negativos de Ordinais e Substantivos Modificados (Ponto 1)...")

    // 1. Falso positivo relatado pelo Maestro: "Primeiro passo é abrir o app e o segundo passo é clicar em iniciar"
    let entradaPassos = "Primeiro passo é abrir o app e o segundo passo é clicar em iniciar"
    let saidaPassos = ParserEnumeracao.formatarSeHouver(entradaPassos)
    assert(saidaPassos == entradaPassos, "ERRO: 'Primeiro passo ... segundo passo' gerou lista indevida!\nObtido:\n\(saidaPassos)")
    print("  ✓ 'Primeiro passo ... segundo passo' NÃO ativou lista!")

    // 2. Substantivos que qualificam ordinais (lugar, semestre, trimestre, mundo, grau, turno, tempo, plano)
    let entradaLugar = "Em primeiro lugar queremos agradecer a presença de todos"
    assert(ParserEnumeracao.formatarSeHouver(entradaLugar) == entradaLugar, "ERRO: 'primeiro lugar' ativou lista indevida!")

    let entradaSemestre = "No primeiro semestre tivemos lucro e no segundo semestre expandimos"
    assert(ParserEnumeracao.formatarSeHouver(entradaSemestre) == entradaSemestre, "ERRO: 'primeiro semestre... segundo semestre' ativou lista indevida!")

    let entradaTrimestre = "No primeiro trimestre batemos a meta e no segundo trimestre superamos"
    assert(ParserEnumeracao.formatarSeHouver(entradaTrimestre) == entradaTrimestre, "ERRO: 'primeiro trimestre... segundo trimestre' ativou lista indevida!")

    let entradaPlano = "O primeiro plano deu certo e o segundo plano falhou"
    assert(ParserEnumeracao.formatarSeHouver(entradaPlano) == entradaPlano, "ERRO: 'primeiro plano... segundo plano' ativou lista indevida!")

    // 3. Precedido de artigo ou preposição ('o segundo', 'no segundo', 'do segundo', 'um segundo')
    let entradaTempo = "espera um segundo por favor"
    assert(ParserEnumeracao.formatarSeHouver(entradaTempo) == entradaTempo, "ERRO: 'um segundo' como tempo ativou lista indevida!")

    let entradaDoSegundo = "gostei mais do segundo modelo apresentado"
    assert(ParserEnumeracao.formatarSeHouver(entradaDoSegundo) == entradaDoSegundo, "ERRO: 'do segundo' ativou lista indevida!")

    // 4. Quantidades e números comuns
    let entradaNumeros = "Quero comprar 5 itens na loja com TV de 53 polegadas"
    assert(ParserEnumeracao.formatarSeHouver(entradaNumeros) == entradaNumeros, "ERRO: números soltos ativaram lista indevidamente!")
    print("  ✓ Todos os casos negativos aprovados com zero falsos positivos!")

    // =========================================================================
    // SEÇÃO 8: Testes Determinísticos de E-mail (Pontos 2 e 3 + Remoção de Para/Assunto)
    // =========================================================================
    print("\n[8/13] Testando Regras de Fechamento Único, Pontuação e Ausência de Cabeçalhos no E-mail...")

    // Ponto 2: Entrada com despedida falada ('obrigado') -> USA O PRÓPRIO FECHAMENTO, SEM 'Atenciosamente,' E SEM Para/Assunto
    let entradaComObrigado = "para o fornecedor assunto formalização da compra do item 345 bom dia segue o e-mail formalizando a compra do item 345 do orçamento 53 obrigado"
    let saidaComObrigado = Formatador.fallbackSemLLM(texto: entradaComObrigado, modo: .prompt)
    print("Saída do Fallback com 'obrigado':\n---\n\(saidaComObrigado)\n---")
    assert(!saidaComObrigado.contains("Para:") && !saidaComObrigado.contains("Assunto:"), "ERRO: Não deve conter cabeçalhos 'Para:' ou 'Assunto:'")
    assert(saidaComObrigado.contains("Bom dia,"), "Deve conter 'Bom dia,'")
    assert(saidaComObrigado.contains("do orçamento 53."), "Frase do corpo deve terminar com ponto final antes do fechamento")
    assert(saidaComObrigado.hasSuffix("Obrigado.") || saidaComObrigado.hasSuffix("Obrigado,"), "Fechamento deve ser o próprio 'Obrigado.' falado em linha própria")
    assert(!saidaComObrigado.contains("Atenciosamente,"), "ERRO: Não deve conter 'Atenciosamente,' quando houver despedida falada!")
    print("  ✓ Ponto 2 (E-mail com 'obrigado' falado): corpo limpo sem cabeçalhos e com fechamento próprio.")

    // Ponto 2: Entrada SEM despedida falada -> ACRESCENTA 'Atenciosamente,' E CONVERTE DESTINATÁRIO EM SAUDAÇÃO NATURAL
    let entradaSemDespedida = "para a Maria assunto fechamento da sprint segue o status das tarefas concluídas com sucesso"
    let saidaSemDespedida = Formatador.fallbackSemLLM(texto: entradaSemDespedida, modo: .prompt)
    print("Saída Sem Despedida:\n---\n\(saidaSemDespedida)\n---")
    assert(!saidaSemDespedida.contains("Para:") && !saidaSemDespedida.contains("Assunto:"), "ERRO: Não deve conter cabeçalhos 'Para:' ou 'Assunto:'")
    assert(saidaSemDespedida.contains("Olá, Maria,"), "Deve converter 'para a Maria' em saudação natural 'Olá, Maria,'")
    assert(saidaSemDespedida.contains("Segue o status das tarefas concluídas com sucesso."), "Corpo deve terminar com ponto final")
    assert(saidaSemDespedida.hasSuffix("Atenciosamente,"), "Deve acrescentar 'Atenciosamente,' quando não houver despedida falada")
    print("  ✓ Ponto 2 (E-mail sem despedida falada): sem cabeçalhos e com saudação natural.")

    // Ponto 3: Pontuação antes do fechamento ('Segue o e-mail, mas não anexei. Obrigado')
    let entradaPontuacao = "para o João assunto envio olá segue o e-mail mas não anexei obrigado"
    let saidaPontuacao = Formatador.fallbackSemLLM(texto: entradaPontuacao, modo: .prompt)
    print("Saída do Teste de Pontuação:\n---\n\(saidaPontuacao)\n---")
    assert(!saidaPontuacao.contains("Para:") && !saidaPontuacao.contains("Assunto:"), "Não deve conter 'Para:' ou 'Assunto:'")
    assert(saidaPontuacao.contains(", mas não anexei."), "Ponto 3: Deve ter vírgula antes de 'mas' e ponto final na frase do corpo antes da despedida")
    assert(saidaPontuacao.hasSuffix("Obrigado."), "Deve terminar com 'Obrigado.' em linha própria")
    assert(!saidaPontuacao.contains("Atenciosamente,"), "Não deve conter 'Atenciosamente,'")
    print("  ✓ Ponto 3 (Pontuação de todas as frases do corpo e antes de despedida) aprovado!")

    // Teste direto de polirEmail sem flag (caso testado pelo Maestro):
    let emailComDuploNoTexto = "Bom dia,\n\nSegue o e-mail formalizando a compra. Obrigado.\n\nAtenciosamente,"
    let polidoSemFlag = Formatador.polirEmail(emailComDuploNoTexto)
    assert(polidoSemFlag.hasSuffix("Obrigado."), "polirEmail chamado diretamente sem flag deve manter 'Obrigado.'")
    assert(!polidoSemFlag.contains("Atenciosamente,"), "polirEmail chamado diretamente sem flag deve eliminar 'Atenciosamente,' quando há 'Obrigado.'")
    assert(!polidoSemFlag.contains("Para:") && !polidoSemFlag.contains("Assunto:"), "polirEmail deve eliminar quaisquer linhas residuais de Para/Assunto")
    print("  ✓ polirEmail direto sem flag mantém 'Obrigado.' e remove 'Atenciosamente,' com sucesso!")

    // =========================================================================
    // SEÇÃO 9: Inferência Ao Vivo com LLMEngine (Metal + Qwen 7B + KV Cache)
    // =========================================================================
    print("\n[9/13] Testando inferência ao vivo com LLMEngine (Qwen 7B)...")
    var motorLLMInstanciado: LLMEngine? = nil
    if FileManager.default.fileExists(atPath: Pastas.modeloLLMPadrao.path) {
        do {
            let t0 = Date()
            let llm = try LLMEngine(modelPath: Pastas.modeloLLMPadrao.path)
            motorLLMInstanciado = llm
            print(String(format: "Modelo carregado em %.2f s. Aquecendo com KV cache do sistema...", Date().timeIntervalSince(t0)))
            let tW = Date()
            let promptAquecimento = Formatador.promptProfissional + GerenciadorVocabulario.shared.formatarParaLLM()
            llm.aquecer(sistema: promptAquecimento)
            print(String(format: "Aquecimento em %.2f s.", Date().timeIntervalSince(tW)))

            // Teste ao vivo 1: Exemplo dos 5 itens através do Formatador completo (Modo Livre)
            print("\n--- Teste Ao Vivo 1: Exemplo dos 5 Itens (Modo Livre) ---")
            let tLivre = Date()
            let taskLivre = Task {
                await Formatador.formatar(texto: entrada5Itens, modo: .livre, motor: llm)
            }
            let resLivre = runSync { await taskLivre.value }
            let dtLivre = Date().timeIntervalSince(tLivre)
            print("Saída Real Obtida:\n---\n\(resLivre)\n---")
            print(String(format: "⏱ Latência Modo Livre: %.2f s (%d ms)", dtLivre, Int(dtLivre * 1000)))
            assert(resLivre == esperado5Itens, "ERRO: Saída do pipeline completo dos 5 itens não bateu com o esperado!")
            print("✓ Teste ao vivo 1 aprovado com perfeição!")

            // Teste ao vivo 2: E-mail Real (Modo Profissional) com fechamento falado único e SEM cabeçalhos Para/Assunto
            print("\n--- Teste Ao Vivo 2: E-mail Real (Modo Profissional) ---")
            let tEmail = Date()
            let taskEmail = Task {
                await Formatador.formatar(texto: entradaComObrigado, modo: .prompt, motor: llm)
            }
            let resEmail = runSync { await taskEmail.value }
            let dtEmail = Date().timeIntervalSince(tEmail)
            print("Saída Real Obtida:\n---\n\(resEmail)\n---")
            print(String(format: "⏱ Latência Modo Profissional: %.2f s (%d ms)", dtEmail, Int(dtEmail * 1000)))

            // Validações rigorosas de estrutura, pontuação, ausência total de Para/Assunto e fechamento único:
            assert(!resEmail.contains("Para:") && !resEmail.contains("Assunto:"), "ERRO: O e-mail NÃO deve conter linhas de cabeçalho 'Para:' ou 'Assunto:'")
            assert(resEmail.contains("Bom dia,"), "ERRO: Saudação deve conter vírgula ('Bom dia,')")
            assert(resEmail.contains("345") && resEmail.contains("53"), "ERRO: Números falados devem ser preservados")
            assert(!resEmail.contains("["), "ERRO: Placeholders detectados")

            // Ponto 3: Frase anterior a 'Obrigado' deve ter ponto final
            assert(resEmail.contains("do orçamento 53.") || resEmail.contains("orçamento 53."), "ERRO: Frase do corpo deve terminar com ponto final")

            // Ponto 2: Fechamento deve ser EXCLUSIVAMENTE o falado ('Obrigado.' ou 'Obrigado,') sem 'Atenciosamente,'
            assert(resEmail.hasSuffix("Obrigado.") || resEmail.hasSuffix("Obrigado,"), "ERRO: Deve terminar com 'Obrigado.' falado em linha própria")
            assert(!resEmail.contains("Atenciosamente,"), "ERRO: NÃO deve conter 'Atenciosamente,' quando o usuário já ditou 'obrigado'!")
            assert(!resEmail.contains("Obrigado,\n\nAtenciosamente,") && !resEmail.contains("Obrigado.\n\nAtenciosamente,"), "ERRO: Duplo fechamento detectado!")
            print("✓ Teste ao vivo 2 (E-mail Real) aprovado sem cabeçalhos Para/Assunto e com fechamento único!")

        } catch {
            print("Erro no teste LLM: \(error)")
            exit(1)
        }
    } else {
        print("  [PULADO] Modelo LLM não encontrado em \(Pastas.modeloLLMPadrao.path) — inferência ao vivo ignorada.")
    }

    // =========================================================================
    // SEÇÃO 10: Vocabulário Personalizado Editável (Termos Neutros e Itens Estruturados)
    // =========================================================================
    print("\n[10/13] Testando Vocabulário Personalizado Editável (Termos Neutros e Variantes)...")
    let suiteUD = UserDefaults(suiteName: "test.vocabulario.\(UUID().uuidString)")!
    let gv = GerenciadorVocabulario(userDefaults: suiteUD, chave: "vocabTeste")

    // 10.1: Termos padrão e Itens com Variantes
    assert(gv.termos == GerenciadorVocabulario.termosPadrao, "Termos iniciais devem ser os termos padrão")
    assert(gv.termos.contains("Claude") && gv.termos.contains("ChatGPT") && gv.termos.contains("WhatsApp"), "Deve conter termos genéricos padrão")
    assert(gv.itens.contains { $0.termo == "Claude Code" && $0.variantes.contains("Cloud Code") }, "Deve conter Claude Code com variante Cloud Code")
    assert(gv.itens.contains { $0.termo == "Claude" && $0.variantes.contains("Cloud") }, "Deve conter Claude com variante Cloud")

    // 10.2: Adição de termo novo com variantes
    assert(gv.adicionar("NovaTech", variantes: ["Nova Tech", "Novinha"]), "Deve adicionar termo novo com variantes")
    assert(gv.termos.first == "NovaTech", "Novo termo deve estar no topo da lista")
    assert(gv.itens.first?.variantes.contains("Novinha") == true, "Variantes cadastradas devem ser persistidas")

    // 10.3: Rejeição de vazios e espaços
    assert(!gv.adicionar(""), "Deve rejeitar termo vazio")
    assert(!gv.adicionar("   \n\t "), "Deve rejeitar termo composto apenas de espaços")

    // 10.4: Rejeição de duplicados ignorando caixa alta/baixa
    assert(!gv.adicionar("novatech"), "Deve rejeitar duplicado case-insensitive")
    assert(!gv.adicionar("CLAUDE"), "Deve rejeitar duplicado de termo já existente")

    // 10.5: Edição de termo existente e gerenciamento de variantes
    assert(gv.editar(noIndice: 0, novoTermo: "Acme Corp"), "Deve permitir editar termo")
    assert(gv.termos.first == "Acme Corp", "Termo editado deve estar atualizado")
    assert(gv.adicionarVariante(aoTermo: "Acme Corp", variante: "Acme"), "Deve permitir adicionar variante")
    assert(gv.removerVariante(doTermo: "Acme Corp", variante: "Novinha"), "Deve permitir remover variante")
    assert(!gv.editar(noIndice: 0, novoTermo: "WhatsApp"), "Deve rejeitar edição que gere duplicata com outro termo existente")
    assert(!gv.editar(noIndice: 0, novoTermo: ""), "Deve rejeitar edição para valor vazio")

    // 10.6: Remoção de termo
    let countAntes = gv.termos.count
    assert(gv.remover("Acme Corp"), "Deve remover termo pelo nome")
    assert(gv.termos.count == countAntes - 1, "Contagem de termos deve diminuir em 1")
    assert(!gv.termos.contains("Acme Corp"), "Termo removido não deve mais constar")

    // 10.7: Formatação para LLM com variantes
    let promptLLM = gv.formatarParaLLM()
    assert(promptLLM.contains("TERMOS DO VOCABULÁRIO E NOMES PRÓPRIOS"), "Prompt LLM deve conter instrução de preservação")
    assert(promptLLM.contains("Claude") && promptLLM.contains("ChatGPT"), "Prompt LLM deve listar os termos genéricos")
    assert(promptLLM.contains("Claude Code (grafias/variantes possíveis: Cloud Code"), "Prompt LLM deve informar as variantes aceitas")

    // 10.8: Formatação para Whisper em frase natural e limite de tokens (~224 tokens)
    let (promptWhisperNormal, excedeuNormal) = gv.formatarParaWhisper(limiteTokens: 224)
    assert(!excedeuNormal, "Termos padrão não devem exceder o limite de 224 tokens do Whisper")
    assert(promptWhisperNormal.hasPrefix("Conversa sobre "), "Prompt do Whisper deve iniciar como frase natural ('Conversa sobre...')")
    assert(promptWhisperNormal.contains("Claude") && promptWhisperNormal.hasSuffix("."), "Prompt do Whisper deve terminar com ponto")

    // 10.9: Teste de regressão de correção fonética e variantes (vocabulário isolado de teste)
    let itensTesteVocab = [
        ItemVocabulario(termo: "NovaTech", variantes: ["Tech", "Nova Tech"]),
        ItemVocabulario(termo: "Antigravity", variantes: ["AntiGravity", "Anti Gravity"]),
        ItemVocabulario(termo: "Claude", variantes: ["Cloud"]),
        ItemVocabulario(termo: "Claude Code", variantes: ["Cloud Code"])
    ]
    let entradaTesteRegressao = "Sou o Tech Engenharia, AntiGravity, Cloud, Cloud Code"
    let saidaTesteRegressao = CorretorVocabulario.corrigir(entradaTesteRegressao, itens: itensTesteVocab)
    assert(saidaTesteRegressao == "Sou o NovaTech Engenharia, Antigravity, Claude, Claude Code",
           "ERRO na regressão de vocabulário!\nEsperado: 'Sou o NovaTech Engenharia, Antigravity, Claude, Claude Code'\nObtido: '\(saidaTesteRegressao)'")
    print("  ✓ Regressão de vocabulário ('Tech Engenharia, AntiGravity, Cloud, Cloud Code' -> 'NovaTech Engenharia, Antigravity, Claude, Claude Code') aprovada!")

    // 10.10: Casos negativos de falsos positivos (nuvem, carro)
    let fraseNuvem = "a nuvem está cloud"
    let saidaNuvem = CorretorVocabulario.corrigir(fraseNuvem, itens: itensTesteVocab)
    assert(saidaNuvem == fraseNuvem, "ERRO: 'a nuvem está cloud' não deve ser substituída por Claude! Obtido: '\(saidaNuvem)'")

    let fraseCarro = "o carro bateu"
    let saidaCarro = CorretorVocabulario.corrigir(fraseCarro, itens: itensTesteVocab)
    assert(saidaCarro == fraseCarro, "ERRO: 'o carro bateu' não deve ser alterado por fuzzy matching! Obtido: '\(saidaCarro)'")
    print("  ✓ Casos negativos de proteção ('a nuvem está cloud', 'o carro bateu') preservados com sucesso!")

    // 10.11: Limpeza determinística de vícios de fala sem corromper palavras legítimas
    let falaComVicios = "Hoje nós vamos, né, alinhar o projeto tipo assim com calma hum"
    let limpaVicios = Formatador.removerViciosDeFala(falaComVicios)
    assert(limpaVicios == "Hoje nós vamos alinhar o projeto com calma", "ERRO na remoção de vícios de fala! Obtido: '\(limpaVicios)'")

    let textoLegitimoComTipo = "qualquer tipo de arquivo é aceito"
    assert(Formatador.removerViciosDeFala(textoLegitimoComTipo) == textoLegitimoComTipo, "ERRO: 'tipo de arquivo' legítimo não deve ser corrompido!")
    print("  ✓ Remoção de vícios de fala (né, tipo assim, hum) validada preservando 'tipo de...' legítimo!")

    // Simula lista longa excedendo limite de tokens
    for i in 1...60 {
        gv.adicionar("TermoTecnicoMuitoLongoParaTestarLimiteDeTokensNumero\(i)")
    }
    let (promptWhisperLongo, excedeuLongo) = gv.formatarParaWhisper(limiteTokens: 224)
    assert(excedeuLongo, "Lista longa deve acusar detecção de limite excedido")
    assert(promptWhisperLongo.contains("TermoTecnicoMuitoLongoParaTestarLimiteDeTokensNumero60"), "Deve priorizar os termos mais recentes no início")
    print("✓ Todos os requisitos de Vocabulário Personalizado (T5.1) aprovados com sucesso!")

    // =========================================================================
    // SEÇÃO 11: Versão do App e Rótulos Amigáveis dos Modelos de IA
    // =========================================================================
    print("\n[11/13] Testando versão do app e rótulos amigáveis de modelos de IA...")

    // 11.1 Testes de formatação individual de modelos (RotuloModelo.formatar)
    let rotuloQwen7B = RotuloModelo.formatar(nomeArquivo: "qwen2.5-7b-instruct-q4_k_m.gguf")
    assert(rotuloQwen7B == "Qwen2.5 7B Instruct (Q4_K_M)", "Falha no rótulo Qwen 7B: '\(rotuloQwen7B)'")

    let rotuloQwen3B = RotuloModelo.formatar(nomeArquivo: "qwen2.5-3b-instruct-q4_k_m.gguf")
    assert(rotuloQwen3B == "Qwen2.5 3B Instruct (Q4_K_M)", "Falha no rótulo Qwen 3B: '\(rotuloQwen3B)'")

    let rotuloWhisperQ8 = RotuloModelo.formatar(nomeArquivo: "ggml-large-v3-turbo-q8_0.bin")
    assert(rotuloWhisperQ8 == "Whisper large-v3-turbo (Q8_0)", "Falha no rótulo Whisper Turbo Q8_0: '\(rotuloWhisperQ8)'")

    let rotuloWhisperSemQuant = RotuloModelo.formatar(nomeArquivo: "ggml-large-v3-turbo.bin")
    assert(rotuloWhisperSemQuant == "Whisper large-v3-turbo", "Falha no rótulo Whisper sem quantização: '\(rotuloWhisperSemQuant)'")

    let rotuloWhisperBase = RotuloModelo.formatar(nomeArquivo: "ggml-base.bin")
    assert(rotuloWhisperBase == "Whisper base", "Falha no rótulo Whisper base: '\(rotuloWhisperBase)'")

    let rotuloDesconhecido = RotuloModelo.formatar(nomeArquivo: "modelo-customizado-inexistente.bin")
    assert(rotuloDesconhecido == "modelo-customizado-inexistente.bin", "Arquivo desconhecido deve preservar nome cru: '\(rotuloDesconhecido)'")

    let rotuloComCaminho = RotuloModelo.formatar(nomeArquivo: "/Users/usuario/Models/qwen2.5-7b-instruct-q4_k_m.gguf")
    assert(rotuloComCaminho == "Qwen2.5 7B Instruct (Q4_K_M)", "Deve extrair lastPathComponent de caminhos absolutos: '\(rotuloComCaminho)'")

    // 11.2 Testes de rótulo combinado (Whisper + LLM)
    let combPronto = RotuloModelo.rotuloCombinado(
        whisperArquivo: "ggml-large-v3-turbo-q8_0.bin",
        statusLLM: .pronto("qwen2.5-7b-instruct-q4_k_m.gguf")
    )
    assert(combPronto == "Whisper large-v3-turbo (Q8_0) · Qwen2.5 7B Instruct (Q4_K_M)",
           "Falha no rótulo combinado pronto: '\(combPronto)'")

    let combCarregando = RotuloModelo.rotuloCombinado(
        whisperArquivo: "ggml-large-v3-turbo-q8_0.bin",
        statusLLM: .carregando
    )
    assert(combCarregando == "Whisper large-v3-turbo (Q8_0) · LLM: carregando…",
           "Falha no rótulo LLM carregando: '\(combCarregando)'")

    let combIndisponivel = RotuloModelo.rotuloCombinado(
        whisperArquivo: "ggml-large-v3-turbo-q8_0.bin",
        statusLLM: .indisponivel
    )
    assert(combIndisponivel == "Whisper large-v3-turbo (Q8_0) · LLM: indisponível (usando só Whisper)",
           "Falha no rótulo LLM indisponível: '\(combIndisponivel)'")

    let combSemWhisper = RotuloModelo.rotuloCombinado(
        whisperArquivo: nil,
        statusLLM: .carregando
    )
    assert(combSemWhisper == "Whisper: carregando… · LLM: carregando…",
           "Falha no rótulo inicial sem Whisper: '\(combSemWhisper)'")

    // 11.3 Testes de InfoApp (versão e build)
    assert(!InfoApp.versao.isEmpty, "Versão do app não pode ser vazia")
    assert(!InfoApp.build.isEmpty, "Build do app não pode ser vazia")
    assert(InfoApp.rotuloVersao.hasPrefix("v\(InfoApp.versao) (build "), "Formato do rótulo de versão incorreto: '\(InfoApp.rotuloVersao)'")
    print("✓ Todos os rótulos de versão do app e modelos de IA validados com sucesso!")

    // =========================================================================
    // SEÇÃO 12: Download de Modelos, Retomada e Verificações (Etapa 3)
    // =========================================================================
    print("\n[12/13] Testando catálogo de modelos, espaço em disco, SHA-256 e retomada com Range...")

    // 12.1 Recomendação por memória RAM
    let ram8GB: UInt64 = 8 * 1024 * 1024 * 1024
    let rec8 = CatalogoModelos.recomendarLLM(memoriaRAMBytes: ram8GB)
    assert(rec8.id == "qwen-1.5b", "8 GB deve recomendar Qwen 1.5B (obtido: \(rec8.id))")

    let ram16GB: UInt64 = 16 * 1024 * 1024 * 1024
    let rec16 = CatalogoModelos.recomendarLLM(memoriaRAMBytes: ram16GB)
    assert(rec16.id == "qwen-7b", "16 GB deve recomendar Qwen 7B (obtido: \(rec16.id))")

    let ram32GB: UInt64 = 32 * 1024 * 1024 * 1024
    let rec32 = CatalogoModelos.recomendarLLM(memoriaRAMBytes: ram32GB)
    assert(rec32.id == "qwen-7b", "32 GB deve recomendar Qwen 7B (obtido: \(rec32.id))")
    print("  ✓ Recomendação de LLM por memória RAM (8 GB -> 1.5B, 16/32 GB -> 7B) aprovada!")

    // 12.2 Cálculo e formatação de espaço em disco
    let strEspaco = VerificadorDisco.formatarBytes(874_188_075)
    assert(strEspaco.contains("MB") || strEspaco.contains("GB"), "Formatação de espaço inválida: '\(strEspaco)'")
    assert(VerificadorDisco.espacoSuficiente(necessario: 1024), "Disco deve ter pelo menos 1 KB de espaço livre")
    assert(!VerificadorDisco.espacoSuficiente(necessario: 500_000_000_000_000), "500 TB não devem ser considerados espaço suficiente")
    print("  ✓ Cálculo e validação de espaço em disco aprovados!")

    // 12.3 Verificação de Hash SHA-256 correta e incorreta
    let tempTesteDir = FileManager.default.temporaryDirectory.appendingPathComponent("dittado_teste_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempTesteDir, withIntermediateDirectories: true)
    let arqHash = tempTesteDir.appendingPathComponent("teste_hash.bin")
    let dadosHash = "Dittado 100% Local e Privado".data(using: .utf8)!
    try dadosHash.write(to: arqHash)

    let hashReal = try VerificadorHash.calcularSHA256(arquivoURL: arqHash)
    assert(VerificadorHash.verificarSHA256(arquivoURL: arqHash, hashEsperado: hashReal), "Hash correto deve retornar true")
    assert(!VerificadorHash.verificarSHA256(arquivoURL: arqHash, hashEsperado: "0000000000000000000000000000000000000000000000000000000000000000"), "Hash divergente deve retornar false")
    print("  ✓ Verificação estrita de hash SHA-256 aprovada!")

    // 12.4 Cancelamento limpando arquivo temporário .part
    let modeloFake = CatalogoModelos.ModeloInfo(
        id: "fake",
        nomeExibicao: "Modelo Fake",
        nomeArquivo: "modelo-fake.bin",
        url: URL(string: "https://example.com/fake.bin")!,
        tamanhoBytes: 100,
        tamanhoExibicao: "100 B",
        sha256: "fake",
        licenca: "MIT",
        ehWhisper: false,
        memoriaMinimaRecomendadaGB: 8,
        descricao: "Fake"
    )
    let gerenciadorFake = GerenciadorDownload(modelo: modeloFake, destinoPasta: tempTesteDir)
    try "parte".data(using: .utf8)!.write(to: gerenciadorFake.arquivoPart)
    assert(FileManager.default.fileExists(atPath: gerenciadorFake.arquivoPart.path), ".part deve existir")
    gerenciadorFake.cancelar()
    assert(!FileManager.default.fileExists(atPath: gerenciadorFake.arquivoPart.path), "cancelar() deve apagar o .part")
    print("  ✓ Cancelamento com exclusão de .part aprovado!")

    // 12.5 Retomada de .part com servidor local HTTP em localhost com Range
    let payloadCompleto = "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789".data(using: .utf8)! // 100 bytes
    let tempArqRange = tempTesteDir.appendingPathComponent("payload_esperado.bin")
    try payloadCompleto.write(to: tempArqRange)
    let hashPayload = try VerificadorHash.calcularSHA256(arquivoURL: tempArqRange)

    let servidor = ServidorLocalTesteRange(dados: payloadCompleto)
    servidor.iniciar()

    let modeloRange = CatalogoModelos.ModeloInfo(
        id: "range-teste",
        nomeExibicao: "Range Teste",
        nomeArquivo: "range-teste.bin",
        url: URL(string: "http://127.0.0.1:\(servidor.porta)/modelo.bin")!,
        tamanhoBytes: Int64(payloadCompleto.count),
        tamanhoExibicao: "100 B",
        sha256: hashPayload,
        licenca: "MIT",
        ehWhisper: false,
        memoriaMinimaRecomendadaGB: 8,
        descricao: "Range"
    )

    // Escreve os primeiros 40 bytes no .part para simular download interrompido de sessão anterior
    let arqPart = tempTesteDir.appendingPathComponent("range-teste.bin.part")
    let primeiros40 = payloadCompleto.subdata(in: 0..<40)
    try primeiros40.write(to: arqPart)

    let gerenciadorRange = GerenciadorDownload(modelo: modeloRange, destinoPasta: tempTesteDir)
    assert(gerenciadorRange.bytesRecebidos == 40, "Deve detectar 40 bytes existentes no .part")

    gerenciadorRange.iniciarOuRetomar()

    // Aguarda conclusão do download e validação do hash
    let limiteEspera = Date().addingTimeInterval(5)
    while Date() < limiteEspera {
        _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        if case .concluido = gerenciadorRange.estado { break }
    }
    servidor.parar()

    assert(gerenciadorRange.estado == .concluido(gerenciadorRange.arquivoFinal), "Download com Range deve concluir com sucesso")
    assert(FileManager.default.fileExists(atPath: gerenciadorRange.arquivoFinal.path), "Arquivo final deve existir")
    let dadosBaixados = try Data(contentsOf: gerenciadorRange.arquivoFinal)
    assert(dadosBaixados == payloadCompleto, "Dados retomados devem ser idênticos ao payload completo")
    assert(!FileManager.default.fileExists(atPath: gerenciadorRange.arquivoPart.path), "Arquivo .part deve ter sido renomeado para final")
    print("  ✓ Retomada de download com cabeçalho Range (HTTP 206) e validação SHA-256 aprovada!")

    // 12.6 Mapeamento dos rótulos novos (1.5B)
    let rotulo1_5B = RotuloModelo.formatar(nomeArquivo: "qwen2.5-1.5b-instruct-q4_k_m.gguf")
    assert(rotulo1_5B == "Qwen2.5 1.5B Instruct (Q4_K_M)", "Falha no rótulo Qwen 1.5B: '\(rotulo1_5B)'")

    let comb1_5B = RotuloModelo.rotuloCombinado(
        whisperArquivo: "ggml-large-v3-turbo-q8_0.bin",
        statusLLM: .pronto("qwen2.5-1.5b-instruct-q4_k_m.gguf")
    )
    assert(comb1_5B == "Whisper large-v3-turbo (Q8_0) · Qwen2.5 1.5B Instruct (Q4_K_M)",
           "Falha no rótulo combinado 1.5B: '\(comb1_5B)'")
    print("  ✓ Mapeamento e rótulos do Qwen2.5 1.5B validados!")

    // Limpeza da pasta temporária de teste
    try? FileManager.default.removeItem(at: tempTesteDir)
    print("✓ Todos os testes de download, retomada de .part e verificação (Etapa 3) aprovados com sucesso!")

    // =========================================================================
    // SEÇÃO 13: Benchmark de Latência Real (T5.2 - Amostras Reais + Ditado Longo de 60s)
    // =========================================================================
    print("\n[13/13] Executando Benchmark Real de Latência (11 Ditados, incluindo Ditado Longo de 60s)...")

    struct AmostraBenchmark {
        let id: Int
        let nome: String
        let modo: ModoDitado
        let texto: String
    }

    let textoLongo60s = "Então, pessoal, hoje nós vamos alinhar três pontos importantes para a entrega do projeto. Primeiro, a conferência dos cálculos estruturais no software da empresa. Segundo, a validação dos relatórios técnicos que precisamos enviar para a prefeitura até sexta-feira. E terceiro, o alinhamento com a equipe de campo para o início da concretagem na próxima semana. Se alguém tiver qualquer dúvida sobre os prazos ou os procedimentos, por favor me procurem logo após a reunião para alinharmos os detalhes."

    let amostras: [AmostraBenchmark] = [
        AmostraBenchmark(id: 1, nome: "Curto Livre (3 pal)", modo: .livre, texto: "bom dia pessoal"),
        AmostraBenchmark(id: 2, nome: "Curto Livre (5 pal)", modo: .livre, texto: "confirmando a reunião de amanhã"),
        AmostraBenchmark(id: 3, nome: "Lista 5 itens", modo: .livre, texto: "preciso comprar primeiro café segundo leite terceiro pão quarto queijo e quinto manteiga"),
        AmostraBenchmark(id: 4, nome: "E-mail Curto (8 pal)", modo: .prompt, texto: "para ana assunto ok combinado já estou enviando obrigado"),
        AmostraBenchmark(id: 5, nome: "E-mail Curto (11 pal)", modo: .prompt, texto: "para suporte assunto chamado segue o comprovante de pagamento em anexo obrigado"),
        AmostraBenchmark(id: 6, nome: "Livre Médio (14 pal)", modo: .livre, texto: "então hoje nós vamos alinhar as metas da semana novo parágrafo foco total no deploy"),
        AmostraBenchmark(id: 7, nome: "E-mail Médio (15 pal)", modo: .prompt, texto: "para pedro assunto deploy o deploy foi concluído com sucesso qualquer dúvida me avise obrigado"),
        AmostraBenchmark(id: 8, nome: "Lista 3 itens", modo: .livre, texto: "temos três etapas primeiro planejamento segundo desenvolvimento e terceiro homologação"),
        AmostraBenchmark(id: 9, nome: "E-mail Formal (18 pal)", modo: .prompt, texto: "para diretoria assunto orçamento segue a cotação aprovada para o projeto dittado com todos os anexos atenciosamente"),
        AmostraBenchmark(id: 10, nome: "E-mail Longo (24 pal)", modo: .prompt, texto: "para fornecedor assunto contrato bom dia encaminhamos a minuta revisada com os itens 10 e 12 do anexo técnico conforme alinhado ontem obrigado"),
        AmostraBenchmark(id: 11, nome: "Longo 60s (71 pal, log)", modo: .livre, texto: textoLongo60s)
    ]

    var latenciasTotais: [Double] = []
    var latenciasCurtos: [Double] = []
    var latenciasUsaramLLM: [Double] = []

    print("-------------------------------------------------------------------------------------------------------------------")
    print(" ID  | Descrição                | Modo         | Palavras | Parser    | LLM       | Total     ")
    print("-------------------------------------------------------------------------------------------------------------------")

    for a in amostras {
        let nPalavras = a.texto.split { $0.isWhitespace }.count
        let tInicio = Date()
        let res = runSync {
            await Formatador.formatarComMetricas(texto: a.texto, modo: a.modo, motor: motorLLMInstanciado)
        }
        let dtTotal = Date().timeIntervalSince(tInicio)
        latenciasTotais.append(dtTotal)

        let ehCurto = nPalavras <= 15
        if ehCurto {
            latenciasCurtos.append(dtTotal)
        }

        if res.duracaoLLM > 0.05 {
            latenciasUsaramLLM.append(res.duracaoLLM)
        }

        let descPadded = a.nome.padding(toLength: 24, withPad: " ", startingAt: 0)
        let modoPadded = a.modo.nomeExibicao.padding(toLength: 12, withPad: " ", startingAt: 0)
        print(String(format: "#%-3d | %@ | %@ | %-8d | %6.3f s | %6.2f s | %6.2f s",
                     a.id, descPadded, modoPadded, nPalavras, res.duracaoParser, res.duracaoLLM, dtTotal))
    }
    print("-------------------------------------------------------------------------------------------------------------------")

    func calcularMediana(_ valores: [Double]) -> Double {
        guard !valores.isEmpty else { return 0 }
        let ordenados = valores.sorted()
        let meio = ordenados.count / 2
        if ordenados.count % 2 == 0 {
            return (ordenados[meio - 1] + ordenados[meio]) / 2.0
        } else {
            return ordenados[meio]
        }
    }

    let medianaTotal = calcularMediana(latenciasTotais)
    let medianaCurtos = calcularMediana(latenciasCurtos)
    let medianaLLM = calcularMediana(latenciasUsaramLLM)

    print(String(format: "📊 Mediana Geral (11 ditados): %.2f s (%d ms)", medianaTotal, Int(medianaTotal * 1000)))
    print(String(format: "🎯 Mediana Ditados Curtos (<= 15 palavras): %.2f s (%d ms)", medianaCurtos, Int(medianaCurtos * 1000)))
    print(String(format: "🧠 Mediana Ditados que Usaram LLM: %.2f s (%d ms)", medianaLLM, Int(medianaLLM * 1000)))
    print(String(format: "⚡ Meta (< 1.5 s em ditados curtos): %@", medianaCurtos < 1.5 ? "ATINGIDA COM SUCESSO! ✓" : "NÃO ATINGIDA"))

    print("\n===========================================================")
    print("  TODAS AS ASSERÇÕES DA SUÍTE UNIFICADA PASSARAM COM SUCESSO! ")
    print("===========================================================")
    motorLLMInstanciado?.encerrar()
    motorLLMInstanciado = nil
    exit(0)
}

// Suporte para gravação e transcrição CLI
if let i = args.firstIndex(of: "--gravar") {
    let segundos = Double(args.count > i + 1 ? args[i + 1] : "2") ?? 2
    let g = GravadorDeAudio()
    g.politica = args.contains("--padrao") ? .padraoDoSistema : (args.contains("--mac") ? .sempreMacBook : .automatico)
    g.aoRegistrar = { print("[log] \($0)") }
    var ultimo: [Float] = []
    for n in 1...3 {
        do {
            try g.iniciar()
            Thread.sleep(forTimeInterval: segundos)
            let a = g.parar()
            ultimo = a
            print(String(format: "Gravação %d: %@ → %.1f s, nível %.4f", n, g.descricao,
                         Double(a.count) / 16_000, nivelRMS(a)))
        } catch {
            print("Gravação \(n): erro \(error)")
        }
    }
    if args.contains("--transcrever"), let motor = try? WhisperEngine(modelPath: modelo) {
        print("Última gravação: " + ((try? motor.transcrever(ultimo)) ?? "erro"))
    }
    exit(0)
}

do {
    let t0 = Date()
    let motor = try WhisperEngine(modelPath: modelo)
    print(String(format: "Modelo carregado em %.2f s", Date().timeIntervalSince(t0)))
    for caminho in args {
        let audio = try carregarAudio(URL(fileURLWithPath: caminho))
        let t1 = Date()
        var texto = try motor.transcrever(audio)
        if modoPrompt { texto = LimpezaSimples.aplicar(texto) }
        let dt = Date().timeIntervalSince(t1)
        let dur = Double(audio.count) / Double(WhisperEngine.amostrasPorSegundo)
        print(String(format: "\n[%@] áudio %.1f s → %.2f s", (caminho as NSString).lastPathComponent, dur, dt))
        print(texto)
    }
} catch {
    print("Erro: \(error)"); exit(1)
}

class ServidorLocalTesteRange {
    let listenerSocket: Int32
    var porta: in_port_t = 0
    let dadosCompletos: Data
    var thread: Thread?
    var executando = true

    init(dados: Data) {
        self.dadosCompletos = dados
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        self.listenerSocket = sock
        var opt: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0

        withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                _ = bind(sock, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        _ = listen(sock, 5)

        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                _ = getsockname(sock, sa, &len)
            }
        }
        self.porta = in_port_t(UInt16(bigEndian: addr.sin_port))
    }

    func iniciar() {
        thread = Thread { [weak self] in
            while let self = self, self.executando {
                var clientAddr = sockaddr_in()
                var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                let clientSock = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        accept(self.listenerSocket, sa, &clientLen)
                    }
                }
                guard clientSock >= 0 else { continue }

                var buf = [UInt8](repeating: 0, count: 4096)
                let lidos = read(clientSock, &buf, 4096)
                guard lidos > 0 else { close(clientSock); continue }
                let reqStr = String(bytes: buf[0..<lidos], encoding: .utf8) ?? ""

                var offset: Int = 0
                var isRange = false
                if let rMatch = reqStr.range(of: "Range: bytes=") {
                    let sub = reqStr[rMatch.upperBound...]
                    if let dash = sub.firstIndex(of: "-") {
                        let numStr = String(sub[..<dash]).trimmingCharacters(in: .whitespaces)
                        if let off = Int(numStr) {
                            offset = off
                            isRange = true
                        }
                    }
                }

                let respData: Data
                let header: String
                if isRange && offset < self.dadosCompletos.count {
                    let sub = self.dadosCompletos.subdata(in: offset..<self.dadosCompletos.count)
                    header = "HTTP/1.1 206 Partial Content\r\nContent-Length: \(sub.count)\r\nContent-Range: bytes \(offset)-\(self.dadosCompletos.count - 1)/\(self.dadosCompletos.count)\r\nConnection: close\r\n\r\n"
                    respData = header.data(using: .utf8)! + sub
                } else {
                    header = "HTTP/1.1 200 OK\r\nContent-Length: \(self.dadosCompletos.count)\r\nConnection: close\r\n\r\n"
                    respData = header.data(using: .utf8)! + self.dadosCompletos
                }

                _ = respData.withUnsafeBytes { ptr in
                    write(clientSock, ptr.baseAddress, respData.count)
                }
                close(clientSock)
            }
        }
        thread?.start()
    }

    func parar() {
        executando = false
        close(listenerSocket)
        thread?.cancel()
    }
}

func runSync<T>(_ block: @escaping () async -> T) -> T {
    let semaforo = DispatchSemaphore(value: 0)
    var result: T?
    Task {
        result = await block()
        semaforo.signal()
    }
    semaforo.wait()
    return result!
}
