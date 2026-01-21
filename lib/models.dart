class Model {
  final String name;
  final String path;
  List<String> files;

  Model(this.name, this.path, this.files);
}

class Models {
  static Model? model;

  static var phi3_5Mini = Model("Phi-3.5-Mini", "Phi35Mini", [
    'config.json',
    'genai_config.json',
    'phi-3.5-mini-instruct-cpu-int4-awq-block-128-acc-level-4.onnx',
    'phi-3.5-mini-instruct-cpu-int4-awq-block-128-acc-level-4.onnx.data',
    'special_tokens_map.json',
    'tokenizer.json',
    'tokenizer_config.json',
  ]);

  static init() {
    model = Models.phi3_5Mini;
  }

  static setModel(Model m) {
    model = m;
  }

  static Model getModel() {
    if (model == null) {
      init();
    }
    return model!;
  }
}
