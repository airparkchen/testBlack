import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import './bigint_ex.dart';

final _input = {
  'largeSafePrime': 'ac6bdb41324a9a9bf166de5e1389582faf72b6651987ee07fc3192943db56050a37329cbb4a099ed8193e0757767a13dd52312ab4b03310dcd7f48a9da04fd50e8083969edb767b0cf6095179a163ab3661a05fbd5faaae82918a9962f0b93b855f97993ec975eeaa80d740adbf4ff747359d041d5c33ea71d281e446b14773bca97b43a23fb801676bd207a436c6481f1d2b9078717461a5b9d32e688f87748544523b524b0d57d5ea77a2775d2ecfa032cfbdbf52fb3786160279004e57ae6af874e7303ce53299ccc041c7bc308d82a5698f3a8d0c38271ae35f8e9dbfbb694b5c803d89f7ae435de236d525f54759b65e372fcd68ef20fa7111f9e4aff73',
  'generatorModulo': '02',
  'hashFunction': 'sha256',
  'hashOutputBytes': 4,
};

class Params {
  static final N = BigInt.parse(_input['largeSafePrime'].toString().replaceAll(' ', ''), radix: 16);
  static final g = BigInt.parse(_input['generatorModulo'].toString().replaceAll(' ', ''), radix: 16);
  static final k = H([N, g]);
  static final int hashOutputBytes = (_input["hashOutputBytes"] is int)
      ? _input["hashOutputBytes"] as int
      : 4; // 默認值為 32

  static BigInt H(List args) {
    final output = new AccumulatorSink<Digest>();
    final input = sha256.startChunkedConversion(output);
    for (final arg in args) {
      if (arg is BigInt) {
        var hexStr = arg.toHex();
        if (!hexStr.length.isEven) {
          hexStr = '0$hexStr';
        }
        input.add(hex.decode(hexStr));
      } else {
        input.add(utf8.encode(arg));
      }
    }
    input.close();
    final hexStr = output.events.single.toString();
    output.close();
    return BigInt.parse(hexStr, radix: 16);
  }
}
