import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

class SshService {
  SSHSocket? _socket;
  SSHClient? _client;

  bool get isConnected => _client != null;

  Future<void> connect({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    await disconnect();

    _socket = await SSHSocket.connect(host, port, timeout: const Duration(seconds: 8));
    _client = SSHClient(
      _socket!,
      username: username,
      onPasswordRequest: () => password,
    );
  }

  Future<String> runCommand(String command) async {
    final client = _client;
    if (client == null) {
      throw StateError('SSH client is not connected');
    }

    final output = await client.run(command);
    return utf8.decode(output).trim();
  }

  Future<void> disconnect() async {
    _client?.close();
    _client = null;

    await _socket?.close();
    _socket = null;
  }
}
