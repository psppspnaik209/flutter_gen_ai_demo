import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'file_helpers.dart';

class SettingsScreen extends StatefulWidget {
  final String systemPrompt;
  final double? temperature;
  final double? maxLength;
  final double? lengthPenalty;

  const SettingsScreen({
    super.key,
    required this.systemPrompt,
    this.temperature,
    this.maxLength,
    this.lengthPenalty,
  });

  @override
  State<SettingsScreen> createState() => _State();
}

class _State extends State<SettingsScreen> {
  final TextEditingController _systemPromptController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _maxLengthController = TextEditingController();
  final TextEditingController _penaltyController = TextEditingController();
  String? _currentModelPath;
  String _selectStatus = '';

  @override
  void initState() {
    super.initState();
    _systemPromptController.text = widget.systemPrompt;
    _temperatureController.text = widget.temperature?.toString() ?? '';
    _maxLengthController.text = widget.maxLength?.toString() ?? '';
    _penaltyController.text = widget.lengthPenalty?.toString() ?? '';
    _loadCurrentPath();
  }

  Future<void> _loadCurrentPath() async {
    final path = await getModelFolderPath();
    setState(() {
      _currentModelPath = path;
    });
  }

  Future<bool> _requestStoragePermission() async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    return status.isGranted;
  }

  Future<void> _selectModelFolder() async {
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      setState(() {
        _selectStatus = "Storage permission denied";
      });
      return;
    }
    final folder = await FilePicker.platform.getDirectoryPath();
    if (folder == null || folder.isEmpty) {
      return;
    }
    try {
      setState(() {
        _selectStatus = "Configuring...";
      });
      await configureModelFolderSelection(folder);
      setState(() {
        _currentModelPath = folder;
        _selectStatus = "Model folder updated. Restart app to load.";
      });
    } catch (e) {
      setState(() {
        _selectStatus = "Failed: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _systemPromptController,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'System Prompt',
                  border: OutlineInputBorder(),
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _temperatureController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Temperature',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _maxLengthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Length',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _penaltyController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Length Penalty',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Model Files',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Current: ${_currentModelPath ?? "Not set"}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _selectModelFolder,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select Model Folder'),
              ),
              if (_selectStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _selectStatus,
                  style: TextStyle(
                    color: _selectStatus.contains("Failed")
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    Navigator.of(context).pop({
      'systemPrompt': _systemPromptController.text,
      'temperature': _temperatureController.text,
      'maxLength': _maxLengthController.text,
      'lengthPenalty': _penaltyController.text,
    });
  }
}
