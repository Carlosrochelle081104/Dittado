import AppKit
import SwiftUI
import DittadoCore

/// Estado do indicador flutuante.
final class EstadoIndicador: ObservableObject {
    enum Fase: Equatable {
        case gravando
        case travado
        case transcrevendo
        case sucesso(String)
        case aviso(String)
    }

    @Published var fase: Fase = .gravando
    @Published var modo: ModoDitado = .livre
    @Published var nivel: Float = 0
    @Published var visivel: Bool = false
}

/// Pílula flutuante na parte de baixo da tela com estética translúcida (estilo Wispr Flow).
final class Indicador {
    let estado = EstadoIndicador()
    private var painel: NSPanel?
    private var ocultar: DispatchWorkItem?

    func mostrar(_ fase: EstadoIndicador.Fase, modo: ModoDitado? = nil, por segundos: Double? = nil) {
        ocultar?.cancel()
        estado.fase = fase
        if let modo { estado.modo = modo }
        if case .gravando = fase { estado.nivel = 0 }

        let p = painel ?? criarPainel()
        posicionar(p)
        p.orderFrontRegardless()

        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            estado.visivel = true
        }

        if let segundos {
            let item = DispatchWorkItem { [weak self] in self?.esconder() }
            ocultar = item
            DispatchQueue.main.asyncAfter(deadline: .now() + segundos, execute: item)
        }
    }

    func esconder() {
        ocultar?.cancel()
        // Ao transcrever com sucesso, exibe uma confirmação animada antes de recolher
        if case .transcrevendo = estado.fase {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                estado.fase = .sucesso("Colado")
            }
            let item = DispatchWorkItem { [weak self] in
                self?.animarSaida()
            }
            ocultar = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: item)
        } else {
            animarSaida()
        }
    }

    private func animarSaida() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            estado.visivel = false
        }
        let item = DispatchWorkItem { [weak self] in
            self?.painel?.orderOut(nil)
        }
        ocultar = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    private func criarPainel() -> NSPanel {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 72),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let hosting = NSHostingView(rootView: VistaIndicador(estado: estado))
        p.contentView = hosting
        painel = p
        return p
    }

    private func posicionar(_ p: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let tela = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let area = tela?.visibleFrame else { return }
        p.setFrameOrigin(NSPoint(x: area.midX - p.frame.width / 2, y: area.minY + 30))
    }
}

// MARK: - Vista Indicador (Estilo Wispr Flow)

private struct VistaIndicador: View {
    @ObservedObject var estado: EstadoIndicador

    var body: some View {
        HStack(spacing: 11) {
            conteudoFase
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 38)
        .background(
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Color(red: 0.07, green: 0.08, blue: 0.11).opacity(0.82))
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.24), Color.white.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
        )
        .shadow(color: corModo.opacity(0.38), radius: 12, y: 2)
        .shadow(color: Color.black.opacity(0.32), radius: 14, y: 6)
        .scaleEffect(estado.visivel ? 1.0 : 0.82)
        .opacity(estado.visivel ? 1.0 : 0.0)
        .offset(y: estado.visivel ? 0 : 8)
        .animation(.spring(response: 0.36, dampingFraction: 0.74), value: estado.fase)
        .animation(.spring(response: 0.36, dampingFraction: 0.74), value: estado.visivel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var conteudoFase: some View {
        switch estado.fase {
        case .gravando:
            PontoPulsante(cor: corModo)
            BarrasOndaFluida(nivel: estado.nivel, cor: corModo)
            Text(estado.modo.nomeExibicao)
                .font(.system(size: 13, weight: .semibold, design: .rounded))

        case .travado:
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(corModo)
            BarrasOndaFluida(nivel: estado.nivel, cor: corModo)
            Text("\(estado.modo.nomeExibicao) · toque para finalizar")
                .font(.system(size: 12, weight: .medium, design: .rounded))

        case .transcrevendo:
            ShimmerOnda(cor: corModo)
            Text("Transcrevendo…")
                .font(.system(size: 13, weight: .medium, design: .rounded))

        case .sucesso(let msg):
            CheckmarkAnimado()
            Text(msg.isEmpty ? "Inserido" : msg)
                .font(.system(size: 13, weight: .semibold, design: .rounded))

        case .aviso(let msg):
            if msg.hasPrefix("✓") || msg.contains("✓") {
                CheckmarkAnimado()
                Text(limparAviso(msg))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.76, blue: 0.28))
                Text(msg)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
        }
    }

    private var corModo: Color {
        estado.modo == .prompt
            ? Color(red: 0.68, green: 0.42, blue: 1.0)
            : Color(red: 0.22, green: 0.65, blue: 1.0)
    }

    private func limparAviso(_ msg: String) -> String {
        msg.replacingOccurrences(of: "✓", with: "").trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Forma de Onda Fluida (Barras que respiram e reagem ao áudio)

private struct BarrasOndaFluida: View {
    let nivel: Float
    let cor: Color
    private let pesos: [CGFloat] = [0.45, 0.75, 1.0, 0.85, 0.5]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let n = CGFloat(min(1, max(0, (log10(max(nivel, 0.0005)) + 3.3) / 2.3)))

            HStack(spacing: 3.2) {
                ForEach(0..<pesos.count, id: \.self) { i in
                    let onda = sin(t * 3.8 + Double(i) * 0.85)
                    let respiracao = (onda + 1.0) * 0.5
                    let alturaIdle = 4.0 + 3.5 * CGFloat(respiracao) * pesos[i]
                    let alturaVoz = 16.0 * n * pesos[i]
                    let h = min(22, max(3.5, alturaIdle + alturaVoz))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [cor.opacity(0.95), cor.opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3.2, height: h)
                }
            }
            .frame(height: 22)
            .animation(.easeOut(duration: 0.07), value: nivel)
        }
    }
}

// MARK: - Componentes de Animação

private struct PontoPulsante: View {
    let cor: Color
    @State private var pulsar = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(cor.opacity(0.45), lineWidth: 2)
                .scaleEffect(pulsar ? 1.8 : 1.0)
                .opacity(pulsar ? 0.0 : 0.8)
            Circle()
                .fill(cor)
                .frame(width: 8, height: 8)
        }
        .frame(width: 14, height: 14)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulsar = true
            }
        }
    }
}

private struct ShimmerOnda: View {
    let cor: Color
    @State private var fase: CGFloat = 0

    var body: some View {
        HStack(spacing: 3.5) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(cor)
                    .frame(width: 3.2, height: altura(i))
                    .opacity(opacidade(i))
            }
        }
        .frame(height: 18)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                fase = 1
            }
        }
    }

    private func altura(_ i: Int) -> CGFloat {
        let base: [CGFloat] = [6, 12, 16, 8]
        let alt: [CGFloat] = [14, 7, 8, 15]
        return base[i] + (alt[i] - base[i]) * fase
    }

    private func opacidade(_ i: Int) -> Double {
        let o0 = [0.45, 0.8, 1.0, 0.55]
        let o1 = [1.0, 0.5, 0.7, 0.95]
        return o0[i] + (o1[i] - o0[i]) * Double(fase)
    }
}

private struct CheckmarkAnimado: View {
    @State private var animado = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.2, green: 0.82, blue: 0.48))
                .frame(width: 18, height: 18)
                .shadow(color: Color(red: 0.2, green: 0.82, blue: 0.48).opacity(0.45), radius: 6, y: 0)
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .scaleEffect(animado ? 1.0 : 0.2)
        .opacity(animado ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.58)) {
                animado = true
            }
        }
    }
}
