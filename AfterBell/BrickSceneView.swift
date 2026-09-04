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
        var restEuler = SCNVector3(-0.55, 0.78, 0.10)
        var lastKey = ""

        func build(in view: SCNView, compact: Bool) {
            let scene = SCNScene()
            view.scene = scene

            let camera = SCNCamera()
            camera.fieldOfView = compact ? 34 : 38
            camera.zNear = 0.05
            camera.zFar = 40
            let camNode = SCNNode()
            camNode.camera = camera
            if compact {
                camNode.position = SCNVector3(1.55, 1.15, 2.15)
            } else {
                camNode.position = SCNVector3(2.05, 1.55, 2.45)
            }
            camNode.look(at: SCNVector3(0, 0.02, 0))
            scene.rootNode.addChildNode(camNode)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 220
            ambient.light?.color = NSColor(calibratedWhite: 0.70, alpha: 1)
            scene.rootNode.addChildNode(ambient)

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 680
            key.light?.color = NSColor(calibratedRed: 1, green: 0.97, blue: 0.94, alpha: 1)
            key.position = SCNVector3(2.4, 2.8, 1.8)
            key.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(key)

            let fill = SCNNode()
            fill.light = SCNLight()
            fill.light?.type = .omni
            fill.light?.intensity = 240
            fill.light?.color = NSColor(calibratedRed: 0.78, green: 0.86, blue: 1, alpha: 1)
            fill.position = SCNVector3(-1.8, 0.6, 2.0)
            scene.rootNode.addChildNode(fill)

            let box = SCNBox(
                width: compact ? 1.28 : 1.58,
                height: compact ? 0.86 : 1.02,
                length: compact ? 0.92 : 1.12,
                chamferRadius: compact ? 0.12 : 0.14
            )
            box.chamferSegmentCount = 16
            let brickNode = SCNNode(geometry: box)
            brickNode.eulerAngles = restEuler
            scene.rootNode.addChildNode(brickNode)
            brick = brickNode

            let shadow = SCNPlane(width: compact ? 1.55 : 1.9, height: compact ? 1.2 : 1.45)
            let sm = SCNMaterial()
            sm.diffuse.contents = NSColor.black
            sm.transparency = 0.28
            sm.lightingModel = .constant
            sm.writesToDepthBuffer = false
            shadow.materials = [sm]
            let shadowNode = SCNNode(geometry: shadow)
            shadowNode.eulerAngles.x = -.pi / 2
            shadowNode.position = SCNVector3(0.12, compact ? -0.55 : -0.68, 0.10)
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
            if key != lastKey, let box = brick.geometry as? SCNBox {
                lastKey = key
                let front = Self.faceMaterial(color: rgb, code: code, name: name, count: count, compact: compact)
                let side = Self.bodyMaterial(color: rgb, highlight: false)
                let top = Self.bodyMaterial(color: rgb, highlight: true)
                box.materials = [front, side, side, side, top, side]
            }

            let lift: CGFloat = hovered ? (compact ? 0.10 : 0.16) : (selected ? 0.07 : 0)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.18
            brick.position.y = lift
            brick.eulerAngles = SCNVector3(
                restEuler.x + (hovered ? 0.06 : 0),
                restEuler.y - (hovered ? 0.06 : 0),
                restEuler.z
            )
            SCNTransaction.commit()
        }

        static func bodyMaterial(color: NSColor, highlight: Bool) -> SCNMaterial {
            let mat = SCNMaterial()
            let body = highlight ? (color.blended(withFraction: 0.10, of: .white) ?? color) : color
            mat.diffuse.contents = body
            mat.roughness.contents = 0.52
            mat.metalness.contents = 0.03
            mat.specular.contents = NSColor(calibratedWhite: 0.28, alpha: 1)
            mat.shininess = 0.22
            mat.lightingModel = .physicallyBased
            Self.smoothMap(mat)
            return mat
        }

        static func faceMaterial(color: NSColor, code: String, name: String, count: String, compact: Bool) -> SCNMaterial {
            let mat = bodyMaterial(color: color, highlight: false)
            mat.diffuse.contents = paintFace(color: color, code: code, name: name, count: count, compact: compact)
            Self.smoothMap(mat)
            return mat
        }

        static func smoothMap(_ mat: SCNMaterial) {
            mat.diffuse.magnificationFilter = .linear
            mat.diffuse.minificationFilter = .linear
            mat.diffuse.mipFilter = .linear
            mat.diffuse.wrapS = .clamp
            mat.diffuse.wrapT = .clamp
            mat.diffuse.maxAnisotropy = 16
        }

        static func paintFace(color: NSColor, code: String, name: String, count: String, compact: Bool) -> NSImage {
            let size = NSSize(width: 2048, height: 1440)
            return NSImage(size: size, flipped: true) { rect in
                NSGraphicsContext.current?.shouldAntialias = true
                NSGraphicsContext.current?.imageInterpolation = .high
                color.setFill()
                rect.fill()
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let ink = NSColor(calibratedWhite: 0.10, alpha: 0.92)
                let mute = NSColor(calibratedWhite: 0.14, alpha: 0.70)
                if compact {
                    (code as NSString).draw(
                        in: NSRect(x: 80, y: 280, width: 1888, height: 880),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 600, weight: .bold),
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
                        ]
                    )
                } else {
                    (code as NSString).draw(
                        in: NSRect(x: 96, y: 140, width: 1856, height: 560),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 420, weight: .bold),
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
                        ]
                    )
                    (name as NSString).draw(
                        in: NSRect(x: 96, y: 720, width: 1856, height: 220),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 156, weight: .semibold),
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
                        ]
                    )
                    (count as NSString).draw(
                        in: NSRect(x: 96, y: 960, width: 1856, height: 160),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 104, weight: .medium),
                            .foregroundColor: mute,
                            .paragraphStyle: paragraph,
                        ]
                    )
                }
                return true
            }
        }
    }
}
