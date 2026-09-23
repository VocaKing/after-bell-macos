import AppKit
import SceneKit
import SwiftUI

final class JellySCNView: SCNView {
    weak var coordinator: BrickSceneView.Coordinator?

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let hits = hitTest(point, options: [
            SCNHitTestOption.searchMode: SCNHitTestSearchMode.closest.rawValue,
            SCNHitTestOption.boundingBoxOnly: false,
        ])
        if let hit = hits.first(where: { Self.isJelly($0.node) }) {
            let local = hit.node.convertPosition(hit.localCoordinates, to: hit.node.parent)
            coordinator?.beginRipple(at: hit.node.name == "body" ? hit.localCoordinates : local)
        }
        super.mouseDown(with: event)
    }

    private static func isJelly(_ node: SCNNode) -> Bool {
        var n: SCNNode? = node
        while let cur = n {
            if cur.name == "body" || cur.name == "core" || cur.name == "jelly" { return true }
            n = cur.parent
        }
        return false
    }
}

struct BrickSceneView: NSViewRepresentable {
    var color: NSColor
    var code: String
    var name: String
    var count: String
    var hovered: Bool
    var selected: Bool
    var compact: Bool = false

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> JellySCNView {
        let view = JellySCNView()
        view.coordinator = context.coordinator
        view.scene = SCNScene()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = compact ? .multisampling2X : .multisampling4X
        view.allowsCameraControl = false
        view.isPlaying = false
        view.rendersContinuously = false
        view.preferredFramesPerSecond = 60
        view.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: context.coordinator,
            userInfo: nil
        ))
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
        view.delegate = context.coordinator
        context.coordinator.apply(
            color: color, code: code, name: name, count: count,
            hovered: hovered, selected: selected, compact: compact
        )
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        var jelly: SCNNode?
        var body: SCNNode?
        var core: SCNNode?
        var materials: [SCNMaterial] = []
        var lastKey = ""
        weak var view: SCNView?

        var trackingHover = false
        var swiftHover = false
        var hoverWork: DispatchWorkItem?

        var pull: Float = 0
        var pullVel: Float = 0
        var jiggle: Float = 0
        var hoverTime: Float = 0
        var wasHovering = false

        var clickAmp: Float = 0
        var clickTime: Float = 0
        var clickPoint = SCNVector3(0, 0.2, 0.55)
        var lastTime: TimeInterval = 0
        var half: Float = 0.62

        func beginRipple(at local: SCNVector3) {
            clickPoint = local
            clickAmp = 1
            clickTime = 0
            wake()
        }

        @objc func mouseEntered(with event: NSEvent) {
            hoverWork?.cancel()
            trackingHover = true
            wake()
        }

        @objc func mouseExited(with event: NSEvent) {
            hoverWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.trackingHover = false
                self?.wake()
            }
            hoverWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
        }

        func wake() {
            view?.isPlaying = true
            view?.rendersContinuously = true
        }

        func build(in view: SCNView, compact: Bool) {
            let scene = SCNScene()
            view.scene = scene
            scene.background.contents = NSColor.clear

            let camera = SCNCamera()
            camera.fieldOfView = compact ? 30 : 34
            camera.zNear = 0.04
            camera.zFar = 40
            camera.wantsHDR = false
            let camNode = SCNNode()
            camNode.camera = camera
            camNode.position = compact
                ? SCNVector3(-0.28, 0.48, 2.70)
                : SCNVector3(-0.38, 0.58, 3.15)
            camNode.look(at: SCNVector3(0, 0.08, 0))
            scene.rootNode.addChildNode(camNode)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 80
            ambient.light?.color = NSColor(calibratedWhite: 0.45, alpha: 1)
            scene.rootNode.addChildNode(ambient)

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 160
            key.light?.color = NSColor(calibratedRed: 1, green: 0.98, blue: 0.94, alpha: 1)
            key.position = SCNVector3(1.4, 2.6, 2.4)
            key.look(at: SCNVector3(0, 0.1, 0))
            scene.rootNode.addChildNode(key)

            let fill = SCNNode()
            fill.light = SCNLight()
            fill.light?.type = .omni
            fill.light?.intensity = 46
            fill.light?.color = NSColor(calibratedRed: 0.82, green: 0.92, blue: 1, alpha: 1)
            fill.position = SCNVector3(-1.5, 0.4, 1.6)
            scene.rootNode.addChildNode(fill)

            let root = SCNNode()
            root.name = "jelly"
            scene.rootNode.addChildNode(root)
            jelly = root

            half = compact ? 0.50 : 0.62
            let mesh = Self.roundedCube(half: CGFloat(half), radius: CGFloat(half) * 0.46, segs: compact ? 12 : 16)
            let bodyNode = SCNNode(geometry: mesh.geometry)
            bodyNode.name = "body"
            bodyNode.renderingOrder = 20
            root.addChildNode(bodyNode)
            body = bodyNode

            let coreMesh = Self.roundedCube(half: CGFloat(half), radius: CGFloat(half) * 0.46, segs: compact ? 8 : 10)
            let coreNode = SCNNode(geometry: coreMesh.geometry)
            coreNode.scale = SCNVector3(0.42, 0.42, 0.42)
            coreNode.name = "core"
            coreNode.renderingOrder = 10
            root.addChildNode(coreNode)
            core = coreNode

            let shadow = SCNPlane(width: CGFloat(half) * 2.6, height: CGFloat(half) * 2.2)
            let sm = SCNMaterial()
            sm.diffuse.contents = NSColor.black
            sm.transparency = 0.35
            sm.lightingModel = .constant
            sm.writesToDepthBuffer = false
            shadow.materials = [sm]
            let shadowNode = SCNNode(geometry: shadow)
            shadowNode.eulerAngles.x = -.pi / 2
            shadowNode.position = SCNVector3(0.06, -half - 0.08, 0.02)
            scene.rootNode.addChildNode(shadowNode)

            materials = []
            pushUniforms(force: true)
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
            swiftHover = hovered
            if hovered { wake() }
            let rgb = color.usingColorSpace(.deviceRGB) ?? color
            let key = "\(code)|\(name)|\(count)|\(compact)|\(rgb.redComponent)|\(rgb.greenComponent)|\(rgb.blueComponent)"
            guard key != lastKey, let body, let core else { return }
            lastKey = key
            let shell = Self.shellMaterial(rgb)
            let face = Self.faceMaterial(rgb, code: code, name: name, count: count, compact: compact)
            body.geometry?.materials = [face, shell]
            let nugget = Self.shellMaterial(Self.richer(rgb))
            nugget.transparency = 0.22
            core.geometry?.materials = [nugget, nugget]
            materials = [face, shell, nugget]
            pushUniforms(force: true)
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            let dt = lastTime == 0 ? 0.016 : Float(min(0.05, time - lastTime))
            lastTime = time

            let hovering = trackingHover || swiftHover
            if hovering && !wasHovering {
                hoverTime = 0
                jiggle = max(jiggle, 0.35)
            }
            if !hovering && wasHovering {
                jiggle = max(jiggle, 0.85)
            }
            wasHovering = hovering
            hoverTime += dt

            let target: Float = hovering ? 1 : 0
            let accel = (target - pull) * 70 - pullVel * 8.5
            pullVel += accel * dt
            pull += pullVel * dt
            pull = min(1.4, max(-0.2, pull))
            jiggle *= exp(-1.6 * dt)
            clickAmp *= exp(-2.15 * dt)
            clickTime += dt

            pushUniforms(force: false)

            let resting = abs(pull) < 0.012 && abs(pullVel) < 0.012 && jiggle < 0.02 && clickAmp < 0.02 && !hovering
            if resting {
                DispatchQueue.main.async { [weak self] in
                    self?.view?.rendersContinuously = false
                    self?.view?.isPlaying = false
                }
                lastTime = 0
            }
        }

        func pushUniforms(force: Bool) {
            guard force || !materials.isEmpty else { return }
            for mat in materials {
                mat.setValue(NSNumber(value: pull), forKey: "uPull")
                mat.setValue(NSNumber(value: jiggle), forKey: "uJiggle")
                mat.setValue(NSNumber(value: hoverTime), forKey: "uTime")
                mat.setValue(NSNumber(value: clickAmp), forKey: "uClick")
                mat.setValue(NSNumber(value: clickTime), forKey: "uClickTime")
                mat.setValue(NSNumber(value: Float(clickPoint.x)), forKey: "uClickX")
                mat.setValue(NSNumber(value: Float(clickPoint.y)), forKey: "uClickY")
                mat.setValue(NSNumber(value: Float(clickPoint.z)), forKey: "uClickZ")
                mat.setValue(NSNumber(value: half), forKey: "uHalf")
            }
        }

        static let liquidShader = """
        #pragma arguments
        float uPull;
        float uJiggle;
        float uTime;
        float uClick;
        float uClickTime;
        float uClickX;
        float uClickY;
        float uClickZ;
        float uHalf;

        #pragma body
        vec3 p = _geometry.position.xyz;
        vec3 n = _geometry.normal.xyz;
        float h = max(uHalf, 0.2);
        vec3 rope = vec3(0.0, h * 0.92, 0.0);
        float ropeDist = length(p - rope);
        float lagged = max(uTime - ropeDist * 0.42, 0.0);
        float rise = 1.0 - exp(-lagged * 12.0);
        float sway = sin(lagged * 12.5) * exp(-lagged * 1.7);
        float center = exp(-dot(p.xz, p.xz) / (h * h) * 2.4);
        float top = smoothstep(-0.15, 0.9, p.y / h);
        float lift = uPull * rise * (0.05 + 0.34 * center) * (0.28 + 0.72 * top);
        lift += uPull * sway * 0.045 * (0.25 + 0.75 * center);
        float echo = sin(uTime * 9.0 - ropeDist * 5.5) * exp(-ropeDist * 1.3);
        lift += uJiggle * echo * 0.07 * (0.35 + 0.65 * center);

        p.y += lift;
        float pinch = lift * 1.15;
        p.x *= 1.0 - pinch * (0.35 + 0.65 * center);
        p.z *= 1.0 - pinch * (0.35 + 0.65 * center);
        p.x += uJiggle * p.x * echo * 0.18;
        p.z += uJiggle * p.z * echo * 0.18;

        vec3 clickP = vec3(uClickX, uClickY, uClickZ);
        float dist = length(p - clickP);
        float ripple = sin(dist * 18.0 - uClickTime * 16.0);
        float ring = exp(-dist * 2.6) * exp(-uClickTime * 1.65);
        p += n * ripple * ring * uClick * 0.20;
        p.y += abs(ripple) * ring * uClick * 0.04;

        _geometry.position.xyz = p;
        _geometry.normal.xyz = normalize(n + vec3(ripple * uClick * 0.8, lift * 2.0, 0.0));
        """

        static func installLiquid(_ mat: SCNMaterial) {
            mat.shaderModifiers = [.geometry: liquidShader]
            mat.setValue(NSNumber(value: Float(0)), forKey: "uPull")
            mat.setValue(NSNumber(value: Float(0)), forKey: "uJiggle")
            mat.setValue(NSNumber(value: Float(0)), forKey: "uTime")
            mat.setValue(NSNumber(value: Float(0)), forKey: "uClick")
            mat.setValue(NSNumber(value: Float(0)), forKey: "uClickTime")
            mat.setValue(NSNumber(value: Float(0)), forKey: "uClickX")
            mat.setValue(NSNumber(value: Float(0)), forKey: "uClickY")
            mat.setValue(NSNumber(value: Float(0.5)), forKey: "uClickZ")
            mat.setValue(NSNumber(value: Float(0.62)), forKey: "uHalf")
        }

        static func shellMaterial(_ color: NSColor) -> SCNMaterial {
            let mat = SCNMaterial()
            mat.lightingModel = .physicallyBased
            mat.diffuse.contents = color.withAlphaComponent(0.88)
            mat.ambient.contents = color
            mat.locksAmbientWithDiffuse = true
            mat.roughness.contents = 0.14
            mat.metalness.contents = 0
            mat.specular.contents = NSColor(calibratedWhite: 0.72, alpha: 1)
            mat.clearCoat.contents = 0.35
            mat.clearCoatRoughness.contents = 0.08
            mat.fresnelExponent = 0.7
            mat.transparency = 0.58
            mat.transparencyMode = .dualLayer
            mat.blendMode = .alpha
            mat.isDoubleSided = true
            mat.writesToDepthBuffer = false
            mat.readsFromDepthBuffer = true
            mat.emission.contents = color.withAlphaComponent(0.05)
            installLiquid(mat)
            return mat
        }

        static func faceMaterial(_ color: NSColor, code: String, name: String, count: String, compact: Bool) -> SCNMaterial {
            let mat = shellMaterial(color)
            let image = raster(paintFace(color: color, code: code, name: name, count: count, compact: compact))
            mat.diffuse.contents = image
            mat.transparent.contents = image
            mat.transparencyMode = .aOne
            mat.transparency = 0.15
            return mat
        }

        static func richer(_ color: NSColor) -> NSColor {
            let c = color.usingColorSpace(.deviceRGB) ?? color
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            return NSColor(calibratedHue: h, saturation: min(1, s * 1.1 + 0.1), brightness: max(0.2, b * 0.78), alpha: 1)
        }

        static func complementaryInk(_ color: NSColor) -> NSColor {
            let c = color.usingColorSpace(.deviceRGB) ?? color
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let hue = (h + 0.5).truncatingRemainder(dividingBy: 1)
            let sat = min(1, max(0.55, s * 0.85 + 0.3))
            let bri: CGFloat = b > 0.6 ? 0.18 : 0.96
            return NSColor(calibratedHue: hue, saturation: sat, brightness: bri, alpha: 1)
        }

        struct CubeMesh {
            var geometry: SCNGeometry
        }

        static func roundedCube(half: CGFloat, radius: CGFloat, segs: Int) -> CubeMesh {
            var positions: [SCNVector3] = []
            var normals: [SCNVector3] = []
            var uvs: [CGPoint] = []
            var front: [UInt32] = []
            var shell: [UInt32] = []

            func project(_ p: SCNVector3) -> (SCNVector3, SCNVector3) {
                let r = min(radius, half * 0.8)
                let inner = max(half - r, 0.02)
                let cx = min(max(p.x, -inner), inner)
                let cy = min(max(p.y, -inner), inner)
                let cz = min(max(p.z, -inner), inner)
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

            func emit(_ point: (CGFloat, CGFloat) -> SCNVector3, into bucket: inout [UInt32]) {
                let start = UInt32(positions.count)
                for j in 0...segs {
                    let v = CGFloat(j) / CGFloat(segs)
                    for i in 0...segs {
                        let u = CGFloat(i) / CGFloat(segs)
                        let (pos, nor) = project(point(u * 2 - 1, v * 2 - 1))
                        positions.append(pos)
                        normals.append(nor)
                        uvs.append(CGPoint(x: u, y: 1 - v))
                    }
                }
                let row = UInt32(segs + 1)
                for j in 0..<UInt32(segs) {
                    for i in 0..<UInt32(segs) {
                        let a = start + j * row + i
                        let b = a + 1
                        let c = a + row
                        let d = c + 1
                        bucket.append(contentsOf: [a, b, c, b, d, c])
                    }
                }
            }

            emit({ u, v in SCNVector3(u * half, v * half, half) }, into: &front)
            emit({ u, v in SCNVector3(half, v * half, -u * half) }, into: &shell)
            emit({ u, v in SCNVector3(-u * half, v * half, -half) }, into: &shell)
            emit({ u, v in SCNVector3(-half, v * half, u * half) }, into: &shell)
            emit({ u, v in SCNVector3(u * half, half, -v * half) }, into: &shell)
            emit({ u, v in SCNVector3(u * half, -half, v * half) }, into: &shell)

            let geo = SCNGeometry(
                sources: [
                    SCNGeometrySource(vertices: positions),
                    SCNGeometrySource(normals: normals),
                    SCNGeometrySource(textureCoordinates: uvs),
                ],
                elements: [
                    SCNGeometryElement(indices: front, primitiveType: .triangles),
                    SCNGeometryElement(indices: shell, primitiveType: .triangles),
                ]
            )
            return CubeMesh(geometry: geo)
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

        static func paintFace(color: NSColor, code: String, name: String, count: String, compact: Bool) -> NSImage {
            let size = NSSize(width: 1024, height: 1024)
            return NSImage(size: size, flipped: true) { rect in
                NSGraphicsContext.current?.shouldAntialias = true
                color.withAlphaComponent(0.5).setFill()
                rect.fill()
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let ink = complementaryInk(color)
                let mute = ink.withAlphaComponent(0.8)
                let monogram = displayFont(size: compact ? 360 : 300)
                (code as NSString).draw(
                    in: NSRect(x: 40, y: compact ? 280 : 160, width: 944, height: compact ? 460 : 420),
                    withAttributes: [
                        .font: monogram,
                        .foregroundColor: ink,
                        .paragraphStyle: paragraph,
                        .kern: 4,
                    ]
                )
                if !compact {
                    (name as NSString).draw(
                        in: NSRect(x: 40, y: 600, width: 944, height: 140),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 72, weight: .semibold),
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
                        ]
                    )
                    (count as NSString).draw(
                        in: NSRect(x: 40, y: 760, width: 944, height: 120),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 56, weight: .medium),
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
                ?? NSFont.systemFont(ofSize: size, weight: .bold)
        }
    }
}
