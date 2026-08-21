import 'package:flutter_base/core/parsing/json_value_parser.dart';
import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JsonValueParser', () {
    test('兼容字符串和浮点数字段', () {
      expect(JsonValueParser.intValue('42'), 42);
      expect(JsonValueParser.intValue(42.9), 42);
      expect(JsonValueParser.stringValue(10086), '10086');
    });

    test('兼容布尔值的常见后端表示', () {
      expect(JsonValueParser.boolValue(1), isTrue);
      expect(JsonValueParser.boolValue('true'), isTrue);
      expect(JsonValueParser.boolValue('0'), isFalse);
    });

    test('秒级时间戳统一转换为毫秒', () {
      expect(JsonValueParser.timestampMillis(1700000000), 1700000000000);
      expect(JsonValueParser.timestampMillis('1700000000000'), 1700000000000);
    });

    test('枚举支持索引、数字字符串和名称并安全处理越界', () {
      expect(
        JsonValueParser.enumValue(
          '1',
          MessageType.values,
          fallback: MessageType.text,
        ),
        MessageType.image,
      );
      expect(
        JsonValueParser.enumValue(
          'video',
          MessageType.values,
          fallback: MessageType.text,
        ),
        MessageType.video,
      );
      expect(
        JsonValueParser.enumValue(
          999,
          MessageType.values,
          fallback: MessageType.text,
        ),
        MessageType.text,
      );
    });
  });
}
