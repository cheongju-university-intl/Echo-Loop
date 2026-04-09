import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/audio_item.dart';
import 'package:fluency/providers/audio_list_settings_provider.dart';
import 'package:fluency/widgets/audio_list_view.dart';

import '../helpers/mock_providers.dart';

void main() {
  group('sortAudioItems 置顶排序', () {
    final jan1 = DateTime(2026, 1, 1);
    final jan5 = DateTime(2026, 1, 5);
    final jan10 = DateTime(2026, 1, 10);
    final jan15 = DateTime(2026, 1, 15);

    AudioItem item(
      String id,
      String name,
      DateTime date, {
      bool pinned = false,
    }) {
      return createTestAudioItem(
        id: id,
        name: name,
        addedDate: date,
      ).copyWith(isPinned: pinned);
    }

    test('置顶项始终排在最前面（dateDesc）', () {
      final items = [
        item('a1', 'Audio A', jan10),
        item('a2', 'Audio B', jan5, pinned: true),
        item('a3', 'Audio C', jan1),
      ];

      final sorted = sortAudioItems(items, AudioSortType.dateDesc);
      final ids = sorted.map((i) => i.id).toList();

      // 置顶区：a2；非置顶区按日期倒序：a1, a3
      expect(ids, ['a2', 'a1', 'a3']);
    });

    test('置顶项始终排在最前面（nameAsc）', () {
      final items = [
        item('a1', 'Zebra', jan10),
        item('a2', 'Apple', jan5, pinned: true),
        item('a3', 'Mango', jan1),
      ];

      final sorted = sortAudioItems(items, AudioSortType.nameAsc);
      final ids = sorted.map((i) => i.id).toList();

      // 置顶区：a2；非置顶区按名称升序：a3(Mango), a1(Zebra)
      expect(ids, ['a2', 'a3', 'a1']);
    });

    test('非置顶项按选定排序类型排列，不受置顶影响', () {
      final items = [
        item('a1', 'Banana', jan10),
        item('a2', 'Apple', jan5, pinned: true),
        item('a3', 'Cherry', jan1),
        item('a4', 'Date', jan15),
      ];

      final sorted = sortAudioItems(items, AudioSortType.nameDesc);
      final unpinnedIds = sorted
          .where((i) => !i.isPinned)
          .map((i) => i.id)
          .toList();

      // 非置顶按名称降序：Date, Cherry, Banana
      expect(unpinnedIds, ['a4', 'a3', 'a1']);
    });

    test('多个置顶项之间按添加日期倒序排列', () {
      final items = [
        item('a1', 'Z', jan1, pinned: true),
        item('a2', 'A', jan10, pinned: true),
        item('a3', 'M', jan5),
      ];

      final sorted = sortAudioItems(items, AudioSortType.nameAsc);
      final ids = sorted.map((i) => i.id).toList();

      // 置顶区按日期倒序：a2(jan10), a1(jan1)；非置顶区：a3
      expect(ids, ['a2', 'a1', 'a3']);
    });

    test('全部置顶时按添加日期倒序排列', () {
      final items = [
        item('a1', 'C', jan1, pinned: true),
        item('a2', 'A', jan10, pinned: true),
        item('a3', 'B', jan5, pinned: true),
      ];

      final sorted = sortAudioItems(items, AudioSortType.nameAsc);
      final ids = sorted.map((i) => i.id).toList();

      // 全部置顶，按日期倒序
      expect(ids, ['a2', 'a3', 'a1']);
    });

    test('无置顶时排序行为与普通排序一致', () {
      final items = [
        item('a1', 'Banana', jan10),
        item('a2', 'Apple', jan5),
        item('a3', 'Cherry', jan1),
      ];

      final sorted = sortAudioItems(items, AudioSortType.nameAsc);
      final names = sorted.map((i) => i.name).toList();

      expect(names, ['Apple', 'Banana', 'Cherry']);
    });

    test('dateAsc 排序下置顶项仍在前面', () {
      final items = [
        item('a1', 'A', jan15),
        item('a2', 'B', jan1, pinned: true),
        item('a3', 'C', jan5),
        item('a4', 'D', jan10),
      ];

      final sorted = sortAudioItems(items, AudioSortType.dateAsc);
      final ids = sorted.map((i) => i.id).toList();

      // 置顶区：a2；非置顶区按日期升序：a3(jan5), a4(jan10), a1(jan15)
      expect(ids, ['a2', 'a3', 'a4', 'a1']);
    });

    test('空列表不报错', () {
      final sorted = sortAudioItems([], AudioSortType.dateDesc);
      expect(sorted, isEmpty);
    });
  });
}
