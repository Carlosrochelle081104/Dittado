import AppKit
import AVFoundation
import DittadoCore
import DittadoWhisper
import DittadoLLM

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var itemBarra: NSStatusItem!
    private let atalho = AtalhoGlobal()
    private let gravador = GravadorDeAudio()
    private let indicador = Indicador()
    private let historico = Historico()
    private let estado = EstadoApp()
    private let config = Config.shared
    private lazy var painel = JanelaPainel(estado: estado, historico: historico)
    private let filaTranscricao = DispatchQueue(label: "dittado.transcricao", qos: .userInitiated)

    private var motor: WhisperEngine?
    private var llm: LLMEngine?
    private var modoAtual: ModoDitado = .livre
    private var inicioGravacao = Date()

    /// Opção de depuração: `defaults write <bundle_id> salvarAudio -bool YES` guarda o último áudio.
    private var salvarAudio: Bool { UserDefaults.standard.bool(forKey: "salvarAudio") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("Boot inicial: Dittado \(InfoApp.rotuloVersao)")
        if !salvarAudio {
            let u = Pastas.suporte.appendingPathComponent("ultimo-audio.wav")
            if FileManager.default.fileExists(atPath: u.path) { try? FileManager.default.removeItem(at: u) }
        }
        itemBarra = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        atualizarIcone(gravando: false)
        let menu = NSMenu()
        menu.delegate = self
        itemBarra.menu = menu

        gravador.aoRegistrar = { msg in log(msg) }
        configurarAtalho()
        pedirPermissoes()
        indicador.mostrar(.aviso("Dittado abrindo… carregando o modelo"))
        carregarMotor()

        // Troca ou conclusão de download de modelo no onboarding / gerenciador
        JanelaOnboarding.shared.aoConcluirOuMudarModelo = { [weak self] modeloEscolhido in
            self?.recarregarLLM(nomeModelo: modeloEscolhido)
        }

        // Se o modelo obrigatório Whisper não estiver no disco, abre o Onboarding inicial
        if !FileManager.default.fileExists(atPath: Pastas.modeloWhisperPadrao.path) {
            JanelaOnboarding.shared.mostrar(passoInicial: .boasVindas)
        }

        // A permissão de Acessibilidade pode chegar com o app aberto
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            let ok = AXIsProcessTrusted()
            if ok != self.estado.acessibilidade { self.estado.acessibilidade = ok }
        }
    }

    /// Sai direto: os destrutores do Metal do whisper.cpp abortam no exit() normal.
    func applicationWillTerminate(_ notification: Notification) {
        _exit(0)
    }

    /// Abrir de novo pelo Spotlight/Finder com o app já rodando: abre o painel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        painel.mostrar()
        return false
    }

    private func mostrarEstado() {
        let msg: String
        if !estado.motorPronto { msg = "Dittado: carregando o modelo…" }
        else if !estado.atalhoAtivo { msg = "Dittado: falta permissão de Monitoramento de Entrada" }
        else if !AXIsProcessTrusted() { msg = "Dittado: falta permissão de Acessibilidade" }
        else { msg = "Dittado pronto — \(config.atalhoLivre.nome) para falar" }
        indicador.mostrar(.aviso(msg), por: 3)
    }

    // MARK: - Inicialização

    private func carregarMotor() {
        filaTranscricao.async { [weak self] in
            let t0 = Date()
            let whisperArquivo = Pastas.modeloWhisperPadrao.lastPathComponent
            do {
                let m = try WhisperEngine(modelPath: Pastas.modeloWhisperPadrao.path)
                _ = try? m.transcrever([Float](repeating: 0, count: 16_000))  // aquece o Metal
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.motor = m
                    self.estado.motorPronto = true
                    self.estado.modeloWhisperCarregado = whisperArquivo
                    self.estado.statusLLM = .carregando
                    self.estado.statusMotor = "Whisper pronto · carregando LLM…"
                    log("Motor Whisper carregado em \(Date().timeIntervalSince(t0)) s")
                    log("Boot: Dittado \(InfoApp.rotuloVersao) | Modelos: \(self.estado.rotuloModelosCompleto)")
                    self.mostrarEstado()
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.estado.statusMotor = "Erro Whisper: \(error)"
                    self.estado.statusLLM = .indisponivel
                    log("Boot: Dittado \(InfoApp.rotuloVersao) | Erro Whisper: \(error)")
                }
                log("Erro ao carregar motor: \(error)")
                return
            }

            // T1: Carrega e aquece o modelo LLM em background (se habilitado)
            let nomeLLMConfigurado = Pastas.nomeModeloLLM
            if nomeLLMConfigurado == "nenhum" || nomeLLMConfigurado.isEmpty {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.estado.statusLLM = .indisponivel
                    self.estado.statusMotor = "Whisper turbo pronto (sem LLM)"
                    log("Boot: Dittado \(InfoApp.rotuloVersao) | Modelos: \(self.estado.rotuloModelosCompleto)")
                }
                return
            }

            let urlLLM = Pastas.modeloLLMPadrao
            let llmArquivo = urlLLM.lastPathComponent
            if FileManager.default.fileExists(atPath: urlLLM.path) {
                let tLLM = Date()
                do {
                    let l = try LLMEngine(modelPath: urlLLM.path)
                    let promptAquecimento = Formatador.promptProfissional + GerenciadorVocabulario.shared.formatarParaLLM()
                    l.aquecer(sistema: promptAquecimento)
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.llm = l
                        self.estado.statusLLM = .pronto(llmArquivo)
                        let rotuloLLM = RotuloModelo.formatar(nomeArquivo: llmArquivo)
                        self.estado.statusMotor = "Pronto (\(rotuloLLM))"
                        log(String(format: "LLM %@ carregado e aquecido com KV cache em %.2f s", rotuloLLM, Date().timeIntervalSince(tLLM)))
                        log("Boot: Dittado \(InfoApp.rotuloVersao) | Modelos: \(self.estado.rotuloModelosCompleto)")
                    }
                } catch {
                    log("Aviso: Falha ao carregar LLM (\(error)). O ditado seguirá com texto bruto do Whisper.")
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.estado.statusLLM = .indisponivel
                        self.estado.statusMotor = "Whisper pronto (LLM indisponível)"
                        log("Boot: Dittado \(InfoApp.rotuloVersao) | Modelos: \(self.estado.rotuloModelosCompleto)")
                    }
                }
            } else {
                log("Aviso: Modelo LLM não encontrado em \(urlLLM.path)")
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.estado.statusLLM = .indisponivel
                    self.estado.statusMotor = "Whisper turbo pronto"
                    log("Boot: Dittado \(InfoApp.rotuloVersao) | Modelos: \(self.estado.rotuloModelosCompleto)")
                }
            }
        }
    }

    /// Recarrega o modelo LLM em background de forma reativa sem reiniciar o aplicativo.
    func recarregarLLM(nomeModelo: String?) {
        filaTranscricao.async { [weak self] in
            guard let self else { return }
            self.llm?.encerrar()
            self.llm = nil

            guard let nome = nomeModelo, !nome.isEmpty, nome != "nenhum" else {
                UserDefaults.standard.set("nenhum", forKey: "nomeModeloLLM")
                DispatchQueue.main.async {
                    self.estado.statusLLM = .indisponivel
                    self.estado.statusMotor = "Whisper turbo pronto (sem LLM)"
                    log("LLM desativado. Dittado operando com Whisper e regras determinísticas.")
                }
                return
            }

            UserDefaults.standard.set(nome, forKey: "nomeModeloLLM")
            let urlLLM = Pastas.modelos.appendingPathComponent(nome)
            guard FileManager.default.fileExists(atPath: urlLLM.path) else {
                DispatchQueue.main.async {
                    self.estado.statusLLM = .indisponivel
                    self.estado.statusMotor = "Whisper pronto (LLM indisponível)"
                    log("Aviso: Modelo LLM \(nome) não encontrado no disco.")
                }
                return
            }

            let tLLM = Date()
            do {
                let l = try LLMEngine(modelPath: urlLLM.path)
                let promptAquecimento = Formatador.promptProfissional + GerenciadorVocabulario.shared.formatarParaLLM()
                l.aquecer(sistema: promptAquecimento)
                DispatchQueue.main.async {
                    self.llm = l
                    self.estado.statusLLM = .pronto(nome)
                    let rotuloLLM = RotuloModelo.formatar(nomeArquivo: nome)
                    self.estado.statusMotor = "Pronto (\(rotuloLLM))"
                    log(String(format: "LLM %@ carregado e aquecido em %.2f s", rotuloLLM, Date().timeIntervalSince(tLLM)))
                    log("Modelos atualizados: \(self.estado.rotuloModelosCompleto)")
                }
            } catch {
                log("Falha ao carregar LLM \(nome): \(error)")
                DispatchQueue.main.async {
                    self.estado.statusLLM = .indisponivel
                    self.estado.statusMotor = "Whisper pronto (erro no LLM)"
                }
            }
        }
    }

    private func configurarAtalho() {
        atalho.aoIniciar = { [weak self] modo in self?.iniciarGravacao(modo) }
        atalho.aoMudarModo = { [weak self] modo in
            self?.modoAtual = modo
            self?.indicador.mostrar(.gravando, modo: modo)
        }
        atalho.aoTravar = { [weak self] in
            guard let self, self.gravador.gravando else { return }
            self.indicador.mostrar(.travado, modo: self.modoAtual)
        }
        atalho.aoTerminar = { [weak self] in self?.terminarGravacao() }
        atalho.aoCancelar = { [weak self] in self?.cancelarGravacao() }
        estado.atalhoAtivo = atalho.iniciar()
        if !estado.atalhoAtivo {
            // Sem permissão ainda: tenta de novo a cada 2 s até o usuário liberar
            Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
                guard let self else { t.invalidate(); return }
                if self.atalho.iniciar() { self.estado.atalhoAtivo = true; t.invalidate() }
            }
        }
    }

    private func pedirPermissoes() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        if !CGPreflightListenEventAccess() { CGRequestListenEventAccess() }
        let opcoes = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opcoes)
    }

    // MARK: - Gravação

    private func iniciarGravacao(_ modo: ModoDitado) {
        guard !gravador.gravando else { return }
        guard motor != nil else {
            atalho.reiniciar()
            indicador.mostrar(.aviso("Carregando modelo, aguarde…"), por: 1.5)
            return
        }
        modoAtual = modo
        gravador.aoMudarNivel = { [weak self] n in
            DispatchQueue.main.async { self?.indicador.estado.nivel = n }
        }
        gravador.politica = config.microfone
        do {
            try gravador.iniciar()
        } catch {
            atalho.reiniciar()
            indicador.mostrar(.aviso("Microfone indisponível"), por: 2)
            log("Erro no microfone: \(error)")
            return
        }
        inicioGravacao = Date()
        log("Gravando: \(gravador.descricao)")
        estado.microfoneAtual = gravador.descricao
        tocar("Tink")
        atualizarIcone(gravando: true)
        indicador.mostrar(.gravando, modo: modo)
    }

    private func cancelarGravacao() {
        guard gravador.gravando else { return }
        _ = gravador.parar()
        atualizarIcone(gravando: false)
        indicador.mostrar(.aviso("Cancelado"), por: 0.7)
    }

    private func terminarGravacao() {
        guard gravador.gravando else { return }
        let audio = gravador.parar()
        atualizarIcone(gravando: false)
        let duracao = Double(audio.count) / Double(WhisperEngine.amostrasPorSegundo)
        log(String(format: "Parou: %.1f s de áudio, nível %.4f", duracao, nivelRMS(audio)))
        guard duracao >= 0.3 else { indicador.esconder(); return }
        guard nivelRMS(audio) > 0.0008 else {
            indicador.mostrar(.aviso("Não ouvi nada — microfone mudo?"), por: 1.5); return
        }
        tocar("Pop")
        let modo = modoAtual
        let app = NSWorkspace.shared.frontmostApplication?.localizedName
        indicador.mostrar(.transcrevendo)
        let urlAudio = Pastas.suporte.appendingPathComponent("ultimo-audio.wav")
        if salvarAudio {
            try? salvarWAV(audio, em: urlAudio)
        } else if FileManager.default.fileExists(atPath: urlAudio.path) {
            try? FileManager.default.removeItem(at: urlAudio)
        }

        filaTranscricao.async { [weak self] in
            guard let self, let motor = self.motor else { return }
            let t0 = Date()
            let tWhisper0 = Date()
            let textoBruto = (try? motor.transcrever(audio)) ?? ""
            let dtWhisper = Date().timeIntervalSince(tWhisper0)
            guard !textoBruto.isEmpty else {
                DispatchQueue.main.async {
                    log(String(format: "%@ | áudio %.1f s | Whisper %.2f s | vazio", modo.rawValue, duracao, dtWhisper))
                    self.indicador.mostrar(.aviso("Não entendi, tente de novo"), por: 1.5)
                }
                return
            }

            Task { [weak self] in
                guard let self else { return }
                // T2, T3 e T5: Formatação com registro dos tempos de Parser e LLM
                let formatacao = await Formatador.formatarComMetricas(texto: textoBruto, modo: modo, motor: self.llm)
                let texto = formatacao.texto
                let dtParser = formatacao.duracaoParser
                let dtLLM = formatacao.duracaoLLM
                let dtTotal = Date().timeIntervalSince(t0)

                await MainActor.run {
                    self.historico.adicionar(ItemHistorico(data: Date(), modo: modo, texto: texto, app: app,
                                                           segundosAudio: duracao, segundosTranscricao: dtTotal))
                    let resultado = InseridorDeTexto.inserir(texto)
                    let nPalavras = texto.split { $0.isWhitespace }.count
                    let registrarTexto = Config.shared.registrarTexto
                    let detalheTexto = registrarTexto ? " | \(texto)" : ""
                    log(String(format: "%@ | %@ | áudio %.1f s | Whisper %.2f s | Parser %.3f s | LLM %.2f s | Total %.2f s | %@ | %d chars (%d pal)%@",
                               modo.rawValue, app ?? "?", duracao, dtWhisper, dtParser, dtLLM, dtTotal, "\(resultado)", texto.count, nPalavras, detalheTexto))
                    switch resultado {
                    case .colado: self.indicador.esconder()
                    case .coladoECopiado: self.indicador.mostrar(.aviso("✓ Colado (também copiado)"), por: 1)
                    case .soCopiado: self.indicador.mostrar(.aviso("Sem campo de texto — copiado ✓"), por: 2)
                    }
                }
            }
        }
    }

    private func tocar(_ som: String) {
        guard config.sons else { return }
        let s = NSSound(named: NSSound.Name(som))
        s?.volume = 0.25
        s?.play()
    }

    private func atualizarIcone(gravando: Bool) {
        estado.gravando = gravando
        let nome = gravando ? "waveform.circle.fill" : "waveform"
        itemBarra.button?.image = NSImage(systemSymbolName: nome, accessibilityDescription: "Dittado")
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(desabilitado("Dittado \(InfoApp.rotuloVersao) — \(estado.rotuloModelosCompleto)"))
        menu.addItem(desabilitado("Livre: \(config.atalhoLivre.nome) · Profissional: \(config.atalhoPrompt.nome)"))
        if !estado.atalhoAtivo { menu.addItem(desabilitado("⚠️ Falta permissão de Monitoramento de Entrada")) }
        if !AXIsProcessTrusted() { menu.addItem(desabilitado("⚠️ Falta permissão de Acessibilidade (para colar)")) }
        menu.addItem(.separator())
        menu.addItem(acao("Abrir painel…", #selector(abrirPainel), tecla: ","))
        menu.addItem(acao("Gerenciar modelos de IA…", #selector(abrirGerenciadorModelos)))
        menu.addItem(acao("Configuração inicial…", #selector(abrirOnboarding)))

        let sub = NSMenu()
        for item in historico.itens.prefix(10) {
            let titulo = item.texto.count > 60 ? String(item.texto.prefix(60)) + "…" : item.texto
            let mi = NSMenuItem(title: titulo, action: #selector(copiarDoHistorico(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = item.texto
            mi.toolTip = item.texto
            sub.addItem(mi)
        }
        if historico.itens.isEmpty { sub.addItem(desabilitado("Vazio")) }
        let hist = NSMenuItem(title: "Histórico (clique para copiar)", action: nil, keyEquivalent: "")
        hist.submenu = sub
        menu.addItem(hist)

        menu.addItem(.separator())
        menu.addItem(acao("Abrir pasta do Dittado", #selector(abrirPasta)))
        menu.addItem(acao("Sair do Dittado", #selector(sair), tecla: "q"))
    }

    private func desabilitado(_ t: String) -> NSMenuItem {
        let i = NSMenuItem(title: t, action: nil, keyEquivalent: ""); i.isEnabled = false; return i
    }

    private func acao(_ t: String, _ s: Selector, tecla: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: t, action: s, keyEquivalent: tecla); i.target = self; return i
    }

    @objc private func copiarDoHistorico(_ sender: NSMenuItem) {
        guard let texto = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(texto, forType: .string)
    }

    @objc private func abrirPainel() { painel.mostrar() }
    @objc private func abrirGerenciadorModelos() { JanelaOnboarding.shared.mostrar(passoInicial: .gerenciarModelos) }
    @objc private func abrirOnboarding() { JanelaOnboarding.shared.mostrar(passoInicial: .boasVindas) }
    @objc private func abrirPasta() { NSWorkspace.shared.open(Pastas.suporte) }
    @objc private func sair() { NSApp.terminate(nil) }
}

func log(_ msg: String) {
    let linha = "\(ISO8601DateFormatter().string(from: Date())) \(msg)\n"
    let url = Pastas.suporte.appendingPathComponent("dittado.log")

    // Rotação de log a 1 MB, preservando 1 arquivo antigo (dittado.log.1)
    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
       let tamanho = attrs[.size] as? Int64, tamanho >= 1_000_000 {
        let urlAntigo = Pastas.suporte.appendingPathComponent("dittado.log.1")
        try? FileManager.default.removeItem(at: urlAntigo)
        try? FileManager.default.moveItem(at: url, to: urlAntigo)
    }

    if let h = try? FileHandle(forWritingTo: url) {
        h.seekToEndOfFile(); h.write(linha.data(using: .utf8)!); try? h.close()
    } else {
        try? linha.write(to: url, atomically: true, encoding: .utf8)
    }
}
