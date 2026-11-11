import AppKit
import SwiftUI
import DittadoCore

/// Estado do app mostrado no painel.
final class EstadoApp: ObservableObject {
    @Published var statusMotor = "Carregando modelo…"
    @Published var motorPronto = false
    @Published var atalhoAtivo = false
    @Published var acessibilidade = AXIsProcessTrusted()
    @Published var gravando = false
    @Published var microfoneAtual = ""
    @Published var modeloWhisperCarregado: String? = nil
    @Published var statusLLM: RotuloModelo.StatusLLM = .carregando

    var rotuloModelosCompleto: String {
        RotuloModelo.rotuloCombinado(whisperArquivo: modeloWhisperCarregado, statusLLM: statusLLM)
    }
}

/// Janela do painel: atalhos, comportamento e últimas transcrições.
/// A janela é destruída ao fechar, para a animação não gastar processador em segundo plano.
final class JanelaPainel: NSObject, NSWindowDelegate {
    private var janela: NSWindow?
    private let estado: EstadoApp
    private let historico: Historico

    init(estado: EstadoApp, historico: Historico) {
        self.estado = estado
        self.historico = historico
    }

    func windowWillClose(_ notification: Notification) {
        janela?.contentView = nil
        janela = nil
    }

    func mostrar() {
        estado.acessibilidade = AXIsProcessTrusted()
        let j = janela ?? criar()
        NSApp.activate(ignoringOtherApps: true)
        j.makeKeyAndOrderFront(nil)
    }

    private func criar() -> NSWindow {
        let j = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        j.title = "Dittado"
        j.titlebarAppearsTransparent = true
        j.titleVisibility = .hidden
        j.isReleasedWhenClosed = false
        j.isMovableByWindowBackground = true
        j.minSize = NSSize(width: 560, height: 560)

        let vista = NSHostingView(rootView: VistaPainel(estado: estado, historico: historico, config: .shared))
        vista.sizingOptions = []  // tamanho fixo pela janela: sem recalcular layout a cada quadro
        j.contentView = vista
        j.delegate = self
        j.center()
        janela = j
        return j
    }
}

// MARK: - Vistas (Linguagem Visual Wispr Flow)

private struct VistaPainel: View {
    @ObservedObject var estado: EstadoApp
    @ObservedObject var historico: Historico
    @ObservedObject var config: Config

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Cabecalho(estado: estado)
                if !estado.atalhoAtivo || !estado.acessibilidade {
                    Permissoes(estado: estado)
                }
                CartaoModelos(estado: estado)
                CartaoAtalhos(config: config)
                if !estado.microfoneAtual.isEmpty {
                    BarraMicrofone(nome: estado.microfoneAtual)
                }
                CartaoVocabulario(config: config)
                CartaoHistorico(historico: historico, config: config)
            }
            .padding(.horizontal, 22)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor).opacity(0.86)
                Rectangle().fill(.ultraThinMaterial)
            }
            .ignoresSafeArea()
        )
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: estado.acessibilidade)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: estado.atalhoAtivo)
    }
}

// MARK: - Cabeçalho

private struct Cabecalho: View {
    @ObservedObject var estado: EstadoApp

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    )
                OndaAnimada(ativa: estado.gravando)
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Dittado")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(InfoApp.rotuloVersao)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }
                HStack(spacing: 7) {
                    Circle()
                        .fill(corStatus)
                        .frame(width: 8, height: 8)
                        .shadow(color: corStatus.opacity(0.6), radius: 4, y: 0)
                    Text(textoStatus)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                )

                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(estado.rotuloModelosCompleto)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }

            Spacer()

            Button {
                JanelaOnboarding.shared.mostrar(passoInicial: .gerenciarModelos)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                    Text("Gerenciar…")
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
            .help("Gerenciar e trocar modelos de IA instalados")
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tema.degrade)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: Tema.roxo.opacity(0.28), radius: 16, y: 6)
    }

    private var pronto: Bool {
        estado.motorPronto && estado.atalhoAtivo && estado.acessibilidade
    }

    private var corStatus: Color {
        if estado.gravando { return Color(red: 1.0, green: 0.32, blue: 0.32) }
        return pronto ? Color(red: 0.22, green: 0.84, blue: 0.48) : Color(red: 1.0, green: 0.76, blue: 0.24)
    }

    private var textoStatus: String {
        if estado.gravando { return "Ouvindo…" }
        if !estado.motorPronto { return estado.statusMotor }
        return pronto ? "Pronto · 100% local neste Mac" : "Falta permissão"
    }
}

/// Ondas sonoras estilizadas do ícone
private struct OndaAnimada: View {
    let ativa: Bool
    private let alturas: [CGFloat] = [14, 24, 38, 24, 14]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(ativa ? 1.0 : 0.92))
                    .frame(width: 4.5, height: alturas[i])
                    .scaleEffect(y: ativa ? 1.15 : 1.0)
                    .animation(
                        ativa ? .easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(Double(i) * 0.08) : .default,
                        value: ativa
                    )
            }
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Cartão Translúcido

private struct Cartao<Conteudo: View>: View {
    let titulo: String
    let icone: String
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icone)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tema.degrade)
                Text(titulo)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            conteudo
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.regularMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 3)
    }
}

// MARK: - Permissões

private struct Permissoes: View {
    @ObservedObject var estado: EstadoApp

    var body: some View {
        Cartao(titulo: "Permissões", icone: "lock.shield") {
            if !estado.acessibilidade {
                linha("Acessibilidade (para colar o texto)", "Privacy_Accessibility")
            }
            if !estado.atalhoAtivo {
                linha("Monitoramento de Entrada (para o atalho)", "Privacy_ListenEvent")
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func linha(_ t: String, _ painel: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(red: 1.0, green: 0.74, blue: 0.2))
                .font(.system(size: 14))
            Text(t)
                .font(.system(size: 13, design: .rounded))
            Spacer()
            Button("Abrir ajustes") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(painel)") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.yellow.opacity(0.1))
        )
    }
}

// MARK: - Cartão de Modelos

private struct CartaoModelos: View {
    @ObservedObject var estado: EstadoApp

    var body: some View {
        Cartao(titulo: "Modelos de Inteligência Artificial", icone: "cpu") {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(estado.rotuloModelosCompleto)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Whisper para transcrição nativa e Qwen para estruturação inteligente.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button("Gerenciar modelos…") {
                    JanelaOnboarding.shared.mostrar(passoInicial: .gerenciarModelos)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(.system(size: 12, weight: .medium, design: .rounded))
            }
        }
    }
}

// MARK: - Cartão de Atalhos

private struct CartaoAtalhos: View {
    @ObservedObject var config: Config

    private var opcoes: [Atalho] {
        Tecla.allCases.flatMap { [Atalho(tecla: $0, comShift: false), Atalho(tecla: $0, comShift: true)] }
    }

    var body: some View {
        Cartao(titulo: "Atalhos", icone: "keyboard") {
            linhaAtalho("Modo Livre", "Transcreve quase tudo o que você fala", .livre, $config.atalhoLivre)
            Divider().opacity(0.6)
            linhaAtalho("Modo Profissional", "Reescreve como e-mail ou mensagem corporativa", .prompt, $config.atalhoPrompt)

            if config.atalhoLivre == config.atalhoPrompt {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text("Os dois modos estão com o mesmo atalho. Escolha atalhos diferentes.")
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.orange)
                .padding(.vertical, 4)
            }

            Divider().opacity(0.6)

            VStack(alignment: .leading, spacing: 8) {
                Text("Como a tecla funciona")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Picker("", selection: $config.comportamento.animation(.spring(response: 0.35))) {
                    ForEach(Comportamento.allCases) { Text($0.nome).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(config.comportamento.explicacao)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .id(config.comportamento)
                    .transition(.opacity.combined(with: .move(edge: .leading)))

                Text("Esc cancela a gravação a qualquer momento.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Divider().opacity(0.6)

            VStack(alignment: .leading, spacing: 8) {
                Text("Microfone")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Picker("", selection: $config.microfone) {
                    ForEach(PoliticaMicrofone.allCases) { Text($0.nome).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(config.microfone.explicacao)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
            }

            Divider().opacity(0.6)

            Toggle("Sons ao começar e terminar", isOn: $config.sons)
                .toggleStyle(.switch)
                .tint(Tema.roxo)
                .font(.system(size: 13, weight: .medium, design: .rounded))

            Toggle("Abrir o Dittado quando o Mac ligar", isOn: $config.abrirAoIniciar)
                .toggleStyle(.switch)
                .tint(Tema.roxo)
                .font(.system(size: 13, weight: .medium, design: .rounded))

            Divider().opacity(0.6)

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Registrar texto no log (depuração)", isOn: $config.registrarTexto)
                    .toggleStyle(.switch)
                    .tint(Tema.roxo)
                    .font(.system(size: 13, weight: .medium, design: .rounded))

                Text("Por padrão, o log registra apenas tempos e erros para proteger sua privacidade.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
        }
    }

    private func linhaAtalho(_ titulo: String, _ desc: String, _ modo: ModoDitado, _ sel: Binding<Atalho>) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Tema.cor(modo))
                .frame(width: 10, height: 10)
                .shadow(color: Tema.cor(modo).opacity(0.4), radius: 4, y: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(desc)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: sel) {
                ForEach(opcoes, id: \.nome) { Text($0.nome).tag($0) }
            }
            .labelsHidden()
            .frame(width: 220)
            .font(.system(size: 12, design: .rounded))
        }
    }
}

// MARK: - Barra de Microfone Ativo

private struct BarraMicrofone: View {
    let nome: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Última gravação pelo microfone: \(nome)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

// MARK: - Cartão de Vocabulário Personalizado

private struct CartaoVocabulario: View {
    @ObservedObject var config: Config
    @State private var novoTermo = ""
    @State private var novasVariantes = ""
    @State private var erroValidacao: String?
    @State private var indiceEdicao: Int?
    @State private var textoEdicao = ""
    @State private var variantesEdicao = ""

    var body: some View {
        Cartao(titulo: "Vocabulário Personalizado", icone: "character.book.closed") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Adicione nomes próprios, siglas e termos técnicos. Você também pode cadastrar variantes (como você fala ou como o Whisper costuma escrever) para correção automática instantânea.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)

                if config.vocabularioExcedeuLimiteWhisper {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.orange)
                            .font(.system(size: 13))
                        Text("O vocabulário ultrapassou o limite recomendado (~224 tokens do Whisper). Os termos mais recentes têm prioridade no reconhecimento.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.orange.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                            )
                    )
                }

                // Campo de inserção com suporte a variantes
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TextField("Termo oficial (ex: Claude Code, Acme)", text: $novoTermo)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12.5, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.primary.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(erroValidacao != nil ? Color.red.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                            )
                            .onSubmit { adicionar() }

                        Button(action: adicionar) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Adicionar")
                            }
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Tema.degrade)
                            )
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    TextField("Variantes ou como costuma falar (opcional, separadas por vírgula: ex: Clod Code, Cloud Code)", text: $novasVariantes)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.025))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                        )
                        .onSubmit { adicionar() }

                    if let erro = erroValidacao {
                        Text(erro)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                            .padding(.leading, 4)
                            .transition(.opacity)
                    }
                }

                // Lista de chips em layout fluido
                let itens = config.itensVocabulario.isEmpty ? GerenciadorVocabulario.shared.itens : config.itensVocabulario
                if itens.isEmpty {
                    Text("Nenhum termo cadastrado.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    FlowLayout(spacing: 7) {
                        ForEach(Array(itens.enumerated()), id: \.offset) { indice, item in
                            ChipTermo(
                                termo: item.termo,
                                variantes: item.variantes,
                                emEdicao: indiceEdicao == indice,
                                textoEdicao: $textoEdicao,
                                variantesEdicao: $variantesEdicao,
                                onSalvar: { salvarEdicao(noIndice: indice) },
                                onCancelar: { cancelarEdicao() },
                                onIniciarEdicao: { iniciarEdicao(noIndice: indice, item: item) },
                                onRemover: { config.removerTermoVocabulario(noIndice: indice) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Rodapé com contador e reset
                HStack {
                    Text("\(itens.count) termos cadastrados")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Restaurar padrões") {
                        cancelarEdicao()
                        config.resetarVocabularioPadrao()
                    }
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
        }
    }

    private func adicionar() {
        let t = novoTermo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else {
            erroValidacao = "Digite um termo para adicionar."
            return
        }
        if config.vocabulario.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
            erroValidacao = "Este termo já está na lista."
            return
        }

        let vars = novasVariantes.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let ok = config.adicionarTermoVocabulario(t, variantes: vars)
        if ok {
            novoTermo = ""
            novasVariantes = ""
            erroValidacao = nil
        }
    }

    private func iniciarEdicao(noIndice indice: Int, item: ItemVocabulario) {
        indiceEdicao = indice
        textoEdicao = item.termo
        variantesEdicao = item.variantes.joined(separator: ", ")
        erroValidacao = nil
    }

    private func salvarEdicao(noIndice indice: Int) {
        let t = textoEdicao.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else {
            cancelarEdicao()
            return
        }
        _ = config.editarTermoVocabulario(noIndice: indice, novoTermo: t)
        let vars = variantesEdicao.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        GerenciadorVocabulario.shared.definirVariantes(doTermo: t, variantes: vars)
        config.itensVocabulario = GerenciadorVocabulario.shared.itens
        cancelarEdicao()
    }

    private func cancelarEdicao() {
        indiceEdicao = nil
        textoEdicao = ""
        variantesEdicao = ""
    }
}

private struct ChipTermo: View {
    let termo: String
    let variantes: [String]
    let emEdicao: Bool
    @Binding var textoEdicao: String
    @Binding var variantesEdicao: String
    let onSalvar: () -> Void
    let onCancelar: () -> Void
    let onIniciarEdicao: () -> Void
    let onRemover: () -> Void

    @State private var sobre = false

    var body: some View {
        HStack(spacing: 6) {
            if emEdicao {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Termo", text: $textoEdicao)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .frame(minWidth: 70)
                        .onSubmit { onSalvar() }

                    TextField("Variantes (separadas por vírgula)", text: $variantesEdicao)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, design: .rounded))
                        .frame(minWidth: 110)
                        .onSubmit { onSalvar() }
                }

                Button(action: onSalvar) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .help("Salvar")

                Button(action: onCancelar) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancelar")
            } else {
                HStack(spacing: 4) {
                    Text(termo)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    if !variantes.isEmpty {
                        Text("← " + variantes.prefix(2).joined(separator: ", ") + (variantes.count > 2 ? "…" : ""))
                            .font(.system(size: 9.5, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.85))
                    }
                }

                Button(action: onIniciarEdicao) {
                    Image(systemName: "pencil")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary.opacity(sobre ? 1.0 : 0.6))
                }
                .buttonStyle(.plain)
                .help("Editar termo e variantes")

                Button(action: onRemover) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(sobre ? 1.0 : 0.6))
                }
                .buttonStyle(.plain)
                .help("Remover termo")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.primary.opacity(emEdicao ? 0.08 : (sobre ? 0.07 : 0.04)))
        )
        .overlay(
            Capsule()
                .strokeBorder(emEdicao ? Tema.roxo.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onHover { h in sobre = h }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 500
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                height += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: max(height, 20))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Cartão de Histórico

private struct CartaoHistorico: View {
    @ObservedObject var historico: Historico
    @ObservedObject var config: Config

    var body: some View {
        Cartao(titulo: "Últimas 10 transcrições", icone: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Toggle("Salvar histórico", isOn: $config.ativarHistorico)
                        .toggleStyle(.switch)
                        .tint(Tema.roxo)
                        .font(.system(size: 13, weight: .medium, design: .rounded))

                    Spacer()

                    if !historico.itens.isEmpty {
                        Button(action: { historico.limpar() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                Text("Apagar histórico")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.red.opacity(0.12))
                            )
                            .foregroundStyle(Color.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !config.ativarHistorico {
                    Text("O salvamento do histórico está desativado.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else if historico.itens.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 18))
                            .foregroundStyle(.tertiary)
                        Text("Nada ainda. Segure o atalho e fale.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                ForEach(historico.itens.prefix(10)) { item in
                    LinhaHistorico(item: item)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: historico.itens.first?.data)
    }
}

private struct LinhaHistorico: View {
    let item: ItemHistorico
    @State private var copiado = false
    @State private var sobre = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(item.modo.nomeExibicao)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(Tema.cor(item.modo).opacity(0.16)))
                        .foregroundStyle(Tema.cor(item.modo))

                    Text(meta)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Text(item.texto)
                    .font(.system(size: 13, design: .rounded))
                    .textSelection(.enabled)
                    .lineLimit(4)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.texto, forType: .string)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { copiado = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    withAnimation(.easeOut(duration: 0.2)) { copiado = false }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(sobre ? 0.08 : 0.0))
                    Image(systemName: copiado ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(copiado ? AnyShapeStyle(Color.green) : AnyShapeStyle(Tema.degrade))
                        .scaleEffect(copiado ? 1.2 : 1.0)
                }
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Copiar")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(sobre ? 0.05 : 0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(sobre ? 0.08 : 0.03), lineWidth: 1)
        )
        .onHover { h in
            withAnimation(.easeOut(duration: 0.15)) { sobre = h }
        }
    }

    private var meta: String {
        let rel = RelativeDateTimeFormatter()
        rel.locale = Locale(identifier: "pt_BR")
        rel.unitsStyle = .short
        var partes = [rel.localizedString(for: item.data, relativeTo: Date())]
        if let app = item.app { partes.append(app) }
        partes.append(String(format: "%.1f s", item.segundosTranscricao).replacingOccurrences(of: ".", with: ","))
        return partes.joined(separator: " · ")
    }
}
