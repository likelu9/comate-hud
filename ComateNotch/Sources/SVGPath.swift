import AppKit
import SwiftUI

/// SVG path 数据 → `CGPath`（只实现本仓库用到的子集：`M/m L/l H/h V/v C/c S/s Q/q T/t A/a Z/z`）。
///
/// 存在的唯一理由：GitHub 官方徽标只有 **SVG path** 一种官方形态（SF Symbols 没有该字形），
/// 而内置位图资产要另建资源拷贝链路、还得为每种尺寸出图 —— 直接解析 path 画成矢量，
/// 与官网下载页用的是同一份坐标数据，缩放无伪影（用户反馈 ②：GitHub 按钮要用真实图标）。
enum SVGPath {
    /// 解析 `d`，坐标系按 `viewBox` 的尺寸原样返回（调用方自行缩放到目标 rect）
    static func cgPath(_ d: String, viewBox: CGSize) -> CGPath {
        _ = viewBox
        let path = CGMutablePath()
        var sc = Scanner(d)

        var cur = CGPoint.zero
        var start = CGPoint.zero
        var cubicCtrl: CGPoint?      // 上一段三次贝塞尔的第二控制点（S/s 的反射源）
        var quadCtrl: CGPoint?       // 上一段二次贝塞尔的控制点（T/t 的反射源）

        func abs(_ x: Double, _ y: Double, _ relative: Bool) -> CGPoint {
            relative ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
        }

        while let cmd = sc.takeCommand() {
            let rel = cmd.isLowercase
            switch Character(cmd.lowercased()) {
            case "m":
                var isFirst = true
                while let x = sc.number(), let y = sc.number() {
                    let p = abs(x, y, rel)
                    if isFirst {
                        path.move(to: p)
                        start = p
                        isFirst = false
                    } else {
                        path.addLine(to: p)
                    }
                    cur = p
                }
                cubicCtrl = nil; quadCtrl = nil

            case "l":
                while let x = sc.number(), let y = sc.number() {
                    let p = abs(x, y, rel)
                    path.addLine(to: p)
                    cur = p
                }
                cubicCtrl = nil; quadCtrl = nil

            case "h":
                while let x = sc.number() {
                    let p = CGPoint(x: rel ? cur.x + x : x, y: cur.y)
                    path.addLine(to: p)
                    cur = p
                }
                cubicCtrl = nil; quadCtrl = nil

            case "v":
                while let y = sc.number() {
                    let p = CGPoint(x: cur.x, y: rel ? cur.y + y : y)
                    path.addLine(to: p)
                    cur = p
                }
                cubicCtrl = nil; quadCtrl = nil

            case "c":
                while let x1 = sc.number(), let y1 = sc.number(),
                      let x2 = sc.number(), let y2 = sc.number(),
                      let x = sc.number(), let y = sc.number() {
                    let c1 = abs(x1, y1, rel)
                    let c2 = abs(x2, y2, rel)
                    let p = abs(x, y, rel)
                    path.addCurve(to: p, control1: c1, control2: c2)
                    cubicCtrl = c2; quadCtrl = nil
                    cur = p
                }

            case "s":
                while let x2 = sc.number(), let y2 = sc.number(),
                      let x = sc.number(), let y = sc.number() {
                    let c1 = cubicCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                    let c2 = abs(x2, y2, rel)
                    let p = abs(x, y, rel)
                    path.addCurve(to: p, control1: c1, control2: c2)
                    cubicCtrl = c2; quadCtrl = nil
                    cur = p
                }

            case "q":
                while let x1 = sc.number(), let y1 = sc.number(),
                      let x = sc.number(), let y = sc.number() {
                    let c = abs(x1, y1, rel)
                    let p = abs(x, y, rel)
                    path.addQuadCurve(to: p, control: c)
                    quadCtrl = c; cubicCtrl = nil
                    cur = p
                }

            case "t":
                while let x = sc.number(), let y = sc.number() {
                    let c = quadCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                    let p = abs(x, y, rel)
                    path.addQuadCurve(to: p, control: c)
                    quadCtrl = c; cubicCtrl = nil
                    cur = p
                }

            case "a":
                while let rx = sc.number(), let ry = sc.number(), let rot = sc.number(),
                      let large = sc.flag(), let sweep = sc.flag(),
                      let x = sc.number(), let y = sc.number() {
                    let p = abs(x, y, rel)
                    addArc(to: path, from: cur, to: p, rx: rx, ry: ry,
                           xAxisRotation: rot, largeArc: large != 0, sweep: sweep != 0)
                    cur = p
                }
                cubicCtrl = nil; quadCtrl = nil

            case "z":
                path.closeSubpath()
                cur = start
                cubicCtrl = nil; quadCtrl = nil

            default:
                break
            }
        }
        return path
    }

    /// 椭圆弧 → 三次贝塞尔（W3C SVG 实现附件 F.6.5 的端点参数化 + F.6.6 的弧转贝塞尔）
    private static func addArc(to path: CGMutablePath, from p0: CGPoint, to p1: CGPoint,
                               rx rxIn: Double, ry ryIn: Double, xAxisRotation: Double,
                               largeArc: Bool, sweep: Bool) {
        var rx = abs(rxIn), ry = abs(ryIn)
        guard rx > 0, ry > 0, p0 != p1 else {
            if p0 != p1 { path.addLine(to: p1) }
            return
        }
        let phi = xAxisRotation * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx2 = (p0.x - p1.x) / 2, dy2 = (p0.y - p1.y) / 2
        let x1p = cosPhi * dx2 + sinPhi * dy2
        let y1p = -sinPhi * dx2 + cosPhi * dy2
        // 半径过小则按 F.6.6.2 等比放大
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let s = sqrt(lambda)
            rx *= s; ry *= s
        }
        let sign: Double = largeArc == sweep ? -1 : 1
        let numer = max(0, rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p)
        let denom = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        let coef = sign * sqrt(denom == 0 ? 0 : numer / denom)
        let cxp = coef * rx * y1p / ry
        let cyp = -coef * ry * x1p / rx
        let cx = cosPhi * cxp - sinPhi * cyp + (p0.x + p1.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p0.y + p1.y) / 2

        func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            let dot = ux * vx + uy * vy
            let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            var a = acos(min(1, max(-1, len == 0 ? 1 : dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }
        let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry,
                          (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }

        // 每段弧不超过 90°，够稳也够平滑
        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let step = delta / Double(segments)
        let alpha = 4.0 / 3.0 * tan(step / 4)

        func point(_ t: Double) -> CGPoint {
            let x = rx * cos(t), y = ry * sin(t)
            return CGPoint(x: cosPhi * x - sinPhi * y + cx, y: sinPhi * x + cosPhi * y + cy)
        }
        func derivative(_ t: Double) -> CGPoint {
            let x = -rx * sin(t), y = ry * cos(t)
            return CGPoint(x: cosPhi * x - sinPhi * y, y: sinPhi * x + cosPhi * y)
        }
        var t = theta1
        for _ in 0..<segments {
            let t2 = t + step
            let a = point(t), b = point(t2)
            let da = derivative(t), db = derivative(t2)
            path.addCurve(to: b,
                          control1: CGPoint(x: a.x + alpha * da.x, y: a.y + alpha * da.y),
                          control2: CGPoint(x: b.x - alpha * db.x, y: b.y - alpha * db.y))
            t = t2
        }
    }

    /// path 数据扫描器：命令字母 + 数字（含 `1.23.82` 这种省略分隔符的连写、`.07` 这种省略整数位）
    private struct Scanner {
        private let chars: [Character]
        private var i = 0

        init(_ s: String) { chars = Array(s) }

        private mutating func skipSeparators() {
            while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i] == "\n"
                    || chars[i] == "\t" || chars[i] == "\r" {
                i += 1
            }
        }

        /// 下一个命令字母；没有则返回 nil（数字由 `number()` 继续读，用于隐式重复上一命令）
        mutating func takeCommand() -> Character? {
            skipSeparators()
            guard i < chars.count, chars[i].isLetter else { return nil }
            defer { i += 1 }
            return chars[i]
        }

        /// 读一个数，失败（含后面确实是命令字母）时不前进
        mutating func number() -> Double? {
            skipSeparators()
            let save = i
            var s = ""
            if i < chars.count, chars[i] == "+" || chars[i] == "-" {
                s.append(chars[i]); i += 1
            }
            var sawDigit = false
            while i < chars.count, chars[i].isNumber {
                s.append(chars[i]); i += 1; sawDigit = true
            }
            if i < chars.count, chars[i] == "." {
                s.append("."); i += 1
                while i < chars.count, chars[i].isNumber {
                    s.append(chars[i]); i += 1; sawDigit = true
                }
            }
            guard sawDigit, let value = Double(s) else {
                i = save
                return nil
            }
            if i < chars.count, chars[i] == "e" || chars[i] == "E" {
                var e = ""
                var j = i + 1
                if j < chars.count, chars[j] == "+" || chars[j] == "-" { e.append(chars[j]); j += 1 }
                var expDigits = 0
                while j < chars.count, chars[j].isNumber { e.append(chars[j]); j += 1; expDigits += 1 }
                if expDigits > 0 {
                    i = j
                    return Double(s + "e" + e) ?? value
                }
            }
            return value
        }

        /// 弧标志位（large-arc / sweep）：SVG 允许 "0 0 1" 也允许 "001" 连写
        mutating func flag() -> Double? {
            skipSeparators()
            guard i < chars.count, chars[i] == "0" || chars[i] == "1" else { return nil }
            defer { i += 1 }
            return Double(String(chars[i]))
        }
    }
}

/// 官方 GitHub 徽标（`viewBox 0 0 16 16` 的 octocat path）
///
/// 与 `ComateHUD/index.html` 下载页的 `<svg>` 是同一份坐标数据 —— 用户反馈「参考官网的 git 按钮图标」，
/// 官网那份就是标准 octocat（官方仓 `logos/github-mark.svg`），因此不再用 SF Symbols 的替代字形。
/// 路径按非零环绕规则填充（官方 path 自带内外轮廓，不需要 even-odd）
struct GitHubMark: Shape {
    static let viewBox = CGSize(width: 16, height: 16)

    static let pathData = """
        M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49\
        -2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07\
        -1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.4 7.4 0 0 1 2-.27c.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z
        """

    private static let cached: CGPath = SVGPath.cgPath(pathData, viewBox: viewBox)

    func path(in rect: CGRect) -> Path {
        let scale = CGAffineTransform(scaleX: rect.width / Self.viewBox.width,
                                      y: rect.height / Self.viewBox.height)
        return Path(Self.cached.copy() ?? Self.cached).applying(scale)
            .offsetBy(dx: rect.minX, dy: rect.minY)
    }
}
