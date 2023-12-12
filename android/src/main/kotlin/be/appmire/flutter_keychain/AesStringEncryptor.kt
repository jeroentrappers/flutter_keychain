package be.appmire.flutter_keychain

import android.content.SharedPreferences
import android.util.Base64
import java.nio.charset.Charset
import java.security.*
import java.util.*
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

class AesStringEncryptor
    @Throws(Exception::class)
    constructor(preferences: SharedPreferences, keyWrapper: KeyWrapper) :
    StringEncryptor {

    private val charset: Charset = Charset.forName("UTF-8")
    private val secureRandom: SecureRandom = SecureRandom()
    private var secretKey: Key
    private val cipher: Cipher

    companion object {
        private const val ivSize = 16
        private const val keySize = 16
        private const val KEY_ALGORITHM = "AES"
        private const val WRAPPED_AES_KEY_ITEM = "W0n5hlJtrAH0K8mIreDGxtG"
    }

    init {
        val wrappedAesKey = preferences.getString(WRAPPED_AES_KEY_ITEM, null)

        secretKey = if (wrappedAesKey == null) {
            createKey(preferences, keyWrapper)
        } else {
            val encrypted = Base64.decode(wrappedAesKey, Base64.DEFAULT)
            try {
                keyWrapper.unwrap(encrypted, KEY_ALGORITHM)
            } catch (_: Exception) {
                createKey(preferences, keyWrapper)
            }
        }
        cipher = Cipher.getInstance("AES/CBC/PKCS7Padding")
    }

    private fun createKey(preferences: SharedPreferences, keyWrapper: KeyWrapper): Key {
        val key = ByteArray(keySize)
        secureRandom.nextBytes(key)
        val secretKey = SecretKeySpec(key, KEY_ALGORITHM)
        preferences
            .edit()
            .putString(
                WRAPPED_AES_KEY_ITEM,
                Base64.encodeToString(keyWrapper.wrap(secretKey), Base64.DEFAULT)
            )
            .apply()
        return secretKey
    }

    // input: UTF-8 cleartext string
    // output: Base64 encoded encrypted string
    @Throws(Exception::class)
    override fun encrypt(input: String?): String? {
        if (null == input) {
            return null
        }

        val iv = ByteArray(ivSize)
        secureRandom.nextBytes(iv)

        val ivParameterSpec = IvParameterSpec(iv)

        cipher.init(Cipher.ENCRYPT_MODE, secretKey, ivParameterSpec)

        val payload = cipher.doFinal(input.toByteArray(charset))
        val combined = ByteArray(iv.size + payload.size)

        System.arraycopy(iv, 0, combined, 0, iv.size)
        System.arraycopy(payload, 0, combined, iv.size, payload.size)

        return Base64.encodeToString(combined, Base64.DEFAULT)
    }

    // input: Base64 encoded encrypted string
    // output: UTF-8 cleartext string
    @Throws(Exception::class)
    override fun decrypt(input: String?): String? {

        if (null == input) {
            return null
        }

        val inputBytes = Base64.decode(input, 0)

        val iv = ByteArray(ivSize)
        System.arraycopy(inputBytes, 0, iv, 0, iv.size)
        val ivParameterSpec = IvParameterSpec(iv)

        val payloadSize = inputBytes.size - ivSize
        val payload = ByteArray(payloadSize)
        System.arraycopy(inputBytes, iv.size, payload, 0, payloadSize)

        cipher.init(Cipher.DECRYPT_MODE, secretKey, ivParameterSpec)
        val outputBytes = cipher.doFinal(payload)
        return String(outputBytes, charset)
    }
}