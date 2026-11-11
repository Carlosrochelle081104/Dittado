import AppKit
import CoreGraphics
import DittadoCore

/// Escuta as teclas de atalho no sistema todo (configuradas em Config).
/// Segurar = grava enquanto aperta; Travar = toque liga, toque desliga; Automático = os dois.
/// Esc cancela. Se outra tecla for usada junto com a de atalho (Fn+F1, Fn+setas...), descarta.
final class AtalhoGlobal {
    var aoIniciar: ((ModoDitado) -> Void)?
    var aoMudarModo: ((ModoDitado) -> Void)?
    var aoTravar: (() -> Void)?
    var aoTerminar: (() -> Void)?
    var aoCancelar: (() -> Void)?

    private enum Estado { case parado, segurando(Tecla, ModoDitado, Date), travado(ModoDitado) }

    private var tap: CFMachPort?
    private var estado: Estado = .parado
    private var teclasApertadas: Set<Tecla> = []
    private let config = Config.shared

    private static let teclaEsc: Int64 = 53
    /// Toque mais curto que isso, no modo Automático, trava a gravação.
    private static let limiteToque: TimeInterval = 0.3

    /// Retorna false se o macOS ainda não deu permissão de Monitoramento de Entrada.
    /// A escuta roda numa thread própria: se a tela principal estiver ocupada, o macOS não desliga o atalho.
    func iniciar() -> Bool {
        guard tap == nil else { return true }
        let mascara = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: CGEventMask(mascara),
            callback: { _, tipo, evento, ref in
                let eu = Unmanaged<AtalhoGlobal>.fromOpaque(ref!).takeUnretainedValue()
                if tipo == .tapDisabledByTimeout || tipo == .tapDisabledByUserInput {
                    if let t = eu.tap { CGEvent.tapEnable(tap: t, enable: true) }
                    return Unmanaged.passUnretained(evento)
                }
                let copia = evento.copy() ?? evento
                DispatchQueue.main.async { eu.tratar(tipo, copia) }
                return Unmanaged.passUnretained(evento)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        let thread = Thread {
            let fonte = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), fonte, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "dittado.atalho"
        thread.qualityOfService = .userInteractive
        thread.start()
        // Vigia: se o macOS desligar a escuta por qualquer motivo, liga de novo
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let t = self?.tap, !CGEvent.tapIsEnabled(tap: t) else { return }
            CGEvent.tapEnable(tap: t, enable: true)
            log("Escuta do atalho estava desligada e foi religada")
        }
        return true
    }

    /// Chamado pelo app quando a gravação termina por outro caminho (ex.: erro).
    func reiniciar() { estado = .parado }

    private func tratar(_ tipo: CGEventType, _ evento: CGEvent) {
        switch tipo {
        case .flagsChanged:
            mudouModificador(evento)
        case .keyDown:
            let codigo = evento.getIntegerValueField(.keyboardEventKeycode)
            switch estado {
            case .segurando:
                estado = .parado
                aoCancelar?()  // Esc, ou atalho do sistema usando a tecla (Fn+seta...)
            case .travado where codigo == Self.teclaEsc:
                estado = .parado
                aoCancelar?()
            default:
                break
            }
        default:
            break
        }
    }

    private func mudouModificador(_ evento: CGEvent) {
        let codigo = evento.getIntegerValueField(.keyboardEventKeycode)
        let flags = evento.flags
        let shift = flags.contains(.maskShift)

        guard let tecla = Tecla.allCases.first(where: { $0.codigo == codigo }) else {
            // Shift apertado durante a gravação: passa para o modo Prompt, se for esse o atalho
            if case .segurando(let t, .livre, let inicio) = estado, shift,
               config.atalhoPrompt == Atalho(tecla: t, comShift: true) {
                estado = .segurando(t, .prompt, inicio)
                aoMudarModo?(.prompt)
            }
            return
        }

        let apertou = tecla.apertada(flags) && !teclasApertadas.contains(tecla)
        let soltou = !tecla.apertada(flags) && teclasApertadas.contains(tecla)
        if tecla.apertada(flags) { teclasApertadas.insert(tecla) } else { teclasApertadas.remove(tecla) }

        if apertou {
            switch estado {
            case .travado:
                estado = .parado
                aoTerminar?()
            case .parado:
                guard let modo = modo(para: tecla, shift: shift) else { return }
                estado = .segurando(tecla, modo, Date())
                aoIniciar?(modo)
            case .segurando:
                break
            }
        } else if soltou, case .segurando(let t, let modo, let inicio) = estado, t == tecla {
            let toqueRapido = Date().timeIntervalSince(inicio) < Self.limiteToque
            switch config.comportamento {
            case .travar:
                estado = .travado(modo)
                aoTravar?()
            case .automatico where toqueRapido:
                estado = .travado(modo)
                aoTravar?()
            default:
                estado = .parado
                aoTerminar?()
            }
        }
    }

    private func modo(para tecla: Tecla, shift: Bool) -> ModoDitado? {
        let livre = config.atalhoLivre, prompt = config.atalhoPrompt
        if prompt.tecla == tecla && prompt.comShift == shift { return .prompt }
        if livre.tecla == tecla && livre.comShift == shift { return .livre }
        // Shift apertado por acaso numa tecla sem variação com Shift
        if livre.tecla == tecla && !livre.comShift { return .livre }
        if prompt.tecla == tecla && !prompt.comShift { return .prompt }
        return nil
    }
}
