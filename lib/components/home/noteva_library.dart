import 'package:flutter/material.dart';

import 'package:saber/components/home/library_glyph.dart';
import 'package:saber/components/theming/defter_design.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/notebooks/paper_templates.dart';

/// Presentation shared by the real library and the visual review harness.
/// File access and navigation are supplied by the application, never simulated.
class LibraryDocument {
  const LibraryDocument({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.folder = false,
    this.favorite = false,
    this.modified,
    this.cover,
  });
  final String id, title, subtitle;
  final bool folder, favorite;
  final DateTime? modified;
  final Widget? cover;
}

class NotevaLibrary extends StatefulWidget {
  const NotevaLibrary({
    super.key,
    required this.documents,
    required this.onOpen,
    required this.onCreate,
    required this.onFavorite,
    required this.onSearch,
    required this.onFavorites,
    required this.onTemplates,
    required this.onSettings,
    required this.onImport,
    required this.onImportPdf,
    required this.onAddImage,
    required this.onNewFolder,
    this.onTemplateGroup,
    this.loading = false,
  });
  final List<LibraryDocument> documents;
  final ValueChanged<LibraryDocument> onOpen, onFavorite;
  final VoidCallback onCreate,
      onSearch,
      onFavorites,
      onTemplates,
      onSettings,
      onImport,
      onImportPdf,
      onAddImage,
      onNewFolder;
  final ValueChanged<PaperGroup>? onTemplateGroup;
  final bool loading;

  @override
  State<NotevaLibrary> createState() => _NotevaLibraryState();
}

class _NotevaLibraryState extends State<NotevaLibrary> {
  static const blue = DefterDesign.gnBlue;
  bool sidebar = true, grid = false, selecting = false;
  int sort = 0;
  final selected = <String>{};

  Widget button(IconData icon, String label, VoidCallback action) => IconButton(
    tooltip: label,
    onPressed: action,
    icon: LibraryGlyph(icon),
    style: IconButton.styleFrom(
      foregroundColor: blue,
      minimumSize: const Size(44, 44),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Keep the approved library appearance independent of Android dark mode.
    const background = Colors.white;
    const rail = DefterDesign.gnLibraryRail;
    const line = DefterDesign.gnDivider;
    const ink = DefterDesign.gnText;
    final documents = [...widget.documents]
      ..sort(
        (a, b) => switch (sort) {
          1 => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          2 =>
            a.folder == b.folder
                ? a.title.compareTo(b.title)
                : (a.folder ? -1 : 1),
          _ => (b.modified ?? DateTime(1970)).compareTo(
            a.modified ?? DateTime(1970),
          ),
        },
      );
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.light,
        ),
        dividerColor: line,
        textTheme: Theme.of(context).textTheme
            .apply(bodyColor: ink, displayColor: ink),
      ),
      child: Material(
        color: background,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              final showRail = wide && sidebar;
              Widget nav(
                IconData icon,
                String text,
                VoidCallback? action, {
                bool active = false,
              }) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Material(
                  color: active
                      ? DefterDesign.gnSelectedSurface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  child: ListTile(
                    minTileHeight: 41,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 9),
                    leading: LibraryGlyph(icon, color: ink),
                    horizontalTitleGap: 10,
                    title: Text(text, style: const TextStyle(fontSize: 16)),
                    onTap: action,
                  ),
                ),
              );
              final navigation = ColoredBox(
                color: rail,
                child: SizedBox(
                  width: (constraints.maxWidth * .271).clamp(220.0, 300.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 0, 0),
                        child: button(
                          Icons.space_dashboard_outlined,
                          'Kenar çubuğunu gizle',
                          () => setState(() => sidebar = false),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 10, 14, 5),
                        child: Text(
                          'Noteva',
                          style: TextStyle(
                            fontSize: 29,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      nav(
                        Icons.folder_outlined,
                        'Belgeler',
                        () {},
                        active: true,
                      ),
                      nav(
                        Icons.bookmark_border,
                        'Favoriler',
                        widget.onFavorites,
                      ),
                      nav(Icons.search, 'Ara', widget.onSearch),
                      Tooltip(
                        message: 'Paylaşılan belge hizmeti henüz bağlı değil',
                        child: nav(Icons.people_outline, 'Paylaşılanlar', null),
                      ),
                      nav(
                        Icons.storefront_outlined,
                        'Şablonlar',
                        widget.onTemplates,
                      ),
                    ],
                  ),
                ),
              );
              return Row(
                children: [
                  if (showRail) ...[
                    navigation,
                    SizedBox(width: 1, child: ColoredBox(color: line)),
                  ],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 64,
                            child: Row(
                              children: [
                                if (!showRail && wide)
                                  button(
                                    Icons.space_dashboard_outlined,
                                    'Kenar çubuğunu göster',
                                    () => setState(() => sidebar = true),
                                  ),
                                if (!wide) ...[
                                  button(Icons.search, 'Ara', widget.onSearch),
                                  button(
                                    Icons.bookmark_border,
                                    'Favoriler',
                                    widget.onFavorites,
                                  ),
                                ],
                                const Spacer(),
                                button(
                                  Icons.notifications_none,
                                  'Bildirimler',
                                  () => showDialog<void>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Bildirimler'),
                                      content: const Text('Yeni bildirim yok.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Tamam'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                button(
                                  Icons.settings_outlined,
                                  'Ayarlar',
                                  widget.onSettings,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Belgeler',
                            key: const Key('libraryTitle'),
                            style: TextStyle(
                              fontSize: wide ? 29 : 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.7,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Divider(height: 1, color: line),
                          SizedBox(
                            height: 48,
                            child: Row(
                              children: [
                                if (wide) const Spacer(),
                                Container(
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: rail,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var i = 0; i < 3; i++)
                                        InkWell(
                                          onTap: () => setState(() => sort = i),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: Container(
                                            width: wide ? 58 : 52,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: sort == i
                                                  ? background
                                                  : null,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              boxShadow: sort == i
                                                  ? [
                                                      const BoxShadow(
                                                        color: Color(
                                                          0x18000000,
                                                        ),
                                                        blurRadius: 3,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Text(
                                              ['Tarih', 'Ad', 'Tür'][i],
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                button(
                                  selecting
                                      ? Icons.check_circle
                                      : Icons.check_circle_outline,
                                  'Belgeleri seç',
                                  () => setState(() {
                                    selecting = !selecting;
                                    selected.clear();
                                  }),
                                ),
                                button(
                                  grid
                                      ? Icons.grid_view
                                      : Icons.format_list_bulleted,
                                  'Görünümü değiştir',
                                  () => setState(() => grid = !grid),
                                ),
                              ],
                            ),
                          ),
                          if (selecting)
                            Row(
                              children: [
                                Text('${selected.length} seçildi'),
                                const Spacer(),
                                TextButton(
                                  onPressed: selected.isEmpty
                                      ? null
                                      : () {
                                          for (final doc in documents.where(
                                            (d) =>
                                                selected.contains(d.id) &&
                                                !d.folder,
                                          )) {
                                            widget.onFavorite(doc);
                                          }
                                          setState(() {
                                            selecting = false;
                                            selected.clear();
                                          });
                                        },
                                  child: const Text('Favorilere ekle / çıkar'),
                                ),
                              ],
                            ),
                          if (widget.loading)
                            const LinearProgressIndicator(minHeight: 2),
                          if (!widget.loading &&
                              !documents.any((doc) => !doc.folder))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(DefterStrings.noRecentNotes),
                            ),
                          Expanded(
                            child: grid
                                ? GridView.builder(
                                    padding: const EdgeInsets.only(top: 12),
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 180,
                                          mainAxisExtent: 200,
                                          crossAxisSpacing: 24,
                                          mainAxisSpacing: 16,
                                        ),
                                    itemCount: documents.length + 1,
                                    itemBuilder: (context, index) => index == 0
                                        ? _createTile(true)
                                        : _gridTile(documents[index - 1]),
                                  )
                                : ListView.separated(
                                    itemCount: documents.length + 1,
                                    separatorBuilder: (_, _) =>
                                        Divider(height: 1, color: line),
                                    itemBuilder: (_, index) => index == 0
                                        ? _createTile(false)
                                        : _row(documents[index - 1]),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void open(LibraryDocument doc) {
    if (selecting) {
      setState(() {
        if (!selected.add(doc.id)) selected.remove(doc.id);
      });
    } else {
      widget.onOpen(doc);
    }
  }

  Widget cover(LibraryDocument doc, {bool large = false}) => SizedBox(
    width: large ? 100 : 54,
    height: large ? 130 : 64,
    child: Center(
      child:
          doc.cover ??
          (doc.folder
              ? LibraryGlyph(
                  Icons.folder,
                  color: const Color(0xfff0b66e),
                  size: large ? 96 : 58,
                )
              : Container(
                  width: large ? 92 : 36,
                  height: large ? 124 : 48,
                  decoration: BoxDecoration(
                    color: const Color(0xffe8edcf),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: const Color(0xffbdc6a4)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 3,
                        offset: Offset(1, 2),
                      ),
                    ],
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(width: 3, color: const Color(0xffc5cfa9)),
                  ),
                )),
    ),
  );

  Widget _row(LibraryDocument doc) => InkWell(
    onTap: () => open(doc),
    child: SizedBox(
      height: 73,
      child: Row(
        children: [
          if (selecting)
            Checkbox(
              value: selected.contains(doc.id),
              onChanged: (_) => open(doc),
            ),
          cover(doc),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  doc.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: blue, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  doc.subtitle,
                  style: const TextStyle(
                    color: Color(0xff929292),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Belge işlemleri',
            icon: const LibraryGlyph(Icons.keyboard_arrow_down, color: blue),
            onSelected: (value) =>
                value == 'open' ? widget.onOpen(doc) : widget.onFavorite(doc),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'open', child: Text('Aç')),
              if (!doc.folder)
                PopupMenuItem(
                  value: 'favorite',
                  child: Text(
                    doc.favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
                  ),
                ),
            ],
          ),
          if (!doc.folder)
            button(
              doc.favorite ? Icons.star : Icons.star_border,
              'Favori',
              () => widget.onFavorite(doc),
            )
          else
            button(Icons.chevron_right, 'Klasörü aç', () => widget.onOpen(doc)),
        ],
      ),
    ),
  );

  Widget _gridTile(LibraryDocument doc) => InkWell(
    onTap: () => open(doc),
    child: Column(
      children: [
        cover(doc, large: true),
        const SizedBox(height: 8),
        Text(
          doc.title,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: blue),
        ),
        Text(
          doc.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        if (selecting)
          SizedBox(
            height: 22,
            child: Checkbox(
              value: selected.contains(doc.id),
              onChanged: (_) => open(doc),
            ),
          ),
      ],
    ),
  );

  Widget _createTile(bool large) {
    final icon = CustomPaint(
      painter: const _DashedOutline(),
      child: SizedBox(
        width: large ? 92 : 46,
        height: large ? 124 : 56,
        child: const Center(
          child: LibraryGlyph(Icons.add, size: 24, color: blue),
        ),
      ),
    );
    final tile = large
        ? Column(
            children: [
              icon,
              const SizedBox(height: 10),
              const Text('Yeni …', style: TextStyle(color: blue)),
            ],
          )
        : SizedBox(
            height: 78,
            child: Row(
              children: [
                const SizedBox(width: 8),
                icon,
                const SizedBox(width: 14),
                const Text(
                  'Yeni …',
                  style: TextStyle(color: blue, fontSize: 14),
                ),
              ],
            ),
          );
    return PopupMenuButton<String>(
      key: const Key('libraryCreateMenu'),
      onSelected: (value) => switch (value) {
        'new' => widget.onCreate(),
        'template' => widget.onTemplates(),
        'pdf' => widget.onImportPdf(),
        'image' => widget.onAddImage(),
        'folder' => widget.onNewFolder(),
        'note' => widget.onImport(),
        _ => null,
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'new', child: Text(DefterStrings.actionNewNote)),
        PopupMenuItem(
          value: 'template',
          child: Text(DefterStrings.actionFromTemplate),
        ),
        PopupMenuItem(value: 'pdf', child: Text(DefterStrings.actionImportPdf)),
        PopupMenuItem(
          value: 'image',
          child: Text(DefterStrings.actionAddImage),
        ),
        PopupMenuItem(
          value: 'folder',
          child: Text(DefterStrings.actionNewFolder),
        ),
        PopupMenuItem(
          value: 'note',
          child: Text(DefterStrings.actionImportNote),
        ),
      ],
      child: tile,
    );
  }
}

class _DashedOutline extends CustomPainter {
  const _DashedOutline();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5)),
      );
    final paint = Paint()
      ..color = const Color(0xff4485bf)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 6) {
        canvas.drawPath(metric.extractPath(start, start + 2.6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline oldDelegate) => false;
}
