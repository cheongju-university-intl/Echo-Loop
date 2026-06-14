import 'package:echo_loop/widgets/dialogs/text_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('通用文本输入对话框弱化输入提示样式', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () {
              showTextInputDialog(
                context: context,
                title: 'Rename',
                labelText: 'Name',
                hintText: 'Enter name',
                confirmLabel: 'OK',
                cancelLabel: 'Cancel',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    final fieldContext = tester.element(find.byType(TextField));
    final theme = Theme.of(fieldContext);

    expect(field.style?.fontSize, theme.textTheme.bodyMedium?.fontSize);
    expect(
      field.decoration?.hintStyle?.fontSize,
      theme.textTheme.bodyMedium?.fontSize,
    );
    expect(
      field.decoration?.hintStyle?.color,
      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.52),
    );
    expect(
      field.decoration?.labelStyle?.fontSize,
      theme.textTheme.bodySmall?.fontSize,
    );
    expect(
      field.decoration?.floatingLabelStyle?.color,
      theme.colorScheme.primary.withValues(alpha: 0.78),
    );
  });
}
