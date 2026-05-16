import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:pointycastle/asn1.dart' as pc_asn1;

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

  /// Encrypt a message using AES, wrapped with recipient's RSA Public Key
  Future<Map<String, String>> encryptMessage(
      String plainText, String recipientPublicKeyPem) async {
    final aesKey = Key.fromSecureRandom(32);
    final iv = IV.fromSecureRandom(16);

    final encrypter = Encrypter(AES(aesKey));
    final encryptedPayload = encrypter.encrypt(plainText, iv: iv);

    final parser = RSAKeyParser();
    final rsaPublicKey = parser.parse(recipientPublicKeyPem) as pc.RSAPublicKey;
    final rsaEncrypter = Encrypter(RSA(publicKey: rsaPublicKey));

    final encryptedAesKey = rsaEncrypter.encrypt(aesKey.base64);

    return {
      'encrypted_payload': encryptedPayload.base64,
      'encrypted_key': encryptedAesKey.base64,
      'iv': iv.base64,
    };
  }

  /// Decrypt a message using own RSA Private Key
  Future<String> decryptMessage({
    required String encryptedPayload,
    required String encryptedKey,
    required String ivBase64,
  }) async {
    final privateKeyPem = await getLocalPrivateKey();
    if (privateKeyPem == null) throw Exception("Local private key not found");

    final parser = RSAKeyParser();
    final rsaPrivateKey = parser.parse(privateKeyPem) as pc.RSAPrivateKey;
    final rsaEncrypter = Encrypter(RSA(privateKey: rsaPrivateKey));

    final decryptedAesKeyBase64 =
        rsaEncrypter.decrypt(Encrypted.fromBase64(encryptedKey));
    final aesKey = Key.fromBase64(decryptedAesKeyBase64);
    final iv = IV.fromBase64(ivBase64);

    final encrypter = Encrypter(AES(aesKey));
    return encrypter.decrypt(Encrypted.fromBase64(encryptedPayload), iv: iv);
  }

  String _encodePublicKeyToPem(pc.RSAPublicKey key) {
    var topLevel = pc_asn1.ASN1Sequence(elements: []);
    var algorithmIdentifier = pc_asn1.ASN1Sequence(elements: []);
    algorithmIdentifier.add(pc_asn1.ASN1ObjectIdentifier.fromIdentifierString(
        '1.2.840.113549.1.1.1'));
    algorithmIdentifier.add(pc_asn1.ASN1Null());

    var publicKeySequence = pc_asn1.ASN1Sequence(elements: []);
    publicKeySequence.add(pc_asn1.ASN1Integer(key.modulus));
    publicKeySequence.add(pc_asn1.ASN1Integer(key.exponent));

    var publicKeyBitString =
        pc_asn1.ASN1BitString(stringValues: publicKeySequence.encode());

    topLevel.add(algorithmIdentifier);
    topLevel.add(publicKeyBitString);

    return '-----BEGIN PUBLIC KEY-----\n${base64.encode(topLevel.encode())}\n-----END PUBLIC KEY-----';
  }

  String _encodePrivateKeyToPem(pc.RSAPrivateKey key) {
    var topLevel = pc_asn1.ASN1Sequence(elements: []);
    topLevel.add(pc_asn1.ASN1Integer(BigInt.from(0)));

    var algorithmIdentifier = pc_asn1.ASN1Sequence(elements: []);
    algorithmIdentifier.add(pc_asn1.ASN1ObjectIdentifier.fromIdentifierString(
        '1.2.840.113549.1.1.1'));
    algorithmIdentifier.add(pc_asn1.ASN1Null());
    topLevel.add(algorithmIdentifier);

    var privateKeySequence = pc_asn1.ASN1Sequence(elements: []);
    privateKeySequence.add(pc_asn1.ASN1Integer(BigInt.from(0)));
    privateKeySequence.add(pc_asn1.ASN1Integer(key.n));
    privateKeySequence.add(pc_asn1.ASN1Integer(key.publicExponent));
    privateKeySequence.add(pc_asn1.ASN1Integer(key.privateExponent));
    privateKeySequence.add(pc_asn1.ASN1Integer(key.p));
    privateKeySequence.add(pc_asn1.ASN1Integer(key.q));
    privateKeySequence.add(pc_asn1.ASN1Integer(
        key.privateExponent! % (key.p! - BigInt.from(1))));
    privateKeySequence.add(pc_asn1.ASN1Integer(
        key.privateExponent! % (key.q! - BigInt.from(1))));
    privateKeySequence
        .add(pc_asn1.ASN1Integer(key.q!.modInverse(key.p!)));

    var privateKeyOctetString =
        pc_asn1.ASN1OctetString(octets: privateKeySequence.encode());
    topLevel.add(privateKeyOctetString);

    return '-----BEGIN PRIVATE KEY-----\n${base64.encode(topLevel.encode())}\n-----END PRIVATE KEY-----';
  }

  pc.SecureRandom _getSecureRandom() {
    final secureRandom = pc.FortunaRandom();
    final random = Random.secure();
    final seed =
        Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
    secureRandom.seed(pc.KeyParameter(seed));
    return secureRandom;
  }
}
