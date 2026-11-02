import 'package:flutter/material.dart';

import '../brand.dart';
import '../content/content_catalog.dart';
import '../discover/content_index.dart';
import 'background_spec.dart';
import 'background_strings.dart';
import 'calm_visuals.dart';
import 'scene_background.dart';
import 'scene_library.dart';

/// A quiet button that opens [showBackgroundPicker]. Sized like the
/// player's stop button, so it can sit opposite it.
class BackgroundPickerButton extends StatelessWidget {
  const BackgroundPickerButton({
    super.key,
    required this.itemId,
    required this.kind,
  });

  final String itemId;
  final ContentKind kind;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: BackgroundStrings.pickerTooltip,
    onPressed: () => showBackgroundPicker(context, itemId: itemId, kind: kind),
    icon: Icon(
      Icons.wallpaper_rounded,
      size: 24,
      color: context.brand.textMuted,
    ),
  );
}

/// A sheet of still previews to pick [itemId]'s background from, with the
/// Calm visuals switch underneath. A pick applies at once, so the scene
/// can be seen changing behind the sheet.
Future<void> showBackgroundPicker(
  BuildContext context, {
  required String itemId,
  required ContentKind kind,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (sheetContext) => ListenableBuilder(
    listenable: Listenable.merge([
      SceneLibrary.instance,
      CalmVisualsSetting.instance,
    ]),
    builder: (sheetContext, _) {
      final c = sheetContext.brand;
      final library = SceneLibrary.instance;
      final setting = CalmVisualsSetting.instance;
      final current = library.backgroundFor(
        itemId,
        kind,
        choice: setting.choiceFor(itemId),
      );
      final itemDefault = library.defaultFor(itemId, kind);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                BackgroundStrings.pickerTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final spec in library.backgrounds)
                    _Preview(
                      spec: spec,
                      selected: spec.id == current.id,
                      // Picking the item's own clears the choice, so it
                      // follows the content if that changes.
                      onTap: () => setting.choose(
                        itemId,
                        spec.id == itemDefault.id ? null : spec.id,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  BackgroundStrings.calmVisuals,
                  style: TextStyle(fontSize: 14.5, color: c.ink),
                ),
                subtitle: Text(
                  MediaQuery.disableAnimationsOf(sheetContext)
                      ? BackgroundStrings.reduceMotionNote
                      : BackgroundStrings.calmVisualsHint,
                  style: TextStyle(fontSize: 12.5, color: c.textMuted),
                ),
                value: setting.enabled,
                onChanged: setting.setEnabled,
              ),
            ],
          ),
        ),
      );
    },
  ),
);

/// A still thumbnail of [spec] on the page colour, with its name.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final BackgroundSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: SizedBox(
          width: 84,
          child: Column(
            children: [
              Container(
                height: 104,
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: radius,
                  border: Border.all(
                    color: selected ? c.blue : c.border,
                    width: selected ? 2 : 1.2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: SceneBackground(spec: spec, animate: false),
              ),
              const SizedBox(height: 6),
              Text(
                spec.titleFor(contentLocale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? c.ink : c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
