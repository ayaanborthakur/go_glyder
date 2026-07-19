// lib/core/address_autocomplete.dart

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/services/places_service.dart';

/// A reusable TextFormField that shows an overlay dropdown with Google Places autocompletion suggestions.
/// It uses OverlayPortal to float suggestions above other widgets cleanly, inheriting the same theme
/// and safely managing lifecycle and disposal automatically to avoid '_dependents.isEmpty' errors.
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextCapitalization textCapitalization;
  final FormFieldValidator<String>? validator;
  final ValueChanged<PlaceSuggestion>? onSelected;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.textCapitalization = TextCapitalization.words,
    this.validator,
    this.onSelected,
  });

  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  final PlacesService _placesService = PlacesService();

  late final FocusNode _focusNode;
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _hideOverlay(); // Safely dismisses the overlay portal before disposal
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _search(widget.controller.text);
    } else {
      _hideOverlay();
    }
  }

  void _onTextChange() {
    if (_focusNode.hasFocus) {
      _search(widget.controller.text);
    }
  }

  void _search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      if (query.trim().isEmpty) {
        setState(() {
          _suggestions = [];
          _isSearching = false;
        });
        _hideOverlay();
        return;
      }

      setState(() {
        _isSearching = true;
      });
      _showOverlay();

      final results = await _placesService.searchPlaces(query);
      if (!mounted) return;

      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
      _showOverlay();
    });
  }

  void _showOverlay() {
    if (!mounted) return;

    if (_suggestions.isEmpty && !_isSearching) {
      _hideOverlay();
      return;
    }

    if (!_overlayController.isShowing) {
      _overlayController.show();
    }
  }

  void _hideOverlay() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
  }

  Widget _buildOverlayChild() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return Positioned(
      width: size.width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: Offset(0, size.height),
        child: Material(
          elevation: 4,
          borderRadius: AppRadius.smAll,
          color: Colors.white,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.smAll,
              border: Border.all(color: AppColors.divider),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: _isSearching
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brandGreen,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.location_on,
                          color: AppColors.brandGreen,
                          size: 18,
                        ),
                        title: Text(
                          suggestion.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        onTap: () {
                          widget.controller.text = suggestion.description;
                          _hideOverlay();
                          _focusNode.unfocus();
                          if (widget.onSelected != null) {
                            widget.onSelected!(suggestion);
                          }
                        },
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) => _buildOverlayChild(),
        child: TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          textCapitalization: widget.textCapitalization,
          decoration: widget.decoration,
          validator: widget.validator,
        ),
      ),
    );
  }
}
