import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saber/data/defter_strings.dart';

/// Shows the result of a pen latency recording, ready to copy.
class PenLatencyDialog extends StatelessWidget {
  const PenLatencyDialog({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(DefterStrings.penProbeResult),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(DefterStrings.penProbeCopied)),
            );
          },
          child: Text(DefterStrings.penProbeCopy),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}
