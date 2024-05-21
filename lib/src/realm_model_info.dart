////////////////////////////////////////////////////////////////////////////////
//
// Copyright 2021 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////////

import 'package:realm_common/realm_common.dart';

import 'dart_type_ex.dart';
import 'field_element_ex.dart';
import 'realm_field_info.dart';

class RealmModelInfo {
  final String name;
  final String modelName;
  final String realmName;
  final List<RealmFieldInfo> fields;
  final ObjectType baseType;

  const RealmModelInfo(this.name, this.modelName, this.realmName, this.fields, this.baseType);

  Iterable<String> toCode() sync* {
    final builderFields = fields.where((f) => !f.isRealmBacklink);

    yield 'class $name extends $modelName with RealmEntity, RealmObjectBase, ${baseType.className} {';
    {
      final allSettable = fields.where((f) => !f.type.isRealmCollection && !f.isRealmBacklink).toList();

      final fieldsWithDefaultValue = allSettable.where((f) => f.hasDefaultValue && !f.type.isUint8List).toList();
      final shouldEmitDefaultsSet = fieldsWithDefaultValue.isNotEmpty;
      if (shouldEmitDefaultsSet) {
        yield 'static var _defaultsSet = false;';
        yield '';
      }

      // Constructor
      yield '$name({';
      {
        yield 'DateTime? createdAt,';
        yield 'DateTime? updatedAt,';

        final required = allSettable.where((f) => f.isRequired || f.isPrimaryKey);
        yield* required.map((f) => 'required ${f.mappedTypeName} ${f.name},');

        final notRequired = allSettable.where((f) => !f.isRequired && !f.isPrimaryKey);
        final lists = fields.where((f) => f.isDartCoreList).toList();
        final sets = fields.where((f) => f.isDartCoreSet).toList();
        final maps = fields.where((f) => f.isDartCoreMap).toList();
        if (notRequired.isNotEmpty || lists.isNotEmpty || sets.isNotEmpty || maps.isNotEmpty) {
          yield* notRequired.map((f) {
            if (f.type.isUint8List && f.hasDefaultValue) {
              return '${f.mappedTypeName}? ${f.name},';
            }
            return '${f.mappedTypeName} ${f.name}${f.initializer},';
          });
          yield* lists.map((c) => 'Iterable<${c.type.basicMappedName}> ${c.name}${c.initializer},');
          yield* sets.map((c) => 'Set<${c.type.basicMappedName}> ${c.name}${c.initializer},');
          yield* maps.map((c) => 'Map<String, ${c.type.basicMappedName}> ${c.name}${c.initializer},');
        }

        yield '}) {';

        yield "RealmObjectBase.set(this, 'createdAt', createdAt ?? DateTime.now());";
        yield "RealmObjectBase.set(this, 'updatedAt', updatedAt ?? DateTime.now());";
        yield "RealmObjectBase.set(this, 'isDeleted', false);";

        if (shouldEmitDefaultsSet) {
          yield 'if (!_defaultsSet) {';
          yield '  _defaultsSet = RealmObjectBase.setDefaults<$name>({';
          yield* fieldsWithDefaultValue.map((f) => "'${f.realmName}': ${f.fieldElement.initializerExpression},");
          yield '  });';
          yield '}';
        }

        yield* allSettable.map((f) {
          if (f.type.isUint8List && f.hasDefaultValue) {
            return "RealmObjectBase.set(this, '${f.realmName}', ${f.name} ?? ${f.fieldElement.initializerExpression});";
          }

          return "RealmObjectBase.set(this, '${f.realmName}', ${f.name});";
        });

        yield* lists.map((c) {
          return "RealmObjectBase.set<${c.mappedTypeName}>(this, '${c.realmName}', ${c.mappedTypeName}(${c.name}));";
        });

        yield* sets.map((c) {
          return "RealmObjectBase.set<${c.mappedTypeName}>(this, '${c.realmName}', ${c.mappedTypeName}(${c.name}));";
        });

        yield* maps.map((c) {
          return "RealmObjectBase.set<${c.mappedTypeName}>(this, '${c.realmName}', ${c.mappedTypeName}(${c.name}));";
        });
      }
      yield '}';
      yield '';
      yield '$name._();';
      yield '';

      // createdAt accessors
      yield "DateTime? get createdAt =>";
      yield "    RealmObjectBase.get<DateTime>(this, 'createdAt') as DateTime?;";
      yield "@Deprecated(\"No setter for this field! Will throw if used\")";
      yield "set createdAt(DateTime? value) => throw 'No setter for field \"createdAt\"';";
      yield "";

      // updatedAt accessors
      yield "DateTime? get updatedAt =>";
      yield "    RealmObjectBase.get<DateTime>(this, 'updatedAt') as DateTime?;";
      yield "@Deprecated(\"No setter for this field! Will throw if used\")";
      yield "set updatedAt(DateTime? value) => throw 'No setter for field \"updatedAt\"';";
      yield "";

      // isDeleted accessors
      yield "bool get isDeleted =>";
      yield "    RealmObjectBase.get<bool>(this, 'isDeleted') as bool? ?? false;";
      yield "@Deprecated(\"No setter for this field! Will throw if used\")";
      yield "set isDeleted(bool? value) => throw 'No setter for field \"isDeleted\"';";
      yield "";
      yield "/// Flag this object as deleted";
      yield "/// May only be called within a Realm.Write block";
      yield "/// This object should not be referenced after calling this";
      yield "void setDeleted() {";
      yield "  if (isDeleted) return;";
      yield "  RealmObjectBase.set(this, 'isDeleted', true);";
      yield "  RealmObjectBase.set(this, 'updatedAt', DateTime.now());";
      yield "}";

      // Rest of the accessors
      yield* fields.expand((f) => [
            ...f.toCode(),
            '',
          ]);

      // Changes
      yield '@override';
      yield 'Stream<RealmObjectChanges<$name>> get changes => RealmObjectBase.getChanges<$name>(this);';
      yield '';

      // Freeze
      yield '@override';
      yield '$name freeze() => RealmObjectBase.freezeObject<$name>(this);';
      yield '';

      yield '${name}Builder toBuilder() {';
      {
        yield 'return ${name}Builder.from(this);';
      }
      yield '}';
      yield '';

      // Schema
      yield 'static SchemaObject get schema => _schema ??= _initSchema();';
      yield 'static SchemaObject? _schema;';
      yield 'static SchemaObject _initSchema() {';
      {
        yield 'RealmObjectBase.registerFactory($name._);';
        yield "return const SchemaObject(ObjectType.${baseType.name}, $name, '$realmName', [";
        {
          yield "SchemaProperty('createdAt', RealmPropertyType.timestamp, optional: true),";
          yield "SchemaProperty('updatedAt', RealmPropertyType.timestamp, optional: true),";
          yield "SchemaProperty('isDeleted', RealmPropertyType.bool, optional: true),";

          yield* fields.map((f) {
            final namedArgs = {
              if (f.name != f.realmName) 'mapTo': f.realmName,
              if (f.optional) 'optional': f.optional,
              if (f.isPrimaryKey) 'primaryKey': f.isPrimaryKey,
              if (f.indexType != null) 'indexType': f.indexType,
              if (f.realmType == RealmPropertyType.object) 'linkTarget': f.basicRealmTypeName,
              if (f.realmType == RealmPropertyType.linkingObjects) ...{
                'linkOriginProperty': f.linkOriginProperty!,
                'collectionType': RealmCollectionType.list,
                'linkTarget': f.basicRealmTypeName,
              },
              if (f.realmCollectionType != RealmCollectionType.none) 'collectionType': f.realmCollectionType,
            };
            return "SchemaProperty('${f.name}', ${f.realmType}${namedArgs.isNotEmpty ? ', ${namedArgs.toArgsString()}' : ''}),";
          });
        }
        yield ']);';
      }
      yield '}';
    }
    yield '}';

    yield 'class ${name}Builder {';
    {
      yield '${name}Builder() : source = null, _didChange = true;';
      yield '${name}Builder.from(this.source) : _didChange = false;';
      yield '';

      yield 'final ${name}? source;';
      yield 'bool _didChange;';
      yield 'bool get didChange => _didChange;';
      yield '';

      yield* builderFields.expand((f) => f.toBuilderDefinition());
      yield '';

      yield '$name build() {';
      {
        yield 'return $name(';

        yield "createdAt: source?.createdAt ?? DateTime.now(),";
        yield "updatedAt: didChange ? DateTime.now() : source!.updatedAt,";

        yield* builderFields.map((f) => f.toBuilderAssignment());
        yield ');';
      }
      yield '}';
    }
    yield '}';
  }
}

extension<K, V> on Map<K, V> {
  String toArgsString() {
    return () sync* {
      for (final e in entries) {
        if (e.value is String) {
          yield "${e.key}: '${e.value}'";
        } else {
          yield '${e.key}: ${e.value}';
        }
      }
    }()
        .join(',');
  }
}
