package be.appmire.flutter_keychain

interface StringEncryptor {
    @Throws(Exception::class)
    fun encrypt(input: String?): String?

    @Throws(Exception::class)
    fun decrypt(input: String?): String?
}