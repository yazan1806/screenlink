import SwiftUI
import UIKit
import LiveKit

struct RemoteSessionView: View {
    @Bindable var model: RemoteModel
    let fullscreen: Bool
    let onFullscreen: () -> Void
    @State private var controls = false
    @State private var keyboard = false
    @State private var fill = true
    @State private var text = ""
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack(alignment:.topTrailing) {
            Color.black
            TimelineView(.periodic(from:.now,by:0.25)) { _ in
                if let track = model.room.remoteParticipants.values.first?.videoTracks.first?.track as? VideoTrack {
                    GeometryReader { geo in
                        let d = track.dimensions
                        let ratio = CGFloat(d?.width ?? 1920) / CGFloat(max(1,d?.height ?? 1080))
                        let cropped = fullscreen && fill
                        let width = cropped ? max(geo.size.width,geo.size.height * ratio) : min(geo.size.width,geo.size.height * ratio)
                        let height = width / ratio
                        ZStack {
                            SwiftUIVideoView(track,layoutMode:cropped ? .fill : .fit,mirrorMode:.off)
                                .frame(width:geo.size.width,height:geo.size.height)
                                .allowsHitTesting(false)
                            Image(systemName:"cursorarrow")
                                .font(.system(size:27,weight:.bold))
                                .foregroundStyle(.white).shadow(color:.black,radius:2)
                                .position(x:(geo.size.width-width)/2 + model.pointer.x*width + 8,
                                          y:(geo.size.height-height)/2 + model.pointer.y*height + 11)
                                .allowsHitTesting(false)
                            MouseSurface(onMove:{model.moveMouse($0,in:geo.size)},onClick:{model.clickMouse($0)},onDrag:{model.dragMouse($0)},onScroll:{model.send(["type":"scroll","delta":Int($0)])})
                        }.clipped()
                    }
                } else {
                    ProgressView("Waiting for PC screen…").tint(.white).foregroundStyle(.white)
                }
            }
            VStack(alignment:.trailing,spacing:10) {
                HStack(spacing:12) {
                    if !fullscreen {Text("Touchpad mouse").font(.footnote)}
                    if fullscreen {
                        Button {fill.toggle()} label:{Image(systemName:fill ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")}
                            .accessibilityLabel(fill ? "Fit entire desktop" : "Fill phone screen")
                    }
                    Button {keyboard.toggle();controls = false} label:{Image(systemName:"keyboard")}.accessibilityLabel("Keyboard")
                    Button {controls.toggle()} label:{Image(systemName:controls ? "xmark" : "computermouse")}.accessibilityLabel("Mouse controls")
                    Button(action:onFullscreen){Image(systemName:fullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")}.accessibilityLabel(fullscreen ? "Exit fullscreen" : "Fullscreen")
                }
                .padding(12).background(.ultraThinMaterial,in:Capsule())
                if controls {
                    VStack(alignment:.trailing,spacing:12) {
                        Text("Swipe to move · tap to click\nTwo fingers to scroll · hold and move to drag").font(.caption)
                        HStack {
                            Button("Left click"){model.clickMouse()}
                            Button("Right click"){model.clickMouse("rightClick")}
                            Button("Double click"){model.clickMouse("doubleClick")}
                        }
                        HStack {
                            Button("Scroll ↑"){model.send(["type":"scroll","delta":360])}
                            Button("Scroll ↓"){model.send(["type":"scroll","delta":-360])}
                            Button("Disconnect",role:.destructive){Task{await model.stop()}}
                        }
                    }.font(.caption).padding(14).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:16))
                }
                Spacer()
            }
            .padding(.top,fullscreen ? 12 : 8).padding(.trailing,fullscreen ? 54 : 10)
        }
        .foregroundStyle(.white)
        .sheet(isPresented:$keyboard){
            VStack(spacing:16) {
                Text("Type on your PC").font(.headline)
                TextField("Text to send",text:$text).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                Button("Send text"){model.send(["type":"text","text":String(text.prefix(1024))]);text = ""}.buttonStyle(.borderedProminent)
                HStack{ForEach(["Enter","Backspace","Tab","Escape"],id:\.self){key in Button(key){model.send(["type":"key","key":key])}}}
                Button("Done"){keyboard = false}
            }.padding().presentationDetents([.medium])
        }
        .onChange(of:phase){_,value in if value != .active {model.releaseMouse()}}
        .onDisappear{model.releaseMouse()}
    }
}

// A native touch surface preserves familiar mouse gestures without reserving
// screen space for a separate touchpad. Only gestures produce PC input.
struct MouseSurface: UIViewRepresentable {
    let onMove: (CGSize) -> Void
    let onClick: (String) -> Void
    let onDrag: (Bool) -> Void
    let onScroll: (Double) -> Void
    func makeCoordinator() -> Coordinator {Coordinator(self)}
    func makeUIView(context:Context) -> UIView {
        let v = UIView();v.backgroundColor = .clear
        v.isAccessibilityElement = true;v.accessibilityLabel = "Remote mouse touchpad"
        v.accessibilityHint = "Swipe to move, tap to click, two fingers to scroll, hold then swipe to drag."
        let pan = UIPanGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches = 2;pan.delegate = context.coordinator;v.addGestureRecognizer(pan)
        let single = UITapGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.single(_:)))
        let double = UITapGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.double(_:)))
        double.numberOfTapsRequired = 2;single.require(toFail:double)
        let right = UITapGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.right(_:)))
        right.numberOfTouchesRequired = 2
        let hold = UILongPressGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.hold(_:)))
        hold.minimumPressDuration = 0.4;hold.delegate = context.coordinator
        single.require(toFail:hold)
        for g in [single,double,right,hold] {v.addGestureRecognizer(g)}
        return v
    }
    func updateUIView(_ v:UIView,context:Context){context.coordinator.parent = self}
    @MainActor final class Coordinator: NSObject,UIGestureRecognizerDelegate {
        var parent: MouseSurface
        init(_ parent:MouseSurface){self.parent = parent}
        @objc func pan(_ g:UIPanGestureRecognizer){
            let delta = g.translation(in:g.view);g.setTranslation(.zero,in:g.view)
            if g.numberOfTouches >= 2 {parent.onScroll(Double(-delta.y * 12))}
            else {parent.onMove(CGSize(width:delta.x,height:delta.y))}
        }
        @objc func single(_ g:UITapGestureRecognizer){parent.onClick("click")}
        @objc func double(_ g:UITapGestureRecognizer){parent.onClick("doubleClick")}
        @objc func right(_ g:UITapGestureRecognizer){parent.onClick("rightClick")}
        @objc func hold(_ g:UILongPressGestureRecognizer){
            if g.state == .began {parent.onDrag(true)}
            if g.state == .ended || g.state == .cancelled || g.state == .failed {parent.onDrag(false)}
        }
        func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith other:UIGestureRecognizer)->Bool {
            (gestureRecognizer is UIPanGestureRecognizer && other is UILongPressGestureRecognizer) ||
            (gestureRecognizer is UILongPressGestureRecognizer && other is UIPanGestureRecognizer)
        }
    }
}
