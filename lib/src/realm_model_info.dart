// Copyright 2021 MongoDB, Inc.
// SPDX-License-Identifier: Apache-2.0

import 'package:realm_common/realm_common.dart';

import 'dart_type_ex.dart';
import 'field_element_ex.dart';
import 'realm_field_info.dart';

extension<T> on Iterable<T> {
  Iterable<T> except(bool Function(T) test) => where((e) => !test(e));
}

extension on String {
  String nonPrivate() => startsWith('_') ? substring(1) : this;
}

class RealmModelInfo {
  final String name;
  final String modelName;
  final String realmName;
  final List<RealmFieldInfo> fields;
  final ObjectType baseType;
  final GeneratorConfig config;

  const RealmModelInfo(
    this.name,
    this.modelName,
    this.realmName,
    this.fields,
    this.baseType,
    this.config,
  );

  Iterable<String> toCode() sync* {
    final builderFields = fields.where((f) => !f.isRealmBacklink);

    yield 'class $name extends $modelName with RealmEntity, RealmObjectBase, ${baseType.className} {';
    {
      final allSettable = fields.where((f) => !f.isComputed).toList();

      final fieldsWithRealmDefaults = allSettable.where((f) => f.hasDefaultValue && !f.isRealmCollection).toList();
      final shouldEmitDefaultsSet = fieldsWithRealmDefaults.isNotEmpty;
      if (shouldEmitDefaultsSet) {
        yield 'static var _defaultsSet = false;';
        yield '';
      }

      bool required(RealmFieldInfo f) => f.isRequired || f.isPrimaryKey;
      bool usePositional(RealmFieldInfo f) => config.ctorStyle != CtorStyle.allNamed && required(f);
      String paramName(RealmFieldInfo f) => usePositional(f) ? f.name : f.name.nonPrivate();
      final positional = allSettable.where(usePositional);
      final named = allSettable.except(usePositional);

      // Constructor
      yield '$name(';
      {
        yield* positional.map((f) => '${f.mappedTypeName} ${paramName(f)},');
        if (named.isNotEmpty) {
          yield '{';
          
          yield 'DateTime? createdAt,';
          yield 'DateTime? updatedAt,';
          yield* named.map((f) {
            final requiredPrefix = required(f) ? 'required ' : '';
            final param = paramName(f);
            final collectionPrefix = switch (f) {
              _ when f.isDartCoreList => 'Iterable<',
              _ when f.isDartCoreSet => 'Set<',
              _ when f.isDartCoreMap => 'Map<String,',
              _ => '',
            };
            final typePrefix = f.isRealmCollection ? '$collectionPrefix${f.type.basicMappedName}>' : f.mappedTypeName;
            return '$requiredPrefix$typePrefix $param${f.initializer},';
          });
          yield '}';
        }

        yield ') {';

        yield "RealmObjectBase.set(this, 'createdAt', createdAt ?? DateTime.now());";
        yield "RealmObjectBase.set(this, 'updatedAt', updatedAt ?? DateTime.now());";
        yield "RealmObjectBase.set(this, 'isDeleted', false);";

        if (shouldEmitDefaultsSet) {
          yield 'if (!_defaultsSet) {';
          yield '  _defaultsSet = RealmObjectBase.setDefaults<$name>({';
          yield* fieldsWithRealmDefaults.map((f) => "'${f.realmName}': ${f.fieldElement.initializerExpression},");
          yield '  });';
          yield '}';
        }

        yield* allSettable.map((f) {
          final param = paramName(f);
          if (f.type.isUint8List && f.hasDefaultValue) {
            return "RealmObjectBase.set(this, '${f.realmName}', $param ?? ${f.fieldElement.initializerExpression});";
          }
          if (f.isRealmCollection) {
            return "RealmObjectBase.set<${f.mappedTypeName}>(this, '${f.realmName}', ${f.mappedTypeName}($param));";
          }
          return "RealmObjectBase.set(this, '${f.realmName}', $param);";
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

      yield '@override';
      yield 'Stream<RealmObjectChanges<$name>> changesFor([List<String>? keyPaths]) => RealmObjectBase.getChangesFor<$name>(this, keyPaths);';
      yield '';

      // Freeze
      yield '@override';
      yield '$name freeze() => RealmObjectBase.freezeObject<$name>(this);';
      yield '';

      // Builder
      yield '${name}Builder toBuilder() {';
      {
        yield 'return ${name}Builder.from(this);';
      }
      yield '}';
      yield '';


      // Encode
      yield 'EJsonValue toEJson() {';
      {
        yield 'return <String, dynamic>{';
        {
          yield* allSettable.map((f) {
            return "'${f.realmName}': ${f.name}.toEJson(),";
          });
        }
        yield '};';
      }
      yield '}';

      yield 'static EJsonValue _toEJson($name value) => value.toEJson();';

      // Decode
      yield 'static $name _fromEJson(EJsonValue ejson) {';
      {
        yield 'if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);';
        final shape = allSettable.where(required);
        if (shape.isEmpty) {
          yield 'return ';
        } else {
          yield 'return switch (ejson) {';
          {
            yield '{';
            {
              yield* shape.map((f) {
                return "'${f.realmName}': EJsonValue ${f.name},";
              });
            }
            yield '} =>';
          }
        }
        yield '$name(';
        {
          getter(RealmFieldInfo f) => f.isRequired ? f.name : "ejson['${f.realmName}']";
          fromEJson(RealmFieldInfo f) => 'fromEJson(${getter(f)}${f.hasDefaultValue ? ', defaultValue: ${f.defaultValue}' : ''})';
          yield* positional.map((f) => '${fromEJson(f)},');
          yield* named.map((f) => '${paramName(f)}: ${fromEJson(f)},');
        }
        yield ')';
        if (shape.isEmpty) {
          yield ';';
        } else {
          yield ',';
          yield '_ => raiseInvalidEJson(ejson),';
          yield '};';
        }
      }
      yield '}';

      // Schema
      yield 'static final schema = () {';
      {
        yield 'RealmObjectBase.registerFactory($name._);';
        yield 'register(_toEJson, _fromEJson);';
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
      yield '}();';
      yield '';
      yield '@override';
      yield 'SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;';   
      
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
