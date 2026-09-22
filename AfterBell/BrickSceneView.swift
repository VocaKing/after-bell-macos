import AppKit
import SceneKit
import SwiftUI

final class JellySCNView: SCNView {
    weak var coordinator: BrickSceneView.Coordinator?

    override func mouseDown(with event: NSEvent) {
        coordinator?.handlePress(hitsJelly(event))
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        coordinator?.handlePress(hitsJelly(event))
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        coordinator?.handlePress(false)
        super.mouseUp(with: event)
    }

    private func hitsJelly(_ event: NSEvent) -> Bool {
        let point = convert(event.locationInWindow, from: nil)
        let hits = hitTest(point, options: [
            .searchMode: SCNHitTestSearchMode.closest.rawValue,
            .boundingBoxOnly: false,
        ])
        return hits.contains { node in
            var n: SCNNode? = node.node
            while let cur = n {
                if cur.name == "body" || cur.name == "core" || cur.name == "jelly" { return true }
                n = cur.parent
            }
            return false
        }
    }
}

struct BrickSceneView: NSViewRepresentable {
    var color: NSColor
    var code: String
    var name: String
    var count: String
    var hovered: Bool
    var selected: Bool
    var pressed: Bool = false
    var compact: Bool = false

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> JellySCNView {
        let view = JellySCNView()
        view.coordinator = context.coordinator
        view.scene = SCNScene()
        view.backgroundColor = .clear
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = compact ? .multisampling2X : .multisampling4X
        view.allowsCameraControl = false
        view.isPlaying = false
        view.rendersContinuously = false
        view.preferredFramesPerSecond = 30
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: context.coordinator,
            userInfo: nil
        )
        view.addTrackingArea(area)
        context.coordinator.view = view
        context.coordinator.build(in: view, compact: compact)
        context.coordinator.apply(
            color: color, code: code, name: name, count: count,
            hovered: hovered, selected: selected, compact: compact
        )
        return view
    }

    func updateNSView(_ view: JellySCNView, context: Context) {
        view.coordinator = context.coordinator
        context.coordinator.apply(
            color: color, code: code, name: name, count: count,
            hovered: hovered, selected: selected, compact: compact
        )
    }

    final class Coordinator: NSObject {
        var jelly: SCNNode?
        var core: SCNNode?
        var legend: SCNNode?
        var lastKey = ""
        var lastPose = ""
        var freezeWork: DispatchWorkItem?
        var hoverWork: DispatchWorkItem?
        var trackingHover = false
        var swiftHover = false
        var meshPressed = false
        var selected = false
        var compact = false
        weak var view: SCNView?

        func handlePress(_ down: Bool) {
            if meshPressed == down { return }
            meshPressed = down
            applyPose()
        }

        @objc func mouseEntered(with event: NSEvent) {
            hoverWork?.cancel()
            trackingHover = true
            applyPose()
        }

        @objc func mouseExited(with event: NSEvent) {
            hoverWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.trackingHover = false
                self?.meshPressed = false
                self?.applyPose()
            }
            hoverWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        }

        func build(in view: SCNView, compact: Bool) {
            let scene = SCNScene()
            view.scene = scene
            scene.lightingEnvironment.contents = Self.studioIBL()
            scene.lightingEnvironment.intensity = 0.34

            let camera = SCNCamera()
            camera.fieldOfView = compact ? 30 : 32
            camera.zNear = 0.05
            camera.zFar = 40
            camera.wantsHDR = false
            let camNode = SCNNode()
            camNode.camera = camera
            camNode.position = compact
                ? SCNVector3(-0.22, 0.28, 2.15)
                : SCNVector3(-0.32, 0.36, 2.45)
            camNode.look(at: SCNVector3(0, 0.02, 0))
            scene.rootNode.addChildNode(camNode)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 70
            ambient.light?.color = NSColor(calibratedWhite: 0.40, alpha: 1)
            scene.rootNode.addChildNode(ambient)

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 120
            key.light?.color = NSColor(calibratedRed: 1.00, green: 0.98, blue: 0.95, alpha: 1)
            key.position = SCNVector3(1.2, 2.4, 2.2)
            key.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(key)

            let rim = SCNNode()
            rim.light = SCNLight()
            rim.light?.type = .omni
            rim.light?.intensity = 40
            rim.light?.color = NSColor(calibratedRed: 0.85, green: 0.94, blue: 1.0, alpha: 1)
            rim.position = SCNVector3(-1.4, 0.6, 1.4)
            scene.rootNode.addChildNode(rim)

            let root = SCNNode()
            root.name = "jelly"
            scene.rootNode.addChildNode(root)
            jelly = root

            let body = SCNNode(geometry: Self.cubeGeometry(compact: compact))
            body.name = "body"
            body.renderingOrder = 20
            root.addChildNode(body)

            let inner = SCNNode(geometry: Self.cubeGeometry(compact: compact))
            inner.scale = SCNVector3(0.34, 0.34, 0.34)
            inner.name = "core"
            inner.renderingOrder = 10
            root.addChildNode(inner)
            core = inner

            let plate = SCNPlane(width: compact ? 0.72 : 0.88, height: compact ? 0.72 : 0.88)
            let legendNode = SCNNode(geometry: plate)
            legendNode.position = SCNVector3(0, 0.02, compact ? 0.50 : 0.60)
            legendNode.name = "legend"
            legendNode.renderingOrder = 30
            root.addChildNode(legendNode)
            legend = legendNode

            let shadow = SCNPlane(width: compact ? 1.35 : 1.70, height: compact ? 1.20 : 1.50)
            let sm = SCNMaterial()
            sm.diffuse.contents = NSColor.black
            sm.transparency = 0.28
            sm.lightingModel = .constant
            sm.writesToDepthBuffer = false
            shadow.materials = [sm]
            let shadowNode = SCNNode(geometry: shadow)
            shadowNode.eulerAngles.x = -.pi / 2
            shadowNode.position = SCNVector3(0.08, compact ? -0.58 : -0.70, 0.04)
            scene.rootNode.addChildNode(shadowNode)
        }

        func apply(
            color: NSColor,
            code: String,
            name: String,
            count: String,
            hovered: Bool,
            selected: Bool,
            compact: Bool
        ) {
            guard let jelly else { return }
            let rgb = color.usingColorSpace(.deviceRGB) ?? color
            swiftHover = hovered
            self.selected = selected
            self.compact = compact

            let key = "\(code)|\(name)|\(count)|\(compact)|\(rgb.redComponent)|\(rgb.greenComponent)|\(rgb.blueComponent)"
            if key != lastKey {
                lastKey = key
                if let body = jelly.childNode(withName: "body", recursively: false) {
                    body.geometry?.firstMaterial = Self.gelatin(rgb, inner: false)
                }
                core?.geometry?.firstMaterial = Self.gelatin(Self.richer(rgb), inner: true)
                legend?.geometry?.firstMaterial = Self.letterPlate(
                    color: rgb, code: code, name: name, count: count, compact: compact
                )
            }
            applyPose()
        }

        func applyPose() {
            guard let jelly else { return }
            let hovering = trackingHover || swiftHover
            let pose = "\(meshPressed)-\(hovering)-\(selected)"
            if pose == lastPose { return }
            lastPose = pose

            // Poke from the screen: squash depth, bulge the face. Never crush from above.
            let scale: SCNVector3
            if meshPressed {
                scale = SCNVector3(1.16, 1.16, 0.58)
            } else if hovering {
                scale = SCNVector3(1.03, 1.03, 1.03)
            } else if selected {
                scale = SCNVector3(1.02, 1.02, 1.02)
            } else {
                scale = SCNVector3(1, 1, 1)
            }

            view?.isPlaying = true
            view?.rendersContinuously = true
            freezeWork?.cancel()
            jelly.removeAction(forKey: "wobble")

            let spring = CASpringAnimation(keyPath: "scale")
            spring.fromValue = NSValue(scnVector3: jelly.scale)
            spring.toValue = NSValue(scnVector3: scale)
            spring.mass = 0.55
            spring.stiffness = meshPressed ? 160 : 95
            spring.damping = meshPressed ? 12 : 8.5
            spring.duration = spring.settlingDuration
            jelly.addAnimation(spring, forKey: "spring")
            jelly.scale = scale
            jelly.position = SCNVector3Zero
            jelly.eulerAngles = SCNVector3Zero

            if hovering && !meshPressed {
                let wobble = SCNAction.repeatForever(
                    SCNAction.customAction(duration: 2.2) { node, t in
                        let s = sin(Double(t) / 2.2 * .pi * 2)
                        node.scale = SCNVector3(1.03 + 0.015 * s, 1.03 + 0.012 * s, 1.03 - 0.012 * s)
                    }
                )
                jelly.runAction(wobble, forKey: "wobble")
            }

            if !meshPressed && !hovering {
                let work = DispatchWorkItem { [weak self] in
                    self?.view?.isPlaying = false
                    self?.view?.rendersContinuously = false
                }
                freezeWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
            }
        }

        static func gelatin(_ color: NSColor, inner: Bool) -> SCNMaterial {
            let mat = SCNMaterial()
            mat.diffuse.contents = color.withAlphaComponent(inner ? 0.95 : 0.55)
            mat.ambient.contents = color
            mat.locksAmbientWithDiffuse = true
            mat.roughness.contents = inner ? 0.28 : 0.12
            mat.metalness.contents = 0.0
            mat.specular.contents = NSColor(calibratedWhite: 0.65, alpha: 1)
            mat.shininess = 0.9
            mat.lightingModel = .physicallyBased
            mat.clearCoat.contents = inner ? 0.08 : 0.42
            mat.clearCoatRoughness.contents = 0.10
            mat.fresnelExponent = 0.9
            // SceneKit: 0 = opaque, 1 = invisible
            mat.transparency = inner ? 0.28 : 0.62
            mat.transparencyMode = .dualLayer
            mat.blendMode = .alpha
            mat.isDoubleSided = true
            mat.writesToDepthBuffer = false
            mat.readsFromDepthBuffer = true
            mat.emission.contents = color.withAlphaComponent(inner ? 0.18 : 0.06)
            mat.shaderModifiers = [
                .surface: """
                float ndotv = max(dot(_surface.normal, _surface.view), 0.0);
                float rim = pow(clamp(1.0 - ndotv, 0.0, 1.0), 1.8);
                float core = pow(ndotv, 2.0);
                _surface.transparent.a = mix(0.72, 0.22, core);
                _surface.emission += vec4(_surface.diffuse.rgb * rim * 0.12, 0.0);
                _surface.reflective = vec4(vec3(0.55 + 0.35 * rim), 1.0);
                """
            ]
            return mat
        }

        static func letterPlate(
            color: NSColor,
            code: String,
            name: String,
            count: String,
            compact: Bool
        ) -> SCNMaterial {
            let mat = SCNMaterial()
            let image = raster(paintFace(color: color, code: code, name: name, count: count, compact: compact))
            mat.diffuse.contents = image
            mat.transparent.contents = image
            mat.transparencyMode = .aOne
            mat.lightingModel = .constant
            mat.blendMode = .alpha
            mat.writesToDepthBuffer = false
            mat.isDoubleSided = false
            return mat
        }

        static func complementaryInk(_ color: NSColor) -> NSColor {
            let c = color.usingColorSpace(.deviceRGB) ?? color
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let hue = (h + 0.5).truncatingRemainder(dividingBy: 1)
            let sat = min(1, max(0.55, s * 0.9 + 0.25))
            let bri: CGFloat = b > 0.62 ? 0.22 : 0.96
            return NSColor(calibratedHue: hue, saturation: sat, brightness: bri, alpha: 1)
        }

        static func richer(_ color: NSColor) -> NSColor {
            let c = color.usingColorSpace(.deviceRGB) ?? color
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            return NSColor(calibratedHue: h, saturation: min(1, s * 1.15 + 0.08), brightness: max(0.18, b * 0.72), alpha: 1)
        }

        static func cubeGeometry(compact: Bool) -> SCNGeometry {
            let s: CGFloat = compact ? 0.48 : 0.58
            return makeRoundedCube(hw: s, hh: s, hd: s, radius: compact ? 0.24 : 0.30, segs: compact ? 12 : 16)
        }

        static func project(
            _ p: SCNVector3,
            hw: CGFloat, hh: CGFloat, hd: CGFloat,
            radius: CGFloat
        ) -> (SCNVector3, SCNVector3) {
            let r = min(radius, hw * 0.82, hh * 0.82, hd * 0.82)
            let ix = max(hw - r, 0.02)
            let iy = max(hh - r, 0.02)
            let iz = max(hd - r, 0.02)
            let cx = min(max(p.x, -ix), ix)
            let cy = min(max(p.y, -iy), iy)
            let cz = min(max(p.z, -iz), iz)
            let dx = p.x - cx, dy = p.y - cy, dz = p.z - cz
            let len = sqrt(dx * dx + dy * dy + dz * dz)
            if len < 1e-5 {
                let ax = abs(p.x), ay = abs(p.y), az = abs(p.z)
                var n = SCNVector3Zero
                if ax >= ay && ax >= az { n.x = p.x >= 0 ? 1 : -1 }
                else if ay >= az { n.y = p.y >= 0 ? 1 : -1 }
                else { n.z = p.z >= 0 ? 1 : -1 }
                return (p, n)
            }
            let n = SCNVector3(dx / len, dy / len, dz / len)
            return (SCNVector3(cx + n.x * r, cy + n.y * r, cz + n.z * r), n)
        }

        static func makeRoundedCube(
            hw: CGFloat, hh: CGFloat, hd: CGFloat,
            radius: CGFloat, segs: Int
        ) -> SCNGeometry {
            var positions: [SCNVector3] = []
            var normals: [SCNVector3] = []
            var uvs: [CGPoint] = []
            var indices: [UInt32] = []

            func emitFace(samples: [(SCNVector3, CGPoint)]) {
                let start = UInt32(positions.count)
                for sample in samples {
                    let (pos, nor) = project(sample.0, hw: hw, hh: hh, hd: hd, radius: radius)
                    positions.append(pos)
                    normals.append(nor)
                    uvs.append(sample.1)
                }
                let row = UInt32(segs + 1)
                for j in 0..<UInt32(segs) {
                    for i in 0..<UInt32(segs) {
                        let a = start + j * row + i
                        let b = a + 1
                        let c = a + row
                        let d = c + 1
                        indices.append(contentsOf: [a, b, c, b, d, c])
                    }
                }
            }

            func grid(_ point: (CGFloat, CGFloat) -> SCNVector3) -> [(SCNVector3, CGPoint)] {
                var out: [(SCNVector3, CGPoint)] = []
                for j in 0...segs {
                    let v = CGFloat(j) / CGFloat(segs)
                    for i in 0...segs {
                        let u = CGFloat(i) / CGFloat(segs)
                        out.append((point(u * 2 - 1, v * 2 - 1), CGPoint(x: u, y: 1 - v)))
                    }
                }
                return out
            }

            emitFace(samples: grid { u, v in SCNVector3(u * hw, v * hh, hd) })
            emitFace(samples: grid { u, v in SCNVector3(hw, v * hh, -u * hd) })
            emitFace(samples: grid { u, v in SCNVector3(-u * hw, v * hh, -hd) })
            emitFace(samples: grid { u, v in SCNVector3(-hw, v * hh, u * hd) })
            emitFace(samples: grid { u, v in SCNVector3(u * hw, hh, -v * hd) })
            emitFace(samples: grid { u, v in SCNVector3(u * hw, -hh, v * hd) })

            return SCNGeometry(
                sources: [
                    SCNGeometrySource(vertices: positions),
                    SCNGeometrySource(normals: normals),
                    SCNGeometrySource(textureCoordinates: uvs),
                ],
                elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
            )
        }

        static func raster(_ image: NSImage) -> CGImage {
            let width = max(Int(image.size.width), 1)
            let height = max(Int(image.size.height), 1)
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )!
            let ctx = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = ctx
            ctx.imageInterpolation = .high
            image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
            NSGraphicsContext.restoreGraphicsState()
            return rep.cgImage!
        }

        static func paintFace(
            color: NSColor,
            code: String,
            name: String,
            count: String,
            compact: Bool
        ) -> NSImage {
            let size = NSSize(width: 2048, height: 2048)
            return NSImage(size: size, flipped: true) { rect in
                NSGraphicsContext.current?.shouldAntialias = true
                NSGraphicsContext.current?.imageInterpolation = .high
                NSColor.clear.setFill()
                rect.fill()
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let ink = complementaryInk(color)
                let mute = ink.withAlphaComponent(0.82)
                let monogram = displayFont(size: compact ? 640 : 520)
                if compact {
                    (code as NSString).draw(
                        in: NSRect(x: 80, y: 420, width: 1888, height: 1200),
                        withAttributes: [
                            .font: monogram,
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
                            .kern: 8,
                        ]
                    )
                } else {
                    (code as NSString).draw(
                        in: NSRect(x: 80, y: 360, width: 1888, height: 820),
                        withAttributes: [
                            .font: monogram,
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
                            .kern: 6,
                        ]
                    )
                    (name as NSString).draw(
                        in: NSRect(x: 80, y: 1220, width: 1888, height: 240),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 140, weight: .semibold),
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
                        ]
                    )
                    (count as NSString).draw(
                        in: NSRect(x: 80, y: 1500, width: 1888, height: 200),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 110, weight: .medium),
                            .foregroundColor: mute,
                            .paragraphStyle: paragraph,
                        ]
                    )
                }
                return true
            }
        }

        static func displayFont(size: CGFloat) -> NSFont {
            NSFont(name: "MarkerFelt-Wide", size: size)
                ?? NSFont(name: "Noteworthy-Bold", size: size)
                ?? NSFont(name: "ChalkboardSE-Bold", size: size)
                ?? NSFont.systemFont(ofSize: size, weight: .bold)
        }

        static func studioIBL() -> NSImage {
            let size = NSSize(width: 64, height: 32)
            return NSImage(size: size, flipped: false) { rect in
                NSGradient(colors: [
                    NSColor(calibratedRed: 0.78, green: 0.84, blue: 0.90, alpha: 1),
                    NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.14, alpha: 1),
                ])?.draw(in: rect, angle: -90)
                return true
            }
        }
    }
}
