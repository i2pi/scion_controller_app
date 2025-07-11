// lib/network_connection_section.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'network.dart';
import 'nsd_client.dart';

class NetworkConnectionSection extends StatefulWidget {
  const NetworkConnectionSection({super.key});

  @override
  State<NetworkConnectionSection> createState() =>
      _NetworkConnectionSectionState();
}

class _NetworkConnectionSectionState extends State<NetworkConnectionSection> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _discovering = false;

  static const _prefKey = 'recent_endpoints';
  static const _maxRecents = 5;

  List<String> _recents = [];
  List<String> _discovered = [];

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefKey) ?? <String>[];
    setState(() {
      _recents = list;
      _controller.text = _recents.isNotEmpty ? _recents.first : '192.168.2.75';
    });
  }

  Future<void> _saveRecent(String host, int port) async {
    final entry = port == 9000 ? host : '$host:$port';
    _recents.remove(entry);
    _recents.insert(0, entry);
    if (_recents.length > _maxRecents) _recents.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKey, _recents);
  }

  Future<void> _connectTo(String input) async {
    final parts = input.split(':');
    if (parts.isEmpty || parts[0].isEmpty) {
      await _showError('Enter a valid host');
      return;
    }
    final host = parts[0];
    final port = (parts.length == 2) ? int.tryParse(parts[1]) ?? 9000 : 9000;

    final net = context.read<Network>();
    try {
      if (net.isConnected) net.disconnect();
      await net.connect(host, port);
      await _saveRecent(host, port);
    } on TimeoutException {
      await _showError('Connection timed out');
    } catch (e) {
      await _showError(e.toString());
    }
  }

  Future<void> _findServices() async {
    setState(() => _discovering = true);

    List<NetworkAddress> services = [];
    try {
      services = await NSDClient()
          .discover()
          .timeout(
            NSDClient().scanDuration + const Duration(seconds: 1),
            onTimeout: () => <NetworkAddress>[],
          );
    } catch (e) {
      if (mounted) setState(() => _discovering = false);
      await _showError('Discovery failed: $e');
      return;
    }

    if (!mounted) return;
    setState(() => _discovering = false);

    if (services.isEmpty) {
      await _showError('No devices found on your local network');
      return;
    }

    final addresses = services.map((s) => '${s.host}:${s.port}').toList();
    setState(() {
      _controller.text = addresses.first;
      _discovered = addresses.length > 1 ? addresses.sublist(1) : [];
    });

    if (addresses.length == 1) {
      await _connectTo(addresses.first);
    } else if (_discovered.isNotEmpty) {
      _focusNode.requestFocus();
    }
  }

  Future<void> _showError(String message) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final network = context.watch<Network>();

    return TypeAheadFormField<String>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: 'Network address',
          hintText: 'e.g. 192.168.10.27, or server.superchromat.com:9010',
          border: const OutlineInputBorder(),
          suffixIcon: _discovering
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : network.isConnecting
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _discovering ? null : _findServices,
                    ),
        ),
        style: const TextStyle(fontFamily: 'monospace'),
        onSubmitted: network.isConnecting
            ? null
            : (val) => _connectTo(val.trim()),
      ),
      suggestionsCallback: (pattern) async {
        final suggestions = List<String>.from(_discovered);
        suggestions.addAll(
          _recents.where(
            (e) => e.toLowerCase().contains(pattern.toLowerCase()),
          ),
        );
        return suggestions;
      },
      itemBuilder: (context, String suggestion) =>
          ListTile(title: Text(suggestion)),
      onSuggestionSelected: (String suggestion) {
        _controller.text = suggestion;
        _connectTo(suggestion);
      },
      hideOnEmpty: false,
      minCharsForSuggestions: 0,
      noItemsFoundBuilder: (_) => const SizedBox.shrink(),
    );
  }
}
