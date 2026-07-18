#!/usr/bin/env swift
//
//  generate_app_icon.swift
//  BarkMate AppIcon 生成器
//
//  用法:
//    swift scripts/generate_app_icon.swift preview   # 仅输出 1024 预览
//    swift scripts/generate_app_icon.swift all       # 输出全部 14 尺寸 × 2 套
//
//  设计: Mission Control HUD 风,方括号青 [ ] + 字母 B 琥珀,深墨绿底。
//

import Foundation
import CoreGraphics
import CoreText
import AppKit
import ImageIO
import UniformTypeIdentifiers

// MARK: - Tokens

let bgColor   = CGColor(red: 0x0A/255.0, green: 0x0D/255.0, blue: 0x0C/255.0, alpha: 1)
let bracketC  = CGColor(red: 0x5C/255.0, green: 0xE1/255.0, blue: 0xE6/255.0, alpha: 1)
let letterC   = CGColor(red: 0xFF/255.0, green: 0xB0/255.0, blue: 0x00/255.0, alpha: 1)

// MARK: - Render

/// 绘制一张 size×size 的 AppIcon。Core Graphics 坐标系原点在左下角。
func renderIcon(size: CGFloat) -> CGImage? {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // --- 底色铺满 ---
    ctx.setFillColor(bgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // --- 几何参数 ---
    // 整体内容居中,占画布 ~62% 宽度。
    let contentW = size * 0.62
    let contentH = size * 0.56
    let contentX = (size - contentW) / 2
    let contentY = (size - contentH) / 2

    // 方括号笔画厚度
    let stroke   = size * 0.048

    // 方括号水平横臂的长度(顶/底各一条)
    let armLen   = contentW * 0.28

    // --- 左方括号 ---
    // 形状: ┌─  └─ (顶横、左竖、底横)
    let leftX  = contentX
    let topY   = contentY + contentH
    let botY   = contentY

    ctx.setFillColor(bracketC)

    // 左竖
    ctx.fill(CGRect(x: leftX, y: botY, width: stroke, height: contentH))
    // 左顶横
    ctx.fill(CGRect(x: leftX, y: topY - stroke, width: armLen, height: stroke))
    // 左底横
    ctx.fill(CGRect(x: leftX, y: botY, width: armLen, height: stroke))

    // --- 右方括号 ---
    let rightX = contentX + contentW - stroke
    // 右竖
    ctx.fill(CGRect(x: rightX, y: botY, width: stroke, height: contentH))
    // 右顶横
    ctx.fill(CGRect(x: rightX - armLen + stroke, y: topY - stroke, width: armLen, height: stroke))
    // 右底横
    ctx.fill(CGRect(x: rightX - armLen + stroke, y: botY, width: armLen, height: stroke))

    // --- 字母 B ---
    // 用 SF Mono Bold,fontSize 按画布比例换算。
    let fontSize = size * 0.42
    // CTFontCreate: SF Mono Bold 在 macOS 上的 PostScript 名是 "SFMono-Bold"。
    let font = CTFontCreateWithName("SFMono-Bold" as CFString, fontSize, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: letterC) ?? .orange,
    ]
    let attr = NSAttributedString(string: "B", attributes: attrs)
    let line = CTLineCreateWithAttributedString(attr)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

    // 居中放置
    let drawX = (size - bounds.width) / 2 - bounds.origin.x
    let drawY = (size - bounds.height) / 2 - bounds.origin.y

    ctx.textPosition = CGPoint(x: drawX, y: drawY)
    CTLineDraw(line, ctx)

    return ctx.makeImage()
}

// MARK: - PNG I/O

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let dst = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        throw NSError(domain: "icon", code: 1)
    }
    CGImageDestinationAddImage(dst, image, nil)
    if !CGImageDestinationFinalize(dst) {
        throw NSError(domain: "icon", code: 2)
    }
}

// MARK: - Targets

// iOS AppIcon 需要的物理尺寸(去重后)
let allSizes: [Int] = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]

// Apple 要求 1024 没有 alpha; 我们的输出都是不透明的,直接用 PNG。

// MARK: - Main

let args = CommandLine.arguments
let mode = args.count > 1 ? args[1] : "preview"

// 输出目录
let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // scripts/
    .deletingLastPathComponent()  // 项目根
let assetsRoot = root
    .appendingPathComponent("BarkMate/App/Resources/Assets.xcassets")
let lightSet = assetsRoot.appendingPathComponent("AppIcon.appiconset")
let darkSet  = assetsRoot.appendingPathComponent("AppIcon-Dark.appiconset")

// preview: 只输出 1024 到项目根 /tmp/appicon-preview-1024.png
if mode == "preview" {
    let outDir = root.appendingPathComponent("tmp")
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let outURL = outDir.appendingPathComponent("appicon-preview-1024.png")
    guard let img = renderIcon(size: 1024) else {
        print("render failed"); exit(1)
    }
    try writePNG(img, to: outURL)
    print("✅ 预览已生成: \(outURL.path)")
    exit(0)
}

// all: 全部尺寸,light + dark 完全一致(深底统一)
if mode == "all" {
    for s in allSizes {
        guard let img = renderIcon(size: CGFloat(s)) else {
            print("render \(s) failed"); exit(1)
        }
        for set in [lightSet, darkSet] {
            let url = set.appendingPathComponent("AppIcon-\(s).png")
            try writePNG(img, to: url)
        }
        print("✅ \(s)pt")
    }
    print("全部完成。")
    exit(0)
}

print("用法: swift scripts/generate_app_icon.swift [preview|all]")
exit(1)
