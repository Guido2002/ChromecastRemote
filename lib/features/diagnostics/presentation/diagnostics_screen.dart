import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../local_diagnostics.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Local measurements')),
    body: SafeArea(
      child: ValueListenableBuilder<List<RemoteMeasurement>>(
        valueListenable: LocalDiagnostics.instance,
        builder: (context, samples, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Measurements describe this phone and connection attempts. Command dispatch measures submitting a request, not when the TV executes it. No TV names, input text, URLs, or credentials are recorded.',
            ),
            const SizedBox(height: 24),
            SelectableText(LocalDiagnostics.instance.report()),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: LocalDiagnostics.instance.report()),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Measurement summary copied.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy summary'),
            ),
            TextButton(
              onPressed: LocalDiagnostics.instance.clear,
              child: const Text('Clear measurements'),
            ),
          ],
        ),
      ),
    ),
  );
}
