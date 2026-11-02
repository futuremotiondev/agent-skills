#include <vector>
#define MAX(a, b) ((a) > (b) ? (a) : (b))

namespace geo {

/// A shape.
class Shape {
public:
    Shape() = default;
    explicit Shape(int sides) : sides_(sides), name_{"x"} {}
    virtual ~Shape();
    virtual double area() const = 0;
    int sides() const noexcept { return sides_; }
    Shape& operator=(const Shape& other);
    static std::vector<int> ids();
private:
    int sides_;
};

Shape::~Shape() {}

Shape& Shape::operator=(const Shape& other) {
    sides_ = other.sides_;
    return *this;
}

std::vector<int> Shape::ids() {
    std::vector<int> v(3);
    for (int i = 0; i < 3; ++i) { v.push_back(i); }
    return v;
}

template <typename T>
T clamp(T v, T lo, T hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}

}  // namespace geo

static int
legacy_c_style(int x)
{
    return x;
}

int main(int argc, char** argv) {
    geo::Shape s(4);
    auto f = [](int x) { return x; };
    return 0;
}
