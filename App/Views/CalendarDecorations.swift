import SwiftUI
import UIKit

struct CalendarBackdrop: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.colorScheme) private var scheme
    var preview: CalendarAppearance? = nil
    var drawsStickers = true
    var animatePaws = true
    var body: some View {
        let appearance = preview ?? store.library.appearance
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: scheme == .dark ? [Color(red: 0.045, green: 0.035, blue: 0.065), .black, Color(red: 0.075, green: 0.045, blue: 0.095)] : [Color(red: 0.98, green: 0.96, blue: 1), Color(red: 1, green: 0.98, blue: 0.99)], startPoint: .topLeading, endPoint: .bottomTrailing)
                if appearance.background.showsImage {
                    Group {
                        if let name = appearance.background.imageName, let image = store.image(named: name) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else { Image("DayWallpaper").resizable().scaledToFill() }
                    }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        .blur(radius: appearance.background.blur)
                    (scheme == .dark ? Color.black : Color.white).opacity(appearance.background.veil)
                }
                if drawsStickers {
                    ForEach(appearance.stickers) { layer in StickerImage(layer: layer, canvas: geometry.size) }
                }
                if appearance.nightPaws && scheme == .dark { PawTrail(animated: animatePaws) }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct StickerImage: View {
    @EnvironmentObject private var store: DiaryStore
    let layer: CalendarSticker
    let canvas: CGSize
    var body: some View {
        if let image = store.image(named: layer.imageName) {
            let width = canvas.width * layer.width
            Image(uiImage: image).resizable().scaledToFit()
                .frame(width: width, height: width * image.size.height / max(1, image.size.width))
                .rotationEffect(.degrees(layer.rotation)).opacity(layer.opacity)
                .position(x: canvas.width * layer.x, y: canvas.height * layer.y)
        }
    }
}

struct PawTrail: View {
    @Environment(\.miuAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    @State private var visible = false
    var animated = true
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: !animated || reduceMotion || phase != .active || !visible)) { context in
            GeometryReader { geometry in
                let time = animated && !reduceMotion ? context.date.timeIntervalSinceReferenceDate : 7.0
                ForEach(0..<5, id: \.self) { index in
                    let progress = (time / 13 + Double(index) / 5).truncatingRemainder(dividingBy: 1)
                    Image(systemName: "pawprint.fill").font(.system(size: index % 2 == 0 ? 12 : 15))
                        .rotationEffect(.degrees(index % 2 == 0 ? -20 : 22))
                        .foregroundStyle(accent.opacity(0.25))
                        .opacity(reduceMotion ? 0.5 : max(0, sin(progress * .pi)))
                        .position(x: index % 2 == 0 ? 12 : geometry.size.width - 12,
                                  y: geometry.size.height * (1 - progress))
                }
            }
        }.onAppear { visible = true }.onDisappear { visible = false }
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct DatePickerDecoration<Content: View>: View {
    @Environment(\.miuAccent) private var accent
    let day: String
    let content: Content
    init(day: String, @ViewBuilder content: () -> Content) { self.day = day; self.content = content() }
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack(spacing: 16) {
                    Image(systemName: "moon.stars").font(.system(size: 30, weight: .light))
                        .frame(width: 68, height: 68).modifier(GlassSurface(radius: 22)).foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("翻一页，遇见那天的你。").font(.headline)
                        Text(MiuTheme.date(day, template: "yyyy年 M月d日"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }.padding(.top, 16)
                content.padding(12).modifier(GlassSurface())
                HStack(spacing: 8) {
                    Image(systemName: "pawprint.fill").foregroundStyle(accent.opacity(0.6))
                    Text("选好日子，Miu 带你翻过去。")
                }.font(.footnote).foregroundStyle(.secondary)
            }.padding(.horizontal, 20).padding(.bottom, 24)
        }.background {
            LinearGradient(colors: [accent.opacity(0.10), MiuTheme.page, MiuTheme.rose.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
        }
    }
}
