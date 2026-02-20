import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/collection.dart';

void main() {
  group('Collection', () {
    final now = DateTime(2026, 1, 15);

    Collection createSample({
      List<String> audioItemIds = const ['a1', 'a2', 'a3'],
    }) {
      return Collection(
        id: 'col-1',
        name: '我的合集',
        createdDate: now,
        isStarred: true,
        sortOrder: 2,
        audioItemIds: audioItemIds,
      );
    }

    group('toJson / fromJson 往返序列化', () {
      test('完整字段往返一致', () {
        final col = createSample();
        final json = col.toJson();
        final restored = Collection.fromJson(json);

        expect(restored.id, col.id);
        expect(restored.name, col.name);
        expect(restored.createdDate, col.createdDate);
        expect(restored.isStarred, col.isStarred);
        expect(restored.sortOrder, col.sortOrder);
        expect(restored.audioItemIds, col.audioItemIds);
      });

      test('fromJson 处理缺失可选字段', () {
        final json = {
          'id': 'col-1',
          'name': '测试',
          'createdDate': now.toIso8601String(),
          // 缺少 isStarred, sortOrder, audioItemIds
        };
        final col = Collection.fromJson(json);

        expect(col.isStarred, isFalse);
        expect(col.sortOrder, 0);
        expect(col.audioItemIds, isEmpty);
      });
    });

    test('audioCount getter', () {
      expect(createSample(audioItemIds: ['a1', 'a2', 'a3']).audioCount, 3);
      expect(createSample(audioItemIds: []).audioCount, 0);
    });

    group('copyWith', () {
      test('部分字段覆盖', () {
        final col = createSample();
        final copied = col.copyWith(name: '新合集', isStarred: false);

        expect(copied.name, '新合集');
        expect(copied.isStarred, isFalse);
        expect(copied.id, col.id);
        expect(copied.audioItemIds, col.audioItemIds);
      });
    });

    test('空 audioItemIds 列表', () {
      final col = createSample(audioItemIds: []);
      expect(col.audioItemIds, isEmpty);
      expect(col.audioCount, 0);
    });
  });
}
