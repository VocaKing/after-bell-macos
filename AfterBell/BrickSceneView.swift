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
        context.coordinator.build(in: view, compact: compact)
        context.coordinator.apply(
            color: color, code: code, name: name, count: count,
            hovered: hovered, selected: selected, compact: compact
        )
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.apply(
            color: color, code: code, name: name, count: count,
            hovered: hovered, selected: selected, compact: compact
        )
    }

    final class Coordinator {
        var brick: SCNNode?
        var lastKey = ""

        func build(in view: SCNView, compact: Bool) {
            let scene = SCNScene()
            view.scene = scene
            scene.lightingEnvironment.contents = Self.studioIBL()
            scene.lightingEnvironment.intensity = 0.20

            let camera = SCNCamera()
            camera.fieldOfView = compact ? 32 : 33
            camera.zNear = 0.05
            camera.zFar = 40
            camera.wantsHDR = false
            let camNode = SCNNode()
            camNode.camera = camera
            camNode.position = compact
                ? SCNVector3(-0.14, 0.38, 2.38)
                : SCNVector3(-0.16, 0.46, 2.82)
            camNode.look(at: SCNVector3(0, 0.02, 0))
            scene.rootNode.addChildNode(camNode)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 64
            ambient.light?.color = NSColor(calibratedWhite: 0.36, alpha: 1)
            scene.rootNode.addChildNode(ambient)

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 155
            key.light?.color = NSColor(calibratedRed: 1.00, green: 0.97, blue: 0.93, alpha: 1)
            key.position = SCNVector3(1.1, 3.1, 1.8)
            key.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(key)

            let bounce = SCNNode()
            bounce.light = SCNLight()
            bounce.light?.type = .omni
            bounce.light?.intensity = 22
            bounce.light?.color = NSColor(calibratedRed: 0.90, green: 0.88, blue: 0.84, alpha: 1)
            bounce.position = SCNVector3(0.15, -1.5, 1.3)
            scene.rootNode.addChildNode(bounce)

            let rim = SCNNode()
            rim.light = SCNLight()
            rim.light?.type = .directional
            rim.light?.intensity = 36
            rim.light?.color = NSColor(calibratedRed: 0.78, green: 0.84, blue: 0.94, alpha: 1)
            rim.position = SCNVector3(-2.3, 1.5, -1.3)
            rim.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(rim)

            let geo = Self.tokenGeometry(compact: compact)
            let brickNode = SCNNode(geometry: geo)
            scene.rootNode.addChildNode(brickNode)
            brick = brickNode

            let shadow = SCNPlane(width: compact ? 1.62 : 2.15, height: compact ? 1.28 : 1.68)
            let sm = SCNMaterial()
            sm.diffuse.contents = NSColor.black
            sm.transparency = 0.22
            sm.lightingModel = .constant
            sm.writesToDepthBuffer = false
            shadow.materials = [sm]
            let shadowNode = SCNNode(geometry: shadow)
            shadowNode.eulerAngles.x = -.pi / 2
            shadowNode.position = SCNVector3(0.12, compact ? -0.54 : -0.68, 0.08)
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
            guard let brick else { return }
            let rgb = color.usingColorSpace(.deviceRGB) ?? color
            let key = "\(code)|\(name)|\(count)|\(compact)|\(rgb.redComponent)|\(rgb.greenComponent)|\(rgb.blueComponent)"
            if key != lastKey {
                lastKey = key
                brick.geometry?.materials = Self.brickMaterials(
                    color: rgb, code: code, name: name, count: count, compact: compact
                )
            }

            let lift: CGFloat = hovered ? (compact ? 0.10 : 0.14) : (selected ? 0.06 : 0)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.18
            brick.position.y = lift
            brick.eulerAngles = SCNVector3(
                hovered ? -0.03 : 0,
                hovered ? -0.04 : 0,
                0
            )
            SCNTransaction.commit()
        }

        static func brickMaterials(
            color: NSColor,
            code: String,
            name: String,
            count: String,
            compact: Bool
        ) -> [SCNMaterial] {
            let shell = ceramic(color)
            let front = ceramic(color)
            front.diffuse.contents = paintFace(
                color: color, code: code, name: name, count: count, compact: compact
            )
            front.diffuse.magnificationFilter = .linear
            front.diffuse.minificationFilter = .linear
            front.diffuse.mipFilter = .linear
            front.diffuse.maxAnisotropy = 16
            front.shaderModifiers = Self.faceGlaze
            return [front, shell, shell, shell, shell, shell]
        }

        static func ceramic(_ color: NSColor) -> SCNMaterial {
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.ambient.contents = color
            mat.locksAmbientWithDiffuse = true
            mat.roughness.contents = 0.62
            mat.metalness.contents = 0.0
            mat.specular.contents = NSColor(calibratedWhite: 0.07, alpha: 1)
            mat.shininess = 0.07
            mat.lightingModel = .physicallyBased
            mat.clearCoat.contents = 0.10
            mat.clearCoatRoughness.contents = 0.42
            mat.fresnelExponent = 3.4
            mat.shaderModifiers = rimGlaze
            return mat
        }

        static let rimGlaze: [SCNShaderModifierEntryPoint: String] = [
            .surface: """
            float ndotv = max(dot(_surface.normal, _surface.view), 0.0);
            float rim = pow(clamp(1.0 - ndotv, 0.0, 1.0), 3.8);
            float band = pow(clamp(1.0 - ndotv, 0.0, 1.0), 2.6);
            vec3 n = _surface.normal;
            float phase = n.x * 3.1 + n.y * 4.2 + n.z * 1.7;
            vec3 oil = vec3(
                0.50 + 0.50 * sin(phase),
                0.50 + 0.50 * sin(phase + 2.094),
                0.50 + 0.50 * sin(phase + 4.188)
            );
            _surface.diffuse.rgb = mix(_surface.diffuse.rgb, oil, rim * 0.50);
            _surface.emission = vec4(oil * rim * 0.18, 0.0);
            _surface.reflective = vec4(oil * band * 0.30, 1.0);
            """
        ]

        static let faceGlaze: [SCNShaderModifierEntryPoint: String] = [
            .surface: """
            float ndotv = max(dot(_surface.normal, _surface.view), 0.0);
            float rim = pow(clamp(1.0 - ndotv, 0.0, 1.0), 4.4);
            vec3 n = _surface.normal;
            float phase = n.x * 3.1 + n.y * 4.2 + n.z * 1.7;
            vec3 oil = vec3(
                0.50 + 0.50 * sin(phase),
                0.50 + 0.50 * sin(phase + 2.094),
                0.50 + 0.50 * sin(phase + 4.188)
            );
            _surface.emission = vec4(oil * rim * 0.10, 0.0);
            _surface.reflective = vec4(oil * rim * 0.16, 1.0);
            """
        ]

        static func tokenGeometry(compact: Bool) -> SCNGeometry {
            let hw: CGFloat = compact ? 0.62 : 0.80
            let hh: CGFloat = compact ? 0.42 : 0.52
            let hd: CGFloat = compact ? 0.38 : 0.48
            let radius: CGFloat = compact ? 0.20 : 0.26
            let taper: CGFloat = 0.16
            let crown: CGFloat = compact ? 0.028 : 0.042
            let segs = compact ? 12 : 16
            return makeToken(
                hw: hw, hh: hh, hd: hd,
                radius: radius, taper: taper, crown: crown, segs: segs
            )
        }

        static func scaleAtZ(_ z: CGFloat, hd: CGFloat, taper: CGFloat) -> CGFloat {
            let t = (z / max(hd, 0.001) + 1) * 0.5
            return (1 - taper) + taper * t
        }

        static func project(
            _ p: SCNVector3,
            hw: CGFloat, hh: CGFloat, hd: CGFloat,
            radius: CGFloat, taper: CGFloat
        ) -> (SCNVector3, SCNVector3) {
            let s = scaleAtZ(p.z, hd: hd, taper: taper)
            let r = min(radius, hw * s * 0.72, hh * s * 0.72, hd * 0.72)
            let ix = max(hw * s - r, 0.02)
            let iy = max(hh * s - r, 0.02)
            let iz = max(hd - r, 0.02)
            let cx = min(max(p.x, -ix), ix)
            let cy = min(max(p.y, -iy), iy)
            let cz = min(max(p.z, -iz), iz)
            let dx = p.x - cx
            let dy = p.y - cy
            let dz = p.z - cz
            let len = sqrt(dx * dx + dy * dy + dz * dz)
            if len < 1e-5 {
                let ax = abs(p.x), ay = abs(p.y), az = abs(p.z)
                var n = SCNVector3Zero
                if ax >= ay && ax >= az { n.x = p.x >= 0 ? 1 : -1 }
                else if ay >= az { n.y = p.y >= 0 ? 1 : -1 }
                else { n.z = p.z >= 0 ? 1 : -1 }
                return (SCNVector3(p.x, p.y, p.z), n)
            }
            let n = SCNVector3(dx / len, dy / len, dz / len)
            return (SCNVector3(cx + n.x * r, cy + n.y * r, cz + n.z * r), n)
        }

        static func makeToken(
            hw: CGFloat, hh: CGFloat, hd: CGFloat,
            radius: CGFloat, taper: CGFloat, crown: CGFloat, segs: Int
        ) -> SCNGeometry {
            var positions: [SCNVector3] = []
            var normals: [SCNVector3] = []
            var uvs: [CGPoint] = []
            var elements: [SCNGeometryElement] = []

            func emitFace(samples: [(SCNVector3, CGPoint)], pillow: Bool) {
                let start = UInt32(positions.count)
                let n = segs
                for sample in samples {
                    var p = sample.0
                    var (pos, nor) = project(p, hw: hw, hh: hh, hd: hd, radius: radius, taper: taper)
                    if pillow {
                        let nx = pos.x / max(hw, 0.001)
                        let ny = pos.y / max(hh, 0.001)
                        let lift = crown * max(0, 1 - nx * nx) * max(0, 1 - ny * ny)
                        pos.z += lift
                        nor.z += lift * 3
                        let nl = max(0.0001, sqrt(nor.x * nor.x + nor.y * nor.y + nor.z * nor.z))
                        nor = SCNVector3(nor.x / nl, nor.y / nl, nor.z / nl)
                    }
                    positions.append(pos)
                    normals.append(nor)
                    uvs.append(sample.1)
                }
                var idx: [UInt32] = []
                let row = UInt32(n + 1)
                for j in 0..<UInt32(n) {
                    for i in 0..<UInt32(n) {
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
                        out.append((point(u * 2 - 1, v * 2 - 1), CGPoint(x: u, y: v)))
                    }
                }
                return out
            }

            // Front +z, Right +x, Back -z, Left -x, Top +y, Bottom -y
            emitFace(samples: grid { u, v in
                let s = scaleAtZ(hd, hd: hd, taper: taper)
                return SCNVector3(u * hw * s, v * hh * s, hd)
            }, pillow: true)

            emitFace(samples: grid { u, v in
                let z = -u * hd
                let s = scaleAtZ(z, hd: hd, taper: taper)
                return SCNVector3(hw * s, v * hh * s, z)
            }, pillow: false)

            emitFace(samples: grid { u, v in
                let s = scaleAtZ(-hd, hd: hd, taper: taper)
                return SCNVector3(-u * hw * s, v * hh * s, -hd)
            }, pillow: false)

            emitFace(samples: grid { u, v in
                let z = u * hd
                let s = scaleAtZ(z, hd: hd, taper: taper)
                return SCNVector3(-hw * s, v * hh * s, z)
            }, pillow: false)

            emitFace(samples: grid { u, v in
                let z = -v * hd
                let s = scaleAtZ(z, hd: hd, taper: taper)
                return SCNVector3(u * hw * s, hh * s, z)
            }, pillow: false)

            emitFace(samples: grid { u, v in
                let z = v * hd
                let s = scaleAtZ(z, hd: hd, taper: taper)
                return SCNVector3(u * hw * s, -hh * s, z)
            }, pillow: false)

            let geo = SCNGeometry(
                sources: [
                    SCNGeometrySource(vertices: positions),
                    SCNGeometrySource(normals: normals),
                    SCNGeometrySource(textureCoordinates: uvs),
                ],
                elements: elements
            )
            return geo
        }

        static func paintFace(
            color: NSColor,
            code: String,
            name: String,
            count: String,
            compact: Bool
        ) -> NSImage {
            let size = NSSize(width: 2048, height: 1280)
            return NSImage(size: size, flipped: true) { rect in
                NSGraphicsContext.current?.shouldAntialias = true
                NSGraphicsContext.current?.imageInterpolation = .high
                color.setFill()
                rect.fill()
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let ink = NSColor(calibratedWhite: 0.11, alpha: 0.90)
                let mute = NSColor(calibratedWhite: 0.12, alpha: 0.58)
                let monogram = Self.displayFont(size: compact ? 500 : 390)
                if compact {
                    (code as NSString).draw(
                        in: NSRect(x: 80, y: 240, width: 1888, height: 800),
                        withAttributes: [
                            .font: monogram,
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
                            .kern: 6,
                        ]
                    )
                } else {
                    (code as NSString).draw(
                        in: NSRect(x: 120, y: 150, width: 1808, height: 500),
                        withAttributes: [
                            .font: monogram,
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
                            .kern: 4,
                        ]
                    )
                    (name as NSString).draw(
                        in: NSRect(x: 120, y: 690, width: 1808, height: 190),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 132, weight: .semibold),
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
                        ]
                    )
                    (count as NSString).draw(
                        in: NSRect(x: 120, y: 900, width: 1808, height: 150),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 92, weight: .medium),
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
                    NSColor(calibratedRed: 0.58, green: 0.60, blue: 0.64, alpha: 1),
                    NSColor(calibratedRed: 0.18, green: 0.17, blue: 0.16, alpha: 1),
                ])?.draw(in: rect, angle: -90)
                return true
            }
        }
    }
}
