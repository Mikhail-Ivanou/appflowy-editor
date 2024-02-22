import 'dart:math';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/flutter/overlay.dart';
import 'package:appflowy_editor/src/service/context_menu/built_in_context_menu_item.dart';
import 'package:flutter/material.dart' hide Overlay, OverlayEntry;
import 'package:provider/provider.dart';

// workaround for the issue:
// the popover will grab the focus even if it's inside the editor
// setup a global value to indicate whether the focus should be grabbed
// increase the value when the popover is opened
// decrease the value when the popover is closed
// only grab the focus when the value is 0
// the operation must be paired
KeepEditorFocusNotifier keepEditorFocusNotifier = KeepEditorFocusNotifier();

class AppFlowyEditor extends StatefulWidget {
  AppFlowyEditor({
    super.key,
    required this.editorState,
    Map<String, BlockComponentBuilder>? blockComponentBuilders,
    List<CharacterShortcutEvent>? characterShortcutEvents,
    List<CommandShortcutEvent>? commandShortcutEvents,
    List<List<ContextMenuItem>>? contextMenuItems,
    this.contentInsertionConfiguration,
    this.editable = true,
    this.autoFocus = false,
    this.focusedSelection,
    this.shrinkWrap = false,
    this.showMagnifier = true,
    this.allowLongTapForIos = false,
    this.editorScrollController,
    this.editorStyle = const EditorStyle.desktop(),
    this.padding,
    this.header,
    this.footer,
    this.focusNode,
  })  : blockComponentBuilders =
            blockComponentBuilders ?? standardBlockComponentBuilderMap,
        characterShortcutEvents =
            characterShortcutEvents ?? standardCharacterShortcutEvents,
        commandShortcutEvents =
            commandShortcutEvents ?? standardCommandShortcutEvents,
        contextMenuItems = contextMenuItems ?? standardContextMenuItems;

  final EditorState editorState;

  final EditorStyle editorStyle;

  /// Block component builders
  ///
  /// Pass the [standardBlockComponentBuilderMap] as well
  ///   if you simply want to extend it with a new one.
  ///
  /// For example, if you want to add a new block component:
  ///
  /// ```dart
  /// AppFlowyEditor(
  ///   blockComponentBuilders: {
  ///     ...standardBlockComponentBuilderMap,
  ///     'my_block_component': MyBlockComponentBuilder(),
  ///   },
  /// );
  /// ```
  ///
  /// Also, you can override the standard block component:
  ///
  /// ```dart
  /// AppFlowyEditor(
  ///   blockComponentBuilders: {
  ///     ...standardBlockComponentBuilderMap,
  ///     'paragraph': MyParagraphBlockComponentBuilder(),
  ///   },
  /// );
  /// ```
  final Map<String, BlockComponentBuilder> blockComponentBuilders;

  /// Character event handlers
  ///
  /// Pass the [standardCharacterShortcutEvents] as well
  ///   if you simply want to extend it with a new one.
  ///
  /// For example, if you want to add a new character shortcut event:
  ///
  /// ```dart
  /// AppFlowyEditor(
  ///  characterShortcutEvents: [
  ///   ...standardCharacterShortcutEvents,
  ///   [YOUR_SHORTCUT_EVENT],
  ///  ],
  /// );
  /// ```
  final List<CharacterShortcutEvent> characterShortcutEvents;

  /// Command event handlers
  ///
  /// Pass the [standardCommandShortcutEvents] as well
  ///   if you simply want to extend it with a new one.
  ///
  /// For example, if you want to add a new command shortcut event:
  ///
  /// ```dart
  /// AppFlowyEditor(
  ///   commandShortcutEvents: [
  ///     ...standardCommandShortcutEvents,
  ///     [YOUR_SHORTCUT_EVENT],
  ///   ],
  /// );
  /// ```
  final List<CommandShortcutEvent> commandShortcutEvents;

  /// The context menu items.
  ///
  /// They will be shown when the user right click on the editor.
  ///
  /// A divider will be added between each list.
  final List<List<ContextMenuItem>> contextMenuItems;

  /// Provide a editorScrollController to control the scroll behavior
  ///
  /// Notes: the shrinkWrap will affect the layout behavior of the editor.
  /// Be carefully to set it as true, it will perform poorly.
  ///
  /// shrinkWrap == true: will use SingleChildView + Column to layout the editor.
  /// shrinkWrap == false: will use ListView to layout the editor.
  final EditorScrollController? editorScrollController;

  /// Set the value to false to disable editing.
  ///
  /// if false, the editor will only render the block components and
  ///   without the editing, selecting, scrolling features.
  final bool editable;

  /// Set the value to true to focus the editor on the start of the document.
  final bool autoFocus;

  /// Set the value to focus the editor on the specified selection.
  ///
  /// only works when [autoFocus] is true.
  final Selection? focusedSelection;

  final FocusNode? focusNode;

  /// Wrap AppFlowy Editor main widget with padding.
  ///
  /// Now you can adjust padding, so selectors are not trimmed.
  final EdgeInsets? padding;

  /// AppFlowy Editor use column as the root widget.
  ///
  /// You can provide a header and/or a footer to the editor.
  final Widget? header;
  final Widget? footer;

  /// if true, the editor will be sized to its contents.
  ///
  /// You should wrap the editor with a sized widget if you set this value to true.
  ///
  /// Notes: Must provide a scrollController when shrinkWrap is true.
  final bool shrinkWrap;

  /// Show the magnifier or not.
  ///
  /// only works on iOS or Android.
  final bool showMagnifier;
  final bool allowLongTapForIos;

  /// {@macro flutter.widgets.editableText.contentInsertionConfiguration}
  final ContentInsertionConfiguration? contentInsertionConfiguration;

  @override
  State<AppFlowyEditor> createState() => _AppFlowyEditorState();
}

class _AppFlowyEditorState extends State<AppFlowyEditor> {
  Widget? services;

  EditorState get editorState => widget.editorState;

  late final EditorScrollController editorScrollController;

  @override
  void initState() {
    super.initState();

    editorScrollController = widget.editorScrollController ??
        EditorScrollController(
          editorState: editorState,
          shrinkWrap: widget.shrinkWrap,
        );

    editorState.editorStyle = widget.editorStyle;
    editorState.renderer = _renderer;
    editorState.editable = widget.editable;

    // auto focus
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _autoFocusIfNeeded();
    });
  }

  @override
  void dispose() {
    // dispose the scroll controller if it's created by the editor
    if (widget.editorScrollController == null) {
      editorScrollController.dispose();
    }

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppFlowyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    editorState.editorStyle = widget.editorStyle;
    editorState.editable = widget.editable;

    if (editorState.service != oldWidget.editorState.service) {
      editorState.renderer = _renderer;
    }

    services = null;
  }

  @override
  Widget build(BuildContext context) {
    services ??= _buildServices(context);

    if (!widget.editable) {
      return Provider.value(
        value: editorState,
        child: services!,
      );
    }

    return Provider.value(
      value: editorState,
      child: FocusScope(
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => services!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServices(BuildContext context) {
    Widget child = editorState.renderer.build(
      context,
      editorState.document.root,
      header: widget.header,
      footer: widget.footer,
    );

    final padding = widget.padding;
    if (padding != null) {
      child = Padding(padding: padding, child: child);
    }

    if (!widget.editable) {
      return child;
    }

    child = SelectionServiceWidget(
      key: editorState.service.selectionServiceKey,
      cursorColor: widget.editorStyle.cursorColor,
      selectionColor: widget.editorStyle.selectionColor,
      showMagnifier: widget.showMagnifier,
      allowLongTapForIos: widget.allowLongTapForIos,
      contextMenuItems: widget.contextMenuItems,
      child: KeyboardServiceWidget(
        key: editorState.service.keyboardServiceKey,
        characterShortcutEvents: widget.characterShortcutEvents,
        commandShortcutEvents: widget.commandShortcutEvents,
        focusNode: widget.focusNode,
        contentInsertionConfiguration: widget.contentInsertionConfiguration,
        child: child,
      ),
    );

    return ScrollServiceWidget(
      key: editorState.service.scrollServiceKey,
      editorScrollController: editorScrollController,
      child: child,
    );
  }

  void _autoFocusIfNeeded() {
    if (widget.editable && widget.autoFocus) {
      editorState.updateSelectionWithReason(
        widget.focusedSelection ??
            Selection.single(
              path: [0],
              startOffset: 0,
            ),
        reason: SelectionUpdateReason.uiEvent,
      );
    }
  }

  BlockComponentRendererService get _renderer => BlockComponentRenderer(
        builders: {...widget.blockComponentBuilders},
      );
}

class KeepEditorFocusNotifier extends ValueNotifier<int> {
  KeepEditorFocusNotifier() : super(0);

  bool get shouldKeepFocus => value > 0;

  @override
  set value(int v) {
    super.value = max(0, v);
  }

  void increase() {
    value++;
  }

  void decrease() {
    value--;
  }

  void reset() {
    value = 0;
  }
}
