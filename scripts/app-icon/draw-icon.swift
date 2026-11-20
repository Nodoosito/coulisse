// Draws the Coulisse app icon. Usage: swift scripts/app-icon/draw-icon.swift <A|B|C|D> <size> <out.png>
// D is the shipped icon (curtains, version 2); A, B, C are the earlier concepts.

import AppKit
import CoreGraphics

// Usage: swift draw.swift <concept A|B|C> <size> <out.png>
let args = CommandLine.arguments
let concept = args[1]
let size = Int(args[2])!
let out = args[3]

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let k = CGFloat(size) / 1024
ctx.scaleBy(x: k, y: k)
ctx.interpolationQuality = .high
ctx.setShouldAntialias(true)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
func white(_ a: CGFloat) -> CGColor { CGColor(srgbRed: 1, green: 1, blue: 1, alpha: a) }
func black(_ a: CGFloat) -> CGColor { CGColor(srgbRed: 0, green: 0, blue: 0, alpha: a) }
func rr(_ r: CGRect, _ rad: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil) }
func linear(_ c: [CGColor], _ from: CGPoint, _ to: CGPoint) {
    let g = CGGradient(colorsSpace: cs, colors: c as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}
func radial(_ c: [CGColor], _ center: CGPoint, _ r: CGFloat) {
    let g = CGGradient(colorsSpace: cs, colors: c as CFArray, locations: nil)!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: r, options: [])
}
func fill(_ p: CGPath, _ c: CGColor) { ctx.addPath(p); ctx.setFillColor(c); ctx.fillPath() }
func fillGradient(_ p: CGPath, _ c: [CGColor], _ from: CGPoint, _ to: CGPoint) {
    ctx.saveGState(); ctx.addPath(p); ctx.clip(); linear(c, from, to); ctx.restoreGState()
}
func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r), transform: nil)
}

// macOS icon grid: 824 pt body centered in 1024, ~185 pt corners, soft drop shadow.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = rr(body, 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: black(0.35))
fill(bodyPath, rgb(0x000000))
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(bodyPath)
ctx.clip()

switch concept {
case "A": // Portes coulissantes
    linear([rgb(0x6366F1), rgb(0x7C3AED), rgb(0x4C1D95)], CGPoint(x: 512, y: 924), CGPoint(x: 512, y: 100))
    radial([white(0.22), white(0)], CGPoint(x: 330, y: 540), 330)
    // revealed menu items, glowing
    for y in [650.0, 512.0, 374.0] as [CGFloat] {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 30, color: rgb(0xFDE68A, 0.9))
        fill(circle(330, y, 44), rgb(0xFFFBEB))
        ctx.restoreGState()
    }
    // rails
    fill(rr(CGRect(x: 196, y: 792, width: 632, height: 18), 9), white(0.75))
    fill(rr(CGRect(x: 196, y: 214, width: 632, height: 18), 9), white(0.75))
    // back (fixed) panel outline on the right
    ctx.addPath(rr(CGRect(x: 480, y: 246, width: 330, height: 532), 34))
    ctx.setStrokeColor(white(0.35)); ctx.setLineWidth(6); ctx.strokePath()
    // sliding front panel, half open, casting a shadow left
    let panel = rr(CGRect(x: 452, y: 246, width: 330, height: 532), 34)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: -18, height: -6), blur: 36, color: black(0.45))
    fill(panel, white(1))
    ctx.restoreGState()
    fillGradient(panel, [rgb(0xFFFFFF), rgb(0xE0E7FF)], CGPoint(x: 452, y: 778), CGPoint(x: 782, y: 246))
    // handle groove
    fill(rr(CGRect(x: 492, y: 452, width: 18, height: 120), 9), rgb(0x6366F1, 0.55))
    // motion hint
    for (i, y) in ([600.0, 512.0, 424.0] as [CGFloat]).enumerated() {
        let w: CGFloat = [70, 100, 70][i]
        fill(rr(CGRect(x: 800, y: y - 6, width: w, height: 12), 6), white(0.55))
    }

case "B": // Barre des menus + panneau coulissant
    linear([rgb(0xF8FAFC), rgb(0xCBD5E1)], CGPoint(x: 512, y: 924), CGPoint(x: 512, y: 100))
    let bar = CGRect(x: 160, y: 412, width: 704, height: 200)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: black(0.25))
    fill(rr(bar, 56), rgb(0x1E293B))
    ctx.restoreGState()
    for x in [250.0, 350.0, 450.0, 550.0, 650.0, 750.0] as [CGFloat] {
        fill(circle(x, 512, 30), white(0.92))
    }
    // the sliding panel hides the right half
    let slide = rr(CGRect(x: 488, y: 396, width: 392, height: 232), 62)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: -14, height: -4), blur: 30, color: black(0.4))
    fill(slide, rgb(0xF97316))
    ctx.restoreGState()
    fillGradient(slide, [rgb(0xFDBA74), rgb(0xEA580C)], CGPoint(x: 488, y: 628), CGPoint(x: 880, y: 396))
    // chevron ‹
    let ch = CGMutablePath()
    ch.move(to: CGPoint(x: 620, y: 572)); ch.addLine(to: CGPoint(x: 560, y: 512)); ch.addLine(to: CGPoint(x: 620, y: 452))
    ctx.addPath(ch); ctx.setStrokeColor(white(1)); ctx.setLineWidth(30); ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.strokePath()
    // slide track hint
    fill(rr(CGRect(x: 560, y: 300, width: 240, height: 16), 8), rgb(0x94A3B8, 0.7))
    fill(rr(CGRect(x: 620, y: 260, width: 120, height: 16), 8), rgb(0x94A3B8, 0.45))

case "D": // C v2: scène épurée, rideaux retenus, barre des menus sous le projecteur
    linear([rgb(0x4C1D95), rgb(0x1E1B4B), rgb(0x0B0820)], CGPoint(x: 512, y: 924), CGPoint(x: 512, y: 100))
    // spotlight cone from the top
    let cone = CGMutablePath()
    cone.move(to: CGPoint(x: 452, y: 840)); cone.addLine(to: CGPoint(x: 572, y: 840))
    cone.addLine(to: CGPoint(x: 760, y: 250)); cone.addLine(to: CGPoint(x: 264, y: 250)); cone.closeSubpath()
    fillGradient(cone, [rgb(0xFEF3C7, 0.38), rgb(0xFEF3C7, 0.04)], CGPoint(x: 512, y: 840), CGPoint(x: 512, y: 250))
    // pool of light on the stage
    ctx.saveGState()
    ctx.translateBy(x: 512, y: 300); ctx.scaleBy(x: 1, y: 0.28)
    radial([rgb(0xFDE68A, 0.55), rgb(0xFDE68A, 0)], .zero, 270)
    ctx.restoreGState()
    // the menu bar on stage, same pill as icon B
    let pill = rr(CGRect(x: 352, y: 410, width: 320, height: 116), 58)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: black(0.5))
    fill(pill, rgb(0x0F172A))
    ctx.restoreGState()
    ctx.addPath(pill); ctx.setStrokeColor(white(0.18)); ctx.setLineWidth(4); ctx.strokePath()
    for x in [430.0, 512.0, 594.0] as [CGFloat] {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 22, color: rgb(0xFDE68A, 0.95))
        fill(circle(x, 468, 24), rgb(0xFFFBEB))
        ctx.restoreGState()
    }
    // stage edge
    fillGradient(CGPath(rect: CGRect(x: 80, y: 80, width: 864, height: 150), transform: nil),
                 [rgb(0x1E1B4B), rgb(0x0B0820)], CGPoint(x: 512, y: 230), CGPoint(x: 512, y: 80))
    fill(CGPath(rect: CGRect(x: 80, y: 226, width: 864, height: 8), transform: nil), rgb(0xF59E0B, 0.8))
    // curtains, tied back at y≈430
    func drape(left: Bool) {
        let s: CGFloat = left ? 1 : -1
        func X(_ v: CGFloat) -> CGFloat { left ? v : 1024 - v }
        let p = CGMutablePath()
        p.move(to: CGPoint(x: X(70), y: 950)); p.addLine(to: CGPoint(x: X(372), y: 950))
        p.addCurve(to: CGPoint(x: X(232), y: 430), control1: CGPoint(x: X(372), y: 720), control2: CGPoint(x: X(250), y: 520))
        p.addCurve(to: CGPoint(x: X(300), y: 70), control1: CGPoint(x: X(214), y: 330), control2: CGPoint(x: X(300), y: 200))
        p.addLine(to: CGPoint(x: X(70), y: 70)); p.closeSubpath()
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 16 * s, height: -4), blur: 34, color: black(0.6))
        fill(p, rgb(0x9F1239))
        ctx.restoreGState()
        ctx.saveGState(); ctx.addPath(p); ctx.clip()
        // three broad, soft folds
        let w: CGFloat = 100
        var x: CGFloat = 70
        while x < 400 {
            ctx.saveGState(); ctx.clip(to: CGRect(x: X(left ? x : x + w), y: 0, width: w, height: 1024))
            let a = CGPoint(x: X(x), y: 0), b = CGPoint(x: X(x + w), y: 0)
            linear([rgb(0x881337), rgb(0xF43F5E), rgb(0xBE123C), rgb(0x881337)], a, b)
            ctx.restoreGState()
            x += w
        }
        // inner edge highlight
        ctx.addPath(p); ctx.setStrokeColor(rgb(0xFDA4AF, 0.35)); ctx.setLineWidth(6); ctx.strokePath()
        ctx.restoreGState()
        // gold tie-back
        let tie = rr(CGRect(x: left ? 150 : 1024 - 150 - 104, y: 410, width: 104, height: 40), 20)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 10, color: black(0.5))
        fill(tie, rgb(0xF59E0B))
        ctx.restoreGState()
        fillGradient(tie, [rgb(0xFDE68A), rgb(0xD97706)], CGPoint(x: 0, y: 450), CGPoint(x: 0, y: 410))
    }
    drape(left: true); drape(left: false)
    // straight valance with gold trim
    let val = CGPath(rect: CGRect(x: 80, y: 800, width: 864, height: 150), transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: black(0.55))
    fill(val, rgb(0x881337))
    ctx.restoreGState()
    fillGradient(val, [rgb(0xBE123C), rgb(0x881337)], CGPoint(x: 512, y: 950), CGPoint(x: 512, y: 800))
    fill(CGPath(rect: CGRect(x: 80, y: 800, width: 864, height: 14), transform: nil), rgb(0xF59E0B))

default: // C: Rideau de scène (coulisses)
    linear([rgb(0x2E1065), rgb(0x0F0A1E)], CGPoint(x: 512, y: 924), CGPoint(x: 512, y: 100))
    // spotlight on stage
    radial([rgb(0xFDE68A, 0.55), rgb(0xFDE68A, 0)], CGPoint(x: 512, y: 300), 300)
    for x in [432.0, 512.0, 592.0] as [CGFloat] {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 26, color: rgb(0xFDE68A, 0.9))
        fill(circle(x, 470, 30), rgb(0xFFFBEB))
        ctx.restoreGState()
    }
    // stage floor
    fill(CGPath(rect: CGRect(x: 100, y: 100, width: 824, height: 150), transform: nil), rgb(0x7C2D12))
    fillGradient(CGPath(rect: CGRect(x: 100, y: 100, width: 824, height: 150), transform: nil),
                 [rgb(0xB45309), rgb(0x451A03)], CGPoint(x: 512, y: 250), CGPoint(x: 512, y: 100))
    func curtain(left: Bool) {
        let p = CGMutablePath()
        if left {
            p.move(to: CGPoint(x: 80, y: 940)); p.addLine(to: CGPoint(x: 380, y: 940))
            p.addCurve(to: CGPoint(x: 250, y: 380), control1: CGPoint(x: 380, y: 700), control2: CGPoint(x: 250, y: 520))
            p.addCurve(to: CGPoint(x: 330, y: 80), control1: CGPoint(x: 250, y: 260), control2: CGPoint(x: 330, y: 160))
            p.addLine(to: CGPoint(x: 80, y: 80)); p.closeSubpath()
        } else {
            p.move(to: CGPoint(x: 944, y: 940)); p.addLine(to: CGPoint(x: 644, y: 940))
            p.addCurve(to: CGPoint(x: 774, y: 380), control1: CGPoint(x: 644, y: 700), control2: CGPoint(x: 774, y: 520))
            p.addCurve(to: CGPoint(x: 694, y: 80), control1: CGPoint(x: 774, y: 260), control2: CGPoint(x: 694, y: 160))
            p.addLine(to: CGPoint(x: 944, y: 80)); p.closeSubpath()
        }
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: left ? 12 : -12, height: 0), blur: 30, color: black(0.6))
        fill(p, rgb(0x991B1B))
        ctx.restoreGState()
        ctx.saveGState(); ctx.addPath(p); ctx.clip()
        // folds
        var x: CGFloat = 80
        while x < 944 {
            ctx.saveGState(); ctx.clip(to: CGRect(x: x, y: 0, width: 64, height: 1024))
            linear([rgb(0x7F1D1D), rgb(0xDC2626), rgb(0x7F1D1D)], CGPoint(x: x, y: 0), CGPoint(x: x + 64, y: 0))
            ctx.restoreGState()
            x += 64
        }
        ctx.restoreGState()
    }
    curtain(left: true); curtain(left: false)
    // valance
    let val = CGMutablePath()
    val.move(to: CGPoint(x: 80, y: 944)); val.addLine(to: CGPoint(x: 944, y: 944)); val.addLine(to: CGPoint(x: 944, y: 800))
    var vx: CGFloat = 944
    while vx > 80 { val.addQuadCurve(to: CGPoint(x: vx - 108, y: 800), control: CGPoint(x: vx - 54, y: 730)); vx -= 108 }
    val.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: black(0.55))
    fill(val, rgb(0x7F1D1D))
    ctx.restoreGState()
    fillGradient(val, [rgb(0xB91C1C), rgb(0x7F1D1D)], CGPoint(x: 512, y: 944), CGPoint(x: 512, y: 760))
    fill(CGPath(rect: CGRect(x: 80, y: 812, width: 864, height: 10), transform: nil), rgb(0xFBBF24, 0.85))
}

// subtle top highlight, as on Apple icons
ctx.restoreGState()
ctx.saveGState(); ctx.addPath(bodyPath); ctx.clip()
linear([white(0.10), white(0)], CGPoint(x: 512, y: 924), CGPoint(x: 512, y: 640))
ctx.restoreGState()

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
