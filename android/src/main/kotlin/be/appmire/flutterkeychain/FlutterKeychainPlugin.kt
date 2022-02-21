package be.appmire.flutterkeychain

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.math.BigInteger
import java.nio.charset.Charset
import java.security.*
import java.security.spec.AlgorithmParameterSpec
import java.util.*
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec
import javax.security.auth.x500.X500Principal


interface KeyWrapper {
    @Throws(Exception::class)
    fun wrap(key: Key): ByteArray

    @Throws(Exception::class)
    fun unwrap(wrappedKey: ByteArray, algorithm: String): Key
}

class RsaKeyStoreKeyWrapper(context: Context) : KeyWrapper {

    private val keyAlias: String
    private val context: Context
    private val TYPE_RSA = "RSA"
    private val KEYSTORE_PROVIDER_ANDROID = "AndroidKeyStore"

    init {
        this.keyAlias = context.packageName + ".FlutterKeychain"
        this.context = context
        createRSAKeysIfNeeded()
    }

    @Throws(Exception::class)
    override fun wrap(key: Key): ByteArray {
        val publicKey = getKeyStore().getCertificate(keyAlias)?.publicKey
        val cipher = getRSACipher()
        cipher.init(Cipher.WRAP_MODE, publicKey)
        return cipher.wrap(key)
    }

    @Throws(Exception::class)
    override fun unwrap(wrappedKey: ByteArray, algorithm: String): Key {
        val privateKey = getKeyStore().getKey(keyAlias, null)
        val cipher = getRSACipher()
        cipher.init(Cipher.UNWRAP_MODE, privateKey)

        return cipher.unwrap(wrappedKey, algorithm, Cipher.SECRET_KEY)
    }

    @Throws(Exception::class)
    fun encrypt(input: ByteArray): ByteArray {
        val publicKey = getKeyStore().getCertificate(keyAlias).publicKey
        val cipher = getRSACipher()
        cipher.init(Cipher.ENCRYPT_MODE, publicKey)

        return cipher.doFinal(input)
    }

    @Throws(Exception::class)
    fun decrypt(input: ByteArray): ByteArray {
        val privateKey = getKeyStore().getKey(keyAlias, null)
        val cipher = getRSACipher()
        cipher.init(Cipher.DECRYPT_MODE, privateKey)

        return cipher.doFinal(input)
    }

    @Throws(Exception::class)
    private fun getKeyStore(): KeyStore {
        val ks = KeyStore.getInstance(KEYSTORE_PROVIDER_ANDROID)
        ks.load(null)

        return ks
    }

    @Throws(Exception::class)
    private fun getRSACipher(): Cipher {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            Cipher.getInstance("RSA/ECB/PKCS1Padding", "AndroidOpenSSL") // error in android 6: InvalidKeyException: Need RSA private or public key
        } else {
            Cipher.getInstance("RSA/ECB/PKCS1Padding", "AndroidKeyStoreBCWorkaround") // error in android 5: NoSuchProviderException: Provider not available: AndroidKeyStoreBCWorkaround
        }
    }

    @Throws(Exception::class)
    private fun createRSAKeysIfNeeded() {
        val ks = KeyStore.getInstance(KEYSTORE_PROVIDER_ANDROID)
        ks.load(null)

        // Added hacks for getting KeyEntry:
        // https://stackoverflow.com/questions/36652675/java-security-unrecoverablekeyexception-failed-to-obtain-information-about-priv
        // https://stackoverflow.com/questions/36488219/android-security-keystoreexception-invalid-key-blob
        var privateKey: PrivateKey? = null
        var publicKey: PublicKey? = null
        for (i in 1..5) {
            try {
                privateKey = ks.getKey(keyAlias, null) as PrivateKey
                publicKey = ks.getCertificate(keyAlias).publicKey
                break
            } catch (ignored: Exception) {
            }
        }

        if (privateKey == null || publicKey == null) {
            createKeys()
            try {
                privateKey = ks.getKey(keyAlias, null) as PrivateKey
                publicKey = ks.getCertificate(keyAlias).publicKey
            } catch (ignored: Exception) {
                ks.deleteEntry(keyAlias)
            }
            if (privateKey == null || publicKey == null) {
                createKeys()
            }
        }
    }

    @SuppressLint("NewApi")
    @Throws(Exception::class)
    private fun createKeys() {
        val start = Calendar.getInstance()
        val end = Calendar.getInstance()
        end.add(Calendar.YEAR, 25)

        val kpGenerator = KeyPairGenerator.getInstance(TYPE_RSA, KEYSTORE_PROVIDER_ANDROID)

        val spec: AlgorithmParameterSpec

    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {

      spec = android.security.KeyPairGeneratorSpec.Builder( context)
              .setAlias(keyAlias)
              .setSubject(X500Principal("CN=$keyAlias"))
              .setSerialNumber(BigInteger.valueOf(1))
              .setStartDate(start.time)
              .setEndDate(end.time)
              .build()
    } else {
        spec = KeyGenParameterSpec.Builder(keyAlias, KeyProperties.PURPOSE_DECRYPT or KeyProperties.PURPOSE_ENCRYPT)
                .setCertificateSubject(X500Principal("CN=$keyAlias"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_PKCS1)
                .setUserAuthenticationRequired(false)
                .setCertificateSerialNumber(BigInteger.valueOf(1))
                .setCertificateNotBefore(start.time)
                .setCertificateNotAfter(end.time)
                .build()
    }
        kpGenerator.initialize(spec)
        kpGenerator.generateKeyPair()
    }

}

interface StringEncryptor {
    @Throws(Exception::class)
    fun encrypt(input: String?): String?

    @Throws(Exception::class)
    fun decrypt(input: String?): String?
}

class AesStringEncryptor// get the key, which is encrypted by RSA cipher.
@Throws(Exception::class) constructor(preferences: SharedPreferences, keyWrapper: KeyWrapper) : StringEncryptor {

    private val ivSize = 16
    private val keySize = 16
    private val KEY_ALGORITHM = "AES"
    private val WRAPPED_AES_KEY_ITEM = "W0n5hlJtrAH0K8mIreDGxtG"
    private val charset: Charset = Charset.forName("UTF-8")
    private val secureRandom: SecureRandom = SecureRandom()

    private var secretKey: Key
    private val cipher: Cipher

    init {
        val wrappedAesKey = preferences.getString(WRAPPED_AES_KEY_ITEM, null)

        if (wrappedAesKey == null) {
            secretKey = createKey(preferences, keyWrapper)
        } else {
            val encrypted = Base64.decode(wrappedAesKey, Base64.DEFAULT)
            try {
                secretKey = keyWrapper.unwrap(encrypted, KEY_ALGORITHM)
            } catch (ingnored: Exception) {
                secretKey = createKey(preferences, keyWrapper)
            }
        }
        cipher = Cipher.getInstance("AES/CBC/PKCS7Padding")
    }

    fun createKey(preferences: SharedPreferences, keyWrapper: KeyWrapper): Key {
        val key = ByteArray(keySize)
        secureRandom.nextBytes(key)
        val secretKey = SecretKeySpec(key, KEY_ALGORITHM)
        preferences
                .edit()
                .putString(WRAPPED_AES_KEY_ITEM, Base64.encodeToString(keyWrapper.wrap(secretKey), Base64.DEFAULT))
                .commit()
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

class FlutterKeychainPlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private val WRAPPED_AES_KEY_ITEM = "W0n5hlJtrAH0K8mIreDGxtG"

    companion object {
        private const val channelName = "plugin.appmire.be/flutter_keychain"

        lateinit private var encryptor: StringEncryptor
        lateinit private var preferences: SharedPreferences

        @JvmStatic
        fun registerWith(registrar: Registrar) {

            try {
                preferences = registrar.context().getSharedPreferences("FlutterKeychain", Context.MODE_PRIVATE)
                encryptor = AesStringEncryptor(preferences = preferences, keyWrapper = RsaKeyStoreKeyWrapper(registrar.context()))

                val instance = FlutterKeychainPlugin()
                instance.channel = MethodChannel(registrar.messenger(), channelName)
                instance.channel?.setMethodCallHandler(FlutterKeychainPlugin())
            } catch (e: Exception) {
                Log.e("flutter_keychain", "Could not register plugin", e)
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        preferences = binding.applicationContext.getSharedPreferences("FlutterKeychain", Context.MODE_PRIVATE)
        encryptor = AesStringEncryptor(preferences = preferences, keyWrapper = RsaKeyStoreKeyWrapper(binding.applicationContext))

        channel = MethodChannel(binding.binaryMessenger, channelName)
        channel!!.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    fun MethodCall.key(): String? {
        return this.argument("key")
    }

    fun MethodCall.value(): String? {
        return this.argument("value")
    }

    override fun onMethodCall(call: MethodCall, result: Result): Unit {
        try {
            when (call.method) {
                "get" -> {
                    val encryptedValue: String? = preferences.getString(call.key(), null)
                    val value = encryptor.decrypt(encryptedValue)
                    result.success(value)
                }
                "put" -> {
                    val value = encryptor.encrypt(call.value())
                    preferences.edit().putString(call.key(), value).commit()
                    result.success(null)
                }
                "remove" -> {
                    preferences.edit().remove(call.key()).commit()
                    result.success(null)
                }
                "clear" -> {
                    val savedValue: String? = preferences.getString(WRAPPED_AES_KEY_ITEM, null)
                    preferences.edit().clear().commit()
                    preferences.edit().putString(WRAPPED_AES_KEY_ITEM, savedValue).commit()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e("flutter_keychain", e.message ?: e.toString())
            result.error("flutter_keychain", e.message, e)
        }
    }
}
