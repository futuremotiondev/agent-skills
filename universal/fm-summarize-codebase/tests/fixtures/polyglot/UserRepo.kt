package demo

data class User(val name: String, val age: Int)

interface Repo {
    fun find(id: Int): User?
    fun all(): List<User> = emptyList()
}

class UserRepo(private val db: Db) : Repo {
    constructor() : this(Db())

    override fun find(id: Int): User? {
        return db.get(id)
    }

    suspend fun <T> load(block: suspend () -> T): T = block()

    companion object {
        fun create(): UserRepo = UserRepo()
    }
}

fun String.shout(): String = uppercase() + "!"

private inline fun helper(x: Int) {
    val f = { y: Int -> y * 2 }
}
