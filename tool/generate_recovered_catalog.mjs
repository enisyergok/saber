import { DatabaseSync } from 'node:sqlite';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { inflateRawSync } from 'node:zlib';

const [
  ,
  ,
  databasePath,
  outputPath,
  attachmentsDirectory,
  catalogAssetsDirectory = 'assets/goodnotes/catalog',
] = process.argv;

if (!databasePath || !outputPath || !attachmentsDirectory) {
  throw new Error(
    'Usage: node generate_recovered_catalog.mjs <projection.sqlite> <output.dart> <attachments-dir> [catalog-assets-dir]',
  );
}

const MAX_TEMPLATE_BYTES = 4 * 1024 * 1024;
const MAX_CSS_BYTES = 256 * 1024;
const MAX_EXTRACTED_BYTES = 32 * 1024 * 1024;

const assetByName = new Map([
  ['Blank', 'blank.svg'],
  ['Ruled Narrow', 'ruledNarrow.svg'],
  ['Ruled Wide', 'ruledWide.svg'],
  ['Squared Paper', 'grid.svg'],
  ['Dots', 'dottedgrid.svg'],
  ['Dotted Paper', 'dottedgrid.svg'],
  ['Legal', 'legal.svg'],
  ['Cornell', 'cornell.svg'],
  ['Single Column', 'singleColumn.svg'],
  ['Single Column Mix', 'singleColumnMix.svg'],
  ['Two Column', 'twoColumn.svg'],
  ['Two Column Left', 'twoColumnLeft.svg'],
  ['Two Column Right', 'twoColumnRight.svg'],
  ['Three Column', 'threeColumn.svg'],
]);

function uint32(bytes, offset) {
  return bytes.readUInt32LE(offset);
}

function uint16(bytes, offset) {
  return bytes.readUInt16LE(offset);
}

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) {
      crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function findEndOfCentralDirectory(bytes) {
  const minimum = Math.max(0, bytes.length - 22 - 0xffff);
  for (let offset = bytes.length - 22; offset >= minimum; offset--) {
    if (uint32(bytes, offset) === 0x06054b50) return offset;
  }
  throw new Error('ZIP end-of-central-directory record not found');
}

function decodeZipName(bytes) {
  return new TextDecoder('utf-8', { fatal: false })
    .decode(bytes)
    .replaceAll('\\', '/');
}

function readZipEntries(bytes) {
  const eocd = findEndOfCentralDirectory(bytes);
  const disk = uint16(bytes, eocd + 4);
  const centralDisk = uint16(bytes, eocd + 6);
  const entriesOnDisk = uint16(bytes, eocd + 8);
  const entries = uint16(bytes, eocd + 10);
  const centralSize = uint32(bytes, eocd + 12);
  const centralOffset = uint32(bytes, eocd + 16);
  if (disk !== 0 || centralDisk !== 0 || entriesOnDisk !== entries) {
    throw new Error('multi-disk ZIP archives are not supported');
  }
  if (entries === 0xffff || centralOffset === 0xffffffff) {
    throw new Error('ZIP64 archives are not supported');
  }
  if (centralOffset + centralSize > bytes.length) {
    throw new Error('ZIP central directory is outside the attachment');
  }

  const result = [];
  let offset = centralOffset;
  for (let index = 0; index < entries; index++) {
    if (uint32(bytes, offset) !== 0x02014b50) {
      throw new Error(`invalid ZIP central directory entry at ${offset}`);
    }
    const flags = uint16(bytes, offset + 8);
    const compression = uint16(bytes, offset + 10);
    const crc = uint32(bytes, offset + 16);
    const compressedSize = uint32(bytes, offset + 20);
    const uncompressedSize = uint32(bytes, offset + 24);
    const nameLength = uint16(bytes, offset + 28);
    const extraLength = uint16(bytes, offset + 30);
    const commentLength = uint16(bytes, offset + 32);
    const localOffset = uint32(bytes, offset + 42);
    const nameStart = offset + 46;
    const name = decodeZipName(bytes.subarray(nameStart, nameStart + nameLength));
    result.push({
      name,
      flags,
      compression,
      crc,
      compressedSize,
      uncompressedSize,
      localOffset,
    });
    offset += 46 + nameLength + extraLength + commentLength;
  }
  return result;
}

function safeZipPath(name) {
  const normalized = name.replaceAll('\\', '/');
  if (normalized.startsWith('/') || /^[A-Za-z]:\//.test(normalized)) {
    return null;
  }
  const parts = normalized.split('/');
  if (parts.some((part) => part === '' || part === '.' || part === '..')) {
    return null;
  }
  return parts.join('/');
}

function readZipEntry(bytes, entry, maxBytes) {
  if ((entry.flags & 1) !== 0) {
    throw new Error(`encrypted ZIP entry: ${entry.name}`);
  }
  if (entry.uncompressedSize > maxBytes) {
    throw new Error(`ZIP entry exceeds extraction limit: ${entry.name}`);
  }
  if (
    entry.localOffset + 30 > bytes.length ||
    uint32(bytes, entry.localOffset) !== 0x04034b50
  ) {
    throw new Error(`invalid local ZIP header: ${entry.name}`);
  }
  const localNameLength = uint16(bytes, entry.localOffset + 26);
  const localExtraLength = uint16(bytes, entry.localOffset + 28);
  const dataStart = entry.localOffset + 30 + localNameLength + localExtraLength;
  const dataEnd = dataStart + entry.compressedSize;
  if (dataEnd > bytes.length) {
    throw new Error(`ZIP entry is truncated: ${entry.name}`);
  }
  const compressed = bytes.subarray(dataStart, dataEnd);
  const data = entry.compression === 0
      ? Buffer.from(compressed)
      : entry.compression === 8
          ? inflateRawSync(compressed, { maxOutputLength: maxBytes })
          : null;
  if (data == null) {
    throw new Error(`unsupported ZIP compression: ${entry.name}`);
  }
  if (data.length !== entry.uncompressedSize || crc32(data) !== entry.crc) {
    throw new Error(`ZIP integrity check failed: ${entry.name}`);
  }
  return data;
}

function mergeDefaultCss(svg, css) {
  if (!css) return svg;
  const escaped = css.replaceAll(']]>', ']]]]><![CDATA[>');
  const style = `<style type="text/css"><![CDATA[\n${escaped}\n]]></style>`;
  const defsEnd = svg.search(/<\/defs\s*>/i);
  if (defsEnd >= 0) {
    return `${svg.slice(0, defsEnd)}${style}\n${svg.slice(defsEnd)}`;
  }
  const rootEnd = svg.indexOf('>');
  if (rootEnd < 0) throw new Error('template.svg has no root element');
  return `${svg.slice(0, rootEnd + 1)}${style}${svg.slice(rootEnd + 1)}`;
}

function field(value) {
  return String(value ?? '').replaceAll('|', ' ').replace(/[\r\n]/g, ' ');
}

const database = new DatabaseSync(resolve(databasePath), { readOnly: true });
const rows = database
  .prepare(`
    SELECT
      t.id AS template_id,
      t.document_id,
      t.attachment_id,
      t.page_number,
      t.line_height,
      t.size_width,
      t.size_height,
      t.is_flash_card,
      d.name,
      d.category,
      d.orientation,
      a.path,
      a.uti
    FROM templates t
    JOIN documents d ON d.id = t.document_id
    LEFT JOIN attachments a ON a.id = t.attachment_id
    ORDER BY t.id
  `)
  .all();
database.close();

const attachmentCache = new Map();
let extractedBytes = 0;
const assetRoot = resolve(catalogAssetsDirectory);
mkdirSync(assetRoot, { recursive: true });

function extractZipAttachment(attachmentId, attachmentPath, uti) {
  if (attachmentCache.has(attachmentId)) return attachmentCache.get(attachmentId);

  const sourcePath = resolve(attachmentsDirectory, attachmentId);
  let bytes;
  try {
    bytes = readFileSync(sourcePath);
  } catch {
    const missing = { kind: uti === 'com.goodnotes.element' ? 'element' : 'unknown' };
    attachmentCache.set(attachmentId, missing);
    return missing;
  }

  const isZip = bytes.length >= 4 && uint32(bytes, 0) === 0x04034b50;
  if (!isZip) {
    const kind = bytes.length >= 4 && bytes.subarray(0, 4).toString() === '%PDF'
        ? 'pdf'
        : uti === 'com.goodnotes.element' ? 'element' : 'binary';
    const result = { kind };
    attachmentCache.set(attachmentId, result);
    return result;
  }

  const entries = readZipEntries(bytes)
    .map((entry) => ({ ...entry, path: safeZipPath(entry.name) }))
    .filter((entry) => entry.path != null);
  const templateEntry = entries.find((entry) => entry.path === 'template.svg');
  const cssEntries = entries
    .filter(
      (entry) =>
        entry.path.startsWith('themes/') &&
        entry.path.toLowerCase().endsWith('.css'),
    )
    .sort((a, b) => a.path.localeCompare(b.path));

  const result = {
    kind: 'zipPackage',
    sourcePath: attachmentPath ?? null,
    styleAssets: [],
  };
  if (!templateEntry) {
    attachmentCache.set(attachmentId, result);
    return result;
  }

  const templateBytes = readZipEntry(bytes, templateEntry, MAX_TEMPLATE_BYTES);
  const templateText = templateBytes.toString('utf8');
  if (!/<svg(?:\s|>)/i.test(templateText)) {
    throw new Error(`ZIP template.svg is not an SVG: ${attachmentId}`);
  }

  const cssData = [];
  for (const cssEntry of cssEntries) {
    const cssBytes = readZipEntry(bytes, cssEntry, MAX_CSS_BYTES);
    extractedBytes += cssBytes.length;
    if (extractedBytes > MAX_EXTRACTED_BYTES) {
      throw new Error('safe ZIP extraction limit exceeded');
    }
    cssData.push({ entry: cssEntry, bytes: cssBytes, text: cssBytes.toString('utf8') });
  }
  extractedBytes += templateBytes.length;
  if (extractedBytes > MAX_EXTRACTED_BYTES) {
    throw new Error('safe ZIP extraction limit exceeded');
  }

  const stableName = attachmentId.toLowerCase().replace(/[^a-z0-9-]/g, '-');
  const templateFile = `${stableName}__template.svg`;
  writeFileSync(
    resolve(assetRoot, templateFile),
    mergeDefaultCss(
      templateText,
      (cssData.find(({ entry }) => /(?:^|\/)white-light\.css$/i.test(entry.path)) ?? cssData[0])
        ?.text,
    ),
  );
  result.sourceAsset = `assets/goodnotes/catalog/${templateFile}`;
  result.styleAssets = cssData.map(({ entry, bytes }, index) => {
    const baseName = entry.path
      .replaceAll('\\', '/')
      .split('/')
      .pop()
      .replace(/[^a-zA-Z0-9._-]/g, '-');
    const cssFile = `${stableName}__theme-${String(index + 1).padStart(3, '0')}-${baseName}`;
    writeFileSync(resolve(assetRoot, cssFile), bytes);
    return `assets/goodnotes/catalog/${cssFile}`;
  });
  result.extracted = true;
  attachmentCache.set(attachmentId, result);
  return result;
}

function catalogRow(row) {
  const existingSource = assetByName.get(row.name) ?? '';
  const extracted = row.attachment_id
    ? extractZipAttachment(row.attachment_id, row.path, row.uti)
    : { kind: 'unknown', styleAssets: [] };
  const sourceAsset = extracted.sourceAsset || existingSource || '';
  const kind = extracted.sourceAsset ? 'zipPackage' : existingSource ? 'svg' : extracted.kind;
  return [
    `gn-${String(row.template_id).toLowerCase()}`,
    row.document_id,
    row.name,
    row.category ?? '',
    row.orientation ?? 1,
    row.size_width ?? 0,
    row.size_height ?? 0,
    row.page_number ?? 1,
    row.line_height ?? '',
    row.is_flash_card === 1 ? 1 : 0,
    row.category === 'dynamic' ? 1 : 0,
    kind,
    row.attachment_id ?? '',
    row.path ?? '',
    sourceAsset,
    extracted.styleAssets?.join(';') ?? '',
  ].map(field).join('|');
}

const catalogData = rows.map(catalogRow).join('\n');
const extractedZipPackages = [...attachmentCache.values()].filter((value) => value.extracted).length;
const extractedCssFiles = [...attachmentCache.values()].reduce(
  (count, value) => count + (value.styleAssets?.length ?? 0),
  0,
);
const renderableCount = rows.filter((row) =>
  Boolean(assetByName.get(row.name) || attachmentCache.get(row.attachment_id)?.sourceAsset),
).length;

const output = `// GENERATED FILE. Run tool/generate_recovered_catalog.mjs to refresh.
// Source: GoodNotes projection.sqlite templates joined with documents/attachments.
// Only template.svg and themes/*.css are extracted. layout.js is never read or copied.

enum RecoveredCatalogSourceKind { svg, zipPackage, pdf, element, binary, unknown }

class RecoveredCatalogRecord {
  const RecoveredCatalogRecord({
    required this.id,
    required this.documentId,
    required this.name,
    required this.category,
    required this.orientation,
    required this.width,
    required this.height,
    required this.pageNumber,
    required this.isFlashCard,
    required this.isDynamic,
    required this.sourceKind,
    this.lineHeight,
    this.attachmentId,
    this.attachmentPath,
    this.sourceAsset,
    this.styleAssets = const [],
  });

  final String id;
  final String documentId;
  final String name;
  final String category;
  final int orientation;
  final double width;
  final double height;
  final int pageNumber;
  final double? lineHeight;
  final bool isFlashCard;
  final bool isDynamic;
  final RecoveredCatalogSourceKind sourceKind;
  final String? attachmentId;
  final String? attachmentPath;
  final String? sourceAsset;
  final List<String> styleAssets;

  bool get isRenderable => sourceAsset != null;
  String get orientationLabel => orientation == 2 ? 'yatay' : 'dikey';
  String get sourceLabel => switch (sourceKind) {
    RecoveredCatalogSourceKind.svg => 'SVG',
    RecoveredCatalogSourceKind.zipPackage => 'ZIP paket',
    RecoveredCatalogSourceKind.pdf => 'PDF',
    RecoveredCatalogSourceKind.element => 'element',
    RecoveredCatalogSourceKind.binary => 'ikili kaynak',
    RecoveredCatalogSourceKind.unknown => 'bilinmeyen kaynak',
  };
  String get metadataLabel => [
    category,
    '\${width.toStringAsFixed(0)} × \${height.toStringAsFixed(0)}',
    orientationLabel,
    sourceLabel,
    if (isFlashCard) 'çalışma kartı',
    if (isDynamic) 'dinamik',
  ].join(' • ');
}

abstract class RecoveredCatalog {
  static const sourceRecordCount = ${rows.length};
  static const _data = r'''
${catalogData}''';

  static final records = List<RecoveredCatalogRecord>.unmodifiable(
    _data.trim().split(RegExp(r'\\r?\\n')).map(_parse),
  );

  static RecoveredCatalogRecord _parse(String row) {
    final fields = row.split('|');
    if (fields.length != 16) {
      throw FormatException('Invalid recovered catalog row', row);
    }
    return RecoveredCatalogRecord(
      id: fields[0],
      documentId: fields[1],
      name: fields[2],
      category: fields[3],
      orientation: int.parse(fields[4]),
      width: double.parse(fields[5]),
      height: double.parse(fields[6]),
      pageNumber: int.parse(fields[7]),
      lineHeight: fields[8].isEmpty ? null : double.parse(fields[8]),
      isFlashCard: fields[9] == '1',
      isDynamic: fields[10] == '1',
      sourceKind: RecoveredCatalogSourceKind.values.byName(fields[11]),
      attachmentId: fields[12].isEmpty ? null : fields[12],
      attachmentPath: fields[13].isEmpty ? null : fields[13],
      sourceAsset: fields[14].isEmpty ? null : fields[14],
      styleAssets: fields[15].isEmpty ? const [] : fields[15].split(';'),
    );
  }

  static int get flashCardCount =>
      records.where((record) => record.isFlashCard).length;
  static int get dynamicCount =>
      records.where((record) => record.isDynamic).length;
  static int get renderableCount =>
      records.where((record) => record.isRenderable).length;
  static int get portablePackageCount => records
      .where((record) => record.sourceKind == RecoveredCatalogSourceKind.zipPackage)
      .length;
  static int get extractedPackageCount => records
      .where((record) =>
          record.sourceKind == RecoveredCatalogSourceKind.zipPackage &&
          record.isRenderable)
      .length;
}
`;

mkdirSync(dirname(resolve(outputPath)), { recursive: true });
writeFileSync(resolve(outputPath), output, 'utf8');
console.log(JSON.stringify({
  records: rows.length,
  flashCards: rows.filter((row) => row.is_flash_card === 1).length,
  dynamic: rows.filter((row) => row.category === 'dynamic').length,
  renderable: renderableCount,
  zipAttachments: [...attachmentCache.values()].filter((value) => value.kind === 'zipPackage').length,
  extractedZipPackages,
  extractedTemplateSvgs: extractedZipPackages,
  extractedCssFiles,
  extractedBytes,
  output: resolve(outputPath),
  assets: assetRoot,
}));
