import Foundation

protocol Drawable {
    func draw(in rect: CGRect)
    var name: String { get }
}

final class Canvas: Drawable {
    private var items: [String] = []

    init(size: Int) {
        self.items = []
    }

    convenience init?() { self.init(size: 0) }

    deinit { print("bye") }

    func draw(in rect: CGRect) {
        items.forEach { print($0) }
    }

    static func == (lhs: Canvas, rhs: Canvas) -> Bool { true }

    subscript(index: Int) -> String { items[index] }

    @objc private func tapped(_ sender: Any) {}
}

extension Canvas {
    func clear() { items.removeAll() }
}
