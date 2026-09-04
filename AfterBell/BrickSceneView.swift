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
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.isPlaying = true
        view.rendersContinuously = true
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
        var restEuler = SCNVector3(-0.42, 0.55, 0.06)
        var lastKey = ""

        func build(in view: SCNView, compact: Bool) {
            let scene = SCNScene()
            view.scene = scene

            let camera = SCNCamera()
            camera.fieldOfView = compact ? 28 : 32
            camera.zNear = 0.05
            camera.zFar = 40
            camera.wantsHDR = true
            camera.exposureOffset = -0.15
            let camNode = SCNNode()
            camNode.camera = camera
            if compact {
                camNode.position = SCNVector3(1.05, 0.72, 2.35)
            } else {
                camNode.position = SCNVector3(1.35, 0.95, 2.55)
            }
            camNode.look(at: SCNVector3(0, 0.02, 0))
            scene.rootNode.addChildNode(camNode)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 160
            ambient.light?.color = NSColor(calibratedWhite: 0.78, alpha: 1)
            scene.rootNode.addChildNode(ambient)

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 980
            key.light?.color = NSColor(calibratedRed: 1, green: 0.98, blue: 0.94, alpha: 1)
            key.position = SCNVector3(2.2, 2.4, 1.6)
            key.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(key)

            let fill = SCNNode()
            fill.light = SCNLight()
            fill.light?.type = .omni
            fill.light?.intensity = 320
            fill.light?.color = NSColor(calibratedRed: 0.82, green: 0.88, blue: 1, alpha: 1)
            fill.position = SCNVector3(-1.6, 0.8, 2.2)
            scene.rootNode.addChildNode(fill)

            let rim = SCNNode()
            rim.light = SCNLight()
            rim.light?.type = .omni
            rim.light?.intensity = 240
            rim.position = SCNVector3(0.2, 1.8, -1.4)
            scene.rootNode.addChildNode(rim)

            let box = SCNBox(
                width: compact ? 1.35 : 1.62,
                height: compact ? 0.92 : 1.12,
                length: compact ? 0.72 : 0.88,
                chamferRadius: compact ? 0.07 : 0.08
            )
            box.chamferSegmentCount = 6
            let brickNode = SCNNode(geometry: box)
            brickNode.eulerAngles = restEuler
            let wrapper = SCNNode()
            wrapper.addChildNode(brickNode)
            scene.rootNode.addChildNode(wrapper)
            brick = brickNode

            let bobUp = SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: 1.8)
            bobUp.timingMode = .easeInEaseOut
            wrapper.runAction(.repeatForever(.sequence([bobUp, bobUp.reversed()])))

            let shadow = SCNPlane(width: compact ? 1.5 : 1.85, height: compact ? 1.05 : 1.3)
            let sm = SCNMaterial()
            sm.diffuse.contents = NSColor.black
            sm.transparency = 0.22
            sm.lightingModel = .constant
            sm.writesToDepthBuffer = false
            shadow.materials = [sm]
            let shadowNode = SCNNode(geometry: shadow)
            shadowNode.eulerAngles.x = -.pi / 2
            shadowNode.position = SCNVector3(0.08, compact ? -0.52 : -0.64, 0.06)
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
                let painted = rgb
                let front = Self.faceMaterial(color: painted, code: code, name: name, count: count, compact: compact)
                let side = Self.bodyMaterial(color: painted, highlight: false)
                let top = Self.bodyMaterial(color: painted, highlight: true)
                box.materials = [front, side, side, side, top, side]
            }

            let lift: CGFloat = hovered ? (compact ? 0.12 : 0.18) : (selected ? 0.08 : 0)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.18
            brick.position.y = lift
            brick.eulerAngles = SCNVector3(
                restEuler.x + (hovered ? 0.08 : 0),
                restEuler.y - (hovered ? 0.08 : 0),
                restEuler.z
            )
            SCNTransaction.commit()
        }

        static func bodyMaterial(color: NSColor, highlight: Bool) -> SCNMaterial {
            let mat = SCNMaterial()
            let body = highlight ? color.blended(withFraction: 0.14, of: .white) ?? color : color
            mat.diffuse.contents = body
            mat.roughness.contents = 0.22
            mat.metalness.contents = 0.12
            mat.specular.contents = NSColor.white
            mat.lightingModel = .physicallyBased
            return mat
        }

        static func faceMaterial(color: NSColor, code: String, name: String, count: String, compact: Bool) -> SCNMaterial {
            let mat = bodyMaterial(color: color, highlight: false)
            mat.diffuse.contents = paintFace(color: color, code: code, name: name, count: count, compact: compact)
            mat.lightingModel = .physicallyBased
            mat.roughness.contents = 0.18
            return mat
        }

        static func paintFace(color: NSColor, code: String, name: String, count: String, compact: Bool) -> NSImage {
            let width = 1024
            let height = 768
            guard let rep = NSBitmapImageRep(
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
            ) else {
                return NSImage(size: NSSize(width: width, height: height))
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            color.setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
            NSGradient(colors: [
                color.blended(withFraction: 0.22, of: .white) ?? color,
                color,
                color.blended(withFraction: 0.08, of: .black) ?? color,
            ])?.draw(
                in: NSRect(x: 0, y: 0, width: width, height: height),
                angle: 118
            )
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let ink = NSColor(calibratedWhite: 0.12, alpha: 0.9)
            let mute = NSColor(calibratedWhite: 0.16, alpha: 0.72)
            if compact {
                (code as NSString).draw(
                    in: NSRect(x: 40, y: 170, width: 944, height: 430),
                    withAttributes: [
                        .font: NSFont.systemFont(ofSize: 300, weight: .bold),
                        .foregroundColor: ink,
                        .paragraphStyle: paragraph,
                    ]
                )
            } else {
                (code as NSString).draw(
                    in: NSRect(x: 48, y: 150, width: 928, height: 250),
                    withAttributes: [
                        .font: NSFont.systemFont(ofSize: 210, weight: .bold),
                        .foregroundColor: ink,
                        .paragraphStyle: paragraph,
                    ]
                )
                (name as NSString).draw(
                    in: NSRect(x: 48, y: 400, width: 928, height: 110),
                    withAttributes: [
                        .font: NSFont.systemFont(ofSize: 78, weight: .semibold),
                        .foregroundColor: ink,
                        .paragraphStyle: paragraph,
                    ]
                )
                (count as NSString).draw(
                    in: NSRect(x: 48, y: 512, width: 928, height: 80),
                    withAttributes: [
                        .font: NSFont.systemFont(ofSize: 52, weight: .medium),
                        .foregroundColor: mute,
                        .paragraphStyle: paragraph,
                    ]
                )
            }
            NSGraphicsContext.restoreGraphicsState()
            let image = NSImage(size: NSSize(width: width, height: height))
            image.addRepresentation(rep)
            return image
        }
    }
}
