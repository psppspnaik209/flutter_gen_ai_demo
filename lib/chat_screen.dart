import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_demo/models.dart';

import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'file_helpers.dart';
import 'gen_ai.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _State();
}

class _State extends State<ChatScreen> {
  bool _modelDownloaded = false;
  bool _isLoadingModel = false;
  String _modelLoadStatus = "Loading...";
  bool _inferencing = false;
  String _systemPrompt = "You are an AI assistant. Always respond with brief, "
      "concise answers and avoid adding extra commentary.";
  double? _temperature = 0.7;
  double? _maxLength;
  double? _lengthPenalty = 1.0;
  String _responseText = '';
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _userPrompt = '';
  StreamSubscription<String>? _tokenSubscription;

  @override
  void initState() {
    super.initState();
    _setupTokenListener();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _setupTokenListener() {
    _tokenSubscription = GenAI.tokenStream.listen((token) {
      print('ChatScreen: Received token in listener: "$token"');
      setState(() {
        _responseText += token;
      });
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }, onError: (error) {
      print('ChatScreen: Stream error: $error');
    });
  }

  void _load() async {
    try {
      setState(() {
        _isLoadingModel = true;
        _modelLoadStatus = "Loading...";
      });
      final missingFiles = await getMissingModelFiles();
      _modelDownloaded = missingFiles.isEmpty;
      setState(() {
        if (!_modelDownloaded) {
          _isLoadingModel = false;
          _modelLoadStatus = "Model files missing: ${missingFiles.join(', ')}";
        }
      });
      if (_modelDownloaded) {
        String path = await getModelPath();
        await GenAI.load(path);
        setState(() {
          _isLoadingModel = false;
          _modelLoadStatus = "";
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingModel = false;
        _modelLoadStatus = "Model load failed: ${e.toString()}";
      });
    }
  }

  Future<bool> _requestStoragePermission() async {
    // iOS doesn't need storage permissions for file_picker - it uses document picker
    if (Platform.isIOS) {
      return true;
    }
    // Android needs storage permission
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    return status.isGranted;
  }

  void _inference() async {
    setState(() {
      _responseText = '';
      _inferencing = true;
    });
    String finalPrompt = "<|system|>\n$_systemPrompt<|end|>\n"
        "<|user|>\n$_userPrompt<|end|>\n"
        "<|assistant|>\n";

    Map<String, double> params = {};
    if (_temperature != null) {
      params["temperature"] = _temperature!;
    }
    if (_maxLength != null) {
      params["max_length"] = _maxLength!;
    }
    if (_lengthPenalty != null) {
      params["length_penalty"] = _lengthPenalty!;
    }
    await GenAI.inference(finalPrompt, params: params);
    setState(() {
      _inferencing = false;
    });
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    GenAI.unload();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Gen AI Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              Map<String, dynamic>? result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    systemPrompt: _systemPrompt,
                    temperature: _temperature,
                    maxLength: _maxLength,
                    lengthPenalty: _lengthPenalty,
                  ),
                ),
              );
              if (result != null) {
                _systemPrompt = result['systemPrompt'];
                if (result['temperature'] != null) {
                  _temperature = result['temperature'];
                }
                if (result['maxLength'] != null) {
                  _maxLength = result['maxLength'];
                }
                if (result['lengthPenalty'] != null) {
                  _lengthPenalty = result['lengthPenalty'];
                }
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  _buildBody() {
    // Show loading indicator while model is loading
    if (_isLoadingModel) {
      return Padding(
        padding: const EdgeInsets.all(28.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(_modelLoadStatus),
            ],
          ),
        ),
      );
    }
    if (!_modelDownloaded) {
      return Padding(
        padding: const EdgeInsets.all(28.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Model files missing for ${Models.getModel().name}"),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final hasPermission = await _requestStoragePermission();
                  if (!hasPermission) {
                    setState(() {
                      _modelLoadStatus = "Storage permission denied";
                    });
                    return;
                  }
                  final folder = await FilePicker.platform.getDirectoryPath();
                  if (folder == null || folder.isEmpty) {
                    return;
                  }
                  try {
                    await configureModelFolderSelection(folder);
                    _load();
                  } catch (e) {
                    setState(() {
                      _modelLoadStatus = "Model load failed: $e";
                    });
                  }
                },
                child: const Text('Select Model Folder'),
              ),
              const SizedBox(height: 8),
              Text(_modelLoadStatus),
            ],
          ),
        ),
      );
    }
    if (_modelLoadStatus.isEmpty) {
      return _buildChatUi();
    } else {
      return Padding(
        padding: const EdgeInsets.all(28.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(_modelLoadStatus),
            ],
          ),
        ),
      );
    }
  }

  _buildChatUi() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_userPrompt,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: _responseText.isEmpty && !_inferencing
                ? const Center(child: Text('Enter your prompt...'))
                : _responseText.isEmpty && _inferencing
                    ? const Center(child: Text('Inferencing...'))
                    : SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 48),
                        child: Text(
                          _responseText,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promptController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    labelText: 'Prompt',
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: Center(
                  child: _inferencing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(),
                        )
                      : IconButton(
                          onPressed: () {
                            _userPrompt = _promptController.text;
                            _inference();
                            _promptController.clear();
                          },
                          icon: const Icon(Icons.send),
                        ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
