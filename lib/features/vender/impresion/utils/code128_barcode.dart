class Code128Bar {
  const Code128Bar({required this.startModule, required this.moduleCount});

  final int startModule;
  final int moduleCount;
}

class Code128Barcode {
  const Code128Barcode({
    required this.bars,
    required this.totalModules,
    required this.value,
  });

  static const quietZoneModules = 10;

  final List<Code128Bar> bars;
  final int totalModules;
  final String value;

  factory Code128Barcode.fromValue(String rawValue) {
    final printable = _printable(rawValue);
    final value = printable.isEmpty ? '0' : printable;
    final codes = _encode(value);
    var checksum = codes.first;
    for (var index = 1; index < codes.length; index += 1) {
      checksum += codes[index] * index;
    }
    codes
      ..add(checksum % 103)
      ..add(106);

    final bars = <Code128Bar>[];
    var cursor = quietZoneModules;
    for (final code in codes) {
      final pattern = _patterns[code];
      for (var index = 0; index < pattern.length; index += 1) {
        final modules = int.parse(pattern[index]);
        if (index.isEven) {
          bars.add(Code128Bar(startModule: cursor, moduleCount: modules));
        }
        cursor += modules;
      }
    }

    return Code128Barcode(
      bars: bars,
      totalModules: cursor + quietZoneModules,
      value: value,
    );
  }

  static List<int> _encode(String value) {
    if (RegExp(r'^\d+$').hasMatch(value)) {
      if (value.length.isEven) {
        return [105, ..._codeCPairs(value)];
      }
      if (value.length == 1) {
        return [104, value.codeUnitAt(0) - 32];
      }
      return [
        104,
        value.codeUnitAt(0) - 32,
        99,
        ..._codeCPairs(value.substring(1)),
      ];
    }
    return [104, ...value.codeUnits.map((unit) => unit - 32)];
  }

  static Iterable<int> _codeCPairs(String value) sync* {
    for (var index = 0; index < value.length; index += 2) {
      yield int.parse(value.substring(index, index + 2));
    }
  }

  static String _printable(String value) {
    return value.runes
        .where((code) => code >= 32 && code <= 126)
        .map(String.fromCharCode)
        .join()
        .trim();
  }
}

const _patterns = <String>[
  '212222',
  '222122',
  '222221',
  '121223',
  '121322',
  '131222',
  '122213',
  '122312',
  '132212',
  '221213',
  '221312',
  '231212',
  '112232',
  '122132',
  '122231',
  '113222',
  '123122',
  '123221',
  '223211',
  '221132',
  '221231',
  '213212',
  '223112',
  '312131',
  '311222',
  '321122',
  '321221',
  '312212',
  '322112',
  '322211',
  '212123',
  '212321',
  '232121',
  '111323',
  '131123',
  '131321',
  '112313',
  '132113',
  '132311',
  '211313',
  '231113',
  '231311',
  '112133',
  '112331',
  '132131',
  '113123',
  '113321',
  '133121',
  '313121',
  '211331',
  '231131',
  '213113',
  '213311',
  '213131',
  '311123',
  '311321',
  '331121',
  '312113',
  '312311',
  '332111',
  '314111',
  '221411',
  '431111',
  '111224',
  '111422',
  '121124',
  '121421',
  '141122',
  '141221',
  '112214',
  '112412',
  '122114',
  '122411',
  '142112',
  '142211',
  '241211',
  '221114',
  '413111',
  '241112',
  '134111',
  '111242',
  '121142',
  '121241',
  '114212',
  '124112',
  '124211',
  '411212',
  '421112',
  '421211',
  '212141',
  '214121',
  '412121',
  '111143',
  '111341',
  '131141',
  '114113',
  '114311',
  '411113',
  '411311',
  '113141',
  '114131',
  '311141',
  '411131',
  '211412',
  '211214',
  '211232',
  '2331112',
];
