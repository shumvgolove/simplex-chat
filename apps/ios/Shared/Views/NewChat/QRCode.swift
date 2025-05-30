//
//  QRCode.swift
//  SimpleX
//
//  Created by Evgeny Poberezkin on 30/01/2022.
//  Copyright © 2022 SimpleX Chat. All rights reserved.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import SimpleXChat

struct MutableQRCode: View {
    @Binding var uri: String
    var small: Bool = false
    var withLogo: Bool = true
    var tintColor = UIColor(red: 0.023, green: 0.176, blue: 0.337, alpha: 1)

    var body: some View {
        QRCode(uri: uri, small: small, withLogo: withLogo, tintColor: tintColor)
            .id("simplex-qrcode-view-for-\(uri)")
    }
}

struct SimpleXCreatedLinkQRCode: View {
    let link: CreatedConnLink
    @Binding var short: Bool
    var onShare: (() -> Void)? = nil

    var body: some View {
        QRCode(uri: link.simplexChatUri(short: short), small: short && link.connShortLink != nil, onShare: onShare)
    }
}

struct SimpleXLinkQRCode: View {
    let uri: String
    var withLogo: Bool = true
    var tintColor = UIColor(red: 0.023, green: 0.176, blue: 0.337, alpha: 1)
    var onShare: (() -> Void)? = nil

    var body: some View {
        QRCode(uri: simplexChatLink(uri), small: uri.count < 200, withLogo: withLogo, tintColor: tintColor, onShare: onShare)
    }
}

private let smallQRRatio: CGFloat = 0.63

struct QRCode: View {
    let uri: String
    var small: Bool = false
    var withLogo: Bool = true
    var tintColor = UIColor(red: 0.023, green: 0.176, blue: 0.337, alpha: 1)
    var onShare: (() -> Void)? = nil
    @State private var image: UIImage? = nil
    @State private var makeScreenshotFunc: () -> Void = {}
    @State private var width: CGFloat = .infinity

    var body: some View {
        ZStack {
            if let image = image {
                qrCodeImage(image).frame(width: width, height: width)
                GeometryReader { g in
                    let w = g.size.width * (small ? smallQRRatio : 1)
                    let l = w * (small ? 0.195 : 0.16)
                    let m = w * 0.005
                    ZStack {
                        if withLogo {
                            Image("icon-light")
                            .resizable()
                            .scaledToFit()
                            .frame(width: l, height: l)
                            .frame(width: l + m, height: l + m)
                            .background(.white)
                            .clipShape(Circle())
                        }
                    }
                    .onAppear {
                        width = w
                        makeScreenshotFunc = {
                            let size = CGSizeMake(1024 / UIScreen.main.scale, 1024 / UIScreen.main.scale)
                            showShareSheet(items: [makeScreenshot(g.frame(in: .local).origin, size)])
                            onShare?()
                        }
                    }
                    .frame(width: g.size.width, height: g.size.height)
                }
            } else {
                Color.clear.aspectRatio(small ? 1 / smallQRRatio : 1, contentMode: .fit)
            }
        }
        .onTapGesture(perform: makeScreenshotFunc)
        .task { image = await generateImage(uri, tintColor: tintColor, errorLevel: small ? "M" : "L") }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private func qrCodeImage(_ image: UIImage) -> some View {
    Image(uiImage: image)
        .resizable()
        .interpolation(.none)
        .aspectRatio(1, contentMode: .fit)
        .textSelection(.enabled)
}

private func generateImage(_ uri: String, tintColor: UIColor, errorLevel: String) async -> UIImage? {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(uri.utf8)
    filter.correctionLevel = errorLevel
    if let outputImage = filter.outputImage,
       let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
        return UIImage(cgImage: cgImage).replaceColor(UIColor.black, tintColor)
    }
    return nil
}

extension View {
    func makeScreenshot(_ origin: CGPoint? = nil, _ targetSize: CGSize? = nil) -> UIImage {
        let controller = UIHostingController(rootView: self.edgesIgnoringSafeArea(.all))
        let targetSize = targetSize ?? controller.view.intrinsicContentSize
        let view = controller.view
        view?.bounds = CGRect(origin: origin ?? .zero, size: targetSize)
        view?.backgroundColor = .clear
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

struct QRCode_Previews: PreviewProvider {
    static var previews: some View {
        QRCode(uri: "https://simplex.chat/invitation#/?v=1&smp=smp%3A%2F%2Fu2dS9sG8nMNURyZwqASV4yROM28Er0luVTx5X1CsMrU%3D%40smp4.simplex.im%2FFe5ICmvrm4wkrr6X1LTMii-lhBqLeB76%23MCowBQYDK2VuAyEAdhZZsHpuaAk3Hh1q0uNb_6hGTpuwBIrsp2z9U2T0oC0%3D&e2e=v%3D1%26x3dh%3DMEIwBQYDK2VvAzkAcz6jJk71InuxA0bOX7OUhddfB8Ov7xwQIlIDeXBRZaOntUU4brU5Y3rBzroZBdQJi0FKdtt_D7I%3D%2CMEIwBQYDK2VvAzkA-hDvk1duBi1hlOr08VWSI-Ou4JNNSQjseY69QyKm7Kgg1zZjbpGfyBqSZ2eqys6xtoV4ZtoQUXQ%3D")
    }
}
