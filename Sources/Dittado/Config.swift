import AppKit
import ServiceManagement
import SwiftUI
import DittadoCore

/// Teclas modificadoras que podem disparar o ditado (sozinhas, sem atrapalhar a digitação).
enum Tecla: String, CaseIterable, Identifiable, Codable {
    case fn, optionDireita, commandDireita, controlDireita

    var id: String { rawValue }
    var nome: String {
        switch self {
        case .fn: return "Fn 🌐"
        case .optionDireita: return "Option direita ⌥"
        case .commandDireita: return "Command direita ⌘"
        case .controlDireita: return "Control direita ⌃"
        }
    }
    var codigo: Int64 {
        switch self {
        case .fn: return 63
        case .optionDireita: return 61
        case .commandDireita: return 54
        case .controlDireita: return 62
        }
    }
    /// Bit do flag que indica a tecla apertada (lado direito usa os bits "device dependent").
    func apertada(_ flags: CGEventFlags) -> Bool {
        switch self {
        case .fn: return flags.contains(.maskSecondaryFn)
        case .optionDireita: return flags.rawValue & 0x40 != 0
        case .commandDireita: return flags.rawValue & 0x10 != 0
        case .controlDireita: return flags.rawValue & 0x2000 != 0
        }
    }
}

struct Atalho: Codable, Hashable {
    var tecla: Tecla
    var comShift: Bool
    var nome: String { comShift ? "\(tecla.nome) + Shift" : tecla.nome }
}

enum Comportamento: String, CaseIterable, Identifiable, Codable {
    case automatico, segurar, travar
    var id: String { rawValue }
    var nome: String {
        switch self {
        case .automatico: return "Automático"
        case .segurar: return "Segurar"
        case .travar: return "Travar"
        }
    }
    var explicacao: String {
        switch self {
        case .automatico: return "Segure para falar e solte para transcrever. Um toque rápido trava, e outro toque termina."
        case .segurar: return "Grava só enquanto a tecla estiver apertada."
        case .travar: return "Um toque começa a gravar e outro toque termina."
        }
    }
}

/// Preferências salvas no UserDefaults.
final class Config: ObservableObject {
    static let shared = Config()
    private let ud = UserDefaults.standard

    @Published var atalhoLivre: Atalho { didSet { salvar(atalhoLivre, "atalhoLivre") } }
    @Published var atalhoPrompt: Atalho { didSet { salvar(atalhoPrompt, "atalhoPrompt") } }
    @Published var comportamento: Comportamento { didSet { ud.set(comportamento.rawValue, forKey: "comportamento") } }
    @Published var sons: Bool { didSet { ud.set(sons, forKey: "sons") } }
    @Published var microfone: PoliticaMicrofone { didSet { ud.set(microfone.rawValue, forKey: "microfone") } }
    @Published var registrarTexto: Bool { didSet { ud.set(registrarTexto, forKey: "registrarTexto") } }
    @Published var ativarHistorico: Bool { didSet { ud.set(ativarHistorico, forKey: "ativarHistorico") } }
    @Published var vocabulario: [String] { didSet { GerenciadorVocabulario.shared.termos = vocabulario } }
    @Published var itensVocabulario: [ItemVocabulario] = []
    @Published var abrirAoIniciar: Bool {
        didSet {
            guard abrirAoIniciar != oldValue else { return }
            do {
                if abrirAoIniciar { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                log("Erro ao mudar abertura automática: \(error)")
            }
        }
    }

    private init() {
        atalhoLivre = Self.ler("atalhoLivre") ?? Atalho(tecla: .fn, comShift: false)
        atalhoPrompt = Self.ler("atalhoPrompt") ?? Atalho(tecla: .fn, comShift: true)
        comportamento = Comportamento(rawValue: ud.string(forKey: "comportamento") ?? "") ?? .automatico
        sons = ud.object(forKey: "sons") as? Bool ?? true
        microfone = PoliticaMicrofone(rawValue: ud.string(forKey: "microfone") ?? "") ?? .automatico
        registrarTexto = ud.bool(forKey: "registrarTexto")
        ativarHistorico = ud.object(forKey: "ativarHistorico") as? Bool ?? true
        vocabulario = GerenciadorVocabulario.shared.termos
        itensVocabulario = GerenciadorVocabulario.shared.itens
        abrirAoIniciar = SMAppService.mainApp.status == .enabled
        // Primeira vez: liga a abertura automática (o atalho só funciona com o Dittado aberto)
        if !ud.bool(forKey: "abrirAoIniciarConfigurado") {
            ud.set(true, forKey: "abrirAoIniciarConfigurado")
            try? SMAppService.mainApp.register()  // didSet não roda dentro do init
            abrirAoIniciar = SMAppService.mainApp.status == .enabled
        }
    }

    @discardableResult
    func adicionarTermoVocabulario(_ termo: String, variantes: [String] = []) -> Bool {
        let ok = GerenciadorVocabulario.shared.adicionar(termo, variantes: variantes)
        if ok {
            atualizarVocabularioLocal()
        }
        return ok
    }

    @discardableResult
    func adicionarVarianteVocabulario(aoTermo termo: String, variante: String) -> Bool {
        let ok = GerenciadorVocabulario.shared.adicionarVariante(aoTermo: termo, variante: variante)
        if ok {
            atualizarVocabularioLocal()
        }
        return ok
    }

    @discardableResult
    func removerVarianteVocabulario(doTermo termo: String, variante: String) -> Bool {
        let ok = GerenciadorVocabulario.shared.removerVariante(doTermo: termo, variante: variante)
        if ok {
            atualizarVocabularioLocal()
        }
        return ok
    }

    func removerTermoVocabulario(noIndice indice: Int) {
        if GerenciadorVocabulario.shared.remover(noIndice: indice) {
            atualizarVocabularioLocal()
        }
    }

    func removerTermoVocabulario(_ termo: String) {
        if GerenciadorVocabulario.shared.remover(termo) {
            atualizarVocabularioLocal()
        }
    }

    @discardableResult
    func editarTermoVocabulario(noIndice indice: Int, novoTermo: String) -> Bool {
        let ok = GerenciadorVocabulario.shared.editar(noIndice: indice, novoTermo: novoTermo)
        if ok {
            atualizarVocabularioLocal()
        }
        return ok
    }

    func resetarVocabularioPadrao() {
        GerenciadorVocabulario.shared.resetarPadroes()
        atualizarVocabularioLocal()
    }

    private func atualizarVocabularioLocal() {
        vocabulario = GerenciadorVocabulario.shared.termos
        itensVocabulario = GerenciadorVocabulario.shared.itens
    }

    var vocabularioExcedeuLimiteWhisper: Bool {
        GerenciadorVocabulario.shared.formatarParaWhisper().excedeuLimite
    }

    private static func ler(_ chave: String) -> Atalho? {
        guard let d = UserDefaults.standard.data(forKey: chave) else { return nil }
        return try? JSONDecoder().decode(Atalho.self, from: d)
    }
    private func salvar(_ a: Atalho, _ chave: String) {
        ud.set(try? JSONEncoder().encode(a), forKey: chave)
    }
}

/// Cores do ícone do Dittado.
enum Tema {
    static let roxo = Color(red: 0.42, green: 0.25, blue: 0.95)
    static let azul = Color(red: 0.13, green: 0.55, blue: 0.98)
    static let degrade = LinearGradient(colors: [roxo, azul], startPoint: .topLeading, endPoint: .bottomTrailing)
    static func cor(_ modo: ModoDitado) -> Color { modo == .prompt ? roxo : azul }
}

extension PoliticaMicrofone: Identifiable {
    public var id: String { rawValue }
    var nome: String {
        switch self {
        case .automatico: return "Automático"
        case .sempreMacBook: return "Sempre o do MacBook"
        case .padraoDoSistema: return "Padrão do sistema"
        }
    }
    var explicacao: String {
        switch self {
        case .automatico: return "Fone com fio: usa o microfone do fone. AirPods, Bluetooth ou sem fone: usa o do MacBook."
        case .sempreMacBook: return "Ignora qualquer fone e grava sempre pelo MacBook."
        case .padraoDoSistema: return "Usa o microfone escolhido nos Ajustes do Mac (com AirPods, o início da fala pode se perder)."
        }
    }
}
