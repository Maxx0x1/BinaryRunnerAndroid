import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const OneScreenApp());

class OneScreenApp extends StatelessWidget {
  const OneScreenApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2B6BE3), // Samsung-like blue
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'binaryRunnerAndroid',
      debugShowCheckedModeBanner: false,
      home: const OneScreen(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        cardTheme: const CardThemeData().copyWith(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.zero,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: colorScheme.surface,
          contentTextStyle: TextStyle(color: colorScheme.onSurface),
        ),
      ),
    );
  }
}

class OneScreen extends StatefulWidget {
  const OneScreen({super.key});

  @override
  State<OneScreen> createState() => _OneScreenState();
}

class _OneScreenState extends State<OneScreen> {
  final _pathCtrl = TextEditingController(text: '/data/local/tmp');
  final _binCtrl = TextEditingController();
  final List<_ArgRow> _args = [_ArgRow()];

  bool _isRunning = false;
  String _stdout = '';
  String _stderr = '';
  int? _exitCode;
  bool _useSu = false;

  static const _channel = MethodChannel('com.example.binaryrunner/runner');

  @override
  void dispose() {
    _pathCtrl.dispose();
    _binCtrl.dispose();
    for (final a in _args) {
      a.dispose();
    }
    super.dispose();
  }

  List<String> _buildArgs() {
    final result = <String>[];
    for (final a in _args) {
      final name = a.nameCtrl.text.trim();
      final value = a.valueCtrl.text.trim();
      if (name.isEmpty && value.isEmpty) continue;
      if (name.isNotEmpty) {
        final flag = name.startsWith('-') ? name : '--$name';
        result.add(flag);
      }
      if (value.isNotEmpty) {
        result.add(value);
      }
    }
    return result;
  }

  Future<void> _run() async {
    final path = _pathCtrl.text.trim();
    final bin = _binCtrl.text.trim();
    if (bin.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill binary name.')));
      return;
    }

    setState(() {
      _isRunning = true;
      _stdout = '';
      _stderr = '';
      _exitCode = null;
    });

    final args = _buildArgs();
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'runBinary',
        {'path': path, 'binaryName': bin, 'args': args, 'useSu': _useSu},
      );

      setState(() {
        _isRunning = false;
        _stdout = (res?['stdout'] ?? '').toString();
        _stderr = (res?['stderr'] ?? '').toString();
        _exitCode = res?['exitCode'] as int?;
      });
    } on PlatformException catch (e) {
      setState(() {
        _isRunning = false;
        _stderr = 'Platform error: ${e.message}\n${e.details ?? ''}';
      });
    } catch (e) {
      setState(() {
        _isRunning = false;
        _stderr = 'Unexpected error: $e';
      });
    }
  }

  Future<void> _stop() async {
    try {
      await _channel.invokeMethod('stopBinary');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mono = const TextStyle(fontFamily: 'monospace', fontSize: 13);

    return Scaffold(
      appBar: AppBar(title: const Text('binaryRunnerAndroid')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Run binaries on device',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),

                  // Target binary section
                  _SectionCard(
                    title: 'Target binary',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _pathCtrl,
                          decoration: const InputDecoration(
                            labelText: 'path',
                            hintText: '/data/local/tmp or /system/bin',
                            prefixIcon: Icon(Icons.folder_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _binCtrl,
                          decoration: const InputDecoration(
                            labelText: 'binary_name',
                            hintText: 'mytool',
                            prefixIcon: Icon(Icons.adb_outlined),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SwitchListTile.adaptive(
                          title: const Text('Run via su (root)'),
                          value: _useSu,
                          onChanged: (v) => setState(() => _useSu = v),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Arguments section
                  _SectionCard(
                    title: 'Arguments',
                    action: OutlinedButton.icon(
                      onPressed: () => setState(() => _args.add(_ArgRow())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add argument'),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        foregroundColor: cs.primary,
                      ),
                    ),
                    child: Column(
                      children: [
                        ..._args.asMap().entries.map((e) {
                          final idx = e.key;
                          final row = e.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: row.nameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'arg_name (e.g. threads)',
                                      hintText:
                                          'leave empty to pass only value',
                                      prefixText: '--',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: row.valueCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'arg_value',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _args.length > 1
                                      ? () => setState(() {
                                          final removed = _args.removeAt(idx);
                                          removed.dispose();
                                        })
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                  tooltip: 'Remove',
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_isRunning) const LinearProgressIndicator(minHeight: 3),
                  if (_exitCode != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text('Exit code: $_exitCode'),
                          avatar: Icon(
                            _exitCode == 0
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color: _exitCode == 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (_stdout.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _SectionCard(
                      title: 'stdout',
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(_stdout, style: mono),
                      ),
                    ),
                  ],

                  if (_stderr.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _SectionCard(
                      title: 'stderr',
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          _stderr,
                          style: mono.copyWith(color: cs.onErrorContainer),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _isRunning ? null : _run,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Run'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                  onPressed: _isRunning ? _stop : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArgRow {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController valueCtrl = TextEditingController();
  void dispose() {
    nameCtrl.dispose();
    valueCtrl.dispose();
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _SectionCard({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
