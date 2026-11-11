import AppKit
import AVFoundation
import DittadoCore
import SwiftUI

// MARK: - Janela de Onboarding e Gerenciamento de Modelos

public final class JanelaOnboarding: NSObject, NSWindowDelegate {
    public static let shared = JanelaOnboarding()

    private var janela: NSWindow?
    public var aoConcluirOuMudarModelo: ((String?) -> Void)?

    public func mostrar(passoInicial: PassoOnboarding = .boasVindas) {
        let j = janela ?? criar()
        if let vista = j.contentView as? NSHostingView<VistaOnboardingWrapper> {
            vista.rootView = VistaOnboardingWrapper(passoInicial: passoInicial) { [weak self] modeloEscolhido in
                self?.aoConcluirOuMudarModelo?(modeloEscolhido)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        j.makeKeyAndOrderFront(nil)
    }

    public func fechar() {
        janela?.orderOut(nil)
    }

    public func windowWillClose(_ notification: Notification) {
        janela?.contentView = nil
        janela = nil
    }

    private func criar() -> NSWindow {
        let j = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        j.title = "Configuração do Dittado"
        j.titlebarAppearsTransparent = true
        j.titleVisibility = .hidden
        j.isReleasedWhenClosed = false
        j.isMovableByWindowBackground = true
        j.minSize = NSSize(width: 600, height: 560)

        let wrapper = VistaOnboardingWrapper(passoInicial: .boasVindas) { [weak self] modeloEscolhido in
            self?.aoConcluirOuMudarModelo?(modeloEscolhido)
        }
        let vista = NSHostingView(rootView: wrapper)
        j.contentView = vista
        j.delegate = self
        j.center()
        janela = j
        return j
    }
}

private struct VistaOnboardingWrapper: View {
    let passoInicial: PassoOnboarding
    let aoMudarModelo: (String?) -> Void

    var body: some View {
        VistaOnboarding(passoAtual: passoInicial, aoMudarModelo: aoMudarModelo)
    }
}

// MARK: - Passos do Onboarding

public enum PassoOnboarding: Int, CaseIterable {
    case boasVindas = 1
    case escolhaModelos = 2
    case download = 3
    case permissoes = 4
    case pronto = 5
    case gerenciarModelos = 6
}

// MARK: - Vista Principal do Onboarding

struct VistaOnboarding: View {
    @State var passoAtual: PassoOnboarding
    let aoMudarModelo: (String?) -> Void

    @State private var llmSelecionado: String = CatalogoModelos.recomendarLLM().id
    @State private var downloadWhisper: GerenciadorDownload = GerenciadorDownload(modelo: CatalogoModelos.whisperLargeV3Turbo)
    @State private var downloadLLM: GerenciadorDownload? = nil

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).opacity(0.88)
            Rectangle().fill(.ultraThinMaterial)

            VStack(spacing: 0) {
                // Barra de progresso dos passos (se estiver no onboarding)
                if passoAtual != .gerenciarModelos {
                    BarraProgressoPassos(passoAtual: passoAtual)
                        .padding(.top, 28)
                        .padding(.horizontal, 36)
                }

                ScrollView {
                    VStack(spacing: 24) {
                        switch passoAtual {
                        case .boasVindas:
                            PassoBoasVindas {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    passoAtual = .escolhaModelos
                                }
                            }
                        case .escolhaModelos:
                            PassoEscolhaModelos(
                                llmSelecionado: $llmSelecionado,
                                aoAvancar: {
                                    iniciarFluxoDownload()
                                }
                            )
                        case .download:
                            PassoDownload(
                                downloadWhisper: downloadWhisper,
                                downloadLLM: downloadLLM,
                                aoConcluir: {
                                    notificarNovoModelo()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        passoAtual = .permissoes
                                    }
                                }
                            )
                        case .permissoes:
                            PassoPermissoes {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    passoAtual = .pronto
                                }
                            }
                        case .pronto:
                            PassoPronto {
                                JanelaOnboarding.shared.fechar()
                            }
                        case .gerenciarModelos:
                            VistaGerenciadorModelos(aoMudarModelo: aoMudarModelo)
                        }
                    }
                    .padding(32)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func iniciarFluxoDownload() {
        let precisaWhisper = !downloadWhisper.estaInstalado
        let modeloLLM: CatalogoModelos.ModeloInfo?
        if llmSelecionado == "qwen-7b" {
            modeloLLM = CatalogoModelos.qwen7B
        } else if llmSelecionado == "qwen-1.5b" {
            modeloLLM = CatalogoModelos.qwen1_5B
        } else {
            modeloLLM = nil
        }

        if let m = modeloLLM {
            downloadLLM = GerenciadorDownload(modelo: m)
        } else {
            downloadLLM = nil
        }

        let precisaLLM = downloadLLM?.estaInstalado == false

        if !precisaWhisper && !precisaLLM {
            // Tudo já baixado: aplica escolha e pula direto para permissões
            notificarNovoModelo()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                passoAtual = .permissoes
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                passoAtual = .download
            }
            if precisaWhisper {
                downloadWhisper.iniciarOuRetomar()
            }
            if precisaLLM {
                downloadLLM?.iniciarOuRetomar()
            }
        }
    }

    private func notificarNovoModelo() {
        if llmSelecionado == "qwen-7b" {
            aoMudarModelo(CatalogoModelos.qwen7B.nomeArquivo)
        } else if llmSelecionado == "qwen-1.5b" {
            aoMudarModelo(CatalogoModelos.qwen1_5B.nomeArquivo)
        } else {
            aoMudarModelo(nil)
        }
    }
}

// MARK: - Barra de Progresso dos Passos

private struct BarraProgressoPassos: View {
    let passoAtual: PassoOnboarding

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { p in
                Capsule()
                    .fill(p <= passoAtual.rawValue ? Tema.roxo : Color.primary.opacity(0.12))
                    .frame(height: 4)
            }
        }
    }
}

// MARK: - 1. Passo: Boas-Vindas

private struct PassoBoasVindas: View {
    let aoAvancar: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Tema.degrade)
                    .frame(width: 80, height: 80)
                    .shadow(color: Tema.roxo.opacity(0.35), radius: 16, y: 6)
                Image(systemName: "waveform")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 12)

            VStack(spacing: 8) {
                Text("Bem-vindo ao Dittado")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Ditado por voz nativo, inteligente e 100% privado no seu Mac.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                DestaqueOnboarding(
                    icone: "lock.shield.fill",
                    cor: Color.green,
                    titulo: "100% Local e Privado",
                    texto: "Nenhum áudio ou texto sai deste computador. Sem servidores na nuvem, sem telemetria e sem contas."
                )
                DestaqueOnboarding(
                    icone: "cpu.fill",
                    cor: Tema.azul,
                    titulo: "Aceleração por IA Metal",
                    texto: "Whisper large-v3-turbo para transcrição instantânea e LLM Qwen2.5 para formatação profissional."
                )
                DestaqueOnboarding(
                    icone: "keyboard.fill",
                    cor: Tema.roxo,
                    titulo: "Integração Nativa",
                    texto: "Pressione a tecla de atalho em qualquer aplicativo do macOS e o texto ditado é inserido onde você estiver digitando."
                )
            }
            .padding(.vertical, 8)

            Button {
                aoAvancar()
            } label: {
                Text("Começar Configuração →")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Tema.degrade)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }
}

private struct DestaqueOnboarding: View {
    let icone: String
    let cor: Color
    let titulo: String
    let texto: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(cor.opacity(0.14))
                Image(systemName: icone)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(cor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(titulo)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(texto)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }
}

// MARK: - 2. Passo: Escolha de Modelos

private struct PassoEscolhaModelos: View {
    @Binding var llmSelecionado: String
    let aoAvancar: () -> Void

    private var ramGB: Int {
        Int(Double(ProcessInfo.processInfo.physicalMemory) / (1024.0 * 1024.0 * 1024.0) + 0.5)
    }

    private var espacoLivre: Int64 {
        VerificadorDisco.espacoLivreEmBytes()
    }

    private var downloadTotalBytes: Int64 {
        var total: Int64 = 0
        if !FileManager.default.fileExists(atPath: Pastas.modeloWhisperPadrao.path) {
            total += CatalogoModelos.whisperLargeV3Turbo.tamanhoBytes
        }
        if llmSelecionado == "qwen-7b" {
            let u = Pastas.modelos.appendingPathComponent(CatalogoModelos.qwen7B.nomeArquivo)
            if !FileManager.default.fileExists(atPath: u.path) {
                total += CatalogoModelos.qwen7B.tamanhoBytes
            }
        } else if llmSelecionado == "qwen-1.5b" {
            let u = Pastas.modelos.appendingPathComponent(CatalogoModelos.qwen1_5B.nomeArquivo)
            if !FileManager.default.fileExists(atPath: u.path) {
                total += CatalogoModelos.qwen1_5B.tamanhoBytes
            }
        }
        return total
    }

    private var espacoSuficiente: Bool {
        VerificadorDisco.espacoSuficiente(necessario: downloadTotalBytes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Escolha dos Modelos de IA")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("O Dittado baixa os modelos uma única vez para rodar offline no seu hardware.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Cartão Whisper (Obrigatório)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Reconhecimento de Fala (Obrigatório)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("MIT")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }

                HStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Tema.azul)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(CatalogoModelos.whisperLargeV3Turbo.nomeExibicao)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("Transcrição multilíngue precisa otimizada para Apple Silicon.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(CatalogoModelos.whisperLargeV3Turbo.tamanhoExibicao)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        if FileManager.default.fileExists(atPath: Pastas.modeloWhisperPadrao.path) {
                            Text("Instalado ✓")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.green)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )

            // Opções de LLM
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Formatação Inteligente (LLM)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Detectado: \(ramGB) GB RAM")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Tema.roxo)
                }

                // Opção 7B
                OpcaoModeloCard(
                    selecionado: llmSelecionado == "qwen-7b",
                    recomendado: ramGB >= 16,
                    titulo: CatalogoModelos.qwen7B.nomeExibicao,
                    subtitulo: "Máxima qualidade em e-mails e parágrafos. Recomendado para Macs com 16 GB+ de RAM.",
                    tamanho: CatalogoModelos.qwen7B.tamanhoExibicao,
                    licenca: CatalogoModelos.qwen7B.licenca,
                    jaInstalado: FileManager.default.fileExists(atPath: Pastas.modelos.appendingPathComponent(CatalogoModelos.qwen7B.nomeArquivo).path)
                ) {
                    llmSelecionado = "qwen-7b"
                }

                // Opção 1.5B
                OpcaoModeloCard(
                    selecionado: llmSelecionado == "qwen-1.5b",
                    recomendado: ramGB < 16,
                    titulo: CatalogoModelos.qwen1_5B.nomeExibicao,
                    subtitulo: "Superleve e rápido. Recomendado para Macs com 8 GB a 15 GB de RAM.",
                    tamanho: CatalogoModelos.qwen1_5B.tamanhoExibicao,
                    licenca: CatalogoModelos.qwen1_5B.licenca,
                    jaInstalado: FileManager.default.fileExists(atPath: Pastas.modelos.appendingPathComponent(CatalogoModelos.qwen1_5B.nomeArquivo).path)
                ) {
                    llmSelecionado = "qwen-1.5b"
                }

                // Opção Sem LLM
                OpcaoModeloCard(
                    selecionado: llmSelecionado == "nenhum",
                    recomendado: false,
                    titulo: "Sem formatação por IA",
                    subtitulo: "Usa apenas o Whisper + regras determinísticas de pontuação e listas.",
                    tamanho: "0 MB",
                    licenca: "—",
                    jaInstalado: true
                ) {
                    llmSelecionado = "nenhum"
                }
            }

            // Espaço em disco
            HStack {
                Image(systemName: "internaldrive")
                    .font(.system(size: 14))
                Text("Espaço livre: \(VerificadorDisco.formatarBytes(espacoLivre)) · Necessário: \(VerificadorDisco.formatarBytes(downloadTotalBytes))")
                    .font(.system(size: 12, design: .rounded))
                Spacer()
                if !espacoSuficiente {
                    Text("⚠️ Espaço insuficiente")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.red)
                }
            }
            .padding(.horizontal, 4)

            Button {
                aoAvancar()
            } label: {
                Text(downloadTotalBytes > 0 ? "Baixar Modelos (\(VerificadorDisco.formatarBytes(downloadTotalBytes))) →" : "Avançar →")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(espacoSuficiente ? AnyShapeStyle(Tema.degrade) : AnyShapeStyle(Color.gray))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!espacoSuficiente)
        }
    }
}

private struct OpcaoModeloCard: View {
    let selecionado: Bool
    let recomendado: Bool
    let titulo: String
    let subtitulo: String
    let tamanho: String
    let licenca: String
    let jaInstalado: Bool
    let aoSelecionar: () -> Void

    var body: some View {
        Button {
            aoSelecionar()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selecionado ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selecionado ? Tema.roxo : Color.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(titulo)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        if recomendado {
                            Text("Recomendado")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Tema.roxo.opacity(0.18)))
                                .foregroundStyle(Tema.roxo)
                        }

                        if jaInstalado && tamanho != "0 MB" {
                            Text("Instalado")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.18)))
                                .foregroundStyle(Color.green)
                        }
                    }

                    Text(subtitulo)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(tamanho)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(licenca)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(selecionado ? 0.9 : 0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selecionado ? Tema.roxo : Color.primary.opacity(0.06), lineWidth: selecionado ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 3. Passo: Download com Progresso e Retomada

private struct PassoDownload: View {
    @ObservedObject var downloadWhisper: GerenciadorDownload
    var downloadLLM: GerenciadorDownload?
    let aoConcluir: () -> Void

    private var todosConcluidos: Bool {
        let whisperOk = downloadWhisper.estaInstalado || {
            if case .concluido = downloadWhisper.estado { return true }
            return false
        }()
        let llmOk = downloadLLM == nil || downloadLLM!.estaInstalado || {
            if case .concluido = downloadLLM!.estado { return true }
            return false
        }()
        return whisperOk && llmOk
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Baixando Modelos")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Download retomável e seguro diretamente dos repositórios oficiais da Hugging Face.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                ItemDownloadCard(gerenciador: downloadWhisper)

                if let llm = downloadLLM {
                    ItemDownloadCard(gerenciador: llm)
                }
            }

            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
                Text("Você pode pausar a qualquer momento. Se fechar o app, o download continuará de onde parou.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            Button {
                aoConcluir()
            } label: {
                Text(todosConcluidos ? "Continuar para Permissões →" : "Aguarde a conclusão do Whisper...")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(downloadWhisper.estaInstalado ? AnyShapeStyle(Tema.degrade) : AnyShapeStyle(Color.gray))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!downloadWhisper.estaInstalado)
        }
    }
}

private struct ItemDownloadCard: View {
    @ObservedObject var gerenciador: GerenciadorDownload

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(gerenciador.modelo.nomeExibicao)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(statusTexto)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(statusCor)
                }
                Spacer()

                // Botões de controle (Pausar/Retomar/Cancelar)
                if !gerenciador.estaInstalado {
                    switch gerenciador.estado {
                    case .baixando:
                        Button("Pausar") { gerenciador.pausar() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    case .pausado:
                        Button("Retomar") { gerenciador.iniciarOuRetomar() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    case .erro:
                        Button("Tentar novamente") { gerenciador.iniciarOuRetomar() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    default:
                        EmptyView()
                    }

                    if case .baixando = gerenciador.estado {
                        Button("Cancelar") { gerenciador.cancelar() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                        .font(.system(size: 18))
                }
            }

            // Barra de Progresso
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Tema.degrade)
                        .frame(width: max(8, geo.size.width * CGFloat(gerenciador.progresso)))
                }
            }
            .frame(height: 8)

            // Métricas (bytes, velocidade, tempo restante)
            HStack {
                Text("\(VerificadorDisco.formatarBytes(gerenciador.bytesRecebidos)) de \(gerenciador.modelo.tamanhoExibicao) (\(Int(gerenciador.progresso * 100))%)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                if gerenciador.velocidadeBytesPorSegundo > 0 {
                    Text(String(format: "%.1f MB/s", gerenciador.velocidadeBytesPorSegundo / 1_000_000))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                if let t = gerenciador.tempoRestanteSegundos, t > 0 {
                    Text("· Restando ~\(Int(t))s")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
    }

    private var statusTexto: String {
        if gerenciador.estaInstalado { return "Instalado e verificado ✓" }
        switch gerenciador.estado {
        case .parado: return "Aguardando início..."
        case .baixando: return "Baixando..."
        case .pausado: return "Pausado"
        case .verificandoHash: return "Verificando hash SHA-256..."
        case .concluido: return "Concluído com sucesso ✓"
        case .erro(let msg): return "Erro: \(msg)"
        }
    }

    private var statusCor: Color {
        if gerenciador.estaInstalado { return .green }
        switch gerenciador.estado {
        case .erro: return .red
        case .concluido: return .green
        case .verificandoHash: return .orange
        default: return .secondary
        }
    }
}

// MARK: - 4. Passo: Guia de Permissões com Polling

private struct PassoPermissoes: View {
    let aoAvancar: () -> Void

    @State private var microfoneOk: Bool = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @State private var acessibilidadeOk: Bool = AXIsProcessTrusted()
    @State private var escutaOk: Bool = CGPreflightListenEventAccess()
    @State private var timer: Timer? = nil

    private var todasPermissoesOk: Bool {
        microfoneOk && acessibilidadeOk && escutaOk
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Permissões do macOS")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("O Dittado precisa de 3 autorizações do sistema para funcionar perfeitamente.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                // Microfone
                ItemPermissaoCard(
                    icone: "mic.fill",
                    nome: "Microfone",
                    porQue: "Para capturar o áudio da sua voz enquanto você dita.",
                    concedida: microfoneOk,
                    painelAjustes: "Privacy_Microphone"
                ) {
                    AVCaptureDevice.requestAccess(for: .audio) { _ in
                        atualizarStatus()
                    }
                }

                // Acessibilidade
                ItemPermissaoCard(
                    icone: "cursorarrow.and.square.on.square.dashed",
                    nome: "Acessibilidade",
                    porQue: "Para colar o texto transcrito diretamente no aplicativo em foco onde você está digitando.",
                    concedida: acessibilidadeOk,
                    painelAjustes: "Privacy_Accessibility"
                ) {
                    let opcoes = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                    _ = AXIsProcessTrustedWithOptions(opcoes)
                }

                // Monitoramento de Entrada
                ItemPermissaoCard(
                    icone: "keyboard.badge.waveform",
                    nome: "Monitoramento de Entrada",
                    porQue: "Para reconhecer o atalho global do teclado (tecla Fn) mesmo com outro aplicativo ativo.",
                    concedida: escutaOk,
                    painelAjustes: "Privacy_ListenEvent"
                ) {
                    CGRequestListenEventAccess()
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.yellow)
                    .font(.system(size: 14))
                Text("Dica: após conceder o Monitoramento de Entrada nos Ajustes do Sistema, pode ser necessário reiniciar o Dittado para que o macOS aplique a alteração.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.yellow.opacity(0.08))
            )

            Button {
                aoAvancar()
            } label: {
                Text(todasPermissoesOk ? "Concluir Configuração →" : "Continuar mesmo assim →")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Tema.degrade)
                    )
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            atualizarStatus()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                atualizarStatus()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func atualizarStatus() {
        microfoneOk = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        acessibilidadeOk = AXIsProcessTrusted()
        escutaOk = CGPreflightListenEventAccess()
    }
}

private struct ItemPermissaoCard: View {
    let icone: String
    let nome: String
    let porQue: String
    let concedida: Bool
    let painelAjustes: String
    let acaoPedir: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(concedida ? Color.green.opacity(0.14) : Color.orange.opacity(0.14))
                Image(systemName: icone)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(concedida ? Color.green : Color.orange)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(nome)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(concedida ? "Concedida ✓" : "Pendente")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(concedida ? Color.green.opacity(0.16) : Color.orange.opacity(0.16)))
                        .foregroundStyle(concedida ? Color.green : Color.orange)
                }

                Text(porQue)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)

            if !concedida {
                Button("Abrir Ajustes") {
                    acaoPedir()
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(painelAjustes)") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
    }
}

// MARK: - 5. Passo: Pronto / Teste Rápido

private struct PassoPronto: View {
    let aoConcluir: () -> Void

    @State private var textoTeste: String = ""

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.22, green: 0.84, blue: 0.48))
                    .frame(width: 76, height: 76)
                    .shadow(color: Color.green.opacity(0.35), radius: 14, y: 6)
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 12)

            VStack(spacing: 8) {
                Text("Tudo Pronto!")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("O Dittado já está ativo e operando na barra de menus.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Tema.azul)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Modo Livre: \(Config.shared.atalhoLivre.nome)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("Transcreve quase tudo o que você fala com pontuação e listas.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )

                HStack(spacing: 14) {
                    Circle()
                        .fill(Tema.roxo)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Modo Profissional: \(Config.shared.atalhoPrompt.nome)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("Reescreve seu ditado de forma polida e estruturada como e-mail.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Teste rápido de digitação:")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("Clique aqui e experimente ditar usando o atalho...", text: $textoTeste)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .rounded))
            }
            .padding(.top, 4)

            Button {
                aoConcluir()
            } label: {
                Text("Começar a Usar o Dittado")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Tema.degrade)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }
}

// MARK: - Painel de Gerenciamento de Modelos (Passo / Modal Dedicado)

public struct VistaGerenciadorModelos: View {
    public let aoMudarModelo: (String?) -> Void

    @State private var modeloAtivo: String = Pastas.nomeModeloLLM
    @State private var downloadWhisper: GerenciadorDownload = GerenciadorDownload(modelo: CatalogoModelos.whisperLargeV3Turbo)
    @State private var download7B: GerenciadorDownload = GerenciadorDownload(modelo: CatalogoModelos.qwen7B)
    @State private var download1_5B: GerenciadorDownload = GerenciadorDownload(modelo: CatalogoModelos.qwen1_5B)
    @State private var modeloParaApagar: CatalogoModelos.ModeloInfo? = nil
    @State private var mostrandoAlertaApagar: Bool = false

    public init(aoMudarModelo: @escaping (String?) -> Void) {
        self.aoMudarModelo = aoMudarModelo
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Gerenciar Modelos de IA")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Gerencie os arquivos de IA instalados neste Mac, alterne o modelo em uso ou libere espaço.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                // Whisper
                CardModeloInstalado(
                    titulo: CatalogoModelos.whisperLargeV3Turbo.nomeExibicao,
                    subtitulo: "Motor de transcrição Whisper large-v3-turbo.",
                    tamanho: CatalogoModelos.whisperLargeV3Turbo.tamanhoExibicao,
                    licenca: CatalogoModelos.whisperLargeV3Turbo.licenca,
                    estaInstalado: downloadWhisper.estaInstalado,
                    ehAtivo: true,
                    podeApagar: false,
                    gerenciador: downloadWhisper,
                    aoAtivar: {},
                    aoApagar: {}
                )

                // Qwen 7B
                CardModeloInstalado(
                    titulo: CatalogoModelos.qwen7B.nomeExibicao,
                    subtitulo: "Modelo de máxima qualidade para Macs com 16 GB+ de RAM.",
                    tamanho: CatalogoModelos.qwen7B.tamanhoExibicao,
                    licenca: CatalogoModelos.qwen7B.licenca,
                    estaInstalado: download7B.estaInstalado,
                    ehAtivo: modeloAtivo == CatalogoModelos.qwen7B.nomeArquivo,
                    podeApagar: true,
                    gerenciador: download7B,
                    aoAtivar: {
                        modeloAtivo = CatalogoModelos.qwen7B.nomeArquivo
                        aoMudarModelo(CatalogoModelos.qwen7B.nomeArquivo)
                    },
                    aoApagar: {
                        modeloParaApagar = CatalogoModelos.qwen7B
                        mostrandoAlertaApagar = true
                    }
                )

                // Qwen 1.5B
                CardModeloInstalado(
                    titulo: CatalogoModelos.qwen1_5B.nomeExibicao,
                    subtitulo: "Modelo superleve para Macs com 8 GB de RAM.",
                    tamanho: CatalogoModelos.qwen1_5B.tamanhoExibicao,
                    licenca: CatalogoModelos.qwen1_5B.licenca,
                    estaInstalado: download1_5B.estaInstalado,
                    ehAtivo: modeloAtivo == CatalogoModelos.qwen1_5B.nomeArquivo,
                    podeApagar: true,
                    gerenciador: download1_5B,
                    aoAtivar: {
                        modeloAtivo = CatalogoModelos.qwen1_5B.nomeArquivo
                        aoMudarModelo(CatalogoModelos.qwen1_5B.nomeArquivo)
                    },
                    aoApagar: {
                        modeloParaApagar = CatalogoModelos.qwen1_5B
                        mostrandoAlertaApagar = true
                    }
                )

                // Sem LLM
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sem Formatação por IA")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("Usar apenas Whisper e regras determinísticas.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if modeloAtivo.isEmpty || modeloAtivo == "nenhum" {
                        Text("Em uso ✓")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Tema.roxo)
                    } else {
                        Button("Ativar") {
                            modeloAtivo = "nenhum"
                            aoMudarModelo(nil)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                )
            }

            Button("Fechar") {
                JanelaOnboarding.shared.fechar()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 8)
        }
        .alert(isPresented: $mostrandoAlertaApagar) {
            Alert(
                title: Text("Apagar modelo?"),
                message: Text("Tem certeza que deseja apagar \(modeloParaApagar?.nomeExibicao ?? "o modelo")? Será necessário baixá-lo novamente se quiser usá-lo."),
                primaryButton: .destructive(Text("Apagar")) {
                    if let m = modeloParaApagar {
                        if m.id == CatalogoModelos.qwen7B.id {
                            try? download7B.apagarInstalado()
                            if modeloAtivo == m.nomeArquivo {
                                modeloAtivo = "nenhum"
                                aoMudarModelo(nil)
                            }
                        } else if m.id == CatalogoModelos.qwen1_5B.id {
                            try? download1_5B.apagarInstalado()
                            if modeloAtivo == m.nomeArquivo {
                                modeloAtivo = "nenhum"
                                aoMudarModelo(nil)
                            }
                        }
                    }
                },
                secondaryButton: .cancel(Text("Cancelar"))
            )
        }
    }
}

private struct CardModeloInstalado: View {
    let titulo: String
    let subtitulo: String
    let tamanho: String
    let licenca: String
    let estaInstalado: Bool
    let ehAtivo: Bool
    let podeApagar: Bool
    @ObservedObject var gerenciador: GerenciadorDownload
    let aoAtivar: () -> Void
    let aoApagar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(titulo)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        if ehAtivo {
                            Text("Em uso")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Tema.roxo.opacity(0.18)))
                                .foregroundStyle(Tema.roxo)
                        }
                    }
                    Text(subtitulo)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(tamanho)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Text(licenca)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            // Ações / Estado
            HStack {
                if estaInstalado {
                    Text("Instalado ✓")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.green)
                    Spacer()
                    if !ehAtivo && podeApagar {
                        Button("Usar este") {
                            aoAtivar()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    if podeApagar {
                        Button("Apagar") {
                            aoApagar()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundStyle(Color.red)
                    }
                } else {
                    switch gerenciador.estado {
                    case .parado:
                        Button("Baixar modelo (\(tamanho))") {
                            gerenciador.iniciarOuRetomar()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    case .baixando:
                        Text("Baixando: \(Int(gerenciador.progresso * 100))%")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Tema.roxo)
                        Button("Pausar") { gerenciador.pausar() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button("Cancelar") { gerenciador.cancelar() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    case .pausado:
                        Text("Pausado (\(Int(gerenciador.progresso * 100))%)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                        Button("Retomar") { gerenciador.iniciarOuRetomar() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    case .verificandoHash:
                        Text("Verificando integridade SHA-256...")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.orange)
                    case .concluido:
                        Text("Concluído ✓")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.green)
                    case .erro(let msg):
                        Text("Erro: \(msg)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.red)
                        Button("Tentar novamente") { gerenciador.iniciarOuRetomar() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(ehAtivo ? 0.8 : 0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(ehAtivo ? Tema.roxo : Color.primary.opacity(0.06), lineWidth: ehAtivo ? 1.5 : 1)
        )
    }
}
