import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;

class EncryptionService {
  static const String _privateKeyKey = 'e2ee_private_key';
  static const String _publicKeyKey = 'e2ee_public_key';

  final FlutterSecureStorage _storage;
  
  EncryptionService({FlutterSecureStorage? storage}) 
      : _storage = storage ?? const FlutterSecureStorage();

  /// Generate a new RSA Key Pair (2048-bit)
  Future<Map<String, String>> generateKeyPair() async {
    final keyGen = pc.KeyGenerator('RSA')
      ..init(pc.ParametersWithRandom(
          pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          _getSecureRandom()));

    final pair = keyGen.generateKeyPair();
    final public = pair.publicKey as pc.RSAPublicKey;
    final private = pair.privateKey as pc.RSAPrivateKey;

    final publicKeyPem = _encodePublicKeyToPem(public);
    final privateKeyPem = _encodePrivateKeyToPem(private);

    await _storage.write(key: _privateKeyKey, value: privateKeyPem);
    await _storage.write(key: _publicKeyKey, value: publicKeyPem);

    return {
      'publicKey': publicKeyPem,
      'privateKey': privateKeyPem,
    };
  }

  Future<String?> getLocalPublicKey() async {
    return await _storage.read(key: _publicKeyKey);
  }

  Future<String?> getLocalPrivateKey() async {
    return await _storage.read(key: _privateKeyKey);
  }

  /// Encrypt a message using AES, and wrap the AES key using the recipient's RSA Public Key.
  Future<Map<String, String>> encryptMessage(String plainText, String recipientPublicKeyPem) async {
    // 1. Generate a random AES key (32 bytes / 256 bits) and IV (16 bytes)
    final aesKey = Key.fromSecureRandom(32);
    final iv = IV.fromSecureRandom(16);

    // 2. Encrypt the plain text with AES-CBC
    final encrypter = Encrypter(AES(aesKey));
    final encryptedPayload = encrypter.encrypt(plainText, iv: iv);

    // 3. Encrypt the AES key with the recipient's RSA Public Key
    final parser = RSAKeyParser();
    final rsaPublicKey = parser.parse(recipientPublicKeyPem) as pc.RSAPublicKey;
    final rsaEncrypter = Encrypter(RSA(publicKey: rsaPublicKey));
    
    // The AES key as bytes needs to be encrypted
    final encryptedAesKey = rsaEncrypter.encrypt(aesKey.base64); // Using encrypt instead of encryptBytes for consistency

    return {
      'encrypted_payload': encryptedPayload.base64,
      'encrypted_key': encryptedAesKey.base64,
      'iv': iv.base64,
    };
  }

  /// Decrypt a message using own RSA Private Key and the provided encrypted AES key/IV.
  Future<String> decryptMessage({
    required String encryptedPayload,
    required String encryptedKey,
    required String ivBase64,
  }) async {
    final privateKeyPem = await getLocalPrivateKey();
    if (privateKeyPem == null) throw Exception("Local private key not found");

    // 1. Decrypt the AES key using own RSA Private Key
    final parser = RSAKeyParser();
    final rsaPrivateKey = parser.parse(privateKeyPem) as pc.RSAPrivateKey;
    final rsaEncrypter = Encrypter(RSA(privateKey: rsaPrivateKey));
    
    final decryptedAesKeyBase64 = rsaEncrypter.decrypt(Encrypted.fromBase64(encryptedKey));
    final aesKey = Key.fromBase64(decryptedAesKeyBase64);
    final iv = IV.fromBase64(ivBase64);

    // 2. Decrypt the payload using the decrypted AES key
    final encrypter = Encrypter(AES(aesKey));
    final decryptedText = encrypter.decrypt(Encrypted.fromBase64(encryptedPayload), iv: iv);

    return decryptedText;
  }

  // --- Helper Methods for PEM encoding ---
  
  String _encodePublicKeyToPem(pc.RSAPublicKey key) {
    var topLevel = pc.ASN1Sequence(elements: []);
    var algorithmIdentifier = pc.ASN1Sequence(elements: []);
    algorithmIdentifier.add(pc.ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1')); // rsaEncryption
    algorithmIdentifier.add(pc.ASN1Null());
    
    var publicKeySequence = pc.ASN1Sequence(elements: []);
    publicKeySequence.add(pc.ASN1Integer(key.modulus));
    publicKeySequence.add(pc.ASN1Integer(key.exponent));
    
    var publicKeyBitString = pc.ASN1BitString(string: publicKeySequence.encode());
    
    topLevel.add(algorithmIdentifier);
    topLevel.add(publicKeyBitString);
    
    return '-----BEGIN PUBLIC KEY-----\n${base64.encode(topLevel.encode())}\n-----END PUBLIC KEY-----';
  }

  String _encodePrivateKeyToPem(pc.RSAPrivateKey key) {
    var topLevel = pc.ASN1Sequence(elements: []);
    topLevel.add(pc.ASN1Integer(BigInt.from(0))); // version
    
    var algorithmIdentifier = pc.ASN1Sequence(elements: []);
    algorithmIdentifier.add(pc.ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1')); // rsaEncryption
    algorithmIdentifier.add(pc.ASN1Null());
    topLevel.add(algorithmIdentifier);
    
    var privateKeySequence = pc.ASN1Sequence(elements: []);
    privateKeySequence.add(pc.ASN1Integer(BigInt.from(0))); // version
    privateKeySequence.add(pc.ASN1Integer(key.n));
    privateKeySequence.add(pc.ASN1Integer(key.publicExponent));
    privateKeySequence.add(pc.ASN1Integer(key.privateExponent));
    privateKeySequence.add(pc.ASN1Integer(key.p));
    privateKeySequence.add(pc.ASN1Integer(key.q));
    privateKeySequence.add(pc.ASN1Integer(key.privateExponent! % (key.p! - BigInt.from(1)))); // exp1
    privateKeySequence.add(pc.ASN1Integer(key.privateExponent! % (key.q! - BigInt.from(1)))); // exp2
    privateKeySequence.add(pc.ASN1Integer(key.q!.modInverse(key.p!))); // coefficient
    
    var privateKeyOctetString = pc.ASN1OctetString(octets: privateKeySequence.encode());
    topLevel.add(privateKeyOctetString);
    
    return '-----BEGIN PRIVATE KEY-----\n${base64.encode(topLevel.encode())}\n-----END PRIVATE KEY-----';
  }

  pc.SecureRandom _getSecureRandom() {
    final secureRandom = pc.FortunaRandom();
    final random = Random.secure();
    final seed = Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
    secureRandom.seed(pc.KeyParameter(seed));
    return secureRandom;
  }
}
