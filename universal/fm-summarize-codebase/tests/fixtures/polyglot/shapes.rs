use std::fmt;

/// A point.
#[derive(Debug, Clone)]
pub struct Point { x: f64, y: f64 }

pub trait Shape {
    fn area(&self) -> f64;
    fn name(&self) -> String { "shape".to_string() }
}

impl Point {
    /// Creates a point.
    pub const fn new(x: f64, y: f64) -> Self { Point { x, y } }

    pub(crate) async fn load<'a, T: Into<String>>(s: &'a str) -> Result<Self, Box<dyn std::error::Error>>
    where
        T: Clone,
    {
        let c = '}';
        Ok(Point { x: 0.0, y: 0.0 })
    }
}

impl fmt::Display for Point {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "({}, {})", self.x, self.y)
    }
}

unsafe extern "C" fn callback(x: i32) -> i32 { x }

mod tests {
    #[test]
    fn it_works() { assert_eq!(2 + 2, 4); }
}
