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
        var label: SCNNode?
        var restEuler = SCNVector3(-0.40, 0.52, 0.07)
        var lastKey = ""
        var depth: CGFloat = 0.66

        func build(in view: SCNView, compact: Bool) {
            let scene = SCNScene()
            view.scene = scene
            scene.lightingEnvironment.contents = Self.studioIBL()
            scene.lightingEnvironment.intensity = 0.55

            let camera = SCNCamera()
            camera.fieldOfView = compact ? 34 : 36
            camera.zNear = 0.05
            camera.zFar = 40
            camera.wantsHDR = false
            let camNode = SCNNode()
            camNode.camera = camera
            camNode.position = compact
                ? SCNVector3(1.35, 1.05, 2.20)
                : SCNVector3(1.55, 1.22, 2.40)
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
            key.light?.intensity = 380
            key.light?.color = NSColor(calibratedRed: 1.00, green: 0.96, blue: 0.90, alpha: 1)
            key.position = SCNVector3(1.6, 2.6, 1.4)
            key.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(key)

            let fill = SCNNode()
            fill.light = SCNLight()
            fill.light?.type = .omni
            fill.light?.intensity = 70
            fill.light?.color = NSColor(calibratedRed: 0.72, green: 0.80, blue: 0.92, alpha: 1)
            fill.position = SCNVector3(-1.6, 0.5, 1.6)
            scene.rootNode.addChildNode(fill)

            let rim = SCNNode()
            rim.light = SCNLight()
            rim.light?.type = .directional
            rim.light?.intensity = 110
            rim.light?.color = NSColor(calibratedRed: 0.82, green: 0.86, blue: 0.95, alpha: 1)
            rim.position = SCNVector3(-1.8, 1.2, -1.6)
            rim.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(rim)

            let width: CGFloat = compact ? 1.32 : 1.72
            let height: CGFloat = compact ? 0.90 : 1.08
            depth = compact ? 0.54 : 0.66
            let chamfer: CGFloat = compact ? 0.10 : 0.12

            let box = SCNBox(width: width, height: height, length: depth, chamferRadius: chamfer)
            box.chamferSegmentCount = 12
            let brickNode = SCNNode(geometry: box)
            brickNode.eulerAngles = restEuler
            scene.rootNode.addChildNode(brickNode)
            brick = brickNode

            let plane = SCNPlane(width: width - chamfer * 1.6, height: height - chamfer * 1.6)
            let labelNode = SCNNode(geometry: plane)
            labelNode.position = SCNVector3(0, 0, depth / 2 + 0.008)
            labelNode.renderingOrder = 8
            brickNode.addChildNode(labelNode)
            label = labelNode

            let shadow = SCNPlane(width: compact ? 1.55 : 1.95, height: compact ? 1.15 : 1.40)
            let sm = SCNMaterial()
            sm.diffuse.contents = NSColor.black
            sm.transparency = 0.22
            sm.lightingModel = .constant
            sm.writesToDepthBuffer = false
            shadow.materials = [sm]
            let shadowNode = SCNNode(geometry: shadow)
            shadowNode.eulerAngles.x = -.pi / 2
            shadowNode.position = SCNVector3(0.10, compact ? -0.52 : -0.62, 0.08)
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
                let body = Self.ceramic(rgb)
                brick.geometry?.materials = [body]
                if let label, let plane = label.geometry as? SCNPlane {
                    plane.materials = [Self.labelMaterial(code: code, name: name, count: count, compact: compact)]
                }
            }

            let lift: CGFloat = hovered ? (compact ? 0.10 : 0.16) : (selected ? 0.07 : 0)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.18
            brick.position.y = lift
            brick.eulerAngles = SCNVector3(
                restEuler.x + (hovered ? 0.05 : 0),
                restEuler.y - (hovered ? 0.05 : 0),
                restEuler.z
            )
            SCNTransaction.commit()
        }

        static func ceramic(_ color: NSColor) -> SCNMaterial {
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.ambient.contents = color
            mat.locksAmbientWithDiffuse = true
            mat.roughness.contents = 0.44
            mat.metalness.contents = 0.02
            mat.specular.contents = NSColor(calibratedWhite: 0.18, alpha: 1)
            mat.shininess = 0.18
            mat.lightingModel = .physicallyBased
            mat.clearCoat.contents = 0.18
            mat.clearCoatRoughness.contents = 0.48
            return mat
        }

        static func labelMaterial(code: String, name: String, count: String, compact: Bool) -> SCNMaterial {
            let mat = SCNMaterial()
            let image = paintLabel(code: code, name: name, count: count, compact: compact)
            mat.diffuse.contents = image
            mat.transparent.contents = image
            mat.transparencyMode = .aOne
            mat.lightingModel = .constant
            mat.blendMode = .alpha
            mat.writesToDepthBuffer = false
            mat.isDoubleSided = false
            mat.diffuse.magnificationFilter = .linear
            mat.diffuse.minificationFilter = .linear
            mat.diffuse.mipFilter = .linear
            mat.diffuse.maxAnisotropy = 16
            return mat
        }

        static func paintLabel(code: String, name: String, count: String, compact: Bool) -> NSImage {
            let size = NSSize(width: 2048, height: 1280)
            return NSImage(size: size, flipped: true) { rect in
                NSGraphicsContext.current?.shouldAntialias = true
                NSGraphicsContext.current?.imageInterpolation = .high
                NSColor.clear.setFill()
                rect.fill()
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let ink = NSColor(calibratedWhite: 0.10, alpha: 0.92)
                let mute = NSColor(calibratedWhite: 0.12, alpha: 0.62)
                if compact {
                    (code as NSString).draw(
                        in: NSRect(x: 80, y: 220, width: 1888, height: 840),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 560, weight: .bold),
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
                        ]
                    )
                } else {
                    (code as NSString).draw(
                        in: NSRect(x: 80, y: 90, width: 1888, height: 560),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 400, weight: .bold),
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
                        ]
                    )
                    (name as NSString).draw(
                        in: NSRect(x: 80, y: 670, width: 1888, height: 200),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 140, weight: .semibold),
                            .foregroundColor: ink,
                            .paragraphStyle: paragraph,
                        ]
                    )
                    (count as NSString).draw(
                        in: NSRect(x: 80, y: 900, width: 1888, height: 150),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 96, weight: .medium),
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
                    NSColor(calibratedRed: 0.62, green: 0.64, blue: 0.68, alpha: 1),
                    NSColor(calibratedRed: 0.16, green: 0.15, blue: 0.14, alpha: 1),
                ])?.draw(in: rect, angle: -90)
                return true
            }
        }
    }
}
