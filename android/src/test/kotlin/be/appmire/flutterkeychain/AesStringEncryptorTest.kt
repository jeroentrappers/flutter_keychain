package be.appmire.flutterkeychain

import android.content.Context
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.security.Key
import javax.crypto.Cipher
import javax.crypto.spec.SecretKeySpec

/**
 * A KeyWrapper backed by a plain AES key, safe for JVM unit tests because it
 * does not touch the AndroidKeyStore hardware module.
 */
private class FakeKeyWrapper : KeyWrapper {
    private val wrapKey = SecretKeySpec(ByteArray(16) { (it + 1).toByte() }, "AES")

    override fun wrap(key: Key): ByteArray {
        val cipher = Cipher.getInstance("AES/ECB/PKCS5Padding")
        cipher.init(Cipher.WRAP_MODE, wrapKey)
        return cipher.wrap(key)
    }

    override fun unwrap(wrappedKey: ByteArray, algorithm: String): Key {
        val cipher = Cipher.getInstance("AES/ECB/PKCS5Padding")
        cipher.init(Cipher.UNWRAP_MODE, wrapKey)
        return cipher.unwrap(wrappedKey, algorithm, Cipher.SECRET_KEY)
    }
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class AesStringEncryptorTest {

    private lateinit var encryptor: AesStringEncryptor
    private val WRAPPED_AES_KEY_ITEM = "W0n5hlJtrAH0K8mIreDGxtG"

    @Before
    fun setUp() {
        val context = RuntimeEnvironment.getApplication()
        val prefs = context.getSharedPreferences("test_prefs", Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
        encryptor = AesStringEncryptor(prefs, FakeKeyWrapper())
    }

    // -------------------------------------------------------------------------
    // encrypt
    // -------------------------------------------------------------------------

    @Test
    fun `encrypt - null input returns null`() {
        assertNull(encryptor.encrypt(null))
    }

    @Test
    fun `encrypt - non-null input returns non-null`() {
        assertNotNull(encryptor.encrypt("hello"))
    }

    @Test
    fun `encrypt - output is Base64 encoded`() {
        val result = encryptor.encrypt("test value")!!
        // android.util.Base64.DEFAULT may include newlines; strip them before checking
        val stripped = result.replace("\n", "")
        val base64Regex = Regex("^[A-Za-z0-9+/]+=*$")
        assertTrue("Expected Base64 output but got: $stripped", stripped.matches(base64Regex))
    }

    @Test
    fun `encrypt - empty string input returns non-null`() {
        assertNotNull(encryptor.encrypt(""))
    }

    @Test
    fun `encrypt - same plaintext produces different ciphertext each call (random IV)`() {
        val c1 = encryptor.encrypt("same value")
        val c2 = encryptor.encrypt("same value")
        // Extremely unlikely to be equal due to random 16-byte IV
        assertNotEquals(
            "Two encryptions of the same value should differ because of the random IV",
            c1, c2
        )
    }

    @Test
    fun `encrypt - output length grows with input length`() {
        val shortLen = encryptor.encrypt("hi")!!.length
        val longLen  = encryptor.encrypt("A".repeat(1000))!!.length
        assertTrue(longLen > shortLen)
    }

    // -------------------------------------------------------------------------
    // decrypt
    // -------------------------------------------------------------------------

    @Test
    fun `decrypt - null input returns null`() {
        assertNull(encryptor.decrypt(null))
    }

    // -------------------------------------------------------------------------
    // roundtrip
    // -------------------------------------------------------------------------

    @Test
    fun `roundtrip - plain ASCII string`() {
        val v = "hello world"
        assertEquals(v, encryptor.decrypt(encryptor.encrypt(v)))
    }

    @Test
    fun `roundtrip - empty string`() {
        val v = ""
        assertEquals(v, encryptor.decrypt(encryptor.encrypt(v)))
    }

    @Test
    fun `roundtrip - unicode characters`() {
        val v = "日本語テスト 🔑 àéîõü"
        assertEquals(v, encryptor.decrypt(encryptor.encrypt(v)))
    }

    @Test
    fun `roundtrip - long string (10 000 chars)`() {
        val v = "Z".repeat(10_000)
        assertEquals(v, encryptor.decrypt(encryptor.encrypt(v)))
    }

    @Test
    fun `roundtrip - special and punctuation characters`() {
        val v = "!@#\$%^&*()_+-=[]{}|;:\",.<>?/\\`~"
        assertEquals(v, encryptor.decrypt(encryptor.encrypt(v)))
    }

    @Test
    fun `roundtrip - newlines and tabs`() {
        val v = "line1\nline2\ttabbed\r\nwindows"
        assertEquals(v, encryptor.decrypt(encryptor.encrypt(v)))
    }

    @Test
    fun `roundtrip - JSON string`() {
        val v = """{"user":"alice","token":"abc123","roles":["admin","user"]}"""
        assertEquals(v, encryptor.decrypt(encryptor.encrypt(v)))
    }

    @Test
    fun `roundtrip - binary-like Base64 string`() {
        val v = "dGVzdCBkYXRhIGhlcmU="
        assertEquals(v, encryptor.decrypt(encryptor.encrypt(v)))
    }

    @Test
    fun `roundtrip - multiple independent values preserve identity`() {
        val pairs = listOf("alpha" to "one", "beta" to "two", "gamma" to "three")
        val ciphertexts = pairs.map { (_, v) -> encryptor.encrypt(v) }
        pairs.forEachIndexed { i, (_, v) ->
            assertEquals(v, encryptor.decrypt(ciphertexts[i]))
        }
    }

    // -------------------------------------------------------------------------
    // key management
    // -------------------------------------------------------------------------

    @Test
    fun `constructor - stores wrapped AES key in preferences`() {
        val context = RuntimeEnvironment.getApplication()
        val prefs = context.getSharedPreferences("key_mgmt_prefs", Context.MODE_PRIVATE)
        prefs.edit().clear().commit()

        AesStringEncryptor(prefs, FakeKeyWrapper())

        assertNotNull(
            "Wrapped AES key should be written to preferences after construction",
            prefs.getString(WRAPPED_AES_KEY_ITEM, null)
        )
    }

    @Test
    fun `constructor - loads existing key from preferences`() {
        val context = RuntimeEnvironment.getApplication()
        val prefs = context.getSharedPreferences("reuse_prefs", Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
        val kw = FakeKeyWrapper()

        val enc1 = AesStringEncryptor(prefs, kw)
        val ciphertext = enc1.encrypt("persisted secret")

        // Second instance must reuse the stored key
        val enc2 = AesStringEncryptor(prefs, kw)
        assertEquals("persisted secret", enc2.decrypt(ciphertext))
    }

    @Test
    fun `createKey - replaces the stored wrapped key`() {
        val context = RuntimeEnvironment.getApplication()
        val prefs = context.getSharedPreferences("create_key_prefs", Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
        val kw = FakeKeyWrapper()

        AesStringEncryptor(prefs, kw)
        val originalKey = prefs.getString(WRAPPED_AES_KEY_ITEM, null)

        // Force key rotation
        encryptor.createKey(prefs, kw)
        val newKey = prefs.getString(WRAPPED_AES_KEY_ITEM, null)

        assertNotNull(newKey)
        assertNotEquals(
            "createKey should generate a new wrapped key",
            originalKey, newKey
        )
    }

    @Test
    fun `wrapped AES key survives a clear-and-restore cycle`() {
        val context = RuntimeEnvironment.getApplication()
        val prefs = context.getSharedPreferences("clear_prefs", Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
        val kw = FakeKeyWrapper()

        val enc = AesStringEncryptor(prefs, kw)
        val ciphertext = enc.encrypt("survive clear")

        // Simulate FlutterKeychainPlugin.clear() behaviour
        val savedKey = prefs.getString(WRAPPED_AES_KEY_ITEM, null)
        prefs.edit().clear().commit()
        prefs.edit().putString(WRAPPED_AES_KEY_ITEM, savedKey).commit()

        // A new encryptor loaded from the preserved key should still decrypt
        val enc2 = AesStringEncryptor(prefs, kw)
        assertEquals("survive clear", enc2.decrypt(ciphertext))
    }
}
