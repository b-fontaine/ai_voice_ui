import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Décale son enfant de `offset × (1 - progress)`, à la **peinture** seulement.
///
/// Quand [progress] change, ni le widget ni son parent ne sont reconstruits ni
/// remis en page : seule la peinture de l'enfant se refait (un `RenderProxyBox`
/// qui écoute [progress]). Un `AnimatedBuilder` ou une `SlideTransition` (un
/// `AnimatedWidget`) sous un `LayoutBuilder` remettrait en page, à chaque
/// image, tout le sous-arbre du `LayoutBuilder`. À 1, l'enfant est en place.
///
/// Les clics suivent le décalage : dans la boîte du `DsShift` (celle de
/// l'enfant en place), la zone sensible est celle que l'on voit.
/// À utiliser pour une apparition ; le fondu est celui de `DsReveal`.
class DsShift extends SingleChildRenderObjectWidget {
  const DsShift({
    super.key,
    required this.progress,
    required this.offset,
    required super.child,
  });

  /// Avancement de l'apparition : 0 (décalé de [offset]) à 1 (en place).
  final Animation<double> progress;

  /// Décalage de départ, en points logiques.
  final Offset offset;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderShift(progress, offset);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderShift)
      ..progress = progress
      ..offset = offset;
  }
}

class _RenderShift extends RenderProxyBox {
  _RenderShift(this._progress, this._offset);

  Animation<double> _progress;
  Offset _offset;

  set progress(Animation<double> value) {
    if (value == _progress) return;
    if (attached) _progress.removeListener(markNeedsPaint);
    _progress = value;
    if (attached) _progress.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  set offset(Offset value) {
    if (value == _offset) return;
    _offset = value;
    markNeedsPaint();
  }

  Offset get _shift => _offset * (1 - _progress.value);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child != null) context.paintChild(child, offset + _shift);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: _shift,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) =>
            child?.hitTest(result, position: transformed) ?? false,
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final Offset shift = _shift;
    transform.translateByDouble(shift.dx, shift.dy, 0, 1);
  }
}
