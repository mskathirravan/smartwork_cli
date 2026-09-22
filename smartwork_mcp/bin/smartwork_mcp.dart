import 'dart:io';

import 'package:dart_mcp/stdio.dart';
import 'package:smartwork_mcp/smartwork_mcp.dart';

void main() {
  SmartworkMcpServer(stdioChannel(input: stdin, output: stdout));
}
