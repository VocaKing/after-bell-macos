import AppKit
import SceneKit
import SwiftUI
import simd

final class JellySCNView: SCNView {
    weak var coordinator: BrickSceneView.Coordinator?

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let hits = hitTest(point, options: [
            SCNHitTestOption.searchMode: SCNHitTestSearchMode.closest.rawValue,
            SCNHitTestOption.boundingBoxOnly: false,
        ])
        if let hit = hits.first(where: { node in
            var n: SCNNode? = node.node
            while let cur = n {
                if cur.name == "body" || cur.name == "core" || cur.name == "jelly" { return true }
                n = cur.parent
            }
            return false
        }) {
            let local = hit.node.name == "body"
                ? hit.localCoordinates
                : hit.node.convertPosition(hit.localCoordinates, to: hit.node.parent)
            coordinator?.beginRipple(SIMD3(Float(local.x), Float(local.y), Float(local.z)))
        }
        super.mouseDown(with: event)
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
        view.antialiasingMode = .multisampling4X
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
        context.coordinator.build(compact: compact)
        context.coordinator.apply(
            color: color, code: code, name: name, count: count,
            hovered: hovered, selected: selected, compact: compact
        )
        return view
    }

    func updateNSView(_ view: JellySCNView, context: Context) {
        view.coordinator = context.coordinator
        view.delegate = context.coordinator
        context.coordinator.view = view
        context.coordinator.apply(
            color: color, code: code, name: name, count: count,
            hovered: hovered, selected: selected, compact: compact
        )
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        weak var view: SCNView?
        var bodyNode = SCNNode()
        var coreNode = SCNNode()
        var mesh = JellyMesh(half: 0.64, radius: 0.30, segs: 18)
        var faceMat = SCNMaterial()
        var shellMat = SCNMaterial()
        var coreMat = SCNMaterial()
        var lastKey = ""
        var trackingHover = false
        var swiftHover = false
        var hoverWork: DispatchWorkItem?
        var env: Float = 0
        var envVel: Float = 0
        var hoverTime: Float = 0
        var wasHovering = false
        var clickAmp: Float = 0
        var clickAge: Float = 0
        var clickPoint = SIMD3<Float>(0, 0.2, 0.55)
        var lastTime: TimeInterval = 0
        let rope = SIMD3<Float>(0, 0.60, 0)

        func build(compact: Bool) {
            guard let view, let scene = view.scene else { return }
            scene.background.contents = NSColor.clear
            scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }

            let camera = SCNCamera()
            camera.fieldOfView = 32
            camera.zNear = 0.04
            camera.zFar = 30
            let cam = SCNNode()
            cam.camera = camera
            cam.position = SCNVector3(-0.42, 0.72, 3.25)
            cam.look(at: SCNVector3(0, 0.06, 0))
            scene.rootNode.addChildNode(cam)

            scene.lightingEnvironment.contents = Self.studioIBL()
            scene.lightingEnvironment.intensity = 1.15

            func light(_ type: SCNLight.LightType, intensity: CGFloat, color: NSColor, at: SCNVector3, look: Bool, scale: CGFloat) {
                let node = SCNNode()
                node.light = SCNLight()
                node.light?.type = type
                node.light?.intensity = intensity
                node.light?.color = color
                node.position = at
                node.scale = SCNVector3(scale, scale * 0.55, 1)
                if look { node.look(at: SCNVector3(0, 0.25, 0)) }
                scene.rootNode.addChildNode(node)
            }
            light(.ambient, intensity: 28, color: NSColor(calibratedWhite: 0.42, alpha: 1), at: .init(0, 0, 0), look: false, scale: 1)
            light(.area, intensity: 420, color: NSColor(calibratedWhite: 0.96, alpha: 1), at: .init(0.05, 2.35, 1.15), look: true, scale: 3.4)
            light(.directional, intensity: 36, color: NSColor(calibratedWhite: 0.72, alpha: 1), at: .init(-0.2, 0.35, 3.2), look: true, scale: 1)
            light(.directional, intensity: 18, color: NSColor(calibratedWhite: 0.55, alpha: 1), at: .init(1.8, 0.6, -1.2), look: true, scale: 1)

            mesh = JellyMesh(half: compact ? 0.52 : 0.64, radius: compact ? 0.24 : 0.30, segs: compact ? 14 : 20)
            bodyNode = SCNNode()
            bodyNode.name = "body"
            bodyNode.renderingOrder = 20
            coreNode = SCNNode()
            coreNode.name = "core"
            coreNode.renderingOrder = 10
            scene.rootNode.addChildNode(coreNode)
            scene.rootNode.addChildNode(bodyNode)

            let shadow = SCNPlane(width: 1.7, height: 1.45)
            let sm = SCNMaterial()
            sm.diffuse.contents = NSColor.black
            sm.transparency = 0.16
            sm.lightingModel = .constant
            sm.writesToDepthBuffer = false
            shadow.materials = [sm]
            let shadowNode = SCNNode(geometry: shadow)
            shadowNode.eulerAngles.x = -.pi / 2
            shadowNode.position = SCNVector3(0.05, -0.72, 0)
            scene.rootNode.addChildNode(shadowNode)
            upload(forceMaterials: false)
        }

        func apply(color: NSColor, code: String, name: String, count: String, hovered: Bool, selected: Bool, compact: Bool) {
            swiftHover = hovered
            if hovered { wake() }
            let rgb = color.usingColorSpace(.deviceRGB) ?? color
            let key = "\(code)|\(name)|\(count)|\(compact)|\(rgb.redComponent)|\(rgb.greenComponent)|\(rgb.blueComponent)"
            guard key != lastKey else { return }
            lastKey = key
            shellMat = Self.gelatin(rgb, transparency: 0.58)
            faceMat = Self.gelatin(rgb, transparency: 0.34)
            let image = Self.raster(Self.paintFace(color: rgb, code: code, name: name, count: count, compact: compact))
            faceMat.diffuse.contents = image
            faceMat.diffuse.magnificationFilter = .linear
            faceMat.diffuse.minificationFilter = .linear
            faceMat.diffuse.mipFilter = .linear
            coreMat = Self.gelatin(Self.richer(rgb), transparency: 0.18)
            upload(forceMaterials: true)
        }

        func beginRipple(_ point: SIMD3<Float>) {
            clickPoint = point
            clickAmp = 1
            clickAge = 0
            let n = mesh.pos.count
            for i in 0..<n {
                let d = simd_length(mesh.rest[i] - point)
                let w = exp(-d * d * 14)
                mesh.vel[i] += mesh.normal[i] * w * 3.2
            }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
        }

        func wake() {
            view?.isPlaying = true
            view?.rendersContinuously = true
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            let dt = lastTime == 0 ? Float(1.0 / 60.0) : Float(min(0.033, time - lastTime))
            lastTime = time
            let hovering = trackingHover || swiftHover
            if hovering != wasHovering {
                if hovering { hoverTime = 0 }
                wasHovering = hovering
            }
            hoverTime += dt
            let target: Float = hovering ? 1 : 0
            envVel += ((target - env) * 64 - envVel * 9) * dt
            env += envVel * dt
            clickAmp *= exp(-1.8 * dt)
            clickAge += dt

            let moving = abs(env) > 0.01 || abs(envVel) > 0.01 || clickAmp > 0.02 || mesh.energy() > 0.0004
            if !moving && !hovering {
                DispatchQueue.main.async { [weak self] in
                    guard let self, !(self.trackingHover || self.swiftHover) else { return }
                    self.view?.rendersContinuously = false
                    self.view?.isPlaying = false
                }
                lastTime = 0
                return
            }

            let h = dt / 3
            for _ in 0..<3 {
                mesh.step(h: h, env: env, hoverTime: hoverTime, rope: rope, click: clickPoint, clickAmp: clickAmp, clickAge: clickAge)
            }
            mesh.recomputeNormals()
            upload(forceMaterials: false)
        }

        func upload(forceMaterials: Bool) {
            let body = mesh.makeGeometry()
            if forceMaterials || bodyNode.geometry?.materials.count != 2 {
                body.materials = [faceMat, shellMat]
            } else if let existing = bodyNode.geometry?.materials, existing.count == 2 {
                body.materials = existing
            } else {
                body.materials = [faceMat, shellMat]
            }
            bodyNode.geometry = body

            let core = mesh.makeCoreGeometry(scale: 0.46)
            core.materials = [coreMat, coreMat]
            coreNode.geometry = core
        }

        static func gelatin(_ color: NSColor, transparency: CGFloat) -> SCNMaterial {
            let mat = SCNMaterial()
            mat.lightingModel = .physicallyBased
            mat.diffuse.contents = color
            mat.ambient.contents = color
            mat.locksAmbientWithDiffuse = true
            mat.roughness.contents = 0.46
            mat.metalness.contents = 0
            mat.specular.contents = NSColor(calibratedWhite: 0.34, alpha: 1)
            mat.clearCoat.contents = 0.06
            mat.clearCoatRoughness.contents = 0.55
            mat.fresnelExponent = 1.55
            mat.transparency = transparency
            mat.transparencyMode = .dualLayer
            mat.blendMode = .alpha
            mat.isDoubleSided = true
            mat.writesToDepthBuffer = false
            mat.readsFromDepthBuffer = true
            mat.emission.contents = color.withAlphaComponent(0.015)
            return mat
        }

        static func studioIBL() -> NSImage {
            let size = NSSize(width: 128, height: 64)
            return NSImage(size: size, flipped: false) { rect in
                NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
                rect.fill()
                let top = NSRect(x: 0, y: rect.height * 0.55, width: rect.width, height: rect.height * 0.45)
                NSGradient(colors: [
                    NSColor(calibratedWhite: 0.22, alpha: 1),
                    NSColor(calibratedWhite: 0.92, alpha: 1),
                    NSColor(calibratedWhite: 0.28, alpha: 1),
                ])?.draw(in: top, angle: 0)
                let glow = NSRect(x: rect.width * 0.28, y: rect.height * 0.62, width: rect.width * 0.44, height: rect.height * 0.32)
                NSColor(calibratedWhite: 1, alpha: 0.85).setFill()
                NSBezierPath(ovalIn: glow).fill()
                return true
            }
        }

        static func richer(_ color: NSColor) -> NSColor {
            let c = color.usingColorSpace(.deviceRGB) ?? color
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            return NSColor(calibratedHue: h, saturation: min(1, s + 0.12), brightness: max(0.22, b * 0.75), alpha: 1)
        }

        static func complementaryInk(_ color: NSColor) -> NSColor {
            let c = color.usingColorSpace(.deviceRGB) ?? color
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let hue = (h + 0.5).truncatingRemainder(dividingBy: 1)
            let sat = min(1, max(0.6, s * 0.8 + 0.35))
            let bri: CGFloat = b > 0.58 ? 0.16 : 0.96
            return NSColor(calibratedHue: hue, saturation: sat, brightness: bri, alpha: 1)
        }

        static func raster(_ image: NSImage) -> CGImage {
            let width = max(Int(image.size.width), 1)
            let height = max(Int(image.size.height), 1)
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            )!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
            NSGraphicsContext.restoreGraphicsState()
            return rep.cgImage!
        }

        static func paintFace(color: NSColor, code: String, name: String, count: String, compact: Bool) -> NSImage {
            let size = NSSize(width: 1024, height: 1024)
            return NSImage(size: size, flipped: true) { rect in
                color.setFill()
                rect.fill()
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let ink = complementaryInk(color)
                let mute = ink.withAlphaComponent(0.78)
                let font = NSFont(name: "MarkerFelt-Wide", size: compact ? 340 : 280)
                    ?? NSFont.systemFont(ofSize: compact ? 340 : 280, weight: .bold)
                (code as NSString).draw(
                    in: NSRect(x: 40, y: compact ? 300 : 180, width: 944, height: 420),
                    withAttributes: [.font: font, .foregroundColor: ink, .paragraphStyle: paragraph, .kern: 4]
                )
                if !compact {
                    (name as NSString).draw(
                        in: NSRect(x: 40, y: 620, width: 944, height: 130),
                        withAttributes: [.font: NSFont.systemFont(ofSize: 64, weight: .semibold), .foregroundColor: ink, .paragraphStyle: paragraph]
                    )
                    (count as NSString).draw(
                        in: NSRect(x: 40, y: 770, width: 944, height: 110),
                        withAttributes: [.font: NSFont.systemFont(ofSize: 48, weight: .medium), .foregroundColor: mute, .paragraphStyle: paragraph]
                    )
                }
                return true
            }
        }
    }
}

func smooth01(_ x: Float) -> Float {
    let t = min(1, max(0, x))
    return t * t * (3 - 2 * t)
}

struct JellyMesh {
    var rest: [SIMD3<Float>] = []
    var pos: [SIMD3<Float>] = []
    var vel: [SIMD3<Float>] = []
    var normal: [SIMD3<Float>] = []
    var uv: [CGPoint] = []
    var neighbors: [[Int]] = []
    var front: [UInt32] = []
    var shell: [UInt32] = []
    var tris: [(Int, Int, Int)] = []

    init() {}

    init(half: Float, radius: Float, segs: Int) {
        self = JellyMesh.make(half: half, radius: radius, segs: segs)
    }

    static func make(half: Float, radius: Float, segs: Int) -> JellyMesh {
        var rest: [SIMD3<Float>] = []
        var normal: [SIMD3<Float>] = []
        var uv: [CGPoint] = []
        var neighbors: [[Int]] = []
        var tris: [(Int, Int, Int)] = []

        func project(_ p: SIMD3<Float>) -> (SIMD3<Float>, SIMD3<Float>) {
            let r = min(radius, half * 0.82)
            let inner = max(half - r, 0.02)
            let c = simd_clamp(p, SIMD3(repeating: -inner), SIMD3(repeating: inner))
            let d = p - c
            let len = simd_length(d)
            if len < 1e-5 {
                let a = abs(p)
                var n = SIMD3<Float>(0, 0, 0)
                if a.x >= a.y && a.x >= a.z { n.x = p.x >= 0 ? 1 : -1 }
                else if a.y >= a.z { n.y = p.y >= 0 ? 1 : -1 }
                else { n.z = p.z >= 0 ? 1 : -1 }
                return (p, n)
            }
            let n = d / len
            return (c + n * r, n)
        }

        func link(_ a: Int, _ b: Int) {
            if a == b { return }
            if !neighbors[a].contains(b) { neighbors[a].append(b) }
            if !neighbors[b].contains(a) { neighbors[b].append(a) }
        }

        func emit(_ point: (Float, Float) -> SIMD3<Float>) -> [UInt32] {
            var bucket: [UInt32] = []
            let start = rest.count
            for j in 0...segs {
                let v = Float(j) / Float(segs)
                for i in 0...segs {
                    let u = Float(i) / Float(segs)
                    let (p, n) = project(point(u * 2 - 1, v * 2 - 1))
                    rest.append(p)
                    normal.append(n)
                    uv.append(CGPoint(x: CGFloat(u), y: CGFloat(1 - v)))
                    neighbors.append([])
                }
            }
            let row = segs + 1
            for j in 0..<segs {
                for i in 0..<segs {
                    let a = start + j * row + i
                    let b = a + 1
                    let c = a + row
                    let d = c + 1
                    bucket.append(contentsOf: [UInt32(a), UInt32(b), UInt32(c), UInt32(b), UInt32(d), UInt32(c)])
                    tris.append((a, b, c))
                    tris.append((b, d, c))
                    link(a, b)
                    link(a, c)
                    link(b, d)
                    link(c, d)
                }
            }
            return bucket
        }

        let face = emit { u, v in SIMD3(u * half, v * half, half) }
        let right = emit { u, v in SIMD3(half, v * half, -u * half) }
        let back = emit { u, v in SIMD3(-u * half, v * half, -half) }
        let left = emit { u, v in SIMD3(-half, v * half, u * half) }
        let top = emit { u, v in SIMD3(u * half, half, -v * half) }
        let bottom = emit { u, v in SIMD3(u * half, -half, v * half) }

        let cell: Float = 0.02
        var buckets: [Int: [Int]] = [:]
        func key(_ p: SIMD3<Float>) -> Int {
            let x = Int(p.x / cell), y = Int(p.y / cell), z = Int(p.z / cell)
            return (x + 80) * 20000 + (y + 80) * 200 + (z + 80)
        }
        for i in 0..<rest.count {
            buckets[key(rest[i]), default: []].append(i)
        }
        for i in 0..<rest.count {
            let x = Int(rest[i].x / cell), y = Int(rest[i].y / cell), z = Int(rest[i].z / cell)
            for dx in -1...1 {
                for dy in -1...1 {
                    for dz in -1...1 {
                        let slot = (x + dx + 80) * 20000 + (y + dy + 80) * 200 + (z + dz + 80)
                        guard let list = buckets[slot] else { continue }
                        for j in list where j > i && simd_length(rest[i] - rest[j]) < 0.012 {
                            link(i, j)
                        }
                    }
                }
            }
        }

        var mesh = JellyMesh()
        mesh.rest = rest
        mesh.pos = rest
        mesh.vel = Array(repeating: .zero, count: rest.count)
        mesh.normal = normal
        mesh.uv = uv
        mesh.neighbors = neighbors
        mesh.front = face
        mesh.shell = right + back + left + top + bottom
        mesh.tris = tris
        mesh.recomputeNormals()
        return mesh
    }

    mutating func step(h: Float, env: Float, hoverTime: Float, rope: SIMD3<Float>, click: SIMD3<Float>, clickAmp: Float, clickAge: Float) {
        let rest = self.rest
        let neighbors = self.neighbors
        let n = rest.count
        var pos = self.pos
        var vel = self.vel
        let normal = self.normal
        var target = rest
        for i in 0..<n {
            let r = rest[i]
            let ropeDist = simd_length(r - rope)
            let lagged = max(0, hoverTime - ropeDist * 0.38)
            let arrive = 1 - exp(-lagged * 14)
            let sway = sin(lagged * 13) * exp(-lagged * 1.8)
            let center = exp(-simd_length_squared(SIMD2(r.x, r.z)) * 7.5)
            let top = smooth01((r.y / 0.64 + 0.1) / 0.95)
            var lift = env * arrive * (0.04 + 0.40 * center) * (0.2 + 0.8 * top)
            lift += env * sway * 0.05 * (0.3 + 0.7 * center)
            var t = r
            t.y += lift
            let pinch = lift * 1.2
            t.x *= 1 - pinch * (0.3 + 0.7 * center)
            t.z *= 1 - pinch * (0.3 + 0.7 * center)
            let cd = simd_length(r - click)
            let ripple = sin(cd * 16 - clickAge * 17) * exp(-cd * 2.5) * exp(-clickAge * 1.55)
            t += normal[i] * ripple * clickAmp * 0.22
            target[i] = t
        }
        for i in 0..<n {
            var f = (target[i] - pos[i]) * 55 - vel[i] * 7.2
            if !neighbors[i].isEmpty {
                var avg = SIMD3<Float>(repeating: 0)
                for j in neighbors[i] { avg += pos[j] - rest[j] }
                avg /= Float(neighbors[i].count)
                f += (avg - (pos[i] - rest[i])) * 38
            }
            vel[i] += f * h
            pos[i] += vel[i] * h
            let delta = pos[i] - rest[i]
            let mag = simd_length(delta)
            if mag > 0.48 {
                pos[i] = rest[i] + delta / mag * 0.48
                vel[i] *= 0.45
            }
        }
        self.pos = pos
        self.vel = vel
    }

    func energy() -> Float {
        var e: Float = 0
        for v in vel { e = max(e, simd_length_squared(v)) }
        return e
    }

    mutating func recomputeNormals() {
        let pos = self.pos
        let rest = self.rest
        let tris = self.tris
        var acc = [SIMD3<Float>](repeating: .zero, count: pos.count)
        for tri in tris {
            let n = simd_cross(pos[tri.1] - pos[tri.0], pos[tri.2] - pos[tri.0])
            acc[tri.0] += n
            acc[tri.1] += n
            acc[tri.2] += n
        }
        var normal = self.normal
        if normal.count != acc.count { normal = Array(repeating: .zero, count: acc.count) }
        for i in 0..<acc.count {
            let len = simd_length(acc[i])
            if len > 1e-6 {
                var n = acc[i] / len
                if simd_dot(n, rest[i]) < 0 { n = -n }
                normal[i] = n
            }
        }
        self.normal = normal
    }

    func makeGeometry() -> SCNGeometry {
        geometry(positions: pos)
    }

    func makeCoreGeometry(scale: Float) -> SCNGeometry {
        let rest = self.rest
        let pos = self.pos
        var inner = rest
        for i in 0..<rest.count {
            inner[i] = rest[i] * scale + (pos[i] - rest[i]) * (scale + 0.12)
        }
        return geometry(positions: inner)
    }

    func geometry(positions: [SIMD3<Float>]) -> SCNGeometry {
        let normal = self.normal
        let uv = self.uv
        let front = self.front
        let shell = self.shell
        var verts: [SCNVector3] = []
        var norms: [SCNVector3] = []
        verts.reserveCapacity(positions.count)
        norms.reserveCapacity(positions.count)
        for i in 0..<positions.count {
            let p = positions[i]
            let n = normal[i]
            verts.append(SCNVector3(p.x, p.y, p.z))
            norms.append(SCNVector3(n.x, n.y, n.z))
        }
        return SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: verts),
                SCNGeometrySource(normals: norms),
                SCNGeometrySource(textureCoordinates: uv),
            ],
            elements: [
                SCNGeometryElement(indices: front, primitiveType: .triangles),
                SCNGeometryElement(indices: shell, primitiveType: .triangles),
            ]
        )
    }
}
