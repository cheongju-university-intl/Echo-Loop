import 'package:fluency/features/official_collections/widgets/discover_entry_banner.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/models/collection.dart';
import 'package:fluency/providers/collection_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 轻量 CollectionList override：只控制 `state`，不接 DB。
class _FakeCollectionList extends CollectionList {
  final List<Collection> _seed;
  _FakeCollectionList(this._seed);

  @override
  CollectionState build() {
    return CollectionState(rawCollections: _seed, isLoading: false);
  }
}

Collection _officialCollection(int i) => Collection(
      id: 'c$i',
      name: 'Official $i',
      createdDate: DateTime(2026, 1, 1),
      source: CollectionSource.official,
      remoteId: 'r$i',
    );

Widget _host({
  required List<Collection> collections,
  VoidCallback? onTap,
}) {
  return ProviderScope(
    overrides: [
      collectionListProvider.overrideWith(
        () => _FakeCollectionList(collections),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh', 'CN'),
      home: Scaffold(body: DiscoverEntryBanner(onTap: onTap)),
    ),
  );
}

void main() {
  testWidgets('态 A：官方合集数 < 3 → 显示「发现官方合集」', (tester) async {
    await tester.pumpWidget(_host(collections: const []));
    await tester.pumpAndSettle();

    expect(find.text('发现官方合集'), findsOneWidget);
    expect(find.text('精选英语内容，一键加入'), findsOneWidget);
    expect(find.text('看看新上架'), findsNothing);
  });

  testWidgets('态 A：加入 2 个官方合集仍在 A 态', (tester) async {
    await tester.pumpWidget(_host(collections: [
      _officialCollection(1),
      _officialCollection(2),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('发现官方合集'), findsOneWidget);
  });

  testWidgets('态 B：加入 3 个官方合集 → 切换为「看看新上架」', (tester) async {
    await tester.pumpWidget(_host(collections: [
      _officialCollection(1),
      _officialCollection(2),
      _officialCollection(3),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('看看新上架'), findsOneWidget);
    expect(find.text('官方合集持续更新'), findsOneWidget);
    expect(find.text('发现官方合集'), findsNothing);
  });

  testWidgets('点击整卡触发 onTap', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(_host(
      collections: const [],
      onTap: () => tapped++,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    expect(tapped, 1);
  });
}
