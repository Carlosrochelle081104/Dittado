import Foundation
import DittadoCore

struct ItemHistorico: Codable, Identifiable {
    var id: Date { data }
    let data: Date
    let modo: ModoDitado
    let texto: String
    let app: String?
    let segundosAudio: Double
    let segundosTranscricao: Double
}

/// Últimas transcrições, salvas em JSON local.
final class Historico: ObservableObject {
    @Published private(set) var itens: [ItemHistorico] = []
    private let url = Pastas.suporte.appendingPathComponent("historico.json")
    private let limite = 200

    init() {
        if let dados = try? Data(contentsOf: url) {
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
            itens = (try? dec.decode([ItemHistorico].self, from: dados)) ?? []
        }
    }

    func adicionar(_ item: ItemHistorico) {
        guard Config.shared.ativarHistorico else { return }
        itens.insert(item, at: 0)
        if itens.count > limite { itens.removeLast(itens.count - limite) }
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = .prettyPrinted
        try? enc.encode(itens).write(to: url, options: .atomic)
    }

    func limpar() {
        itens.removeAll()
        try? FileManager.default.removeItem(at: url)
    }
}
