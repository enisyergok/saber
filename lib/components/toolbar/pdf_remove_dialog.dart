import 'package:flutter/material.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/pdf/pdf_removal.dart';

/// Asks which PDF pages are taken out of the note: the open page's, the
/// whole PDF's, or those of every PDF in the note. Each choice says how
/// many pages it means and what happens to the ones that were written on.
///
/// Pops with the [PdfRemovalScope] that was chosen, or with nothing.
class PdfRemoveDialog extends StatelessWidget {
  const new({
    super.key,
    required this.coreInfo,
    required this.currentPageIndex,
  });

  final EditorCoreInfo coreInfo;
  final int currentPageIndex;

  @override
  Widget build(BuildContext context) {
    List<int> pagesOf(PdfRemovalScope scope) =>
        PdfRemover.pagesIn(coreInfo, scope, currentPageIndex);
    final page = pagesOf(.page);
    final document = pagesOf(.document);
    final all = pagesOf(.all);

    Widget choice(
      PdfRemovalScope scope,
      IconData icon,
      String title,
      List<int> pages,
    ) => ListTile(
      key: Key('pdfRemove-${scope.name}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        DefterStrings.pdfRemoveCounts(
          pages: pages.length,
          written: PdfRemover.writtenOn(coreInfo, pages),
        ),
      ),
      onTap: () => Navigator.of(context).pop(scope),
    );

    return AlertDialog(
      title: Text(DefterStrings.pdfRemoveTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DefterStrings.pdfRemoveAbout),
            const SizedBox(height: 8),
            if (page.isNotEmpty)
              choice(
                .page,
                Icons.insert_drive_file_outlined,
                DefterStrings.pdfRemoveThisPage,
                page,
              ),
            // The same pages as the choice above are not offered twice.
            if (document.length > page.length)
              choice(
                .document,
                Icons.picture_as_pdf_outlined,
                DefterStrings.pdfRemoveThisPdf,
                document,
              ),
            if (all.length > document.length)
              choice(
                .all,
                Icons.layers_clear_outlined,
                DefterStrings.pdfRemoveAll,
                all,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('pdfRemoveCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(DefterStrings.cancel),
        ),
      ],
    );
  }
}
