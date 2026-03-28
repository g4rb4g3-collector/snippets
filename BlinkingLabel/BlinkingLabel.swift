import UIKit

/// A UILabel subclass that stores a Double value and displays it
/// with a configurable number of decimal places. The label blinks
/// briefly whenever the value changes.
@IBDesignable
public class BlinkingLabel: UILabel {

    // MARK: - Public properties

    /// Number of decimal places shown. Updating re-formats the display.
    @IBInspectable public var precision: Int = 2 {
        didSet { updateText() }
    }

    /// The stored numeric value. `nil` means no value has been set yet
    /// (label shows empty text). The first assignment only formats the
    /// text without blinking.
    public var value: Double? {
        didSet {
            updateText()
            guard let value, let oldValue else { return }
            if value > oldValue {
                blink(color: increaseColor)
            } else if value < oldValue {
                blink(color: decreaseColor)
            }
        }
    }

    /// How long the color stays visible before fading back (seconds).
    @IBInspectable public var colorHoldDuration: TimeInterval = 2.0

    /// Duration of the fade-back animation to the original color (seconds).
    @IBInspectable public var fadeDuration: TimeInterval = 0.3

    /// Color used when the value increases. Default is green.
    @IBInspectable public var increaseColor: UIColor = .systemGreen

    /// Color used when the value decreases. Default is red.
    @IBInspectable public var decreaseColor: UIColor = .systemRed

    /// The text color to revert to after a blink. Uses a dynamic color
    /// so it adapts automatically to light/dark mode changes.
    @IBInspectable public var baseColor: UIColor = .label
    private var revertWorkItem: DispatchWorkItem?

    // MARK: - Display

    private func updateText() {
        guard let value else { text = nil; return }
        text = String(format: "%.\(precision)f", value)
    }

    /// Cancels any pending revert animation and resets visual state.
    /// Call this when the label is about to be reused for a different
    /// data item (e.g. in a table/collection view cell).
    public func reset() {
        revertWorkItem?.cancel()
        revertWorkItem = nil
        value = nil
        textColor = baseColor
        layer.removeAllAnimations()
    }

    // MARK: - Blink animation

    private func blink(color: UIColor) {
        revertWorkItem?.cancel()

        textColor = color

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            UIView.animate(withDuration: self.fadeDuration) {
                self.textColor = self.baseColor
            }
        }
        revertWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + colorHoldDuration,
                                      execute: workItem)
    }
}
