import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ebike_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _telemetryCommandController;
  late final TextEditingController _controlTemplateController;

  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<EbikeProvider>();
    _hostController = TextEditingController(text: provider.host);
    _portController = TextEditingController(text: provider.port.toString());
    _usernameController = TextEditingController(text: provider.username);
    _passwordController = TextEditingController(text: provider.password);
    _telemetryCommandController =
        TextEditingController(text: provider.telemetryCommand);
    _controlTemplateController =
        TextEditingController(text: provider.controlTemplate);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _telemetryCommandController.dispose();
    _controlTemplateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EbikeProvider>(
      builder: (context, provider, _) {
        _hydrate(provider);
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'SSH Connection',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _input(_hostController, 'Bike Local IP'),
              _input(_portController, 'SSH Port', number: true),
              _input(_usernameController, 'Username'),
              _input(_passwordController, 'Password', secure: true),
              _input(_telemetryCommandController, 'Telemetry Command'),
              _input(
                _controlTemplateController,
                'Control Template (use {action})',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: provider.isConnecting
                        ? null
                        : () async {
                            _save(provider);
                            if (provider.isConnected) {
                              await provider.disconnect();
                            } else {
                              await provider.connect();
                            }
                          },
                    child: Text(provider.isConnected ? 'Disconnect' : 'Connect'),
                  ),
                  OutlinedButton(
                    onPressed: () => _save(provider),
                    child: const Text('Save Settings'),
                  ),
                  OutlinedButton(
                    onPressed: provider.isConnected
                        ? () async => provider.refreshTelemetry()
                        : null,
                    child: const Text('Refresh Telemetry'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Status: ${provider.statusMessage}'),
            ],
          ),
        );
      },
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    bool secure = false,
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: secure,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFF0D162E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A284A)),
          ),
        ),
      ),
    );
  }

  void _save(EbikeProvider provider) {
    provider.updateConnectionSettings(
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 22,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      telemetryCommand: _telemetryCommandController.text.trim(),
      controlTemplate: _controlTemplateController.text.trim(),
    );
  }

  void _hydrate(EbikeProvider provider) {
    if (_hydrated || !provider.settingsLoaded) {
      return;
    }
    _hostController.text = provider.host;
    _portController.text = provider.port.toString();
    _usernameController.text = provider.username;
    _passwordController.text = provider.password;
    _telemetryCommandController.text = provider.telemetryCommand;
    _controlTemplateController.text = provider.controlTemplate;
    _hydrated = true;
  }
}
