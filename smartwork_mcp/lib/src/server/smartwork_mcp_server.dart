import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:smartwork_core/smartwork_core.dart';

import '../tools/discover_tool.dart';
import '../tools/doctor_tool.dart';
import '../tools/feature_tools.dart';
import '../tools/icon_tools.dart';
import '../tools/init_tools.dart';
import '../tools/model_tools.dart';
import '../tools/service_tools.dart';
import '../tools/splash_tools.dart';
import '../tools/target_tools.dart';

base class SmartworkMcpServer extends MCPServer with ToolsSupport {
  final DoctorTool _doctorTool;
  final FeatureTools _featureTools;
  final ServiceTools _serviceTools;
  final InitTools _initTools;
  final TargetTools _targetTools;
  final SplashTools _splashTools;
  final ModelTools _modelTools;
  final IconTools _iconTools;
  final DiscoverTool _discoverTool;
  final ProjectValidator _formatter;

  SmartworkMcpServer(
    super.channel, {
    DoctorTool? doctorTool,
    FeatureTools? featureTools,
    ServiceTools? serviceTools,
    InitTools? initTools,
    TargetTools? targetTools,
    SplashTools? splashTools,
    ModelTools? modelTools,
    IconTools? iconTools,
    DiscoverTool? discoverTool,
    ProjectValidator? formatter,
  })  : _doctorTool = doctorTool ?? DoctorTool(),
        _featureTools = featureTools ?? FeatureTools(),
        _serviceTools = serviceTools ?? ServiceTools(),
        _initTools = initTools ?? InitTools(),
        _targetTools = targetTools ?? TargetTools(),
        _splashTools = splashTools ?? SplashTools(),
        _modelTools = modelTools ?? ModelTools(),
        _iconTools = iconTools ?? IconTools(),
        _discoverTool = discoverTool ?? DiscoverTool(),
        _formatter = formatter ?? ProjectValidator(),
        super.fromStreamChannel(
          implementation: Implementation(
            name: 'smartwork_mcp',
            version: '0.1.0',
          ),
          instructions: 'SmartWork MCP server. Use smartwork_doctor to check '
              'environment/project readiness, smartwork_feature_add/'
              'remove to manage features, smartwork_service_add/remove '
              'to manage Production Services, '
              'smartwork_init_plan/smartwork_init_apply to initialize a '
              'new project, '
              'smartwork_target_plan/smartwork_target_apply to change '
              'an existing project\'s App Targets (plan first, then '
              'apply with confirm: true), smartwork_splash_add to '
              'add or reconfigure the Splash Screen, '
              'smartwork_model_from_json to generate Dart models from a '
              'JSON sample document into an existing feature, and '
              'smartwork_app_icon_set to generate the App Icon from a '
              'single square source image, and smartwork_discover to '
              'build a machine-readable understanding of an existing '
              'project.',
        );

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) {
    registerTool(smartworkDoctorTool, _doctorTool.call);
    registerTool(smartworkFeatureAddTool, _formatting(_featureTools.add));
    registerTool(smartworkFeatureRemoveTool, _formatting(_featureTools.remove));
    registerTool(smartworkServiceAddTool, _formatting(_serviceTools.add));
    registerTool(smartworkServiceRemoveTool, _formatting(_serviceTools.remove));
    registerTool(smartworkInitPlanTool, _initTools.plan);
    registerTool(smartworkInitApplyTool, _formatting(_initTools.apply));
    registerTool(smartworkTargetPlanTool, _targetTools.plan);
    registerTool(smartworkTargetApplyTool, _formatting(_targetTools.apply));
    registerTool(smartworkSplashAddTool, _formatting(_splashTools.add));
    registerTool(smartworkModelFromJsonTool, _formatting(_modelTools.fromJson));
    registerTool(smartworkAppIconSetTool, _formatting(_iconTools.set));
    registerTool(smartworkDiscoverTool, _discoverTool.call);
    return super.initialize(request);
  }

  /// Wraps a tool that generates code so every Dart file it writes is run
  /// through `dart format` — generated code stays formatter-clean whatever
  /// the feature/model names.
  FutureOr<CallToolResult> Function(CallToolRequest) _formatting(
    FutureOr<CallToolResult> Function(CallToolRequest) tool,
  ) {
    return (request) async {
      late CallToolResult result;
      final written = await FileWriter.recordDartWrites(() async {
        result = await tool(request);
      });
      final projectPath = request.arguments?['projectPath'] as String? ?? '.';
      await _formatter.formatDartFiles(projectPath, written);
      return result;
    };
  }
}
