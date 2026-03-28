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

    /// The stored numeric value. Setting it re-formats the display and
    /// triggers a short blink animation.
    public var value: Double = 0 {
        didSet {
            updateText()
            if oldValue != value { blink() }
        }
    }

    /// Duration of a single fade-out/fade-in cycle (seconds).
    @IBInspectable public var blinkDuration: TimeInterval = 0.15

    // MARK: - Display

    private func updateText() {
        text = String(format: "%.\(precision)f", value)
    }

    // MARK: - Blink animation

    private func blink() {
        UIView.animate(withDuration: blinkDuration,
                       animations: { self.alpha = 0 },
                       completion: { _ in
            UIView.animate(withDuration: self.blinkDuration) {
                self.alpha = 1
            }
        })
    }
}
