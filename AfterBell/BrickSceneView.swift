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
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.isOpaque = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.isPlaying = true
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
        var lastKey = ""
        var bob: SCNAction?

        func build(in view: SCNView, compact: Bool) {
            let scene = view.scene ?? SCNScene()
            view.scene = scene

            let camera = SCNCamera()
            camera.fieldOfView = compact ? 24 : 26
            camera.zNear = 0.1
            camera.zFar = 40
            let camNode = SCNNode()
            camNode.camera = camera
            camNode.position = SCNVector3(compact ? 0.68 : 0.5, compact ? 0.34 : 0.24, compact ? 5.4 : 4.2)
            camNode.look(at: SCNVector3(0.18, 0.03, 0))
            scene.rootNode.addChildNode(camNode)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 420
            ambient.light?.color = NSColor(white: 0.72, alpha: 1)
            scene.rootNode.addChildNode(ambient)

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 1100
            key.light?.color = NSColor(white: 1, alpha: 1)
            key.position = SCNVector3(1.6, 1.4, 1.1)
            key.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(key)

            let fill = SCNNode()
            fill.light = SCNLight()
            fill.light?.type = .omni
            fill.light?.intensity = 550
            fill.position = SCNVector3(2.2, 1.6, 1.4)
            scene.rootNode.addChildNode(fill)

            let box = SCNBox(width: 1.5, height: 1.08, length: 0.66, chamferRadius: 0.14)
            box.chamferSegmentCount = 8
            let brickNode = SCNNode(geometry: box)
            brickNode.eulerAngles = SCNVector3(-0.3, 0.4, 0)
            scene.rootNode.addChildNode(brickNode)
            brick = brickNode

            let plane = SCNPlane(width: compact ? 1.05 : 1.18, height: compact ? 0.72 : 0.88)
            plane.cornerRadius = 0.04
            let labelNode = SCNNode(geometry: plane)
            labelNode.position = SCNVector3(0, compact ? 0 : 0.02, 0.338)
            labelNode.renderingOrder = 2
            brickNode.addChildNode(labelNode)
            label = labelNode

            let bobUp = SCNAction.moveBy(x: 0, y: 0.04, z: 0, duration: 1.7)
            bobUp.timingMode = .easeInEaseOut
            let bobDown = bobUp.reversed()
            brickNode.runAction(.repeatForever(.sequence([bobUp, bobDown])))
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
            guard let brick, let label else { return }
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.roughness.contents = 0.28
            mat.metalness.contents = 0.06
            mat.lightingModel = .physicallyBased
            brick.geometry?.materials = [mat]

            let key = "\(code)|\(name)|\(count)|\(compact)"
            if key != lastKey, let geom = label.geometry as? SCNPlane {
                lastKey = key
                let image = Self.makeLabel(code: code, name: name, count: count, compact: compact)
                let lm = SCNMaterial()
                lm.diffuse.contents = image
                lm.transparent.contents = image
                lm.lightingModel = .constant
                lm.isDoubleSided = true
                lm.writesToDepthBuffer = false
                geom.materials = [lm]
            }

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.18
            brick.position.y = hovered ? (compact ? 0.12 : 0.16) : (selected ? 0.09 : 0)
            brick.eulerAngles = SCNVector3(
                hovered ? -0.24 : -0.3,
                hovered ? 0.34 : 0.4,
                0
            )
            SCNTransaction.commit()
        }

        static func makeLabel(code: String, name: String, count: String, compact: Bool) -> NSImage {
            let size = NSSize(width: 1024, height: 768)
            return NSImage(size: size, flipped: true) { rect in
                NSColor.clear.setFill()
                rect.fill()
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let ink = NSColor(calibratedWhite: 0.1, alpha: 0.92)
                if compact {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 280, weight: .bold),
                        .foregroundColor: ink,
                        .paragraphStyle: paragraph,
                    ]
                    (code as NSString).draw(
                        in: NSRect(x: 40, y: 180, width: 944, height: 420),
                        withAttributes: attrs
                    )
                } else {
                    let codeAttrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 188, weight: .bold),
                        .foregroundColor: ink,
                        .paragraphStyle: paragraph,
                    ]
                    let nameAttrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 72, weight: .semibold),
                        .foregroundColor: ink,
                        .paragraphStyle: paragraph,
                    ]
                    let countAttrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 50, weight: .medium),
                        .foregroundColor: NSColor(calibratedWhite: 0.25, alpha: 0.9),
                        .paragraphStyle: paragraph,
                    ]
                    (code as NSString).draw(in: NSRect(x: 50, y: 160, width: 924, height: 240), withAttributes: codeAttrs)
                    (name as NSString).draw(in: NSRect(x: 50, y: 400, width: 924, height: 110), withAttributes: nameAttrs)
                    (count as NSString).draw(in: NSRect(x: 50, y: 510, width: 924, height: 80), withAttributes: countAttrs)
                }
                return true
            }
        }
    }
}
