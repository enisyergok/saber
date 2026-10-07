import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_circle_stroke.dart';
import 'package:saber/components/canvas/_rectangle_stroke.dart';
import 'package:saber/data/extensions/list_extensions.dart';
import 'package:saber/data/extensions/point_extensions.dart';
import 'package:sbn/has_size.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'package:sbn/tool_id.dart';

/// A point of the line a stroke is drawn along, and half the width of the
/// ink there.
typedef InkPoint = ({Offset at, double radius});

class Stroke {
  static final log = Logger('Stroke');

  @visibleForTesting
  @protected
  final List<PointVector> points = [];

  bool get isEmpty => points.isEmpty;
  int get length => points.length;

  int pageIndex;
  HasSize page;
  final ToolId toolId;

  static const defaultColor = Colors.black;
  static const defaultPressureEnabled = true;

  Color color;
  bool pressureEnabled;
  final StrokeOptions options;

  List<Offset>? _lowQualityPolygon, _highQualityPolygon;
  List<Offset> get lowQualityPolygon =>
      _lowQualityPolygon ??= getPolygon(quality: .low);
  List<Offset> get highQualityPolygon =>
      _highQualityPolygon ??= getPolygon(quality: .high);

  /// The bounding box of [lowQualityPolygon], cached.
  /// Lets tools skip strokes that are nowhere near them.
  Rect? _bounds;
  Rect get bounds => _bounds ??= _boundsOf(lowQualityPolygon);

  static Rect _boundsOf(List<Offset> polygon) {
    if (polygon.isEmpty) return Rect.zero;
    var left = polygon.first.dx, right = left;
    var top = polygon.first.dy, bottom = top;
    for (final point in polygon) {
      if (point.dx < left) left = point.dx;
      if (point.dx > right) right = point.dx;
      if (point.dy < top) top = point.dy;
      if (point.dy > bottom) bottom = point.dy;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Path? _lowQualityPath, _highQualityPath;
  Path get lowQualityPath =>
      _lowQualityPath ??= getPath(lowQualityPolygon, smooth: false);
  Path get highQualityPath => _highQualityPath ??= getPath(highQualityPolygon);

  void shift(Offset offset) {
    if (offset == .zero) return;

    points.shift(offset);
    _lowQualityPolygon?.shift(offset);
    _highQualityPolygon?.shift(offset);
    _bounds = _bounds?.shift(offset);
    _lowQualityPath = _lowQualityPath?.shift(offset);
    _highQualityPath = _highQualityPath?.shift(offset);
  }

  /// Whether [transform] can rotate this stroke (rectangles can't).
  bool get canRotate => true;

  /// Applies [matrix], which may scale (uniformly), rotate and translate, to
  /// the stroke. Its thickness is scaled along with it.
  /// Undo it by applying the inverse matrix.
  void transform(Matrix4 matrix) {
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final moved = MatrixUtils.transformPoint(matrix, Offset(point.x, point.y));
      points[i] = PointVector(moved.dx, moved.dy, point.pressure);
    }
    options.size *= scaleOfMatrix(matrix);
    markPolygonNeedsUpdating();
  }

  /// How much [matrix] scales lengths (the matrix is assumed to be uniform).
  static double scaleOfMatrix(Matrix4 matrix) => sqrt(
    (matrix.entry(0, 0) * matrix.entry(1, 1) -
            matrix.entry(0, 1) * matrix.entry(1, 0))
        .abs(),
  );

  void markPolygonNeedsUpdating() {
    _bounds = null;
    _lowQualityPolygon = null;
    _highQualityPolygon = null;
    _lowQualityPath = null;
    _highQualityPath = null;
  }

  new({
    required this.color,
    required this.pressureEnabled,
    required this.options,
    required this.pageIndex,
    required this.page,
    required this.toolId,
  });

  factory fromJson(
    Map<String, dynamic> json, {
    required int fileVersion,
    required int pageIndex,
    required HasSize page,
  }) {
    assert(json['i'] == pageIndex || json['i'] == null);
    switch (json['shape'] as String?) {
      case null:
        break;
      case 'circle':
        return CircleStroke.fromJson(
          json,
          fileVersion: fileVersion,
          pageIndex: pageIndex,
          page: page,
        );
      case 'rect':
        return RectangleStroke.fromJson(
          json,
          fileVersion: fileVersion,
          pageIndex: pageIndex,
          page: page,
        );
      default:
        log.severe('Unknown shape: ${json['shape']}');
    }

    final ToolId toolId = .parsePenType(json['ty'], fallback: .fountainPen);

    final options = StrokeOptions.fromJson(json);
    final pressureEnabled = json['pe'] ?? defaultPressureEnabled;
    if (toolId == .shapePen) {
      // Set smoothing and streamline to 0 for ShapePen
      // to mitigate https://github.com/saber-notes/saber/issues/1587
      options.smoothing = 0;
      options.streamline = 0;
    }

    final Color color;
    switch (json['c']) {
      case (final int value):
        color = Color(value);
      case (final Int64 value):
        color = Color(value.toInt());
      case null:
        color = defaultColor;
      default:
        throw Exception(
          'Invalid color value: (${json['c'].runtimeType}) ${json['c']}',
        );
    }

    final offset = Offset(json['ox'] ?? 0, json['oy'] ?? 0);
    final pointsJson = json['p'] as List<dynamic>;
    final Iterable<PointVector> points;
    if (fileVersion >= 13) {
      points = pointsJson.map(
        (point) => PointExtensions.fromBsonBinary(json: point, offset: offset),
      );
    } else {
      points = pointsJson.map(
        // ignore: deprecated_member_use_from_same_package
        (point) => PointExtensions.fromJson(
          json: Map<String, dynamic>.from(point),
          offset: offset,
        ),
      );
    }

    return Stroke(
      color: color,
      pressureEnabled: pressureEnabled,
      options: options,
      pageIndex: pageIndex,
      page: page,
      toolId: toolId,
    )..points.addAll(points);
  }
  Map<String, dynamic> toJson() {
    // these json keys should not be the same as the ones in [StrokeOptions.toJson]
    return {
      'shape': null,
      'p': points
          .where((point) => point.isFinite)
          .map((PointVector point) => point.toBsonBinary())
          .toList(),
      'i': pageIndex,
      'ty': toolId.id,
      'pe': pressureEnabled,
      'c': color.toARGB32(),
    }..addAll(options.toJson());
  }

  void addPoint(Offset point, [double? pressure]) {
    if (!pressureEnabled) {
      pressure = null;
    } else if (pressure != null) {
      options.simulatePressure = false;
    }

    points.add(PointVector(point.dx, point.dy, pressure));
    markPolygonNeedsUpdating();
  }

  /// Makes this a straight line of even width from [a] to [b]: what the
  /// ruler draws while the pen is still down.
  void setLine(Offset a, Offset b) {
    points
      ..clear()
      ..add(PointVector(a.dx, a.dy, 0.5))
      ..add(PointVector(b.dx, b.dy, 0.5));
    options.simulatePressure = false;
    markPolygonNeedsUpdating();
  }

  /// The distance along the line, from its first point to its last.
  double get pathLength {
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      length += sqrt(points[i].distanceSquaredTo(points[i - 1]));
    }
    return length;
  }

  void addPoints(List<Offset> points) {
    for (final point in points) {
      addPoint(point);
    }
  }

  void popFirstPoint() {
    points.removeAt(0);
    markPolygonNeedsUpdating();
  }

  /// Points that are closer than this
  /// threshold multiplied by the stroke's size
  /// will be counted as duplicates.
  static const _optimisePointsThreshold = 0.1;

  /// Removes points that are too close together. See [_optimisePointsThreshold].
  ///
  /// This function is idempotent, so running it multiple times
  /// will not change the result.
  ///
  /// This function does not change [_polygonNeedsUpdating].
  void optimisePoints({double thresholdMultiplier = _optimisePointsThreshold}) {
    if (points.length <= 3) return;

    final minDistance = options.size * thresholdMultiplier;

    // Remove points with null pressure because they were duplicates
    points.removeWhere((point) => point.pressure == null);

    for (int i = 1; i < points.length - 1; i++) {
      final point = points[i];
      final prev = points[i - 1];
      final next = points[i + 1];

      if (prev.distanceSquaredTo(point) < minDistance * minDistance &&
          point.distanceSquaredTo(next) < minDistance * minDistance) {
        points.removeAt(i);
        i--;
      }
    }
  }

  @protected
  List<Offset> getPolygon({required StrokeQuality quality}) {
    if (!pressureEnabled) {
      options.simulatePressure = false;
    }
    final rememberSimulatedPressure =
        quality == .high && options.simulatePressure && options.isComplete;

    // A shape with corners is drawn from points along its sides, not from
    // its corners alone: two sharp corners in a row leave the side between
    // them a thin wedge otherwise.
    final List<PointVector> source;
    if (_isDrawnFromCorners &&
        points.length > 3 &&
        options.streamline == 0 &&
        !options.simulatePressure) {
      final spacing = inkLineSpacing(options.size);
      source = _alongSides(points, quality == .low ? spacing * 4 : spacing);
    } else {
      source = skipPoints(points, quality.N);
    }

    final polygon = getStroke(
      source,
      options: switch (quality) {
        .low => options.copyWith(
          simulatePressure: false,
          smoothing: 0,
          streamline: 0,
        ),
        .high => options,
      },
      rememberSimulatedPressure: rememberSimulatedPressure,
    );

    if (rememberSimulatedPressure) {
      // Ensure we don't simulate pressure again
      options.simulatePressure = false;
      // Remove points that are too close together
      optimisePoints();
    }

    return polygon;
  }

  /// Returns a [Path] that represents the stroke.
  ///
  /// If [smooth] is true, and the stroke is complete,
  /// the path will be a smooth curve between the points in [polygon].
  ///
  /// Otherwise, the path will use straight lines between each point
  /// in [polygon] for performance.
  @protected
  Path getPath(List<Offset> polygon, {bool smooth = true}) {
    // Shapes with corners are drawn with straight sides: smoothing the few
    // points of a polygon would round it into a blob.
    if (smooth && options.isComplete && vertexHandles == null) {
      return smoothPathFromPolygon(polygon);
    }

    return Path()..addPolygon(polygon, true);
  }

  /// [corners] with points added along the sides between them, no more
  /// than [spacing] apart.
  static List<PointVector> _alongSides(
    List<PointVector> corners,
    double spacing,
  ) {
    if (corners.length < 2) return corners;
    final dense = <PointVector>[corners.first];
    for (var i = 1; i < corners.length; i++) {
      final a = corners[i - 1], b = corners[i];
      final steps = (a.distanceTo(b) / spacing).ceil();
      for (var step = 1; step < steps; step++) {
        dense.add(a.lerp(step / steps, b));
      }
      dense.add(b);
    }
    return dense;
  }

  /// Returns a list with every Nth point in [points].
  static List<PointVector> skipPoints(List<PointVector> points, int N) {
    // Nothing is being skipped, just return [points].
    if (N <= 1) return points;

    // If we have too few points, skip less points
    final divided = points.length / N;
    const minDivided = 8;
    if (divided < minDivided) {
      N = (N * divided / minDivided).floor();
      if (N <= 1) return points;
    }

    return [
      for (int i = 0; i < points.length - 1; i += N) points[i],
      points.last,
    ];
  }

  static Path smoothPathFromPolygon(List<Offset> polygon) {
    final path = Path();
    path.moveTo(polygon.first.dx, polygon.first.dy);
    for (int i = 1; i < polygon.length - 1; i++) {
      final p1 = polygon[i];
      final p2 = polygon[i + 1];
      final mid = (p1 + p2) / 2;
      path.quadraticBezierTo(p1.dx, p1.dy, mid.dx, mid.dy);
    }
    return path..close();
  }

  String toSvgPath() {
    String toSvgPoint(Offset point) {
      return '${point.dx} '
          '${page.size.height - point.dy}';
    }

    // Remove NaN points, and convert to SVG coordinates
    final svgPoints = highQualityPolygon
        .where((offset) => offset.isFinite)
        .map(toSvgPoint);

    return svgPoints.isNotEmpty ? 'M${svgPoints.join('L')}' : '';
  }

  double get maxY {
    return points.isEmpty ? 0 : points.map((point) => point.y).reduce(max);
  }

  RecognizedUnistroke? detectShape() {
    if (points.length < 3) return null;
    return recognizeUnistroke(points);
  }

  /// Uses the one_dollar_unistroke_recognizer package
  /// only to recognize straight lines.
  ///
  /// In addition, the line must be sufficiently long
  /// relative to [options.size].
  bool isStraightLine([int minLength = 5]) {
    if (points.length < 3) return false;

    final recognized = recognizeUnistroke(
      points,
      overrideReferenceUnistrokes: default$1Unistrokes
          .where((unistroke) => unistroke.name == DefaultUnistrokeNames.line)
          .toList(),
    );
    if (recognized == null) return false;
    assert(recognized.name == DefaultUnistrokeNames.line);
    if (recognized.score < 0.7) return false;

    final sqrLength = points.first.distanceSquaredTo(points.last);
    final sqrMinLength = minLength * minLength * options.size * options.size;
    return sqrLength >= sqrMinLength;
  }

  /// Replaces the points in this stroke with a straight line.
  ///
  /// If the resulting line is close to horizontal or vertical,
  /// it will be snapped to be exactly horizontal or vertical.
  void convertToLine() {
    assert(points.length >= 2);

    // Use the average pressure
    final pressure = points.map((point) => point.pressure ?? 0.5).average;
    var firstPoint = PointVector.fromOffset(
      offset: points.first,
      pressure: pressure,
    );
    var lastPoint = PointVector.fromOffset(
      offset: points.last,
      pressure: pressure,
    );

    // Snap to the horizontal or vertical axis
    (firstPoint, lastPoint) = snapLine(firstPoint, lastPoint);

    points.clear();
    points.add(firstPoint);
    points.add(lastPoint);
    points.add(lastPoint);
    options.isComplete = true;
    options.start.taperEnabled = false;
    options.end.taperEnabled = false;
  }

  /// The two points that, drawn from the tip, make the head of an arrow
  /// pointing from [tail] to [tip].
  static (Offset left, Offset right) arrowHead(
    Offset tail,
    Offset tip, {
    required double headLength,
    double angle = 0.45, // about 26 degrees
  }) {
    final back = (tail - tip).direction;
    Offset wing(double a) =>
        tip + Offset.fromDirection(back + a, headLength);
    return (wing(angle), wing(-angle));
  }

  /// Turns a line (see [convertToLine]) into an arrow pointing at its end.
  /// The head is drawn as part of the same stroke, so arrows are saved,
  /// moved and resized like any other stroke.
  void convertToArrow() {
    assert(points.length >= 2);
    final tail = points.first;
    final tip = points[1];
    final length = (tip - tail).distance;
    if (length < 1) return;

    final headLength = min(max(options.size * 6, 18.0), length * 0.4);
    final (left, right) = arrowHead(tail, tip, headLength: headLength);
    final pressure = points.first.pressure;
    PointVector at(Offset o) => PointVector.fromOffset(offset: o, pressure: pressure);

    points.clear();
    points
      ..add(at(tail))
      ..add(at(tip))
      ..add(at(left))
      ..add(at(tip))
      ..add(at(right))
      ..add(at(right));
    options.isComplete = true;
    markPolygonNeedsUpdating();
  }

  /// Snaps a line to either horizontal or vertical
  /// if the angle is close enough.
  static (PointVector firstPoint, PointVector lastPoint) snapLine(
    PointVector firstPoint,
    PointVector lastPoint,
  ) {
    final dx = (lastPoint.dx - firstPoint.dx).abs();
    final dy = (lastPoint.dy - firstPoint.dy).abs();
    final angle = atan2(dy, dx);

    const snapAngle = 5 * pi / 180; // 5 degrees
    if (angle < snapAngle) {
      // snap to horizontal
      return (
        firstPoint,
        PointVector(lastPoint.dx, firstPoint.dy, lastPoint.pressure),
      );
    } else if (angle > pi / 2 - snapAngle) {
      // snap to vertical
      return (
        firstPoint,
        PointVector(firstPoint.dx, lastPoint.dy, lastPoint.pressure),
      );
    } else {
      return (firstPoint, lastPoint);
    }
  }

  /// How far apart the points of this stroke lie at most: the diagonal of
  /// the box around them. (Not the length of the line: a pen held on one
  /// spot wanders a long way without going anywhere.)
  double get reach {
    if (points.isEmpty) return 0;
    var left = points.first.dx, right = left;
    var top = points.first.dy, bottom = top;
    for (final point in points) {
      left = min(left, point.dx);
      right = max(right, point.dx);
      top = min(top, point.dy);
      bottom = max(bottom, point.dy);
    }
    final width = right - left, height = bottom - top;
    return sqrt(width * width + height * height);
  }

  /// Makes this stroke a dot: a single point in the middle of where its
  /// points were, with round ends whatever the pen's tip.
  ///
  /// It is as wide as the pen writes at [minPressure], or wider if the pen
  /// was pressed harder than that. A tap is over before the pen has
  /// reported any pressure to speak of, and a line this short is nothing
  /// but its two pointed ends: drawn as it came, it is a mark too small
  /// to see.
  void becomeDot({double minPressure = 0.5}) {
    if (points.isEmpty) return;
    var left = points.first.dx, right = left;
    var top = points.first.dy, bottom = top;
    double? pressure;
    for (final point in points) {
      left = min(left, point.dx);
      right = max(right, point.dx);
      top = min(top, point.dy);
      bottom = max(bottom, point.dy);
      final pointPressure = point.pressure;
      if (pointPressure != null) {
        pressure = max(pressure ?? minPressure, pointPressure);
      }
    }
    points
      ..clear()
      ..add(PointVector((left + right) / 2, (top + bottom) / 2, pressure));
    options
      ..start.taperEnabled = false
      ..end.taperEnabled = false
      ..isComplete = true;
    markPolygonNeedsUpdating();
  }

  /// The points of this stroke as plain offsets.
  List<Offset> get pointOffsets => [
    for (final point in points) Offset(point.dx, point.dy),
  ];

  /// The most points a stroke can have and still count as a shape with
  /// corners that can be dragged.
  static const _maxVertexPoints = 16;

  /// The corners of a stroke made by shape recognition: both ends of a line,
  /// or every corner of a closed polygon. Null for any other stroke.
  ///
  /// Such strokes are recognised by their points: they are few, and the last
  /// point is repeated (see [setVertexHandles]).
  List<Offset>? get vertexHandles {
    final n = points.length;
    if (n < 3 || n > _maxVertexPoints) return null;
    if (this is CircleStroke || this is RectangleStroke) return null;
    final last = points[n - 1], before = points[n - 2];
    if (last.dx != before.dx || last.dy != before.dy) return null;

    final core = [
      for (var i = 0; i < n - 1; i++) Offset(points[i].dx, points[i].dy),
    ];
    if (core.length == 2) return core;
    // An arrow is a line with a head: its corners aren't separate handles.
    if (core.length == 5 && core[1] == core[3]) return null;
    if (core.length >= 4 && core.first == core.last) {
      return core.sublist(0, core.length - 1);
    }
    return null;
  }

  /// Replaces the shape of this stroke with [vertices]: two points make a
  /// line, three or more a closed polygon. See [vertexHandles].
  void setVertexHandles(List<Offset> vertices) {
    assert(vertices.length >= 2);
    final pressure = points.isEmpty ? null : points.first.pressure;
    PointVector at(Offset o) =>
        PointVector.fromOffset(offset: o, pressure: pressure);

    points.clear();
    if (vertices.length == 2) {
      points
        ..add(at(vertices[0]))
        ..add(at(vertices[1]))
        ..add(at(vertices[1]));
    } else {
      for (final vertex in vertices) {
        points.add(at(vertex));
      }
      points
        ..add(at(vertices[0]))
        ..add(at(vertices[0]));
    }
    options.isComplete = true;
    markPolygonNeedsUpdating();
  }

  Stroke copy() => Stroke(
    color: color,
    pressureEnabled: pressureEnabled,
    options: options.copyWith(),
    pageIndex: pageIndex,
    page: page,
    toolId: toolId,
  )..points.addAll(points);

  // -- the ink as it is drawn ----------------------------------------------

  /// Whether this stroke is a shape drawn from its few corners (a straight
  /// line, a polygon, an arrow) and not from many points along its way.
  bool get _isDrawnFromCorners {
    final n = points.length;
    if (n < 3 || n > _maxVertexPoints) return false;
    final last = points[n - 1], before = points[n - 2];
    return last.dx == before.dx && last.dy == before.dy;
  }

  /// Whether the [inkLine] ends where it starts (a closed outline).
  bool get inkLineIsClosed => (vertexHandles?.length ?? 0) >= 3;

  /// The line the ink of this stroke follows, exactly as it is drawn: with
  /// the pen's steadying applied, and with half the ink's width at every
  /// point (pressure and pointed ends included).
  ///
  /// This is what the eraser cuts, so that what is left of a stroke stays
  /// where it was and as wide as it was (see [fromInkLine]).
  List<InkPoint> inkLine() {
    if (points.isEmpty) return const [];
    // A line whose width was made up from the pen's speed keeps those
    // widths from the first time it is drawn in full: make sure it has been.
    if (options.simulatePressure && options.isComplete && pressureEnabled) {
      highQualityPolygon.length;
    }
    if (!pressureEnabled) options.simulatePressure = false;

    // The same steps as the drawing itself takes (see perfect_freehand's
    // getStrokePoints and getStrokeOutlinePoints).
    final strokePoints = getStrokePoints(points, options: options);
    if (strokePoints.isEmpty) return const [];
    final size = options.size;
    final total = strokePoints.last.runningLength;
    final taperStart = options.start.taperEnabled
        ? options.start.customTaper ?? max(size, total)
        : 0.0;
    final taperEnd = options.end.taperEnabled
        ? options.end.customTaper ?? max(size, total)
        : 0.0;

    var previous = strokePoints.first.pressure;
    if (options.simulatePressure) {
      for (final point in strokePoints.sublist(
        0,
        min(10, strokePoints.length - 1),
      )) {
        previous = (previous + point.simulatePressure(previous, size)) / 2;
      }
    }

    final line = <InkPoint>[];
    for (final point in strokePoints) {
      double radius;
      if (options.thinning != 0) {
        final double pressure;
        if (options.simulatePressure) {
          pressure = point.simulatePressure(previous, size);
          previous = pressure;
        } else {
          pressure = point.pressure;
        }
        radius = size * options.easing(0.5 - options.thinning * (0.5 - pressure));
      } else {
        radius = size / 2;
      }
      final run = point.runningLength;
      final atStart = run < taperStart
          ? options.start.easing(run / taperStart)
          : 1.0;
      final atEnd = total - run < taperEnd
          ? options.end.easing((total - run) / taperEnd)
          : 1.0;
      radius = max(0.01, radius * min(atStart, atEnd));
      line.add((at: Offset(point.point.x, point.point.y), radius: radius));
    }
    // A shape's sides are single long steps; cut into pieces, it is drawn
    // like handwriting, which rounds corners over the length of a step.
    return _isDrawnFromCorners
        ? densifyInkLine(line, inkLineSpacing(size))
        : line;
  }

  /// How far apart the points of a shape's [inkLine] are at most.
  static double inkLineSpacing(double size) => max(2.0, size * 0.6);

  /// [line] with points added so that none are more than [spacing] apart.
  static List<InkPoint> densifyInkLine(List<InkPoint> line, double spacing) {
    if (line.length < 2) return line;
    final dense = <InkPoint>[line.first];
    for (var i = 1; i < line.length; i++) {
      final a = line[i - 1], b = line[i];
      final steps = ((b.at - a.at).distance / spacing).ceil();
      for (var step = 1; step < steps; step++) {
        final t = step / steps;
        dense.add((
          at: Offset.lerp(a.at, b.at, t)!,
          radius: a.radius + (b.radius - a.radius) * t,
        ));
      }
      dense.add(b);
    }
    return dense;
  }

  /// A stroke that is drawn along [line] with exactly the widths it gives,
  /// in the colour and with the tool of [like].
  ///
  /// An end that is [flatStart] or [flatEnd] is cut off square (it is where
  /// the eraser went through); the others are round.
  static Stroke fromInkLine(
    Stroke like,
    List<InkPoint> line, {
    bool flatStart = false,
    bool flatEnd = false,
  }) {
    final size = like.options.size;
    final stroke = Stroke(
      color: like.color,
      // The widths are kept as pressure: with thinning at 1, the ink is
      // exactly `size * pressure` wide on either side of the line.
      pressureEnabled: true,
      options: StrokeOptions(
        size: size,
        thinning: 1,
        smoothing: like.options.smoothing,
        streamline: 0,
        simulatePressure: false,
        isComplete: true,
        start: StrokeEndOptions.start(cap: !flatStart, taperEnabled: false),
        end: StrokeEndOptions.end(cap: !flatEnd, taperEnabled: false),
      ),
      pageIndex: like.pageIndex,
      page: like.page,
      toolId: like.toolId,
    );
    PointVector at(InkPoint point) => PointVector(
      point.at.dx,
      point.at.dy,
      size <= 0 ? 0.5 : (point.radius / size).clamp(0.0, 1.0).toDouble(),
    );

    if (line.isEmpty) return stroke;
    stroke.points.add(at(line.first));
    if (line.length == 1) return stroke;

    // The drawing leaves out the points at the very start of a line until
    // they add up to the pen's size away from its first point (it takes
    // them for the pen settling). Here they are the line itself, so the
    // first of them is given often enough to be counted in (see the
    // `runningLength` of perfect_freehand's getStrokePoints). A point too
    // close to the start to matter is left out instead.
    var second = 1;
    while (second < line.length - 1 &&
        (line[second].at - line.first.at).distance < size / 32) {
      second++;
    }
    if (second < line.length - 1) {
      final distance = (line[second].at - line.first.at).distance;
      final times = distance <= 0
          ? 1
          : (size / distance).ceil().clamp(1, 32).toInt();
      for (var i = 0; i < times; i++) {
        stroke.points.add(at(line[second]));
      }
      second++;
    }
    for (var i = second; i < line.length; i++) {
      stroke.points.add(at(line[i]));
    }
    return stroke;
  }

  /// A straight line like this one (see [vertexHandles]) from [a] to [b].
  /// An end that is [flatStart] or [flatEnd] is cut off square.
  Stroke lineLike(
    Offset a,
    Offset b, {
    bool flatStart = false,
    bool flatEnd = false,
  }) {
    final line = Stroke(
      color: color,
      pressureEnabled: pressureEnabled,
      options: options.copyWith(
        isComplete: true,
        start: StrokeEndOptions.start(
          cap: !flatStart && options.start.cap,
          taperEnabled: false,
        ),
        end: StrokeEndOptions.end(
          cap: !flatEnd && options.end.cap,
          taperEnabled: false,
        ),
      ),
      pageIndex: pageIndex,
      page: page,
      toolId: toolId,
    );
    final pressure = points.isEmpty ? null : points.first.pressure;
    line.points
      ..add(PointVector(a.dx, a.dy, pressure))
      ..add(PointVector(b.dx, b.dy, pressure))
      ..add(PointVector(b.dx, b.dy, pressure));
    return line;
  }
}

enum StrokeQuality(
  /// We use every Nth point for this quality level.
  final int N,
) {
  low(4),
  high(1),
}
