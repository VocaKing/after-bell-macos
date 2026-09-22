import AppKit
import SceneKit
import SwiftUI

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

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
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
        context.coordinator.build(in: view, compact: compact)
        context.coordinator.apply(
            color: color, code: code, name: name, count: count,
            hovered: hovered, selected: selected, pressed: pressed,
            compact: compact, view: view
        )
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.apply(
            color: color, code: code, name: name, count: count,
            hovered: hovered, selected: selected, pressed: pressed,
            compact: compact, view: view
        )
    }

    final class Coordinator {
        var jelly: SCNNode?
        var core: SCNNode?
        var lastKey = ""
        var lastPose = ""
        var freezeWork: DispatchWorkItem?

        func build(in view: SCNView, compact: Bool) {
            let scene = SCNScene()
            view.scene = scene
            scene.lightingEnvironment.contents = Self.studioIBL()
            scene.lightingEnvironment.intensity = 0.28

            let camera = SCNCamera()
            camera.fieldOfView = compact ? 32 : 34
            camera.zNear = 0.05
            camera.zFar = 40
            camera.wantsHDR = false
            let camNode = SCNNode()
            camNode.camera = camera
            camNode.position = compact
                ? SCNVector3(-0.12, 0.42, 2.30)
                : SCNVector3(-0.14, 0.52, 2.72)
            camNode.look(at: SCNVector3(0, 0.02, 0))
            scene.rootNode.addChildNode(camNode)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 90
            ambient.light?.color = NSColor(calibratedWhite: 0.42, alpha: 1)
            scene.rootNode.addChildNode(ambient)

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 140
            key.light?.color = NSColor(calibratedRed: 1.00, green: 0.98, blue: 0.95, alpha: 1)
            key.position = SCNVector3(1.0, 2.8, 2.0)
            key.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(key)

            let fill = SCNNode()
            fill.light = SCNLight()
            fill.light?.type = .omni
            fill.light?.intensity = 36
            fill.light?.color = NSColor(calibratedRed: 0.92, green: 0.96, blue: 1.0, alpha: 1)
            fill.position = SCNVector3(-1.2, 0.4, 1.6)
            scene.rootNode.addChildNode(fill)

            let root = SCNNode()
            scene.rootNode.addChildNode(root)
            jelly = root

            let body = SCNNode(geometry: Self.jellyGeometry(compact: compact, radiusBoost: 0))
            body.name = "body"
            root.addChildNode(body)

            let inner = SCNNode(geometry: Self.jellyGeometry(compact: compact, radiusBoost: 0.02))
            inner.scale = SCNVector3(0.62, 0.58, 0.62)
            inner.name = "core"
            root.addChildNode(inner)
            core = inner

            let shadow = SCNPlane(width: compact ? 1.55 : 2.05, height: compact ? 1.18 : 1.55)
            let sm = SCNMaterial()
            sm.diffuse.contents = NSColor.black
            sm.transparency = 0.22
            sm.lightingModel = .constant
            sm.writesToDepthBuffer = false
            shadow.materials = [sm]
            let shadowNode = SCNNode(geometry: shadow)
            shadowNode.eulerAngles.x = -.pi / 2
            shadowNode.position = SCNVector3(0.10, compact ? -0.48 : -0.60, 0.06)
            scene.rootNode.addChildNode(shadowNode)
        }

        func apply(
            color: NSColor,
            code: String,
            name: String,
            count: String,
            hovered: Bool,
            selected: Bool,
            pressed: Bool,
            compact: Bool,
            view: SCNView
        ) {
            guard let jelly else { return }
            let rgb = color.usingColorSpace(.deviceRGB) ?? color
            let key = "\(code)|\(name)|\(count)|\(compact)|\(rgb.redComponent)|\(rgb.greenComponent)|\(rgb.blueComponent)"
            if key != lastKey {
                lastKey = key
                if let body = jelly.childNode(withName: "body", recursively: false) {
                    body.geometry?.materials = Self.bodyMaterials(
                        color: rgb, code: code, name: name, count: count, compact: compact
                    )
                }
                core?.geometry?.materials = [Self.gelatin(Self.darker(rgb), inner: true)]
            }

            let pose = "\(pressed)-\(hovered)-\(selected)"
            guard pose != lastPose else { return }
            lastPose = pose

            let scale: SCNVector3
            let y: CGFloat
            if pressed {
                scale = SCNVector3(1.34, 0.52, 1.34)
                y = compact ? -0.10 : -0.14
            } else if hovered {
                scale = SCNVector3(1.05, 1.07, 1.05)
                y = compact ? 0.05 : 0.07
            } else if selected {
                scale = SCNVector3(1.03, 0.97, 1.03)
                y = 0.02
            } else {
                scale = SCNVector3(1, 1, 1)
                y = 0
            }

            view.isPlaying = true
            view.rendersContinuously = true
            freezeWork?.cancel()

            SCNTransaction.begin()
            SCNTransaction.animationDuration = pressed ? 0.10 : 0.48
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(
                controlPoints: pressed ? 0.15 : 0.22,
                pressed ? 0.90 : 1.70,
                0.28,
                1.00
            )
            jelly.scale = scale
            jelly.position.y = y
            jelly.eulerAngles = SCNVector3(pressed ? 0.04 : (hovered ? -0.03 : 0), hovered && !pressed ? -0.04 : 0, 0)
            SCNTransaction.commit()

            jelly.removeAction(forKey: "wobble")
            if hovered && !pressed {
                let wobble = SCNAction.repeatForever(
                    SCNAction.sequence([
                        SCNAction.customAction(duration: 0.55) { node, t in
                            let u = sin(Double(t) / 0.55 * .pi)
                            node.scale = SCNVector3(1.05 + 0.03 * u, 1.07 - 0.035 * u, 1.05 + 0.03 * u)
                        },
                        SCNAction.customAction(duration: 0.55) { node, t in
                            let u = sin(Double(t) / 0.55 * .pi)
                            node.scale = SCNVector3(1.08 - 0.03 * u, 1.035 + 0.035 * u, 1.08 - 0.03 * u)
                        },
                    ])
                )
                jelly.runAction(wobble, forKey: "wobble")
            }

            if !pressed && !hovered {
                let work = DispatchWorkItem { [weak view] in
                    view?.isPlaying = false
                    view?.rendersContinuously = false
                }
                freezeWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
            }
        }

        static func gelatin(_ color: NSColor, inner: Bool) -> SCNMaterial {
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.ambient.contents = color
            mat.locksAmbientWithDiffuse = true
            mat.roughness.contents = inner ? 0.35 : 0.16
            mat.metalness.contents = 0.0
            mat.specular.contents = NSColor(calibratedWhite: inner ? 0.18 : 0.55, alpha: 1)
            mat.shininess = inner ? 0.2 : 0.85
            mat.lightingModel = .physicallyBased
            mat.clearCoat.contents = inner ? 0.05 : 0.55
            mat.clearCoatRoughness.contents = 0.12
            mat.fresnelExponent = 1.4
            mat.transparency = inner ? 0.92 : 0.62
            mat.transparencyMode = .singleLayer
            mat.blendMode = .alpha
            mat.isDoubleSided = true
            mat.writesToDepthBuffer = true
            mat.emission.contents = color.withAlphaComponent(inner ? 0.10 : 0.16)
            mat.shaderModifiers = [
                .surface: """
                float ndotv = max(dot(_surface.normal, _surface.view), 0.0);
                float rim = pow(clamp(1.0 - ndotv, 0.0, 1.0), 2.4);
                vec3 n = _surface.normal;
                float phase = n.x * 2.4 + n.y * 3.1 + n.z * 1.2;
                vec3 oil = vec3(
                    0.55 + 0.45 * sin(phase),
                    0.55 + 0.45 * sin(phase + 2.094),
                    0.55 + 0.45 * sin(phase + 4.188)
                );
                _surface.emission += vec4(oil * rim * 0.16, 0.0);
                _surface.reflective = vec4(mix(vec3(0.55), oil, 0.45) * rim * 0.55, 1.0);
                _surface.transparent.a = mix(_surface.transparent.a, 0.28, rim * 0.55);
                """
            ]
            return mat
        }

        static func bodyMaterials(
            color: NSColor,
            code: String,
            name: String,
            count: String,
            compact: Bool
        ) -> [SCNMaterial] {
            let shell = gelatin(color, inner: false)
            let front = gelatin(color, inner: false)
            front.transparency = 1
            front.blendMode = .alpha
            front.shaderModifiers = nil
            let face = raster(paintFace(color: color, code: code, name: name, count: count, compact: compact))
            front.diffuse.contents = face
            front.transparent.contents = nil
            front.diffuse.wrapS = .clamp
            front.diffuse.wrapT = .clamp
            front.diffuse.magnificationFilter = .linear
            front.diffuse.minificationFilter = .linear
            front.diffuse.mipFilter = .linear
            front.diffuse.maxAnisotropy = 16
            return [front, shell, shell, shell, shell, shell]
        }

        static func darker(_ color: NSColor) -> NSColor {
            let c = color.usingColorSpace(.deviceRGB) ?? color
            return NSColor(
                calibratedRed: max(0, c.redComponent * 0.72),
                green: max(0, c.greenComponent * 0.72),
                blue: max(0, c.blueComponent * 0.72),
                alpha: 1
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

        static func jellyGeometry(compact: Bool, radiusBoost: CGFloat) -> SCNGeometry {
            let hw: CGFloat = compact ? 0.58 : 0.74
            let hh: CGFloat = compact ? 0.40 : 0.50
            let hd: CGFloat = compact ? 0.36 : 0.46
            let radius: CGFloat = (compact ? 0.28 : 0.36) + radiusBoost
            return makeJelly(hw: hw, hh: hh, hd: hd, radius: radius, segs: compact ? 10 : 14)
        }

        static func project(
            _ p: SCNVector3,
            hw: CGFloat, hh: CGFloat, hd: CGFloat,
            radius: CGFloat
        ) -> (SCNVector3, SCNVector3) {
            let flare = 1 + 0.10 * max(0, (-p.y / max(hh, 0.001) + 1) * 0.5)
            let r = min(radius, hw * flare * 0.78, hh * 0.78, hd * 0.78)
            let ix = max(hw * flare - r, 0.02)
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

        static func makeJelly(
            hw: CGFloat, hh: CGFloat, hd: CGFloat,
            radius: CGFloat, segs: Int
        ) -> SCNGeometry {
            var positions: [SCNVector3] = []
            var normals: [SCNVector3] = []
            var uvs: [CGPoint] = []
            var elements: [SCNGeometryElement] = []

            func emitFace(samples: [(SCNVector3, CGPoint)]) {
                let start = UInt32(positions.count)
                for sample in samples {
                    let (pos, nor) = project(sample.0, hw: hw, hh: hh, hd: hd, radius: radius)
                    positions.append(pos)
                    normals.append(nor)
                    uvs.append(sample.1)
                }
                var idx: [UInt32] = []
                let row = UInt32(segs + 1)
                for j in 0..<UInt32(segs) {
                    for i in 0..<UInt32(segs) {
                        let a = start + j * row + i
                        let b = a + 1
                        let c = a + row
                        let d = c + 1
                        idx.append(contentsOf: [a, b, c, b, d, c])
                    }
                }
                elements.append(SCNGeometryElement(indices: idx, primitiveType: .triangles))
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
                elements: elements
            )
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
                color.setFill()
                rect.fill()
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let ink = NSColor(calibratedWhite: 0.07, alpha: 0.92)
                let mute = NSColor(calibratedWhite: 0.10, alpha: 0.70)
                let monogram = displayFont(size: compact ? 720 : 560)
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
                        in: NSRect(x: 80, y: 280, width: 1888, height: 900),
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
                    NSColor(calibratedRed: 0.70, green: 0.78, blue: 0.86, alpha: 1),
                    NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.16, alpha: 1),
                ])?.draw(in: rect, angle: -90)
                return true
            }
        }
    }
}
