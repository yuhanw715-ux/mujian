import SwiftUI
import PhotosUI
import UIKit

struct CalendarArtEditor: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.miuAccent) private var accent
    @State private var draft = CalendarAppearance()
    @State private var loaded = false
    @State private var selected: UUID?
    @State private var backgroundPhoto: PhotosPickerItem?
    @State private var stickerPhoto: PhotosPickerItem?
    @State private var loading = false
    @State private var issue: AlertMessage?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("背景打底，再贴上喜欢的小图片。").font(.subheadline).foregroundStyle(.secondary)
                    GeometryReader { proxy in
                        ZStack {
                            CalendarBackdrop(preview: draft, drawsStickers: false, animatePaws: false)
                            ForEach($draft.stickers) { $layer in
                                EditableSticker(layer: $layer, canvas: proxy.size, selected: selected == layer.id) { selected = layer.id }
                            }
                            VStack {
                                HStack { Text("暮笺 · 月历").font(.headline); Spacer(); Image(systemName: "calendar") }
                                Spacer()
                                Text("图片可拖动、双指缩放和旋转").font(.caption).padding(10).modifier(GlassSurface(radius: 18))
                            }.padding(18).allowsHitTesting(false)
                        }.clipped().clipShape(RoundedRectangle(cornerRadius: 24))
                    }.frame(height: 390)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("底层背景").font(.headline)
                        Toggle("显示背景图片", isOn: $draft.background.showsImage)
                        HStack {
                            PhotosPicker(selection: $backgroundPhoto, matching: .images, photoLibrary: .shared()) { Label("选择背景", systemImage: "photo") }.disabled(loading)
                            Spacer()
                            Button("默认插画") { draft.background.imageName = nil; draft.background.showsImage = true }
                        }.font(.subheadline)
                        Text("遮罩 \(Int(draft.background.veil * 100))%").font(.caption)
                        Slider(value: $draft.background.veil, in: 0...0.9).accessibilityLabel("月历背景遮罩")
                        Text("模糊 \(Int(draft.background.blur))").font(.caption)
                        Slider(value: $draft.background.blur, in: 0...12).accessibilityLabel("月历背景模糊")
                    }.padding(18).modifier(GlassSurface())
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("图片图层 · \(draft.stickers.count)/12").font(.headline)
                            Spacer()
                            PhotosPicker(selection: $stickerPhoto, matching: .images, photoLibrary: .shared()) { Label("添加", systemImage: "plus") }
                                .disabled(loading || draft.stickers.count >= 12)
                        }
                        if draft.stickers.isEmpty { Text("可以放透明 PNG，猫爪、小贴纸都可以。\n图片叠在背景上，日期和操作按钮仍在最前方。")
                            .font(.footnote).foregroundStyle(.secondary) }
                        ForEach(Array(draft.stickers.enumerated().reversed()), id: \.element.id) { index, layer in
                            Button { selected = layer.id } label: {
                                HStack(spacing: 12) {
                                    if let image = store.image(named: layer.imageName) { Image(uiImage: image).resizable().scaledToFit().frame(width: 38, height: 38) }
                                    Text("图片 \(index + 1)").foregroundStyle(.primary)
                                    Spacer()
                                    if selected == layer.id { Image(systemName: "checkmark.circle.fill") }
                                }.padding(8).background(selected == layer.id ? accent.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                        }
                        if let index = draft.stickers.firstIndex(where: { $0.id == selected }) {
                            Divider()
                            Text("选中图片").font(.subheadline.weight(.semibold))
                            HStack {
                                Button { if let selected { draft.bringToFront(selected) } } label: { Label("置顶", systemImage: "square.3.layers.3d.top.filled") }
                                Spacer()
                                Button("移除", role: .destructive) { draft.stickers.remove(at: index); selected = nil }
                            }.buttonStyle(.borderless)
                            Text("点一次置顶，就移到其他图片上方；下次置顶的图片会盖住它。")
                                .font(.caption).foregroundStyle(.secondary)
                            control("大小", value: $draft.stickers[index].width, range: 0.08...0.95)
                            control("透明度", value: $draft.stickers[index].opacity, range: 0...1)
                            control("左右位置", value: $draft.stickers[index].x, range: 0...1)
                            control("上下位置", value: $draft.stickers[index].y, range: 0...1)
                            control("旋转", value: $draft.stickers[index].rotation, range: -180...180)
                        }
                    }.padding(18).modifier(GlassSurface())
                    if loading { HStack { ProgressView(); Text("正在整理图片…").font(.footnote) } }
                    Text("只编辑月历的装饰，不改变单日背景。位置和大小会随屏幕比例适配；保存后图片不会拦住日期点击和翻月。")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(20)
            }.background(MiuTheme.page).navigationTitle("布置月历").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(loading) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            var next = store.library.appearance
                            next.background = draft.background; next.stickers = draft.stickers
                            do { try store.setAppearance(next); dismiss() }
                            catch { issue = AlertMessage(text: error.localizedDescription) }
                        }.disabled(loading)
                    }
                }
        }.interactiveDismissDisabled(loading)
            .onAppear { if !loaded { draft = store.library.appearance; loaded = true } }
            .onChange(of: backgroundPhoto) { _, value in if let value { load(value, sticker: false) } }
            .onChange(of: stickerPhoto) { _, value in if let value { load(value, sticker: true) } }
            .alert(item: $issue) { item in Alert(title: Text("图片还没放好"), message: Text(item.text), dismissButton: .default(Text("知道啦"))) }
    }
    private func control(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).font(.caption); Slider(value: value, in: range).accessibilityLabel(title) }
    }
    private func load(_ item: PhotosPickerItem, sticker: Bool) {
        loading = true
        Task { @MainActor in
            defer { loading = false; if sticker { stickerPhoto = nil } else { backgroundPhoto = nil } }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw DiaryFailure.message("没有读到图片，请再选一次。") }
                let name = try store.storeImage(data, preservingAlpha: sticker)
                if sticker {
                    guard draft.stickers.count < 12 else { throw DiaryFailure.message("可以放 12 张小图片，请先移除一张。") }
                    let layer = CalendarSticker(imageName: name)
                    draft.stickers.append(layer); selected = layer.id
                } else { draft.background.imageName = name; draft.background.showsImage = true }
            } catch { issue = AlertMessage(text: error.localizedDescription) }
        }
    }
}

private struct EditableSticker: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.miuAccent) private var accent
    @Binding var layer: CalendarSticker
    let canvas: CGSize
    let selected: Bool
    let select: () -> Void
    @GestureState private var offset = CGSize.zero
    @GestureState private var scale: CGFloat = 1
    @GestureState private var rotation = Angle.zero
    var body: some View {
        if let image = store.image(named: layer.imageName) {
            let width = canvas.width * layer.width
            Image(uiImage: image).resizable().scaledToFit()
                .frame(width: width, height: width * image.size.height / max(1, image.size.width))
                .opacity(layer.opacity)
                .overlay { if selected { RoundedRectangle(cornerRadius: 8).strokeBorder(accent, style: StrokeStyle(lineWidth: 1, dash: [4, 3])) } }
                .contentShape(Rectangle()).scaleEffect(scale).rotationEffect(.degrees(layer.rotation) + rotation)
                .position(x: canvas.width * layer.x + offset.width, y: canvas.height * layer.y + offset.height)
                .onTapGesture(perform: select)
                .gesture(DragGesture(minimumDistance: 2).updating($offset) { value, state, _ in state = value.translation }
                    .onChanged { _ in select() }.onEnded { value in
                        layer.x = min(1, max(0, layer.x + value.translation.width / canvas.width))
                        layer.y = min(1, max(0, layer.y + value.translation.height / canvas.height))
                    })
                .simultaneousGesture(MagnifyGesture().updating($scale) { value, state, _ in state = value.magnification }
                    .onChanged { _ in select() }.onEnded { layer.width = min(0.95, max(0.08, layer.width * $0.magnification)) })
                .simultaneousGesture(RotationGesture().updating($rotation) { value, state, _ in state = value }
                    .onChanged { _ in select() }.onEnded { value in
                        let angle = (layer.rotation + value.degrees).truncatingRemainder(dividingBy: 360)
                        layer.rotation = angle > 180 ? angle - 360 : angle < -180 ? angle + 360 : angle
                    })
                .accessibilityLabel("装饰图片，可在下方滑块调整")
        }
    }
}
