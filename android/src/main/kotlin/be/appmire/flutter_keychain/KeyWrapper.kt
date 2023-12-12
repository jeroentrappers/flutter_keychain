package be.appmire.flutter_keychain

import java.security.*
import java.util.*

interface KeyWrapper {
    @Throws(Exception::class)
    fun wrap(key: Key): ByteArray

    @Throws(Exception::class)
    fun unwrap(wrappedKey: ByteArray, algorithm: String): Key
}