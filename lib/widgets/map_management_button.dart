import 'package:flutter/material.dart';

import '../models/map_config.dart';
import '../services/map_image_storage.dart';
import '../theme/app_strings.dart';

class MapManagementButton extends StatelessWidget {
  const MapManagementButton({
    super.key,
    required this.activeMap,
    required this.maps,
    required this.onSelect,
    required this.onAdd,
    required this.onDelete,
  });

  final MapConfig activeMap;
  final List<MapConfig> maps;
  final Future<void> Function(MapConfig) onSelect;
  final Future<void> Function(MapConfig) onAdd;
  final Future<void> Function(MapConfig) onDelete;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => _MapManagementDialog(
        activeMap: activeMap,
        maps: maps,
        onSelect: onSelect,
        onAdd: onAdd,
        onDelete: onDelete,
      ),
    ),
    icon: const Icon(Icons.map_outlined),
    label: Text(activeMap.name, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

class _MapManagementDialog extends StatefulWidget {
  const _MapManagementDialog({
    required this.activeMap,
    required this.maps,
    required this.onSelect,
    required this.onAdd,
    required this.onDelete,
  });

  final MapConfig activeMap;
  final List<MapConfig> maps;
  final Future<void> Function(MapConfig) onSelect;
  final Future<void> Function(MapConfig) onAdd;
  final Future<void> Function(MapConfig) onDelete;

  @override
  State<_MapManagementDialog> createState() => _MapManagementDialogState();
}

class _MapManagementDialogState extends State<_MapManagementDialog> {
  final MapImageStorage _imageStorage = MapImageStorage();
  late final List<MapConfig> _maps;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _maps = List<MapConfig>.of(widget.maps);
  }

  Future<void> _select(MapConfig map) async {
    try {
      if (map.id == widget.activeMap.id) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      await widget.onSelect(map);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _addMap() async {
    try {
      final image = await _imageStorage.pickFromGallery();
      if (!mounted || image == null) return;
      final details = await showDialog<_MapDetails>(
        context: context,
        builder: (_) =>
            _MapDetailsDialog(width: image.width, height: image.height),
      );
      if (!mounted || details == null) return;

      setState(() => _busy = true);
      final path = await _imageStorage.save(image);
      final map = MapConfig(
        name: details.name,
        assetPath: path,
        resolution: details.resolution,
        originX: details.originX,
        originY: details.originY,
        imageWidth: image.width.toDouble(),
        imageHeight: image.height.toDouble(),
      );
      try {
        await widget.onAdd(map);
      } catch (_) {
        await _imageStorage.delete(path);
        rethrow;
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(MapConfig map) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteMapTitle),
        content: Text(AppStrings.deleteMapConfirm(map.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.onDelete(map);
      if (mounted) {
        setState(() => _maps.removeWhere((item) => item.id == map.id));
      }
      await _imageStorage.delete(map.assetPath);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.mapOperationFailed('$error'))),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(AppStrings.mapsTitle),
    content: SizedBox(
      width: 420,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final map in _maps)
                    ListTile(
                      title: Text(map.name),
                      subtitle: Text(
                        '${map.imageWidth.toInt()} × '
                        '${map.imageHeight.toInt()} px · '
                        '${map.resolution} m/px',
                      ),
                      leading: Icon(
                        map.id == widget.activeMap.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      onTap: () => _select(map),
                      trailing: map.id == widget.activeMap.id
                          ? null
                          : IconButton(
                              tooltip: AppStrings.delete,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(map),
                            ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addMap,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text(AppStrings.addMap),
                  ),
                ],
              ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(AppStrings.close),
      ),
    ],
  );
}

class _MapDetails {
  const _MapDetails({
    required this.name,
    required this.resolution,
    required this.originX,
    required this.originY,
  });

  final String name;
  final double resolution;
  final double originX;
  final double originY;
}

class _MapDetailsDialog extends StatefulWidget {
  const _MapDetailsDialog({required this.width, required this.height});

  final int width;
  final int height;

  @override
  State<_MapDetailsDialog> createState() => _MapDetailsDialogState();
}

class _MapDetailsDialogState extends State<_MapDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _resolutionController = TextEditingController(text: '0.05');
  final _originXController = TextEditingController(text: '0');
  final _originYController = TextEditingController(text: '0');

  @override
  void dispose() {
    _nameController.dispose();
    _resolutionController.dispose();
    _originXController.dispose();
    _originYController.dispose();
    super.dispose();
  }

  double? _number(String? value, {required bool positive}) {
    final number = double.tryParse(value ?? '');
    if (number == null || !number.isFinite || (positive && number <= 0)) {
      return null;
    }
    return number;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(AppStrings.mapDetailsTitle),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.detectedMapDimensions(widget.width, widget.height),
              ),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: AppStrings.mapName,
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? AppStrings.requiredField
                    : null,
              ),
              TextFormField(
                controller: _resolutionController,
                decoration: const InputDecoration(
                  labelText: AppStrings.mapResolution,
                  helperText: AppStrings.mapResolutionHelp,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) => _number(value, positive: true) == null
                    ? AppStrings.positiveNumberRequired
                    : null,
              ),
              TextFormField(
                controller: _originXController,
                decoration: const InputDecoration(
                  labelText: AppStrings.mapOriginX,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (value) => _number(value, positive: false) == null
                    ? AppStrings.numberRequired
                    : null,
              ),
              TextFormField(
                controller: _originYController,
                decoration: const InputDecoration(
                  labelText: AppStrings.mapOriginY,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (value) => _number(value, positive: false) == null
                    ? AppStrings.numberRequired
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text(AppStrings.cancel),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _MapDetails(
              name: _nameController.text.trim(),
              resolution: double.parse(_resolutionController.text),
              originX: double.parse(_originXController.text),
              originY: double.parse(_originYController.text),
            ),
          );
        },
        child: const Text(AppStrings.addMap),
      ),
    ],
  );
}
