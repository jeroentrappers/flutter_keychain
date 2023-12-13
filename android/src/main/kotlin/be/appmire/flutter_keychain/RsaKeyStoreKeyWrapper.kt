package be.appmire.flutter_keychain

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.math.BigInteger
import java.security.*
import java.security.spec.AlgorithmParameterSpec
import java.util.*
import javax.crypto.Cipher
import javax.security.auth.x500.X500Principal

class RsaKeyStoreKeyWrapper(context: Context) : KeyWrapper {
    private val keyAlias: String
    private val context: Context

    companion object {
        private const val TYPE_RSA = "RSA"
        private const val KEYSTORE_PROVIDER_ANDROID = "AndroidKeyStore"
    }

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
            Cipher.getInstance(
                "RSA/ECB/PKCS1Padding",
                "AndroidOpenSSL"
            ) // error in android 6: InvalidKeyException: Need RSA private or public key
        } else {
            Cipher.getInstance(
                "RSA/ECB/PKCS1Padding",
                "AndroidKeyStoreBCWorkaround"
            ) // error in android 5: NoSuchProviderException: Provider not available: AndroidKeyStoreBCWorkaround
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

    @Suppress("DEPRECATION")
    @Throws(Exception::class)
    private fun createKeys() {
        val start = Calendar.getInstance()
        val end = Calendar.getInstance()
        end.add(Calendar.YEAR, 25)

        val kpGenerator = KeyPairGenerator.getInstance(TYPE_RSA, KEYSTORE_PROVIDER_ANDROID)

        val spec: AlgorithmParameterSpec

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {

            spec = android.security.KeyPairGeneratorSpec.Builder(context)
                .setAlias(keyAlias)
                .setSubject(X500Principal("CN=$keyAlias"))
                .setSerialNumber(BigInteger.valueOf(1))
                .setStartDate(start.time)
                .setEndDate(end.time)
                .build()
        } else {
            spec = KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_DECRYPT or KeyProperties.PURPOSE_ENCRYPT
            )
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