import '../template.dart';

class GetxTemplates {
  static Template controllerTemplate(String featureName, String pascalName) {
    return Template(content: '''import 'package:get/get.dart';

class {{pascalName}}Controller extends GetxController {
  final isLoading = false.obs;

  Future<void> load{{pascalName}}() async {
    isLoading.value = true;
    // TODO: implement {{featureName}} logic
    isLoading.value = false;
  }
}
''');
  }
}
