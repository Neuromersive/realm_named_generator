// Copyright 2021 MongoDB, Inc.
// SPDX-License-Identifier: Apache-2.0

import 'dart:math';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:realm_named_generator/src/annotation_value.dart';
import 'package:realm_named_generator/src/expanded_context_span.dart';
import 'package:source_gen/source_gen.dart';
import 'package:source_span/source_span.dart';

import 'class_element_ex.dart';
import 'error.dart';
import 'field_element_ex.dart';
import 'session.dart';
import 'type_checkers.dart';
import 'utils.dart';

ElementDeclarationResult? getDeclarationFromElement(Element element) {
  return session.resolvedLibrary.getElementDeclaration(element);
}

extension on FileSpan {
  FileSpan clampEnd(FileSpan other) => file.span(
        start.offset,
        min(end.offset, other.end.offset),
      );

  FileSpan extentToEndOfLine([int noOfLines = 1]) {
    var end = this.end.offset;
    final line = file.location(end).line;
    end = max(end, file.getOffset(min(line + noOfLines, file.lines - 1)));
    return file.span(start.offset, end);
  }
}

extension AstNodeEx on AstNode {
  FileSpan span(SourceFile file) {
    return file.span(offset, offset + length);
  }
}

extension ElementEx on Element {
  FileSpan? get _shortSpan {
    try {
      return spanForElement(this) as FileSpan;
    } catch (_) {}
    return null;
  }

  AnnotatedNode get declarationAstNode {
    final self = this;
    if (self is ClassElement) return self.declarationAstNode;
    if (self is FieldElement) return self.declarationAstNode;
    throw UnsupportedError('$runtimeType not supported');
  }

  Iterable<AnnotationValue> _annotationsInfoOfExact(TypeChecker checker) sync* {
    // This is a bit backwards because of the api surface on TypeCheckers
    final values = checker.annotationsOfExact(this).toSet();
    final node = declarationAstNode;
    for (final annotation in node.metadata) {
      final value = annotation.elementAnnotation?.computeConstantValue();
      if (value != null && values.contains(value)) {
        yield AnnotationValue(annotation, value);
      }
    }
  }

  AnnotationValue? annotationInfoOfExact(TypeChecker checker) {
    final annotations = _annotationsInfoOfExact(checker).toList();
    if (annotations.length > 1) {
      final second = annotations[1];
      final elementSpan = span!;
      final file = elementSpan.file;

      throw RealmInvalidGenerationSourceError('Repeated annotation',
          element: this,
          primarySpan: ExpandedContextSpan(second.annotation.span(file), [elementSpan]),
          primaryLabel: 'duplicated annotation',
          secondarySpans: {
            ...{for (final a in annotations..removeAt(1)) a.annotation.span(file): ''}
          },
          todo: 'Remove all duplicated ${second.annotation} annotations.');
    }
    return annotations.singleOrNull;
  }

  String? get remappedRealmName {
    final mapTo = mapToChecker.annotationsOfExact(this).singleOrNull;
    return mapTo?.getField('name')!.toStringValue();
  }

  FileSpan? get span {
    FileSpan? elementSpan;
    try {
      elementSpan = _shortSpan!;
      final self = this;
      if (self is FieldElement) {
        final node = self.declarationAstNode;
        if (node.metadata.isNotEmpty) {
          return ExpandedContextSpan(elementSpan, [node.span(elementSpan.file)]);
        }
      } else if (self is ClassElement) {
        final node = self.declarationAstNode;
        if (node.metadata.isNotEmpty) {
          // don't include full class
          return ExpandedContextSpan(elementSpan, [node.span(elementSpan.file).clampEnd(elementSpan.extentToEndOfLine())]);
        }
      }
    } catch (_) {}
    // don't allow span calculation to bring us down
    return elementSpan;
  }
}
