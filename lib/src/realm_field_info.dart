// Copyright 2021 MongoDB, Inc.
// SPDX-License-Identifier: Apache-2.0

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:realm_common/realm_common.dart';

import 'dart_type_ex.dart';
import 'element.dart';
import 'field_element_ex.dart';

class RealmFieldInfo {
  final FieldElement fieldElement;
  final String? mapTo;
  final bool isPrimaryKey;
  final RealmIndexType? indexType;
  final RealmPropertyType realmType;
  final String? linkOriginProperty;

  RealmFieldInfo({
    required this.fieldElement,
    required this.mapTo,
    required this.isPrimaryKey,
    this.indexType,
    required this.realmType,
    required this.linkOriginProperty,
  });

  DartType get type => fieldElement.type;

  bool get isFinal => fieldElement.isFinal;
  bool get isLate => fieldElement.isLate;
  bool get hasDefaultValue => fieldElement.hasInitializer;
  bool get optional => type.basicType.isNullable || realmType == RealmPropertyType.mixed;
  bool get isRequired => !(hasDefaultValue || optional || isRealmCollection);
  bool get isRealmBacklink => realmType == RealmPropertyType.linkingObjects;
  bool get isMixed => realmType == RealmPropertyType.mixed;
  bool get isComputed => isRealmBacklink; // only computed, so far

  bool get isRealmCollection => type.isRealmCollection;
  bool get isDartCoreList => type.isDartCoreList;
  bool get isDartCoreSet => type.isDartCoreSet;
  bool get isDartCoreMap => type.isDartCoreMap;

  String get name => fieldElement.name;
  String get realmName => mapTo ?? name;

  String get basicMappedTypeName => type.basicMappedName;

  String get basicNonNullableMappedTypeName => type.basicType.asNonNullable.mappedName;

  String get basicRealmTypeName =>
      fieldElement.modelType.basicType.asNonNullable.element?.remappedRealmName ?? fieldElement.modelType.basicType.asNonNullable.basicMappedName;

  String get modelTypeName => fieldElement.modelTypeName;

  String get mappedTypeName => fieldElement.mappedTypeName;

  String get initializer {
    final v = defaultValue;
    return v == null ? '' : ' = $v';
  }

  String? get defaultValue {
    if (type.realmCollectionType == RealmCollectionType.list) return 'const []';
    if (type.realmCollectionType == RealmCollectionType.set) return 'const {}';
    if (type.realmCollectionType == RealmCollectionType.map) return 'const {}';
    if (isMixed) return 'const RealmValue.nullValue()';
    if (hasDefaultValue) return '${fieldElement.initializerExpression}';
    return null; // no default value
  }

  RealmCollectionType get realmCollectionType => type.realmCollectionType;

  Iterable<String> toCode() sync* {
    final getTypeName = type.isRealmCollection ? basicMappedTypeName : basicNonNullableMappedTypeName;
    yield '@override';
    if (isRealmBacklink) {
      yield "$mappedTypeName get $name {";
      yield "if (!isManaged) { throw RealmError('Using backlinks is only possible for managed objects.'); }";
      yield "return RealmObjectBase.get<$getTypeName>(this, '$realmName') as $mappedTypeName;}";
    } else {
      yield "$mappedTypeName get $name => RealmObjectBase.get<$getTypeName>(this, '$realmName') as $mappedTypeName;";
    }
    bool generateSetter = !isFinal && !isRealmCollection && !isRealmBacklink;
    final setterSignature =
        "set $name(${mappedTypeName != modelTypeName ? 'covariant ' : ''}$mappedTypeName value)";
    if (generateSetter) {
      yield '@override';
      yield "$setterSignature {";
      yield "  RealmObjectBase.set(this, '$realmName', value);";
      yield "  RealmObjectBase.set(this, 'updatedAt', DateTime.now());";
      yield "}";
    } else {
      yield '@override';
      yield '@Deprecated("No setter for this field! Will throw if used")';
      yield "$setterSignature => throw 'No setter for field \"$name\"';";
    }
  }

  Iterable<String> toBuilderDefinition() sync* {
    var typeName = isRealmCollection ? modelTypeName : basicMappedTypeName;
    if (!type.isNullable) typeName += '?';
    yield "$typeName _$name;";
    yield "$typeName get $name => _$name ?? source?.$name;";
    yield "set $name($typeName value) {";
    yield "  _$name = value;";
    yield "  _didChange = true;";
    yield "}";
  }

  String toBuilderAssignment() {
    var fieldName = name;
    if (!type.isNullable) fieldName += '!';
    return "$name: $fieldName,";
  }

  @override
  String toString() => fieldElement.displayName;
}
