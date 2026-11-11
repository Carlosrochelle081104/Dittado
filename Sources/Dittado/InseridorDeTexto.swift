import AppKit
import ApplicationServices

enum ResultadoInsercao {
    case colado          // havia campo de texto: colou e restaurou a área de transferência
    case coladoECopiado  // não deu para confirmar o campo: colou e deixou o texto copiado
    case soCopiado       // sem campo de texto (ou campo de senha): só copiou
}

/// Cola o texto no campo ativo de qualquer app (Cmd+V simulado).
enum InseridorDeTexto {
    private enum Alvo { case editavel, senha, desconhecido, nenhum }

    private static let papeisDeTexto: Set<String> = [
        kAXTextFieldRole as String, kAXTextAreaRole as String, kAXComboBoxRole as String, "AXSearchField",
    ]

    static func inserir(_ texto: String) -> ResultadoInsercao {
        let alvo = alvoAtual()
        let pb = NSPasteboard.general

        guard alvo == .editavel || alvo == .desconhecido else {
            pb.clearContents()
            pb.setString(texto, forType: .string)
            return .soCopiado
        }

        let anterior = alvo == .editavel ? salvar(pb) : nil
        pb.clearContents()
        pb.setString(texto, forType: .string)
        let contagemNossa = pb.changeCount
        colar()

        if let anterior {
            // Devolve o que estava copiado antes, se ninguém mexeu na área de transferência
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard pb.changeCount == contagemNossa else { return }
                pb.clearContents()
                if !anterior.isEmpty { pb.writeObjects(anterior) }
            }
            return .colado
        }
        return .coladoECopiado
    }

    /// Apps em que o Dittado é mais usado. Nunca ficam sem colar, mesmo se a Acessibilidade não
    /// disser qual campo está ativo (Electron e Chrome muitas vezes não dizem).
    private static let appsPrincipais: Set<String> = [
        "com.anthropic.claudefordesktop", "com.openai.chat", "com.openai.codex", "com.google.Chrome", "net.whatsapp.WhatsApp",
    ]

    private static func alvoAtual() -> Alvo {
        guard let app = NSWorkspace.shared.frontmostApplication else { return .nenhum }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        // Electron (Claude, ChatGPT antigo, WhatsApp antigo) só expõe os campos com isso ligado
        AXUIElementSetAttributeValue(appEl, "AXManualAccessibility" as CFString, kCFBooleanTrue)

        guard let elemento = elementoEmFoco(appEl) else {
            // Sem informação: só deixa de colar no Finder/mesa (aí não há onde colar mesmo)
            if app.bundleIdentifier == "com.apple.finder" { return .nenhum }
            return .desconhecido
        }

        if atributo(elemento, kAXSubroleAttribute) == kAXSecureTextFieldSubrole as String { return .senha }
        if appsPrincipais.contains(app.bundleIdentifier ?? "") { return .editavel }
        if let papel = atributo(elemento, kAXRoleAttribute), papeisDeTexto.contains(papel) { return .editavel }
        var ajustavel = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(elemento, kAXValueAttribute as CFString, &ajustavel) == .success,
           ajustavel.boolValue { return .editavel }
        // Finder com algo selecionado mas sem campo de texto: não cola (Cmd+V duplicaria arquivos)
        if app.bundleIdentifier == "com.apple.finder" { return .nenhum }
        return .desconhecido
    }

    private static func elementoEmFoco(_ appEl: AXUIElement) -> AXUIElement? {
        for origem in [appEl, AXUIElementCreateSystemWide()] {
            var valor: CFTypeRef?
            if AXUIElementCopyAttributeValue(origem, kAXFocusedUIElementAttribute as CFString, &valor) == .success,
               let valor, CFGetTypeID(valor) == AXUIElementGetTypeID() {
                return (valor as! AXUIElement)
            }
        }
        return nil
    }

    private static func atributo(_ el: AXUIElement, _ nome: String) -> String? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, nome as CFString, &v) == .success else { return nil }
        return v as? String
    }

    private static func salvar(_ pb: NSPasteboard) -> [NSPasteboardItem] {
        (pb.pasteboardItems ?? []).map { item in
            let copia = NSPasteboardItem()
            for tipo in item.types {
                if let dados = item.data(forType: tipo) { copia.setData(dados, forType: tipo) }
            }
            return copia
        }
    }

    private static func colar() {
        let fonte = CGEventSource(stateID: .combinedSessionState)
        let teclaV: CGKeyCode = 9
        let desce = CGEvent(keyboardEventSource: fonte, virtualKey: teclaV, keyDown: true)
        let sobe = CGEvent(keyboardEventSource: fonte, virtualKey: teclaV, keyDown: false)
        // Só Cmd, mesmo que o Shift ainda esteja apertado (senão vira Cmd+Shift+V)
        desce?.flags = .maskCommand
        sobe?.flags = .maskCommand
        desce?.post(tap: .cghidEventTap)
        sobe?.post(tap: .cghidEventTap)
    }
}
