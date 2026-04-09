import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluency/models/audio_item.dart';
import 'package:fluency/providers/audio_library_provider.dart';

import '../helpers/mock_providers.dart';

void main() {
  group('AudioLibrary.togglePin', () {
    late ProviderContainer container;

    /// 创建带不同日期的音频项，方便验证排序
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

    final jan1 = DateTime(2026, 1, 1);
    final jan5 = DateTime(2026, 1, 5);
    final jan10 = DateTime(2026, 1, 10);

    setUp(() {
      // 列表按日期倒序：jan10, jan5, jan1
      final initialItems = [
        item('a3', 'Audio 3', jan10),
        item('a2', 'Audio 2', jan5),
        item('a1', 'Audio 1', jan1),
      ];
      container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: initialItems)),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('togglePin 将未置顶音频切换为置顶', () async {
      final notifier = container.read(audioLibraryProvider.notifier);
      await notifier.togglePin('a1');

      final items = container.read(audioLibraryProvider).audioItems;
      expect(items.firstWhere((i) => i.id == 'a1').isPinned, isTrue);
    });

    test('togglePin 将已置顶音频切换为未置顶', () async {
      final notifier = container.read(audioLibraryProvider.notifier);
      await notifier.togglePin('a1');
      await notifier.togglePin('a1');

      final items = container.read(audioLibraryProvider).audioItems;
      expect(items.firstWhere((i) => i.id == 'a1').isPinned, isFalse);
    });

    test('togglePin 对不存在的 ID 无操作', () async {
      final notifier = container.read(audioLibraryProvider.notifier);
      final before = container.read(audioLibraryProvider).audioItems.length;

      await notifier.togglePin('non-existent');

      expect(container.read(audioLibraryProvider).audioItems.length, before);
    });

    test('置顶后的音频排在列表最前面', () async {
      final notifier = container.read(audioLibraryProvider.notifier);
      // 置顶最后一项 a1（日期最早）
      await notifier.togglePin('a1');

      final ids = container
          .read(audioLibraryProvider)
          .audioItems
          .map((i) => i.id)
          .toList();
      // a1 应排到最前面，其余保持日期倒序
      expect(ids, ['a1', 'a3', 'a2']);
    });

    test('多个置顶项之间按添加日期倒序排列', () async {
      final notifier = container.read(audioLibraryProvider.notifier);
      // 置顶 a1（jan1）和 a2（jan5）
      await notifier.togglePin('a1');
      await notifier.togglePin('a2');

      final ids = container
          .read(audioLibraryProvider)
          .audioItems
          .map((i) => i.id)
          .toList();
      // 置顶区：a2(jan5) > a1(jan1)，非置顶区：a3(jan10)
      expect(ids, ['a2', 'a1', 'a3']);
    });

    test('取消置顶后音频回到日期排序的正确位置', () async {
      final notifier = container.read(audioLibraryProvider.notifier);
      await notifier.togglePin('a1');
      // 此时顺序：a1, a3, a2

      await notifier.togglePin('a1');
      // 取消置顶后回到日期倒序：a3(jan10), a2(jan5), a1(jan1)
      final ids = container
          .read(audioLibraryProvider)
          .audioItems
          .map((i) => i.id)
          .toList();
      expect(ids, ['a3', 'a2', 'a1']);
    });
  });
}
