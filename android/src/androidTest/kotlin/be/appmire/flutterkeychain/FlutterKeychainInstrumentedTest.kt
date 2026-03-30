package be.appmire.flutterkeychain

import android.content.Context
import android.content.SharedPreferences
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.security.KeyStore
import javax.crypto.spec.SecretKeySpec

/**
 * Instrumented tests that exercise the full encryption stack on a real Android device or
 * emulator, including the AndroidKeyStore-backed RSA key wrapper.
 *
 * Run with: ./gradlew connectedAndroidTest
 */
@RunWith(AndroidJUnit4::class)
class FlutterKeychainInstrumentedTest {

    private lateinit var context: Context
    private lateinit var preferences: SharedPreferences
    private lateinit var keyWrapper: RsaKeyStoreKeyWrapper
    private lateinit var encryptor: AesStringEncryptor

    companion object {
        private const val TEST_PREFS = "FlutterKeychainInstrumentedTest"
        private const val WRAPPED_AES_KEY_ITEM = "W0n5hlJtrAH0K8mIreDGxtG"
    }

    @Before
    fun setUp() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        preferences = context.getSharedPreferences(TEST_PREFS, Context.MODE_PRIVATE)
        preferences.edit().clear().commit()
        keyWrapper = RsaKeyStoreKeyWrapper(context)
        encryptor = AesStringEncryptor(preferences, keyWrapper)
    }

    // -------------------------------------------------------------------------
    // RsaKeyStoreKeyWrapper
    // -------------------------------------------------------------------------

    @Test
    fun rsaWrapper_keyPairExistsInAndroidKeyStore() {
        val ks = KeyStore.getInstance("AndroidKeyStore").also { it.load(null) }
        val alias = context.packageName + ".FlutterKeychain"
        assertTrue("RSA key pair must be present in AndroidKeyStore", ks.containsAlias(alias))
    }

    @Test
    fun rsaWrapper_wrapsAndUnwrapsAesKey() {
        val original = SecretKeySpec(ByteArray(16) { it.toByte() }, "AES")
        val wrapped = keyWrapper.wrap(original)
        val unwrapped = keyWrapper.unwrap(wrapped, "AES")
        assertArrayEquals(
            "Unwrapped key bytes must match the original",
            original.encoded, unwrapped.encoded
        )
    }

    @Test
    fun rsaWrapper_encryptsAndDecryptsBytes() {
        val plainBytes = "test bytes".toByteArray(Charsets.UTF_8)
        val encrypted = keyWrapper.encrypt(plainBytes)
        val decrypted = keyWrapper.decrypt(encrypted)
        assertArrayEquals(plainBytes, decrypted)
    }

    @Test
    fun rsaWrapper_idempotentKeyCreation() {
        // Calling the constructor a second time with an existing alias must not throw
        // and must leave the keystore entry intact.
        val ks = KeyStore.getInstance("AndroidKeyStore").also { it.load(null) }
        val alias = context.packageName + ".FlutterKeychain"
        val certBefore = ks.getCertificate(alias)

        RsaKeyStoreKeyWrapper(context) // second initialisation

        val certAfter = ks.getCertificate(alias)
        assertArrayEquals(
            "Certificate must not change on repeated initialisation",
            certBefore.encoded, certAfter.encoded
        )
    }

    // -------------------------------------------------------------------------
    // AesStringEncryptor – roundtrip on device
    // -------------------------------------------------------------------------

    @Test
    fun encryptor_roundtrip_ascii() {
        val v = "secret token"
        assertEquals(v, encryptor.decrypt(encryptor.encrypt(v)))
    }

    @Test
    fun encryptor_roundtrip_emptyString() {
        val v = ""
        assertEquals(v, encryptor.decrypt(encryptor.encrypt(v)))
    }

    @Test
    fun encryptor_roundtrip_unicode() {
        val v = "日本語 🔑 àéîõü"
        assertEquals(v, encryptor.decrypt(encryptor.encrypt(v)))
    }

    @Test
    fun encryptor_roundtrip_longString() {
        val v = "X".repeat(10_000)
        assertEquals(v, encryptor.decrypt(encryptor.encrypt(v)))
    }

    @Test
    fun encryptor_roundtrip_specialCharacters() {
        val v = "!@#\$%^&*()_+-=[]{}|;:\",.<>?/\\`~\n\t\r"
        assertEquals(v, encryptor.decrypt(encryptor.encrypt(v)))
    }

    @Test
    fun encryptor_roundtrip_jsonPayload() {
        val v = """{"user":"alice","roles":["admin"],"token":"eyJhbGciOiJIUzI1NiJ9"}"""
        assertEquals(v, encryptor.decrypt(encryptor.encrypt(v)))
    }

    @Test
    fun encryptor_encryptNull_returnsNull() {
        assertNull(encryptor.encrypt(null))
    }

    @Test
    fun encryptor_decryptNull_returnsNull() {
        assertNull(encryptor.decrypt(null))
    }

    @Test
    fun encryptor_randomIV_differentCiphertextsForSamePlaintext() {
        val c1 = encryptor.encrypt("same")
        val c2 = encryptor.encrypt("same")
        assertNotEquals("Random IV should produce different ciphertexts", c1, c2)
    }

    // -------------------------------------------------------------------------
    // AesStringEncryptor – key persistence
    // -------------------------------------------------------------------------

    @Test
    fun encryptor_keyPersistedAcrossInstances() {
        val v = "must survive restarts"
        val ciphertext = encryptor.encrypt(v)

        // Simulate app restart by creating a new encryptor from the same preferences
        val encryptor2 = AesStringEncryptor(preferences, keyWrapper)
        assertEquals(v, encryptor2.decrypt(ciphertext))
    }

    @Test
    fun encryptor_wrappedKeyStoredInPreferences() {
        assertNotNull(
            "Wrapped AES key must be stored in SharedPreferences",
            preferences.getString(WRAPPED_AES_KEY_ITEM, null)
        )
    }

    // -------------------------------------------------------------------------
    // clear() behaviour
    // -------------------------------------------------------------------------

    @Test
    fun clear_preservesWrappedAesKey() {
        encryptor.encrypt("something")   // ensure key is in prefs

        // Simulate FlutterKeychainPlugin.clear()
        val savedKey = preferences.getString(WRAPPED_AES_KEY_ITEM, null)
        preferences.edit().clear().commit()
        preferences.edit().putString(WRAPPED_AES_KEY_ITEM, savedKey).commit()

        assertNotNull(
            "Wrapped AES key must be preserved after clear",
            preferences.getString(WRAPPED_AES_KEY_ITEM, null)
        )
    }

    @Test
    fun clear_removesUserData() {
        preferences.edit().putString("user_secret", encryptor.encrypt("my data")).commit()

        val savedKey = preferences.getString(WRAPPED_AES_KEY_ITEM, null)
        preferences.edit().clear().commit()
        preferences.edit().putString(WRAPPED_AES_KEY_ITEM, savedKey).commit()

        assertNull(
            "User-stored key must be gone after clear",
            preferences.getString("user_secret", null)
        )
    }

    @Test
    fun clear_newEncryptorStillWorksAfterClear() {
        val v = "survive clear"
        val ciphertext = encryptor.encrypt(v)

        val savedKey = preferences.getString(WRAPPED_AES_KEY_ITEM, null)
        preferences.edit().clear().commit()
        preferences.edit().putString(WRAPPED_AES_KEY_ITEM, savedKey).commit()

        val encryptorAfterClear = AesStringEncryptor(preferences, keyWrapper)
        assertEquals(v, encryptorAfterClear.decrypt(ciphertext))
    }

    // -------------------------------------------------------------------------
    // Multiple keys
    // -------------------------------------------------------------------------

    @Test
    fun multipleKeys_eachDecryptsToOwnValue() {
        val entries = mapOf(
            "key_a" to "value A",
            "key_b" to "value B",
            "key_c" to "value C",
            "key_d" to "value D"
        )

        // Encrypt every entry and store ciphertext in preferences under the key name
        entries.forEach { (k, v) ->
            preferences.edit().putString(k, encryptor.encrypt(v)).commit()
        }

        // Decrypt and verify each
        entries.forEach { (k, expected) ->
            val cipher = preferences.getString(k, null)
            assertEquals("Value mismatch for key '$k'", expected, encryptor.decrypt(cipher))
        }
    }

    @Test
    fun overwrite_latestValueIsDecrypted() {
        preferences.edit().putString("token", encryptor.encrypt("old_token")).commit()
        preferences.edit().putString("token", encryptor.encrypt("new_token")).commit()

        val stored = preferences.getString("token", null)
        assertEquals("new_token", encryptor.decrypt(stored))
    }
}
