// Gera Recursos/AppIcon.icns: quadrado arredondado em degradê com ondas de voz.
// Uso: swift scripts/gerar-icone.swift
import AppKit

func desenhar(_ lado: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(lado), pixelsHigh: Int(lado),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Grade do macOS: ícone ocupa ~80% do quadro, cantos ~22%
    let m = lado * 0.1
    let caixa = NSRect(x: m, y: m, width: lado - 2 * m, height: lado - 2 * m)
    let fundo = NSBezierPath(roundedRect: caixa, xRadius: caixa.width * 0.225, yRadius: caixa.width * 0.225)
    NSGradient(colors: [NSColor(red: 0.42, green: 0.25, blue: 0.95, alpha: 1),
                        NSColor(red: 0.13, green: 0.55, blue: 0.98, alpha: 1)])!
        .draw(in: fundo, angle: -60)

    // Barras de onda sonora
    let alturas: [CGFloat] = [0.22, 0.42, 0.62, 0.42, 0.22]
    let largura = caixa.width * 0.085
    let espaco = caixa.width * 0.06
    let total = CGFloat(alturas.count) * largura + CGFloat(alturas.count - 1) * espaco
    var x = caixa.midX - total / 2
    NSColor.white.setFill()
    for a in alturas {
        let h = caixa.height * a
        NSBezierPath(roundedRect: NSRect(x: x, y: caixa.midY - h / 2, width: largura, height: h),
                     xRadius: largura / 2, yRadius: largura / 2).fill()
        x += largura + espaco
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let pasta = URL(fileURLWithPath: "build/AppIcon.iconset")
try? FileManager.default.removeItem(at: pasta)
try! FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for escala in [1, 2] {
        let nome = escala == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let png = desenhar(CGFloat(base * escala)).representation(using: .png, properties: [:])!
        try! png.write(to: pasta.appendingPathComponent(nome))
    }
}
print("iconset gerado")
