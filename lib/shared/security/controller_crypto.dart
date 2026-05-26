import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart';

class ControllerCrypto {
  ControllerCrypto({Random? random}) : _random = random ?? Random.secure();

  static const _idKeyAppController =
      'AppController_b15a201f-9088-4c61-86cb-e5b97318a269';
  static const _idKeyCharacters =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  final Random _random;

  String md5Lower(String input) {
    return crypto.md5.convert(utf8.encode(input)).toString().toLowerCase();
  }

  String base64Utf8(String input) => base64Encode(utf8.encode(input));

  String encryptAES256(String plainText, String password) {
    final salt = _randomBytes(16);
    final iv = _randomBytes(16);
    final key = _deriveKey(password, salt);
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            true,
            PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
              ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
              null,
            ),
          );

    final encrypted = cipher.process(
      Uint8List.fromList(utf8.encode(plainText)),
    );
    return base64Encode([...salt, ...iv, ...encrypted]);
  }

  String decryptAES256(String cipherText, String password) {
    final payload = base64Decode(cipherText.replaceAll(RegExp(r'\s'), ''));
    if (payload.length < 33) {
      throw const FormatException('Payload AES invalido.');
    }
    final salt = Uint8List.fromList(payload.sublist(0, 16));
    final iv = Uint8List.fromList(payload.sublist(16, 32));
    final encrypted = Uint8List.fromList(payload.sublist(32));
    final key = _deriveKey(password, salt);
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            false,
            PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
              ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
              null,
            ),
          );

    return utf8.decode(cipher.process(encrypted));
  }

  String decryptFrameworkSecret({
    required String encryptionKeyBase64,
    required String cipherText,
  }) {
    final encryptionKey = utf8.decode(base64Decode(encryptionKeyBase64));
    final payload = base64Decode(cipherText.replaceAll(' ', '+'));
    final keyAndIv = _deriveFrameworkKeyAndIv(encryptionKey);
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            false,
            PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
              ParametersWithIV<KeyParameter>(
                KeyParameter(keyAndIv.sublist(0, 32)),
                keyAndIv.sublist(32, 48),
              ),
              null,
            ),
          );

    return _utf16leToString(cipher.process(Uint8List.fromList(payload)));
  }

  String decryptControllerAes({
    required String encryptionKeyBase64,
    required String saltBase64,
    required String cipherText,
  }) {
    final encryptionKey = utf8.decode(base64Decode(encryptionKeyBase64));
    final salt = Uint8List.fromList(base64Decode(saltBase64));
    final payload = base64Decode(cipherText.replaceAll(RegExp(r'\s'), ''));
    final keyAndIv = _deriveControllerKeyAndIv(encryptionKey, salt);
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            false,
            PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
              ParametersWithIV<KeyParameter>(
                KeyParameter(keyAndIv.sublist(0, 32)),
                keyAndIv.sublist(32, 48),
              ),
              null,
            ),
          );

    return _utf16leToString(cipher.process(Uint8List.fromList(payload)));
  }

  String encryptControllerIdKey({
    required String token,
    required String encryptionKeyBase64,
    required String saltBase64,
  }) {
    final payload =
        '${_randomAlphaNumeric(2)}'
        '${jsonEncode({'Token': token, 'IdKey': _idKeyAppController})}'
        '${_randomAlphaNumeric(2)}';
    final encryptionKey = utf8.decode(base64Decode(encryptionKeyBase64));
    final salt = Uint8List.fromList(base64Decode(saltBase64));
    final keyAndIv = _deriveControllerKeyAndIv(encryptionKey, salt);
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            true,
            PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
              ParametersWithIV<KeyParameter>(
                KeyParameter(keyAndIv.sublist(0, 32)),
                keyAndIv.sublist(32, 48),
              ),
              null,
            ),
          );

    return base64Encode(cipher.process(_utf16le(payload)));
  }

  Uint8List _deriveKey(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA1Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 10000, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  Uint8List _deriveControllerKeyAndIv(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA1Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 1000, 48));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  Uint8List _deriveFrameworkKeyAndIv(String password) {
    final salt = Uint8List.fromList(const [
      0x49,
      0x76,
      0x61,
      0x6e,
      0x20,
      0x4d,
      0x65,
      0x64,
      0x76,
      0x65,
      0x64,
      0x65,
      0x76,
    ]);
    final derivator = PBKDF2KeyDerivator(HMac(SHA1Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 1000, 48));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }

  String _randomAlphaNumeric(int length) {
    return String.fromCharCodes(
      List<int>.generate(
        length,
        (_) => _idKeyCharacters.codeUnitAt(
          _random.nextInt(_idKeyCharacters.length),
        ),
      ),
    );
  }

  Uint8List _utf16le(String value) {
    final bytes = BytesBuilder();
    for (final codeUnit in value.codeUnits) {
      bytes.add([codeUnit & 0xff, codeUnit >> 8]);
    }
    return bytes.toBytes();
  }

  String _utf16leToString(List<int> bytes) {
    var start = 0;
    if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) {
      start = 2;
    }
    final codeUnits = <int>[];
    for (var i = start; i + 1 < bytes.length; i += 2) {
      codeUnits.add(bytes[i] | (bytes[i + 1] << 8));
    }
    return String.fromCharCodes(codeUnits);
  }
}
