// This is a generated file - do not edit.
//
// Generated from remotemessage.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class RemoteDirection extends $pb.ProtobufEnum {
  static const RemoteDirection UNKNOWN_DIRECTION =
      RemoteDirection._(0, _omitEnumNames ? '' : 'UNKNOWN_DIRECTION');
  static const RemoteDirection START_LONG =
      RemoteDirection._(1, _omitEnumNames ? '' : 'START_LONG');
  static const RemoteDirection END_LONG =
      RemoteDirection._(2, _omitEnumNames ? '' : 'END_LONG');
  static const RemoteDirection SHORT =
      RemoteDirection._(3, _omitEnumNames ? '' : 'SHORT');

  static const $core.List<RemoteDirection> values = <RemoteDirection>[
    UNKNOWN_DIRECTION,
    START_LONG,
    END_LONG,
    SHORT,
  ];

  static final $core.List<RemoteDirection?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static RemoteDirection? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RemoteDirection._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
