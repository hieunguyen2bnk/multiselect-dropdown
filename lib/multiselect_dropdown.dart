library multiselect_dropdown;

import 'package:base_list_data/base_list_data.dart';
import 'package:flutter/material.dart';
import 'package:multi_dropdown/widgets/hint_text.dart';

import 'models/value_item.dart';
import 'enum/app_enums.dart';

export 'enum/app_enums.dart';
export 'models/value_item.dart';

typedef OnOptionSelected<T> = void Function(List<ValueItem<T>> selectedOptions);

class MultiSelectDropDown<T> extends StatefulWidget {
  // selection type of the dropdown
  final SelectionType selectionType;

  // Hint
  final String hint;
  final Color? hintColor;
  final double? hintFontSize;
  final TextStyle? hintStyle;
  final EdgeInsetsGeometry? hintPadding;

  // Options
  final List<ValueItem<T>> options;
  final List<ValueItem<T>> selectedOptions;
  final List<ValueItem<T>> disabledOptions;
  final OnOptionSelected<T>? onOptionSelected;

  final void Function(int index, ValueItem<T> option)? onOptionRemoved;

  // selected option
  final Widget? selectedOptionIcon;
  final Color? selectedOptionTextColor;
  final Color? selectedOptionBackgroundColor;
  final Widget Function(BuildContext, ValueItem<T>)? selectedItemBuilder;

  // options configuration
  final Color? optionsBackgroundColor;
  final TextStyle? optionTextStyle;
  final double dropdownHeight;
  final bool alwaysShowOptionIcon;

  final Widget Function(BuildContext ctx, ValueItem<T> item, bool selected)? optionBuilder;

  // dropdownfield configuration
  final Color? fieldBackgroundColor;
  final Widget suffixIcon;
  final bool animateSuffixIcon;
  final Decoration? inputDecoration;
  final double? fieldBorderRadius;
  final BorderRadiusGeometry? radiusGeometry;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final double? borderWidth;
  final double? focusedBorderWidth;
  final EdgeInsets? padding;

  final int? maxItems;

  final Color? dropdownBackgroundColor;
  final Color? searchBackgroundColor;

  // dropdown border radius
  final double? dropdownBorderRadius;
  final double? dropdownMargin;

  // network configuration
  final BaseListData<ValueItem<T>, void>? data;
  final Widget Function(BuildContext, dynamic)? responseErrorBuilder;

  /// focus node
  final FocusNode? focusNode;

  /// Controller for the dropdown
  /// [controller] is the controller for the dropdown. It can be used to programmatically open and close the dropdown.
  final MultiSelectController<T>? controller;

  /// Search label
  /// [searchLabel] is the label for search bar in dropdown.
  final String? searchLabel;

  final Widget? optionIcon;

  final EdgeInsets? dropdownPadding;

  final BorderRadiusGeometry? borderRadiusOption;

  final bool disabled;

  final Widget? loading;

  final Widget? loadingMore;

  final Widget Function(List<ValueItem> selectedOptions) renderSelected;

  final Widget Function(void Function() clear)? renderClearIcon;

  final Widget Function(FocusNode? focusNode, void Function(String v) search)?
      onRenderSearch;

  const MultiSelectDropDown({
    Key? key,
    required this.onOptionSelected,
    required this.options,
    required this.data,
    required this.loading,
    required this.loadingMore,
    required this.renderSelected,
    this.onOptionRemoved,
    this.responseErrorBuilder,
    this.selectedOptionTextColor,
    this.selectionType = SelectionType.multi,
    this.hint = 'Select',
    this.hintColor = Colors.grey,
    this.hintFontSize = 14.0,
    this.selectedOptions = const [],
    this.disabledOptions = const [],
    this.alwaysShowOptionIcon = false,
    this.optionTextStyle,
    this.selectedOptionIcon,
    this.selectedOptionBackgroundColor,
    this.optionsBackgroundColor,
    this.fieldBackgroundColor = Colors.white,
    required this.dropdownHeight,
    required this.suffixIcon,
    this.renderClearIcon,
    this.selectedItemBuilder,
    this.inputDecoration,
    this.hintStyle,
    this.hintPadding = HintText.hintPaddingDefault,
    this.padding,
    this.borderColor = Colors.grey,
    this.focusedBorderColor = Colors.black54,
    this.borderWidth = 0.4,
    this.focusedBorderWidth = 0.4,
    this.fieldBorderRadius = 12.0,
    this.radiusGeometry,
    this.maxItems,
    this.focusNode,
    this.controller,
    this.onRenderSearch,
    this.dropdownBorderRadius,
    this.dropdownMargin,
    this.dropdownBackgroundColor,
    this.searchBackgroundColor,
    this.animateSuffixIcon = true,
    this.optionBuilder,
    this.searchLabel = 'Search',
    this.optionIcon,
    this.dropdownPadding,
    this.borderRadiusOption,
    this.disabled = false,
  }) : super(key: key);

  @override
  State<MultiSelectDropDown<T>> createState() => _MultiSelectDropDownState<T>();
}

class _MultiSelectDropDownState<T> extends State<MultiSelectDropDown<T>> {
  /// Options list that is used to display the options.
  final List<ValueItem<T>> _options = [];

  /// Selected options list that is used to display the selected options.
  final List<ValueItem<T>> _selectedOptions = [];

  /// Disabled options list that is used to display the disabled options.
  final List<ValueItem<T>> _disabledOptions = [];

  /// The controller for the dropdown.
  OverlayState? _overlayState;
  OverlayEntry? _overlayEntry;
  bool _selectionMode = false;

  late final FocusNode _focusNode;
  final LayerLink _layerLink = LayerLink();

  /// value notifier that is used for controller.
  late MultiSelectController<T> _controller;

  /// search field focus node
  FocusNode? _searchFocusNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? MultiSelectController<T>();
  }

  /// Initializes the options, selected options and disabled options.
  /// If the options are fetched from the network, then the network call is made.
  /// If the options are passed as a parameter, then the options are initialized.
  void _initialize() async {
    if (!mounted) return;
    if (widget.data != null) {
      if (widget.data!.list.isEmpty) {
        widget.data!.setFncRender(setState);
        await widget.data!.getList(onLoadDone: (v) {
          if (mounted) _options.addAll(v);
        });
      } else {
        _options.addAll(widget.data!.list);
      }
    } else {
      _options
          .addAll(_controller.options.isNotEmpty == true ? _controller.options : widget.options);
    }
    _addOptions();
    if (mounted) {
      _initializeOverlay();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _initializeOverlay();
      });
    }
  }

  void _initializeOverlay() {
    _overlayState ??= Overlay.of(context);

    _focusNode.addListener(_handleFocusChange);

    if (widget.onRenderSearch != null) {
      _searchFocusNode = FocusNode();
      _searchFocusNode!.addListener(_handleFocusChange);
    }
  }

  /// Adds the selected options and disabled options to the options list.
  void _addOptions() {
    setState(() {
      _selectedOptions.addAll(_controller.selectedOptions.isNotEmpty == true
          ? _controller.selectedOptions
          : widget.selectedOptions);
      _disabledOptions.addAll(_controller.disabledOptions.isNotEmpty == true
          ? _controller.disabledOptions
          : widget.disabledOptions);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller._isDisposed == false) {
        _controller.setOptions(_options);
        _controller.setSelectedOptions(_selectedOptions);
        _controller.setDisabledOptions(_disabledOptions);

        _controller.addListener(_handleControllerChange);
      }
    });
  }

  /// Handles the focus change to show/hide the dropdown.
  void _handleFocusChange() {
    if (_focusNode.hasFocus && mounted) {
      _overlayEntry = widget.data != null && widget.data!.error != null
          ? _buildNetworkErrorOverlayEntry()
          : _buildOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
      _updateSelection();
      return;
    }

    if ((_searchFocusNode == null || _searchFocusNode?.hasFocus == false) &&
        _overlayEntry != null) {
      _overlayEntry?.remove();
    }

    if (mounted) _updateSelection();

    _controller.value._isDropdownOpen = _focusNode.hasFocus || _searchFocusNode?.hasFocus == true;
  }

  void _updateSelection() {
    setState(() {
      _selectionMode = _focusNode.hasFocus || _searchFocusNode?.hasFocus == true;
    });
  }

  /// Calculate offset size for dropdown.
  List _calculateOffsetSize() {
    RenderBox? renderBox = context.findRenderObject() as RenderBox?;

    var size = renderBox?.size ?? Size.zero;
    var offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    final availableHeight = MediaQuery.of(context).size.height - offset.dy;

    return [size, availableHeight < widget.dropdownHeight];
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Focus(
          canRequestFocus: true,
          skipTraversal: true,
          focusNode: _focusNode,
          child: InkWell(
            splashColor: null,
            splashFactory: null,
            onTap: widget.disabled ? null : _toggleFocus,
            child: Container(
              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
              padding: widget.padding,
              decoration: _getContainerDecoration(),
              child: widget.data == null || !widget.data!.loading
                  ? Row(children: [
                      Expanded(child: _getContainerContent()),
                      if (widget.renderClearIcon != null && _anyItemSelected)
                        widget.renderClearIcon!(clear),
                      _buildSuffixIcon(),
                    ])
                  : widget.loading ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuffixIcon() {
    if (widget.animateSuffixIcon) {
      return AnimatedRotation(
        turns: _selectionMode ? 0.5 : 0,
        duration: const Duration(milliseconds: 300),
        child: widget.suffixIcon,
      );
    }
    return widget.suffixIcon;
  }

  /// Container Content for the dropdown.
  Widget _getContainerContent() {
    if (_selectedOptions.isEmpty) {
      return HintText(
        hintText: widget.hint,
        hintColor: widget.hintColor,
        hintStyle: widget.hintStyle,
        hintPadding: widget.hintPadding,
      );
    }

    return widget.renderSelected(_selectedOptions);
  }

  /// return true if any item is selected.
  bool get _anyItemSelected => _selectedOptions.isNotEmpty;

  /// Container decoration for the dropdown.
  Decoration _getContainerDecoration() {
    return widget.inputDecoration ??
        BoxDecoration(
          color: widget.fieldBackgroundColor ?? Colors.white,
          borderRadius:
              widget.radiusGeometry ?? BorderRadius.circular(widget.fieldBorderRadius ?? 12.0),
          border: _selectionMode
              ? Border.all(
                  color: widget.focusedBorderColor ?? Colors.grey,
                  width: widget.focusedBorderWidth ?? 0.4,
                )
              : Border.all(
                  color: widget.borderColor ?? Colors.grey,
                  width: widget.borderWidth ?? 0.4,
                ),
        );
  }

  /// Dispose the focus node and overlay entry.
  @override
  void dispose() {
    if (_overlayEntry?.mounted == true) {
      if (_overlayState != null && _overlayEntry != null) {
        _overlayEntry?.remove();
      }
      _overlayEntry = null;
      _overlayState?.dispose();
    }
    _focusNode.removeListener(_handleFocusChange);
    _searchFocusNode?.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _searchFocusNode?.dispose();
    _controller.removeListener(_handleControllerChange);

    if (widget.controller == null || widget.controller?.isDisposed == true) {
      _controller.dispose();
    }

    super.dispose();
  }

  /// Util method to map with index.
  Iterable<E> mapIndexed<E, F>(Iterable<F> items, E Function(int index, F item) f) sync* {
    var index = 0;

    for (final item in items) {
      yield f(index, item);
      index = index + 1;
    }
  }

  /// Handle the focus change on tap outside of the dropdown.
  void _onOutSideTap() {
    if (_searchFocusNode != null) {
      _searchFocusNode!.unfocus();
    }
    _focusNode.unfocus();
  }

  /// Method to toggle the focus of the dropdown.
  void _toggleFocus() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  /// Get the selectedItem icon for the dropdown
  Widget? _getSelectedIcon(bool isSelected) {
    if (isSelected) return widget.selectedOptionIcon;

    if (!widget.alwaysShowOptionIcon) return null;

    return widget.optionIcon;
  }

  /// Create the overlay entry for the dropdown.
  OverlayEntry _buildOverlayEntry() {
    // Calculate the offset and the size of the dropdown button
    final values = _calculateOffsetSize();
    // Get the size from the first item in the values list
    final size = values[0] as Size;
    // Get the showOnTop value from the second item in the values list
    final showOnTop = values[1] as bool;

    return OverlayEntry(builder: (context) {
      List<ValueItem<T>> selectedOptions = [..._selectedOptions];
      String keyword = '';
      final scroll = ScrollController();

      return StatefulBuilder(builder: ((context, dropdownState) {
        Widget renderOption(ValueItem<T> e) {
          final isSelected = selectedOptions.contains(e);

          onTap() {
            if (widget.selectionType == SelectionType.multi) {
              if (isSelected) {
                dropdownState(() {
                  selectedOptions.remove(e);
                });
                setState(() {
                  _selectedOptions.remove(e);
                });
              } else {
                final bool hasReachMax = widget.maxItems == null
                    ? false
                    : (_selectedOptions.length + 1) > widget.maxItems!;
                if (hasReachMax) return;

                dropdownState(() {
                  selectedOptions.add(e);
                });
                setState(() {
                  _selectedOptions.add(e);
                });
              }
            } else {
              dropdownState(() {
                selectedOptions.clear();
                selectedOptions.add(e);
              });
              setState(() {
                _selectedOptions.clear();
                _selectedOptions.add(e);
              });
              _focusNode.unfocus();
            }

            _controller.value._selectedOptions.clear();
            _controller.value._selectedOptions.addAll(_selectedOptions);

            widget.onOptionSelected?.call(_selectedOptions);
          }

          if (widget.optionBuilder != null) {
            return InkWell(
              onTap: onTap,
              child: widget.optionBuilder!(context, e, isSelected),
            );
          }

          final primaryColor = Theme.of(context).primaryColor;

          return _buildOption(
            option: e,
            primaryColor: primaryColor,
            isSelected: isSelected,
            dropdownState: dropdownState,
            onTap: onTap,
            selectedOptions: selectedOptions,
          );
        }

        if (widget.data != null) {
          widget.data!.setFncRender(dropdownState);
          scroll.addListener(() {
            if (scroll.position.pixels >= scroll.position.maxScrollExtent) {
              widget.data!.getList(onLoadDone: (v) {
                if (mounted) _options.addAll(v);
              });
            }
          });
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _onOutSideTap,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: true,
              targetAnchor: showOnTop ? Alignment.topLeft : Alignment.bottomLeft,
              followerAnchor: showOnTop ? Alignment.bottomLeft : Alignment.topLeft,
              offset: widget.dropdownMargin != null
                  ? Offset(0, showOnTop ? -widget.dropdownMargin! : widget.dropdownMargin!)
                  : Offset.zero,
              child: Material(
                  color: widget.dropdownBackgroundColor ?? Colors.white,
                  elevation: 4,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(widget.dropdownBorderRadius ?? 0),
                    ),
                  ),
                  shadowColor: Colors.black,
                  child: Container(
                    decoration: BoxDecoration(
                      backgroundBlendMode: BlendMode.dstATop,
                      color: widget.dropdownBackgroundColor ?? Colors.white,
                      borderRadius: widget.dropdownBorderRadius != null
                          ? BorderRadius.circular(widget.dropdownBorderRadius!)
                          : null,
                    ),
                    padding: widget.dropdownPadding,
                    constraints: widget.onRenderSearch != null
                        ? BoxConstraints.loose(Size(size.width, widget.dropdownHeight + 50))
                        : BoxConstraints.loose(Size(size.width, widget.dropdownHeight)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onRenderSearch != null)
                          widget.onRenderSearch!(
                              _searchFocusNode, (v) => dropdownState(() => keyword = v)),
                        // ColoredBox(
                        //   color: widget.dropdownBackgroundColor ?? Colors.white,
                        //   child: Padding(
                        //     padding: const EdgeInsets.all(8.0),
                        //     child: TextFormField(
                        //       controller: searchController,
                        //       onTapOutside: (_) {},
                        //       // scrollPadding: EdgeInsets.only(
                        //       //     bottom: MediaQuery.of(context).viewInsets.bottom),
                        //       focusNode: _searchFocusNode,
                        //       decoration: InputDecoration(
                        //         fillColor: widget.searchBackgroundColor ?? Colors.grey.shade200,
                        //         isDense: true,
                        //         filled: true,
                        //         hintText: widget.searchLabel,
                        //         enabledBorder: OutlineInputBorder(
                        //           borderRadius:
                        //               BorderRadius.circular(widget.fieldBorderRadius ?? 12),
                        //           borderSide: BorderSide(
                        //             color: Colors.grey.shade300,
                        //             width: 0.8,
                        //           ),
                        //         ),
                        //         focusedBorder: OutlineInputBorder(
                        //           borderRadius:
                        //               BorderRadius.circular(widget.fieldBorderRadius ?? 12),
                        //           borderSide: BorderSide(
                        //             color: Theme.of(context).primaryColor,
                        //             width: 0.8,
                        //           ),
                        //         ),
                        //         suffixIcon: IconButton(
                        //           icon: const Icon(Icons.close),
                        //           onPressed: () {
                        //             searchController.clear();
                        //             dropdownState(() => keyword = '');
                        //           },
                        //         ),
                        //       ),
                        //       onChanged: (v) => dropdownState(() => keyword = v),
                        //     ),
                        //   ),
                        // ),
                        Expanded(
                          child: ListView(
                            controller: scroll,
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: [
                              ..._options
                                  .where((e) => keyword.isEmpty
                                      ? true
                                      : e.label.toLowerCase().contains(keyword.toLowerCase()))
                                  .map(renderOption),
                              if (widget.data != null && widget.data!.loadingMore)
                                widget.loadingMore!
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ),
          ],
        );
      }));
    });
  }

  ListTile _buildOption({
    required ValueItem<T> option,
    required Color primaryColor,
    required bool isSelected,
    required StateSetter dropdownState,
    required void Function() onTap,
    required List<ValueItem<T>> selectedOptions,
  }) =>
      ListTile(
        title: Text(option.label,
            style: widget.optionTextStyle ??
                TextStyle(
                  fontSize: widget.hintFontSize,
                )),
        selectedColor: widget.selectedOptionTextColor ?? primaryColor,
        selected: isSelected,
        autofocus: true,
        dense: true,
        tileColor: widget.optionsBackgroundColor ?? Colors.white,
        selectedTileColor: widget.selectedOptionBackgroundColor ?? Colors.grey.shade200,
        enabled: !_disabledOptions.contains(option),
        onTap: onTap,
        leading: _getSelectedIcon(isSelected),
        shape: widget.borderRadiusOption == null
            ? null
            : RoundedRectangleBorder(borderRadius: widget.borderRadiusOption!),
        // trailing: _getSelectedIcon(isSelected, primaryColor),
      );

  /// Builds overlay entry for showing error when fetching data from network fails.
  OverlayEntry _buildNetworkErrorOverlayEntry() {
    final values = _calculateOffsetSize();
    final size = values[0] as Size;
    final showOnTop = values[1] as bool;

    // final offsetY = showOnTop ? -(size.height + 5) : size.height + 5;

    return OverlayEntry(builder: (context) {
      return StatefulBuilder(builder: ((context, dropdownState) {
        return Stack(
          children: [
            Positioned.fill(
                child: GestureDetector(
              onTap: _onOutSideTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
              ),
            )),
            CompositedTransformFollower(
                link: _layerLink,
                targetAnchor: showOnTop ? Alignment.topLeft : Alignment.bottomLeft,
                followerAnchor: showOnTop ? Alignment.bottomLeft : Alignment.topLeft,
                offset: widget.dropdownMargin != null
                    ? Offset(0, showOnTop ? -widget.dropdownMargin! : widget.dropdownMargin!)
                    : Offset.zero,
                child: Material(
                    clipBehavior: Clip.none,
                    borderRadius: widget.dropdownBorderRadius != null
                        ? BorderRadius.circular(widget.dropdownBorderRadius!)
                        : null,
                    elevation: 4,
                    child: Container(
                        width: size.width,
                        constraints: BoxConstraints.loose(Size(size.width, widget.dropdownHeight)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            widget.responseErrorBuilder != null
                                ? widget.responseErrorBuilder!(context, widget.data!.error)
                                : Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text('Error fetching data: ${widget.data!.error}'),
                                  ),
                          ],
                        ))))
          ],
        );
      }));
    });
  }

  /// Clear the selected options.
  /// [MultiSelectController] is used to clear the selected options.
  void clear() {
    if (!_controller._isDisposed) {
      _controller.clearAllSelection();
    } else {
      setState(() {
        _selectedOptions.clear();
      });
      widget.onOptionSelected?.call(_selectedOptions);
    }
    if (_focusNode.hasFocus) _focusNode.unfocus();
  }

  /// handle the controller change.
  void _handleControllerChange() {
    // if the controller is null, return.
    if (_controller.isDisposed == true) return;

    // if current disabled options are not equal to the controller's disabled options, update the state.
    if (_disabledOptions != _controller.value._disabledOptions) {
      setState(() {
        _disabledOptions.clear();
        _disabledOptions.addAll(_controller.value._disabledOptions);
      });
    }

    // if current options are not equal to the controller's options, update the state.
    if (_options != _controller.value._options) {
      setState(() {
        _options.clear();
        _options.addAll(_controller.value._options);
      });
    }

    // if current selected options are not equal to the controller's selected options, update the state.
    if (_selectedOptions != _controller.value._selectedOptions) {
      setState(() {
        _selectedOptions.clear();
        _selectedOptions.addAll(_controller.value._selectedOptions);
      });
      widget.onOptionSelected?.call(_selectedOptions);
    }

    if (_selectionMode != _controller.value._isDropdownOpen) {
      if (_controller.value._isDropdownOpen) {
        _focusNode.requestFocus();
      } else {
        _focusNode.unfocus();
      }
    }
  }
}

/// MultiSelect Controller class.
/// This class is used to control the state of the MultiSelectDropdown widget.
/// This is just base class. The implementation of this class is in the MultiSelectController class.
/// The implementation of this class is hidden from the user.
class _MultiSelectController<T> {
  final List<ValueItem<T>> _disabledOptions = [];
  final List<ValueItem<T>> _options = [];
  final List<ValueItem<T>> _selectedOptions = [];
  bool _isDropdownOpen = false;
}

/// implementation of the MultiSelectController class.
class MultiSelectController<T> extends ValueNotifier<_MultiSelectController<T>> {
  MultiSelectController() : super(_MultiSelectController());

  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  /// set the dispose method.
  @override
  void dispose() {
    super.dispose();
    _isDisposed = true;
  }

  /// Clear the selected options.
  /// [MultiSelectController] is used to clear the selected options.
  void clearAllSelection() {
    value._selectedOptions.clear();
    notifyListeners();
  }

  /// clear specific selected option
  /// [MultiSelectController] is used to clear specific selected option.
  void clearSelection(ValueItem<T> option) {
    if (!value._selectedOptions.contains(option)) return;

    if (value._disabledOptions.contains(option)) {
      throw Exception('Cannot clear selection of a disabled option');
    }

    if (!value._options.contains(option)) {
      throw Exception('Cannot clear selection of an option that is not in the options list');
    }

    value._selectedOptions.remove(option);
    notifyListeners();
  }

  /// select the options
  /// [MultiSelectController] is used to select the options.
  void setSelectedOptions(List<ValueItem<T>> options) {
    if (options.any((element) => value._disabledOptions.contains(element))) {
      throw Exception('Cannot select disabled options');
    }

    if (options.any((element) => !value._options.contains(element))) {
      throw Exception('Cannot select options that are not in the options list');
    }

    value._selectedOptions.clear();
    value._selectedOptions.addAll(options);
    notifyListeners();
  }

  /// add selected option
  /// [MultiSelectController] is used to add selected option.
  void addSelectedOption(ValueItem<T> option) {
    if (value._disabledOptions.contains(option)) {
      throw Exception('Cannot select disabled option');
    }

    if (!value._options.contains(option)) {
      throw Exception('Cannot select option that is not in the options list');
    }

    value._selectedOptions.add(option);
    notifyListeners();
  }

  /// set disabled options
  /// [MultiSelectController] is used to set disabled options.
  void setDisabledOptions(List<ValueItem<T>> disabledOptions) {
    if (disabledOptions.any((element) => !value._options.contains(element))) {
      throw Exception('Cannot disable options that are not in the options list');
    }

    value._disabledOptions.clear();
    value._disabledOptions.addAll(disabledOptions);
    notifyListeners();
  }

  /// setDisabledOption method
  /// [MultiSelectController] is used to set disabled option.
  void setDisabledOption(ValueItem<T> disabledOption) {
    if (!value._options.contains(disabledOption)) {
      throw Exception('Cannot disable option that is not in the options list');
    }

    value._disabledOptions.add(disabledOption);
    notifyListeners();
  }

  /// set options
  /// [MultiSelectController] is used to set options.
  void setOptions(List<ValueItem<T>> options) {
    value._options.clear();
    value._options.addAll(options);
    notifyListeners();
  }

  /// get disabled options
  List<ValueItem<T>> get disabledOptions => value._disabledOptions;

  /// get enabled options
  List<ValueItem<T>> get enabledOptions =>
      value._options.where((element) => !value._disabledOptions.contains(element)).toList();

  /// get options
  List<ValueItem<T>> get options => value._options;

  /// get selected options
  List<ValueItem<T>> get selectedOptions => value._selectedOptions;

  /// get is dropdown open
  bool get isDropdownOpen => value._isDropdownOpen;

  /// show dropdown
  /// [MultiSelectController] is used to show dropdown.
  void showDropdown() {
    if (value._isDropdownOpen) return;
    value._isDropdownOpen = true;
    notifyListeners();
  }

  /// hide dropdown
  /// [MultiSelectController] is used to hide dropdown.
  void hideDropdown() {
    if (!value._isDropdownOpen) return;
    value._isDropdownOpen = false;
    notifyListeners();
  }
}
