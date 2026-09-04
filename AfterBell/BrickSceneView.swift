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
            scene.lightingEnvironment.intensity = 0.42

            let camera = SCNCamera()
            camera.fieldOfView = compact ? 34 : 35
            camera.zNear = 0.05
            camera.zFar = 40
            camera.wantsHDR = false
            let camNode = SCNNode()
            camNode.camera = camera
            camNode.position = compact
                ? SCNVector3(0.28, 0.52, 2.15)
                : SCNVector3(0.34, 0.62, 2.48)
            camNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(camNode)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 105
            ambient.light?.color = NSColor(calibratedWhite: 0.48, alpha: 1)
            scene.rootNode.addChildNode(ambient)

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 300
            key.light?.color = NSColor(calibratedRed: 1.00, green: 0.97, blue: 0.93, alpha: 1)
            key.position = SCNVector3(1.2, 3.0, 1.6)
            key.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(key)

            let bounce = SCNNode()
            bounce.light = SCNLight()
            bounce.light?.type = .omni
            bounce.light?.intensity = 55
            bounce.light?.color = NSColor(calibratedRed: 0.90, green: 0.88, blue: 0.84, alpha: 1)
            bounce.position = SCNVector3(0.2, -1.4, 1.2)
            scene.rootNode.addChildNode(bounce)

            let rim = SCNNode()
            rim.light = SCNLight()
            rim.light?.type = .directional
            rim.light?.intensity = 85
            rim.light?.color = NSColor(calibratedRed: 0.78, green: 0.84, blue: 0.94, alpha: 1)
            rim.position = SCNVector3(-2.2, 1.4, -1.4)
            rim.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(rim)

            let width: CGFloat = compact ? 1.22 : 1.58
            let height: CGFloat = compact ? 0.82 : 1.02
            let depth: CGFloat = compact ? 0.62 : 0.78
            let chamfer: CGFloat = compact ? 0.16 : 0.20

            let box = SCNBox(width: width, height: height, length: depth, chamferRadius: chamfer)
            box.chamferSegmentCount = 24
            let brickNode = SCNNode(geometry: box)
            scene.rootNode.addChildNode(brickNode)
            brick = brickNode

            let shadow = SCNPlane(width: compact ? 1.55 : 2.05, height: compact ? 1.20 : 1.55)
            let sm = SCNMaterial()
            sm.diffuse.contents = NSColor.black
            sm.transparency = 0.20
            sm.lightingModel = .constant
            sm.writesToDepthBuffer = false
            shadow.materials = [sm]
            let shadowNode = SCNNode(geometry: shadow)
            shadowNode.eulerAngles.x = -.pi / 2
            shadowNode.position = SCNVector3(0.16, compact ? -0.50 : -0.62, 0.10)
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
                hovered ? -0.04 : 0,
                hovered ? 0.05 : 0,
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
            let side = ceramic(color)
            let front = ceramic(color)
            front.diffuse.contents = paintFace(
                color: color, code: code, name: name, count: count, compact: compact
            )
            front.diffuse.magnificationFilter = .linear
            front.diffuse.minificationFilter = .linear
            front.diffuse.mipFilter = .linear
            front.diffuse.maxAnisotropy = 16
            return [front, side, ceramic(color), ceramic(color), ceramic(color), ceramic(color)]
        }

        static func ceramic(_ color: NSColor) -> SCNMaterial {
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.ambient.contents = color
            mat.locksAmbientWithDiffuse = true
            mat.roughness.contents = 0.48
            mat.metalness.contents = 0.012
            mat.specular.contents = NSColor(calibratedWhite: 0.14, alpha: 1)
            mat.shininess = 0.14
            mat.lightingModel = .physicallyBased
            mat.clearCoat.contents = 0.10
            mat.clearCoatRoughness.contents = 0.58
            return mat
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
                if compact {
                    (code as NSString).draw(
                        in: NSRect(x: 80, y: 220, width: 1888, height: 840),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 540, weight: .bold),
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
                        ]
                    )
                } else {
                    (code as NSString).draw(
                        in: NSRect(x: 120, y: 140, width: 1808, height: 520),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 380, weight: .bold),
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
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
