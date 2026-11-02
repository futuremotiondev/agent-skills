object Main extends App {
  def greet(name: String): String = s"Hello $name"
  def size: Int = 3
  private def helper(x: Int)(implicit ctx: Ctx): Unit = {
    println(x)
  }
}

trait Shape {
  def area: Double
}

case class Circle(r: Double) extends Shape {
  def area: Double = 3.14 * r * r
}
