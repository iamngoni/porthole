import MetalKit
import PortholeProtocol
import PortholeSession
import SwiftUI
import UIKit

/// The streamed window, used like an iPad app: there is no pointer to push around.
///
/// Touch: tap anywhere to click there, drag to scroll (with momentum), touch and hold to right-click,
/// touch and hold then move to drag, two-finger tap to right-click. Pinch to zoom in and drag with
/// two fingers to look around; zooming stays on this device.
/// Trackpad or mouse: move, click, right-click, drag and two-finger scroll, as on a Mac.
/// Keyboard: hardware keys go over as physical keys, so the Mac's own layout applies.
final class StreamSurfaceView: UIView, UIGestureRecognizerDelegate {
    var send: ((ClientMessage) -> Void)?
    /// The stream the input is aimed at; nil means no video yet, so input is dropped.
    var gen: UInt32? {
        didSet {
            guard gen != oldValue else { return }
            endGestures()
            send?(.releaseAll)
            // A different window starts unzoomed.
            setViewport(ZoomViewport(), animated: false)
        }
    }
    /// The video's pixel size, to find where it sits in this view.
    var videoSize: CGSize = .zero {
        didSet {
            guard videoSize != oldValue else { return }
            setViewport(viewport.settled(content: videoSize, in: bounds.size), animated: false)
        }
    }
    var canControl = true
    var onKeyboardHidden: (() -> Void)?
    var onZoomChange: ((CGFloat) -> Void)?
    /// Any touch on the window, so the controls can step out of the way.
    var onInteraction: (() -> Void)?

    private let videoView = RTCMTLVideoView(frame: .zero)
    private let feedback = TouchFeedbackView()
    private let keyboard = KeyboardProxy()
    private weak var track: RTCVideoTrack?

    /// Where the gestures have put the zoom, and what's drawn (the same, give or take rubber-banding).
    private var viewport = ZoomViewport()
    private var shown = ZoomViewport()
    private var reportedScale: CGFloat = 1

    private var scrollPoint: NormalizedPoint?
    private var momentum: MomentumScroller?
    private var momentumLink: CADisplayLink?
    private var hold: (start: NormalizedPoint, startLocation: CGPoint, dragging: Bool)?
    private var pointerButton: MouseButton?

    private var scrollPan: UIPanGestureRecognizer!
    private var holdPress: UILongPressGestureRecognizer!
    private var pinch: UIPinchGestureRecognizer!
    private var lookPan: UIPanGestureRecognizer!

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .black
        clipsToBounds = true

        videoView.videoContentMode = .scaleAspectFit
        videoView.backgroundColor = .black
        videoView.isUserInteractionEnabled = false
        addSubview(videoView)
        feedback.isUserInteractionEnabled = false
        addSubview(feedback)

        let direct = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.allowedTouchTypes = direct
        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(twoFingerTapped(_:)))
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.allowedTouchTypes = direct
        tap.require(toFail: twoFingerTap)

        holdPress = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
        holdPress.minimumPressDuration = 0.45
        holdPress.allowedTouchTypes = direct

        scrollPan = UIPanGestureRecognizer(target: self, action: #selector(scrolled(_:)))
        scrollPan.maximumNumberOfTouches = 1
        scrollPan.allowedTouchTypes = direct
        scrollPan.delegate = self

        // Two-finger scrolling on a trackpad or mouse wheel: scroll events only, no touches.
        let trackpad = UIPanGestureRecognizer(target: self, action: #selector(scrolled(_:)))
        trackpad.allowedScrollTypesMask = .all
        trackpad.allowedTouchTypes = []

        pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:)))
        pinch.allowedTouchTypes = direct
        pinch.delegate = self
        lookPan = UIPanGestureRecognizer(target: self, action: #selector(looked(_:)))
        lookPan.minimumNumberOfTouches = 2
        lookPan.maximumNumberOfTouches = 2
        lookPan.allowedTouchTypes = direct
        lookPan.delegate = self

        let hover = UIHoverGestureRecognizer(target: self, action: #selector(hovered(_:)))

        [tap, twoFingerTap, holdPress, scrollPan, trackpad, pinch, lookPan, hover].forEach(addGestureRecognizer)

        keyboard.onText = { [weak self] in self?.typeFromKeyboard($0) }
        keyboard.onDeleteBackward = { [weak self] in self?.pressKey(HIDKeyMap.Usage.deleteBackward, modifiers: self?.keyboard.takeStickyModifiers() ?? []) }
        keyboard.onKey = { [weak self] usage in self?.pressKey(usage, modifiers: self?.keyboard.takeStickyModifiers() ?? []) }
        keyboard.onHardwarePresses = { [weak self] presses, isDown in self?.handle(presses, isDown: isDown) ?? false }
        keyboard.onResign = { [weak self] in
            guard let self else { return }
            self.onKeyboardHidden?()
            // Take hardware keys again once the on-screen keyboard is gone.
            if self.window != nil { self.becomeFirstResponder() }
        }
        addSubview(keyboard)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func setTrack(_ newTrack: RTCVideoTrack?) {
        guard newTrack !== track else { return }
        track?.remove(videoView)
        newTrack?.add(videoView)
        track = newTrack
    }

    func detach() {
        track?.remove(videoView)
        track = nil
    }

    // MARK: Layout and zoom

    private var laidOutSize: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        feedback.frame = bounds
        // Only a new size (rotation, the keyboard) moves the video; a pinch in progress keeps its place.
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        viewport = viewport.settled(content: videoSize, in: bounds.size)
        shown = viewport
        placeVideo()
    }

    /// The video keeps its fitted size and is zoomed with a transform, so pinching never resizes its drawable.
    private func placeVideo() {
        let fitted = videoSize == .zero ? bounds : AspectFit.rect(content: videoSize, in: bounds.size)
        videoView.transform = .identity
        videoView.bounds = CGRect(origin: .zero, size: fitted.size)
        videoView.center = CGPoint(x: fitted.midX, y: fitted.midY)
        videoView.transform = CGAffineTransform(translationX: shown.offset.x, y: shown.offset.y).scaledBy(x: shown.scale, y: shown.scale)
    }

    private func setViewport(_ new: ZoomViewport, animated: Bool) {
        viewport = new
        shown = new
        if animated {
            UIView.animate(withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.placeVideo()
            }
        } else {
            placeVideo()
        }
        reportZoom()
    }

    func resetZoom() {
        setViewport(ZoomViewport(), animated: true)
    }

    private func reportZoom() {
        let scale = (viewport.scale * 10).rounded() / 10
        guard scale != reportedScale else { return }
        reportedScale = scale
        onZoomChange?(scale)
    }

    // MARK: Keyboard focus

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window {
            becomeFirstResponder()
            // WebRTC's Metal view draws on its MTKView's clock, which defaults to 60 a second even on ProMotion.
            for case let metal as MTKView in videoView.subviews {
                metal.preferredFramesPerSecond = window.screen.maximumFramesPerSecond
            }
        } else {
            endGestures()
            send?(.releaseAll)
        }
    }

    func setKeyboardVisible(_ visible: Bool) {
        if visible, !keyboard.isFirstResponder {
            keyboard.becomeFirstResponder()
        } else if !visible, keyboard.isFirstResponder {
            _ = keyboard.resignFirstResponder()
        }
    }

    // MARK: Mapping

    private func normalized(_ location: CGPoint) -> NormalizedPoint? {
        shown.normalized(location, content: videoSize, in: bounds.size)
    }

    /// Like `normalized`, but clamps points off the video to its nearest edge, for drags that wander off.
    private func clampedNormalized(_ location: CGPoint) -> NormalizedPoint? {
        shown.spot(at: location, content: videoSize, in: bounds.size)?.clamped
    }

    /// The video as drawn, zoom included; scrolling divides by it so content moves with the finger.
    private var videoFrame: CGRect { shown.frame(content: videoSize, in: bounds.size) }

    private func click(_ button: MouseButton, at point: NormalizedPoint) {
        guard let gen else { return }
        send?(.button(ButtonEvent(gen: gen, point: point, button: button, isDown: true)))
        send?(.button(ButtonEvent(gen: gen, point: point, button: button, isDown: false)))
    }

    // MARK: Touch gestures

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        guard gesture.state == .ended else { return }
        onInteraction?()
        guard let point = normalized(location) else { return }
        stopMomentum()
        click(.left, at: point)
        if canControl { feedback.tap(at: location) }
    }

    @objc private func twoFingerTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        guard gesture.state == .ended else { return }
        onInteraction?()
        guard let point = normalized(location) else { return }
        click(.right, at: point)
        if canControl { feedback.secondaryTap(at: location) }
    }

    @objc private func held(_ gesture: UILongPressGestureRecognizer) {
        guard let gen else { return }
        let location = gesture.location(in: self)
        switch gesture.state {
        case .began:
            onInteraction?()
            guard let point = normalized(location) else { return }
            stopMomentum()
            hold = (point, location, false)
            if canControl {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                feedback.beginHold(at: location)
            }
        case .changed:
            guard var current = hold, let point = clampedNormalized(location) else { return }
            if !current.dragging, hypot(location.x - current.startLocation.x, location.y - current.startLocation.y) > 6 {
                current.dragging = true
                hold = current
                send?(.button(ButtonEvent(gen: gen, point: current.start, button: .left, isDown: true)))
                if canControl { feedback.beginDrag() }
            }
            if current.dragging {
                send?(.pointer(PointerEvent(gen: gen, point: point)))
                feedback.moveHold(to: location)
            }
        case .ended:
            guard let current = hold else { return }
            hold = nil
            feedback.endHold()
            if current.dragging {
                send?(.button(ButtonEvent(gen: gen, point: clampedNormalized(location) ?? current.start, button: .left, isDown: false)))
            } else {
                click(.right, at: current.start)
                if canControl { feedback.secondaryTap(at: current.startLocation) }
            }
        case .cancelled, .failed:
            if let current = hold, current.dragging {
                send?(.button(ButtonEvent(gen: gen, point: current.start, button: .left, isDown: false)))
            }
            hold = nil
            feedback.endHold()
        default:
            break
        }
    }

    @objc private func scrolled(_ gesture: UIPanGestureRecognizer) {
        guard let gen else { return }
        let frame = videoFrame
        guard frame.width > 0, frame.height > 0 else { return }
        switch gesture.state {
        case .began:
            onInteraction?()
            stopMomentum()
            // Scroll what's under the finger (or pointer) where the gesture started.
            let start = gesture.location(in: self)
            let translation = gesture.translation(in: self)
            guard let point = clampedNormalized(CGPoint(x: start.x - translation.x, y: start.y - translation.y)) else { return }
            scrollPoint = point
            sendScroll(gen: gen, point: point, delta: translation, frame: frame, phase: .began)
            gesture.setTranslation(.zero, in: self)
        case .changed:
            guard let point = scrollPoint else { return }
            sendScroll(gen: gen, point: point, delta: gesture.translation(in: self), frame: frame, phase: .changed)
            gesture.setTranslation(.zero, in: self)
        case .ended:
            guard let point = scrollPoint else { return }
            sendScroll(gen: gen, point: point, delta: gesture.translation(in: self), frame: frame, phase: .ended)
            startMomentum(velocity: gesture.velocity(in: self), point: point)
        case .cancelled, .failed:
            if let point = scrollPoint {
                sendScroll(gen: gen, point: point, delta: .zero, frame: frame, phase: .cancelled)
            }
            scrollPoint = nil
        default:
            break
        }
    }

    private func sendScroll(gen: UInt32, point: NormalizedPoint, delta: CGPoint, frame: CGRect,
                            phase: PortholeProtocol.ScrollPhase?, momentum: PortholeProtocol.MomentumPhase = .none) {
        send?(.scroll(ScrollEvent(gen: gen, point: point, dx: delta.x / frame.width, dy: delta.y / frame.height,
                                  phase: phase, momentum: momentum)))
    }

    // MARK: Zoom gestures

    @objc private func pinched(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            beginLooking()
        case .changed:
            viewport = viewport.zoomed(by: gesture.scale, around: gesture.location(in: self), content: videoSize, in: bounds.size)
            gesture.scale = 1
            showResisted()
        case .ended, .cancelled, .failed:
            settleIfIdle()
        default:
            break
        }
    }

    @objc private func looked(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            beginLooking()
            gesture.setTranslation(.zero, in: self)
        case .changed:
            viewport = viewport.panned(by: gesture.translation(in: self))
            gesture.setTranslation(.zero, in: self)
            showResisted()
        case .ended, .cancelled, .failed:
            settleIfIdle()
        default:
            break
        }
    }

    /// Two fingers on the glass mean looking around, not using the window: drop any one-finger gesture.
    private func beginLooking() {
        onInteraction?()
        stopMomentum()
        let oneFinger: [UIGestureRecognizer] = [scrollPan, holdPress]
        for recognizer in oneFinger where recognizer.state == .began || recognizer.state == .changed {
            recognizer.isEnabled = false
            recognizer.isEnabled = true
        }
    }

    private func showResisted() {
        shown = viewport.resisted(content: videoSize, in: bounds.size)
        placeVideo()
    }

    private func settleIfIdle() {
        let active: Set<UIGestureRecognizer.State> = [.began, .changed]
        guard !active.contains(pinch.state), !active.contains(lookPan.state) else { return }
        let settled = viewport.settled(content: videoSize, in: bounds.size)
        setViewport(settled.isZoomed ? settled : ZoomViewport(), animated: true)
    }

    func gestureRecognizer(_ gesture: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        let looking: [UIGestureRecognizer] = [pinch, lookPan]
        if looking.contains(gesture), looking.contains(other) { return true }
        // A second finger can land just after the first started scrolling; let the pinch take over.
        return (looking.contains(gesture) && other === scrollPan) || (gesture === scrollPan && looking.contains(other))
    }

    // MARK: Momentum

    private func startMomentum(velocity: CGPoint, point: NormalizedPoint) {
        var scroller = MomentumScroller(velocity: velocity)
        guard !scroller.isFinished, let gen else {
            scrollPoint = nil
            return
        }
        if let step = scroller.next() {
            sendScroll(gen: gen, point: point, delta: CGPoint(x: step.dx, y: step.dy), frame: videoFrame, phase: nil, momentum: .began)
        }
        momentum = scroller
        let link = CADisplayLink(target: self, selector: #selector(momentumFrame))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        momentumLink = link
    }

    @objc private func momentumFrame() {
        guard var scroller = momentum, let gen, let point = scrollPoint else {
            stopMomentum()
            return
        }
        if let step = scroller.next() {
            momentum = scroller
            sendScroll(gen: gen, point: point, delta: CGPoint(x: step.dx, y: step.dy), frame: videoFrame, phase: nil, momentum: .changed)
        } else {
            stopMomentum()
        }
    }

    /// Ends a glide in progress, telling the Mac it ended (a new touch stops scrolling, as on a trackpad).
    private func stopMomentum() {
        momentumLink?.invalidate()
        momentumLink = nil
        if momentum != nil, let gen, let point = scrollPoint {
            sendScroll(gen: gen, point: point, delta: .zero, frame: videoFrame, phase: nil, momentum: .ended)
        }
        momentum = nil
        scrollPoint = nil
    }

    /// Lets go of everything in progress, for a new window or when the view goes away.
    private func endGestures() {
        stopMomentum()
        let oneFinger: [UIGestureRecognizer] = [scrollPan, holdPress]
        for recognizer in oneFinger {
            recognizer.isEnabled = false
            recognizer.isEnabled = true
        }
        hold = nil
        pointerButton = nil
        feedback.endHold()
    }

    // MARK: Pointer

    @objc private func hovered(_ gesture: UIHoverGestureRecognizer) {
        guard let gen, gesture.state == .began || gesture.state == .changed,
              let point = normalized(gesture.location(in: self)) else { return }
        send?(.pointer(PointerEvent(gen: gen, point: point)))
    }

    // Pointer clicks arrive as indirect touches; the gesture recognizers above only take direct ones.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first(where: { $0.type == .indirectPointer }), let gen, pointerButton == nil,
           let point = normalized(touch.location(in: self)) {
            onInteraction?()
            stopMomentum()
            let button: MouseButton = event?.buttonMask.contains(.secondary) == true ? .right : .left
            pointerButton = button
            send?(.button(ButtonEvent(gen: gen, point: point, button: button, isDown: true)))
        }
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first(where: { $0.type == .indirectPointer }), let gen, pointerButton != nil,
           let point = clampedNormalized(touch.location(in: self)) {
            send?(.pointer(PointerEvent(gen: gen, point: point)))
        }
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endPointerPress(touches)
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endPointerPress(touches)
        super.touchesCancelled(touches, with: event)
    }

    private func endPointerPress(_ touches: Set<UITouch>) {
        guard let touch = touches.first(where: { $0.type == .indirectPointer }), let button = pointerButton else { return }
        pointerButton = nil
        guard let gen, let point = clampedNormalized(touch.location(in: self)) else { return }
        send?(.button(ButtonEvent(gen: gen, point: point, button: button, isDown: false)))
    }

    // MARK: Hardware keyboard

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !handle(presses, isDown: true) { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !handle(presses, isDown: false) { super.pressesEnded(presses, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !handle(presses, isDown: false) { super.pressesCancelled(presses, with: event) }
    }

    /// Sends key presses to the Mac. Returns false when there is nothing to send them to,
    /// so the system can use them (for example, to leave the stream with ⌘[).
    private func handle(_ presses: Set<UIPress>, isDown: Bool) -> Bool {
        guard let gen else { return false }
        var handled = false
        for press in presses {
            guard let key = press.key else { continue }
            let usage = UInt16(truncatingIfNeeded: key.keyCode.rawValue)
            // Caps Lock itself stays on the iPad; its effect travels as Shift on letters.
            guard usage != 0x39 else { continue }
            var modifiers = Self.modifiers(key.modifierFlags)
            if key.modifierFlags.contains(.alphaShift), (0x04...0x1D).contains(usage) { modifiers.insert(.shift) }
            send?(.key(KeyEvent(gen: gen, usage: usage, isDown: isDown, modifiers: modifiers)))
            handled = true
        }
        return handled
    }

    private static func modifiers(_ flags: UIKeyModifierFlags) -> Modifiers {
        var modifiers: Modifiers = []
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.alternate) { modifiers.insert(.option) }
        if flags.contains(.command) { modifiers.insert(.command) }
        return modifiers
    }

    // MARK: On-screen keyboard

    private func pressKey(_ usage: UInt16, modifiers: Modifiers) {
        guard let gen else { return }
        send?(.key(KeyEvent(gen: gen, usage: usage, isDown: true, modifiers: modifiers)))
        send?(.key(KeyEvent(gen: gen, usage: usage, isDown: false, modifiers: modifiers)))
    }

    private func typeFromKeyboard(_ text: String) {
        guard let gen else { return }
        let sticky = keyboard.takeStickyModifiers()
        // With ⌘, ⌥ or ⌃ held on the bar, one typed character becomes a shortcut: ⌘ then "c" is Copy. A
        // paste or dictation goes in as text, or "Quarterly" would be ⌘Q.
        guard !sticky.subtracting(.shift).isEmpty, text.count == 1, let character = text.first,
              let key = HIDKeyMap.usage(forCharacter: character) else {
            send?(.text(TextEvent(gen: gen, text: text)))
            return
        }
        pressKey(key.usage, modifiers: key.shift ? sticky.union(.shift) : sticky)
    }
}

// MARK: - Touch feedback

/// Shows where a touch landed, since there's no pointer on the video: a ripple for a tap,
/// a double ring for a right-click, and a lit dot under the finger while dragging.
private final class TouchFeedbackView: UIView {
    private static let primary = UIColor.white
    private static let secondary = UIColor(Theme.accent)
    private var holdLayer: CAShapeLayer?

    func tap(at point: CGPoint) {
        ripple(at: point, color: Self.primary, radius: 26, delay: 0)
    }

    func secondaryTap(at point: CGPoint) {
        ripple(at: point, color: Self.secondary, radius: 24, delay: 0)
        ripple(at: point, color: Self.secondary, radius: 24, delay: 0.09)
    }

    func beginHold(at point: CGPoint) {
        endHold()
        let layer = circle(radius: 30, color: Self.secondary)
        layer.position = point
        layer.fillColor = Self.secondary.withAlphaComponent(0.18).cgColor
        self.layer.addSublayer(layer)
        holdLayer = layer
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.4
        grow.toValue = 1
        grow.duration = 0.22
        grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(grow, forKey: "grow")
    }

    /// The press turned into a drag: the ring tightens into a dot that follows the finger.
    func beginDrag() {
        guard let layer = holdLayer else { return }
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.18)
        layer.transform = CATransform3DMakeScale(0.55, 0.55, 1)
        layer.fillColor = Self.primary.withAlphaComponent(0.45).cgColor
        layer.strokeColor = Self.primary.cgColor
        CATransaction.commit()
    }

    func moveHold(to point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        holdLayer?.position = point
        CATransaction.commit()
    }

    func endHold() {
        guard let layer = holdLayer else { return }
        holdLayer = nil
        CATransaction.begin()
        CATransaction.setCompletionBlock { layer.removeFromSuperlayer() }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.2
        layer.opacity = 0
        layer.add(fade, forKey: "fade")
        CATransaction.commit()
    }

    private func ripple(at point: CGPoint, color: UIColor, radius: CGFloat, delay: CFTimeInterval) {
        let layer = circle(radius: radius, color: color)
        layer.position = point
        layer.opacity = 0
        self.layer.addSublayer(layer)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.35
        scale.toValue = 1.25
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0.95, 0.7, 0]
        fade.keyTimes = [0, 0.4, 1]
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 0.48
        group.beginTime = CACurrentMediaTime() + delay
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        CATransaction.begin()
        CATransaction.setCompletionBlock { layer.removeFromSuperlayer() }
        layer.add(group, forKey: "ripple")
        CATransaction.commit()
    }

    private func circle(radius: CGFloat, color: UIColor) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.bounds = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
        layer.path = UIBezierPath(ovalIn: layer.bounds).cgPath
        layer.fillColor = color.withAlphaComponent(0.22).cgColor
        layer.strokeColor = color.withAlphaComponent(0.95).cgColor
        layer.lineWidth = 2
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = 0.8
        layer.shadowRadius = 8
        layer.shadowOffset = .zero
        return layer
    }
}

// MARK: - On-screen keyboard

/// An invisible text field for the on-screen keyboard, with Esc, Tab, arrows and sticky modifier keys above it.
private final class KeyboardProxy: UIView, UIKeyInput {
    var onText: ((String) -> Void)?
    var onDeleteBackward: (() -> Void)?
    var onKey: ((UInt16) -> Void)?
    var onHardwarePresses: ((Set<UIPress>, Bool) -> Bool)?
    var onResign: (() -> Void)?

    // Text traits: no autocorrect or smart punctuation; the Mac app does its own.
    var autocorrectionType: UITextAutocorrectionType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var spellCheckingType: UITextSpellCheckingType = .no
    var smartQuotesType: UITextSmartQuotesType = .no
    var smartDashesType: UITextSmartDashesType = .no
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .no
    var keyboardType: UIKeyboardType = .asciiCapable
    var keyboardAppearance: UIKeyboardAppearance = .dark
    var inlinePredictionType: UITextInlinePredictionType = .no

    private var modifierButtons: [(Modifiers, UIButton)] = []
    private lazy var accessory = makeAccessory()

    var hasText: Bool { true }
    override var canBecomeFirstResponder: Bool { true }
    override var inputAccessoryView: UIView? { accessory }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        // Hide the iPad's shortcut bar (undo, redo, paste); those would act on this invisible field.
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func insertText(_ text: String) { onText?(text) }
    func deleteBackward() { onDeleteBackward?() }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            clearStickyModifiers()
            onResign?()
        }
        return resigned
    }

    // A hardware keyboard typing while this field has focus still goes over as physical keys.
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if onHardwarePresses?(presses, true) != true { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if onHardwarePresses?(presses, false) != true { super.pressesEnded(presses, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if onHardwarePresses?(presses, false) != true { super.pressesCancelled(presses, with: event) }
    }

    /// The modifiers toggled on the bar, which apply to the next key only.
    func takeStickyModifiers() -> Modifiers {
        let modifiers = modifierButtons.reduce(into: Modifiers()) { result, entry in
            if entry.1.isSelected { result.insert(entry.0) }
        }
        clearStickyModifiers()
        return modifiers
    }

    private func clearStickyModifiers() {
        for (_, button) in modifierButtons { button.isSelected = false }
    }

    private static func keyConfiguration(title: String?, image: String? = nil) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = image.flatMap { UIImage(systemName: $0) }
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = UIColor.white.withAlphaComponent(0.12)
        configuration.cornerStyle = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            let base = UIFont.systemFont(ofSize: 16, weight: .semibold)
            attributes.font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 16) } ?? base
            return attributes
        }
        return configuration
    }

    private func makeAccessory() -> UIView {
        let bar = UIInputView(frame: CGRect(x: 0, y: 0, width: 0, height: 52), inputViewStyle: .keyboard)
        bar.allowsSelfSizing = true

        func keyButton(_ title: String, label: String, usage: UInt16) -> UIButton {
            let button = UIButton(configuration: Self.keyConfiguration(title: title), primaryAction: UIAction { [weak self] _ in self?.onKey?(usage) })
            button.accessibilityLabel = label
            return button
        }

        func modifierButton(_ title: String, label: String, modifier: Modifiers) -> UIButton {
            let button = UIButton(configuration: Self.keyConfiguration(title: title))
            button.changesSelectionAsPrimaryAction = true
            button.configurationUpdateHandler = { button in
                button.configuration?.baseBackgroundColor = button.isSelected
                    ? UIColor(Theme.accent)
                    : UIColor.white.withAlphaComponent(0.12)
            }
            button.accessibilityLabel = label
            modifierButtons.append((modifier, button))
            return button
        }

        let hide = UIButton(configuration: Self.keyConfiguration(title: nil, image: "keyboard.chevron.compact.down"),
                            primaryAction: UIAction { [weak self] _ in _ = self?.resignFirstResponder() })
        hide.accessibilityLabel = "Hide Keyboard"

        let views: [UIView] = [
            keyButton("esc", label: "Escape", usage: HIDKeyMap.Usage.escape),
            keyButton("tab", label: "Tab", usage: HIDKeyMap.Usage.tab),
            modifierButton("⌘", label: "Command", modifier: .command),
            modifierButton("⌥", label: "Option", modifier: .option),
            modifierButton("⌃", label: "Control", modifier: .control),
            modifierButton("⇧", label: "Shift", modifier: .shift),
            keyButton("←", label: "Left Arrow", usage: HIDKeyMap.Usage.leftArrow),
            keyButton("↑", label: "Up Arrow", usage: HIDKeyMap.Usage.upArrow),
            keyButton("↓", label: "Down Arrow", usage: HIDKeyMap.Usage.downArrow),
            keyButton("→", label: "Right Arrow", usage: HIDKeyMap.Usage.rightArrow),
            hide,
        ]
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillProportionally

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        bar.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            scroll.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -10),
            scroll.topAnchor.constraint(equalTo: bar.topAnchor, constant: 7),
            scroll.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -7),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            stack.widthAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.widthAnchor),
        ])
        return bar
    }
}

// MARK: - SwiftUI

/// SwiftUI wrapper for `StreamSurfaceView`.
struct StreamSurface: UIViewRepresentable {
    let track: RTCVideoTrack?
    let gen: UInt32?
    let videoSize: CGSize
    let canControl: Bool
    @Binding var showsKeyboard: Bool
    /// Bumped to ask for the zoom to go back to fit.
    let zoomResetToken: Int
    let onZoomChange: (CGFloat) -> Void
    let onInteraction: () -> Void
    let send: (ClientMessage) -> Void

    final class Coordinator {
        var zoomResetToken = 0
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> StreamSurfaceView {
        let view = StreamSurfaceView(frame: .zero)
        context.coordinator.zoomResetToken = zoomResetToken
        update(view, context: context)
        return view
    }

    func updateUIView(_ view: StreamSurfaceView, context: Context) {
        update(view, context: context)
    }

    static func dismantleUIView(_ view: StreamSurfaceView, coordinator: Coordinator) {
        view.detach()
    }

    private func update(_ view: StreamSurfaceView, context: Context) {
        view.send = send
        view.onZoomChange = onZoomChange
        view.onInteraction = onInteraction
        view.canControl = canControl
        view.gen = gen
        view.videoSize = videoSize
        view.setTrack(track)
        let binding = $showsKeyboard
        view.onKeyboardHidden = { if binding.wrappedValue { binding.wrappedValue = false } }
        view.setKeyboardVisible(showsKeyboard)
        if context.coordinator.zoomResetToken != zoomResetToken {
            context.coordinator.zoomResetToken = zoomResetToken
            view.resetZoom()
        }
    }
}
