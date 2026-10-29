// This is a generated file - do not edit.
//
// Generated from remotemessage.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use remoteDirectionDescriptor instead')
const RemoteDirection$json = {
  '1': 'RemoteDirection',
  '2': [
    {'1': 'UNKNOWN_DIRECTION', '2': 0},
    {'1': 'START_LONG', '2': 1},
    {'1': 'END_LONG', '2': 2},
    {'1': 'SHORT', '2': 3},
  ],
};

/// Descriptor for `RemoteDirection`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List remoteDirectionDescriptor = $convert.base64Decode(
    'Cg9SZW1vdGVEaXJlY3Rpb24SFQoRVU5LTk9XTl9ESVJFQ1RJT04QABIOCgpTVEFSVF9MT05HEA'
    'ESDAoIRU5EX0xPTkcQAhIJCgVTSE9SVBAD');

@$core.Deprecated('Use remoteAppLinkLaunchRequestDescriptor instead')
const RemoteAppLinkLaunchRequest$json = {
  '1': 'RemoteAppLinkLaunchRequest',
  '2': [
    {'1': 'app_link', '3': 1, '4': 1, '5': 9, '10': 'appLink'},
  ],
};

/// Descriptor for `RemoteAppLinkLaunchRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteAppLinkLaunchRequestDescriptor =
    $convert.base64Decode(
        'ChpSZW1vdGVBcHBMaW5rTGF1bmNoUmVxdWVzdBIZCghhcHBfbGluaxgBIAEoCVIHYXBwTGluaw'
        '==');

@$core.Deprecated('Use remoteSetVolumeLevelDescriptor instead')
const RemoteSetVolumeLevel$json = {
  '1': 'RemoteSetVolumeLevel',
  '2': [
    {'1': 'unknown1', '3': 1, '4': 1, '5': 13, '10': 'unknown1'},
    {'1': 'unknown2', '3': 2, '4': 1, '5': 13, '10': 'unknown2'},
    {'1': 'player_model', '3': 3, '4': 1, '5': 9, '10': 'playerModel'},
    {'1': 'unknown4', '3': 4, '4': 1, '5': 13, '10': 'unknown4'},
    {'1': 'unknown5', '3': 5, '4': 1, '5': 13, '10': 'unknown5'},
    {'1': 'volume_max', '3': 6, '4': 1, '5': 13, '10': 'volumeMax'},
    {'1': 'volume_level', '3': 7, '4': 1, '5': 13, '10': 'volumeLevel'},
    {'1': 'volume_muted', '3': 8, '4': 1, '5': 8, '10': 'volumeMuted'},
  ],
};

/// Descriptor for `RemoteSetVolumeLevel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteSetVolumeLevelDescriptor = $convert.base64Decode(
    'ChRSZW1vdGVTZXRWb2x1bWVMZXZlbBIaCgh1bmtub3duMRgBIAEoDVIIdW5rbm93bjESGgoIdW'
    '5rbm93bjIYAiABKA1SCHVua25vd24yEiEKDHBsYXllcl9tb2RlbBgDIAEoCVILcGxheWVyTW9k'
    'ZWwSGgoIdW5rbm93bjQYBCABKA1SCHVua25vd240EhoKCHVua25vd241GAUgASgNUgh1bmtub3'
    'duNRIdCgp2b2x1bWVfbWF4GAYgASgNUgl2b2x1bWVNYXgSIQoMdm9sdW1lX2xldmVsGAcgASgN'
    'Ugt2b2x1bWVMZXZlbBIhCgx2b2x1bWVfbXV0ZWQYCCABKAhSC3ZvbHVtZU11dGVk');

@$core.Deprecated('Use remoteStartDescriptor instead')
const RemoteStart$json = {
  '1': 'RemoteStart',
  '2': [
    {'1': 'started', '3': 1, '4': 1, '5': 8, '10': 'started'},
  ],
};

/// Descriptor for `RemoteStart`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteStartDescriptor = $convert
    .base64Decode('CgtSZW1vdGVTdGFydBIYCgdzdGFydGVkGAEgASgIUgdzdGFydGVk');

@$core.Deprecated('Use remoteTextFieldStatusDescriptor instead')
const RemoteTextFieldStatus$json = {
  '1': 'RemoteTextFieldStatus',
  '2': [
    {'1': 'counter_field', '3': 1, '4': 1, '5': 5, '10': 'counterField'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
    {'1': 'start', '3': 3, '4': 1, '5': 5, '10': 'start'},
    {'1': 'end', '3': 4, '4': 1, '5': 5, '10': 'end'},
    {'1': 'int5', '3': 5, '4': 1, '5': 5, '10': 'int5'},
    {'1': 'label', '3': 6, '4': 1, '5': 9, '10': 'label'},
  ],
};

/// Descriptor for `RemoteTextFieldStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteTextFieldStatusDescriptor = $convert.base64Decode(
    'ChVSZW1vdGVUZXh0RmllbGRTdGF0dXMSIwoNY291bnRlcl9maWVsZBgBIAEoBVIMY291bnRlck'
    'ZpZWxkEhQKBXZhbHVlGAIgASgJUgV2YWx1ZRIUCgVzdGFydBgDIAEoBVIFc3RhcnQSEAoDZW5k'
    'GAQgASgFUgNlbmQSEgoEaW50NRgFIAEoBVIEaW50NRIUCgVsYWJlbBgGIAEoCVIFbGFiZWw=');

@$core.Deprecated('Use remoteAppInfoDescriptor instead')
const RemoteAppInfo$json = {
  '1': 'RemoteAppInfo',
  '2': [
    {'1': 'counter', '3': 1, '4': 1, '5': 5, '10': 'counter'},
    {'1': 'int2', '3': 2, '4': 1, '5': 5, '10': 'int2'},
    {'1': 'int3', '3': 3, '4': 1, '5': 5, '10': 'int3'},
    {'1': 'int4', '3': 4, '4': 1, '5': 9, '10': 'int4'},
    {'1': 'int7', '3': 7, '4': 1, '5': 5, '10': 'int7'},
    {'1': 'int8', '3': 8, '4': 1, '5': 5, '10': 'int8'},
    {'1': 'label', '3': 10, '4': 1, '5': 9, '10': 'label'},
    {'1': 'app_package', '3': 12, '4': 1, '5': 9, '10': 'appPackage'},
    {'1': 'int13', '3': 13, '4': 1, '5': 5, '10': 'int13'},
  ],
};

/// Descriptor for `RemoteAppInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteAppInfoDescriptor = $convert.base64Decode(
    'Cg1SZW1vdGVBcHBJbmZvEhgKB2NvdW50ZXIYASABKAVSB2NvdW50ZXISEgoEaW50MhgCIAEoBV'
    'IEaW50MhISCgRpbnQzGAMgASgFUgRpbnQzEhIKBGludDQYBCABKAlSBGludDQSEgoEaW50NxgH'
    'IAEoBVIEaW50NxISCgRpbnQ4GAggASgFUgRpbnQ4EhQKBWxhYmVsGAogASgJUgVsYWJlbBIfCg'
    'thcHBfcGFja2FnZRgMIAEoCVIKYXBwUGFja2FnZRIUCgVpbnQxMxgNIAEoBVIFaW50MTM=');

@$core.Deprecated('Use remoteImeKeyInjectDescriptor instead')
const RemoteImeKeyInject$json = {
  '1': 'RemoteImeKeyInject',
  '2': [
    {
      '1': 'app_info',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteAppInfo',
      '10': 'appInfo'
    },
    {
      '1': 'text_field_status',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteTextFieldStatus',
      '10': 'textFieldStatus'
    },
  ],
};

/// Descriptor for `RemoteImeKeyInject`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteImeKeyInjectDescriptor = $convert.base64Decode(
    'ChJSZW1vdGVJbWVLZXlJbmplY3QSMAoIYXBwX2luZm8YASABKAsyFS5yZW1vdGUuUmVtb3RlQX'
    'BwSW5mb1IHYXBwSW5mbxJJChF0ZXh0X2ZpZWxkX3N0YXR1cxgCIAEoCzIdLnJlbW90ZS5SZW1v'
    'dGVUZXh0RmllbGRTdGF0dXNSD3RleHRGaWVsZFN0YXR1cw==');

@$core.Deprecated('Use remoteImeShowRequestDescriptor instead')
const RemoteImeShowRequest$json = {
  '1': 'RemoteImeShowRequest',
  '2': [
    {
      '1': 'remote_text_field_status',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteTextFieldStatus',
      '10': 'remoteTextFieldStatus'
    },
  ],
};

/// Descriptor for `RemoteImeShowRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteImeShowRequestDescriptor = $convert.base64Decode(
    'ChRSZW1vdGVJbWVTaG93UmVxdWVzdBJWChhyZW1vdGVfdGV4dF9maWVsZF9zdGF0dXMYAiABKA'
    'syHS5yZW1vdGUuUmVtb3RlVGV4dEZpZWxkU3RhdHVzUhVyZW1vdGVUZXh0RmllbGRTdGF0dXM=');

@$core.Deprecated('Use remoteImeObjectDescriptor instead')
const RemoteImeObject$json = {
  '1': 'RemoteImeObject',
  '2': [
    {'1': 'start', '3': 1, '4': 1, '5': 5, '10': 'start'},
    {'1': 'end', '3': 2, '4': 1, '5': 5, '10': 'end'},
    {'1': 'value', '3': 3, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `RemoteImeObject`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteImeObjectDescriptor = $convert.base64Decode(
    'Cg9SZW1vdGVJbWVPYmplY3QSFAoFc3RhcnQYASABKAVSBXN0YXJ0EhAKA2VuZBgCIAEoBVIDZW'
    '5kEhQKBXZhbHVlGAMgASgJUgV2YWx1ZQ==');

@$core.Deprecated('Use remoteEditInfoDescriptor instead')
const RemoteEditInfo$json = {
  '1': 'RemoteEditInfo',
  '2': [
    {'1': 'insert', '3': 1, '4': 1, '5': 5, '10': 'insert'},
    {
      '1': 'text_field_status',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteImeObject',
      '10': 'textFieldStatus'
    },
  ],
};

/// Descriptor for `RemoteEditInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteEditInfoDescriptor = $convert.base64Decode(
    'Cg5SZW1vdGVFZGl0SW5mbxIWCgZpbnNlcnQYASABKAVSBmluc2VydBJDChF0ZXh0X2ZpZWxkX3'
    'N0YXR1cxgCIAEoCzIXLnJlbW90ZS5SZW1vdGVJbWVPYmplY3RSD3RleHRGaWVsZFN0YXR1cw==');

@$core.Deprecated('Use remoteImeBatchEditDescriptor instead')
const RemoteImeBatchEdit$json = {
  '1': 'RemoteImeBatchEdit',
  '2': [
    {'1': 'ime_counter', '3': 1, '4': 1, '5': 5, '10': 'imeCounter'},
    {'1': 'field_counter', '3': 2, '4': 1, '5': 5, '10': 'fieldCounter'},
    {
      '1': 'edit_info',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.remote.RemoteEditInfo',
      '10': 'editInfo'
    },
  ],
};

/// Descriptor for `RemoteImeBatchEdit`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteImeBatchEditDescriptor = $convert.base64Decode(
    'ChJSZW1vdGVJbWVCYXRjaEVkaXQSHwoLaW1lX2NvdW50ZXIYASABKAVSCmltZUNvdW50ZXISIw'
    'oNZmllbGRfY291bnRlchgCIAEoBVIMZmllbGRDb3VudGVyEjMKCWVkaXRfaW5mbxgDIAMoCzIW'
    'LnJlbW90ZS5SZW1vdGVFZGl0SW5mb1IIZWRpdEluZm8=');

@$core.Deprecated('Use remoteVoiceBeginDescriptor instead')
const RemoteVoiceBegin$json = {
  '1': 'RemoteVoiceBegin',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 5, '10': 'sessionId'},
    {'1': 'package_name', '3': 2, '4': 1, '5': 9, '10': 'packageName'},
  ],
};

/// Descriptor for `RemoteVoiceBegin`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteVoiceBeginDescriptor = $convert.base64Decode(
    'ChBSZW1vdGVWb2ljZUJlZ2luEh0KCnNlc3Npb25faWQYASABKAVSCXNlc3Npb25JZBIhCgxwYW'
    'NrYWdlX25hbWUYAiABKAlSC3BhY2thZ2VOYW1l');

@$core.Deprecated('Use remoteVoicePayloadDescriptor instead')
const RemoteVoicePayload$json = {
  '1': 'RemoteVoicePayload',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 5, '10': 'sessionId'},
    {'1': 'samples', '3': 2, '4': 1, '5': 12, '10': 'samples'},
  ],
};

/// Descriptor for `RemoteVoicePayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteVoicePayloadDescriptor = $convert.base64Decode(
    'ChJSZW1vdGVWb2ljZVBheWxvYWQSHQoKc2Vzc2lvbl9pZBgBIAEoBVIJc2Vzc2lvbklkEhgKB3'
    'NhbXBsZXMYAiABKAxSB3NhbXBsZXM=');

@$core.Deprecated('Use remoteVoiceEndDescriptor instead')
const RemoteVoiceEnd$json = {
  '1': 'RemoteVoiceEnd',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 5, '10': 'sessionId'},
  ],
};

/// Descriptor for `RemoteVoiceEnd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteVoiceEndDescriptor = $convert.base64Decode(
    'Cg5SZW1vdGVWb2ljZUVuZBIdCgpzZXNzaW9uX2lkGAEgASgFUglzZXNzaW9uSWQ=');

@$core.Deprecated('Use remoteKeyInjectDescriptor instead')
const RemoteKeyInject$json = {
  '1': 'RemoteKeyInject',
  '2': [
    {'1': 'key_code', '3': 1, '4': 1, '5': 5, '10': 'keyCode'},
    {
      '1': 'direction',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.remote.RemoteDirection',
      '10': 'direction'
    },
  ],
};

/// Descriptor for `RemoteKeyInject`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteKeyInjectDescriptor = $convert.base64Decode(
    'Cg9SZW1vdGVLZXlJbmplY3QSGQoIa2V5X2NvZGUYASABKAVSB2tleUNvZGUSNQoJZGlyZWN0aW'
    '9uGAIgASgOMhcucmVtb3RlLlJlbW90ZURpcmVjdGlvblIJZGlyZWN0aW9u');

@$core.Deprecated('Use remotePingResponseDescriptor instead')
const RemotePingResponse$json = {
  '1': 'RemotePingResponse',
  '2': [
    {'1': 'val1', '3': 1, '4': 1, '5': 5, '10': 'val1'},
  ],
};

/// Descriptor for `RemotePingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remotePingResponseDescriptor = $convert
    .base64Decode('ChJSZW1vdGVQaW5nUmVzcG9uc2USEgoEdmFsMRgBIAEoBVIEdmFsMQ==');

@$core.Deprecated('Use remotePingRequestDescriptor instead')
const RemotePingRequest$json = {
  '1': 'RemotePingRequest',
  '2': [
    {'1': 'val1', '3': 1, '4': 1, '5': 5, '10': 'val1'},
    {'1': 'val2', '3': 2, '4': 1, '5': 5, '10': 'val2'},
  ],
};

/// Descriptor for `RemotePingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remotePingRequestDescriptor = $convert.base64Decode(
    'ChFSZW1vdGVQaW5nUmVxdWVzdBISCgR2YWwxGAEgASgFUgR2YWwxEhIKBHZhbDIYAiABKAVSBH'
    'ZhbDI=');

@$core.Deprecated('Use remoteSetActiveDescriptor instead')
const RemoteSetActive$json = {
  '1': 'RemoteSetActive',
  '2': [
    {'1': 'active', '3': 1, '4': 1, '5': 5, '10': 'active'},
  ],
};

/// Descriptor for `RemoteSetActive`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteSetActiveDescriptor = $convert
    .base64Decode('Cg9SZW1vdGVTZXRBY3RpdmUSFgoGYWN0aXZlGAEgASgFUgZhY3RpdmU=');

@$core.Deprecated('Use remoteDeviceInfoDescriptor instead')
const RemoteDeviceInfo$json = {
  '1': 'RemoteDeviceInfo',
  '2': [
    {'1': 'model', '3': 1, '4': 1, '5': 9, '10': 'model'},
    {'1': 'vendor', '3': 2, '4': 1, '5': 9, '10': 'vendor'},
    {'1': 'unknown1', '3': 3, '4': 1, '5': 5, '10': 'unknown1'},
    {'1': 'unknown2', '3': 4, '4': 1, '5': 9, '10': 'unknown2'},
    {'1': 'package_name', '3': 5, '4': 1, '5': 9, '10': 'packageName'},
    {'1': 'app_version', '3': 6, '4': 1, '5': 9, '10': 'appVersion'},
  ],
};

/// Descriptor for `RemoteDeviceInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteDeviceInfoDescriptor = $convert.base64Decode(
    'ChBSZW1vdGVEZXZpY2VJbmZvEhQKBW1vZGVsGAEgASgJUgVtb2RlbBIWCgZ2ZW5kb3IYAiABKA'
    'lSBnZlbmRvchIaCgh1bmtub3duMRgDIAEoBVIIdW5rbm93bjESGgoIdW5rbm93bjIYBCABKAlS'
    'CHVua25vd24yEiEKDHBhY2thZ2VfbmFtZRgFIAEoCVILcGFja2FnZU5hbWUSHwoLYXBwX3Zlcn'
    'Npb24YBiABKAlSCmFwcFZlcnNpb24=');

@$core.Deprecated('Use remoteConfigureDescriptor instead')
const RemoteConfigure$json = {
  '1': 'RemoteConfigure',
  '2': [
    {'1': 'code1', '3': 1, '4': 1, '5': 5, '10': 'code1'},
    {
      '1': 'device_info',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteDeviceInfo',
      '10': 'deviceInfo'
    },
  ],
};

/// Descriptor for `RemoteConfigure`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteConfigureDescriptor = $convert.base64Decode(
    'Cg9SZW1vdGVDb25maWd1cmUSFAoFY29kZTEYASABKAVSBWNvZGUxEjkKC2RldmljZV9pbmZvGA'
    'IgASgLMhgucmVtb3RlLlJlbW90ZURldmljZUluZm9SCmRldmljZUluZm8=');

@$core.Deprecated('Use remoteErrorDescriptor instead')
const RemoteError$json = {
  '1': 'RemoteError',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 8, '10': 'value'},
    {
      '1': 'message',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteMessage',
      '10': 'message'
    },
  ],
};

/// Descriptor for `RemoteError`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteErrorDescriptor = $convert.base64Decode(
    'CgtSZW1vdGVFcnJvchIUCgV2YWx1ZRgBIAEoCFIFdmFsdWUSLwoHbWVzc2FnZRgCIAEoCzIVLn'
    'JlbW90ZS5SZW1vdGVNZXNzYWdlUgdtZXNzYWdl');

@$core.Deprecated('Use remoteMessageDescriptor instead')
const RemoteMessage$json = {
  '1': 'RemoteMessage',
  '2': [
    {
      '1': 'remote_configure',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteConfigure',
      '10': 'remoteConfigure'
    },
    {
      '1': 'remote_set_active',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteSetActive',
      '10': 'remoteSetActive'
    },
    {
      '1': 'remote_error',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteError',
      '10': 'remoteError'
    },
    {
      '1': 'remote_ping_request',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.remote.RemotePingRequest',
      '10': 'remotePingRequest'
    },
    {
      '1': 'remote_ping_response',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.remote.RemotePingResponse',
      '10': 'remotePingResponse'
    },
    {
      '1': 'remote_key_inject',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteKeyInject',
      '10': 'remoteKeyInject'
    },
    {
      '1': 'remote_ime_key_inject',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteImeKeyInject',
      '10': 'remoteImeKeyInject'
    },
    {
      '1': 'remote_ime_batch_edit',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteImeBatchEdit',
      '10': 'remoteImeBatchEdit'
    },
    {
      '1': 'remote_ime_show_request',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteImeShowRequest',
      '10': 'remoteImeShowRequest'
    },
    {
      '1': 'remote_voice_begin',
      '3': 30,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteVoiceBegin',
      '10': 'remoteVoiceBegin'
    },
    {
      '1': 'remote_voice_payload',
      '3': 31,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteVoicePayload',
      '10': 'remoteVoicePayload'
    },
    {
      '1': 'remote_voice_end',
      '3': 32,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteVoiceEnd',
      '10': 'remoteVoiceEnd'
    },
    {
      '1': 'remote_start',
      '3': 40,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteStart',
      '10': 'remoteStart'
    },
    {
      '1': 'remote_set_volume_level',
      '3': 50,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteSetVolumeLevel',
      '10': 'remoteSetVolumeLevel'
    },
    {
      '1': 'remote_app_link_launch_request',
      '3': 90,
      '4': 1,
      '5': 11,
      '6': '.remote.RemoteAppLinkLaunchRequest',
      '10': 'remoteAppLinkLaunchRequest'
    },
  ],
};

/// Descriptor for `RemoteMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteMessageDescriptor = $convert.base64Decode(
    'Cg1SZW1vdGVNZXNzYWdlEkIKEHJlbW90ZV9jb25maWd1cmUYASABKAsyFy5yZW1vdGUuUmVtb3'
    'RlQ29uZmlndXJlUg9yZW1vdGVDb25maWd1cmUSQwoRcmVtb3RlX3NldF9hY3RpdmUYAiABKAsy'
    'Fy5yZW1vdGUuUmVtb3RlU2V0QWN0aXZlUg9yZW1vdGVTZXRBY3RpdmUSNgoMcmVtb3RlX2Vycm'
    '9yGAMgASgLMhMucmVtb3RlLlJlbW90ZUVycm9yUgtyZW1vdGVFcnJvchJJChNyZW1vdGVfcGlu'
    'Z19yZXF1ZXN0GAggASgLMhkucmVtb3RlLlJlbW90ZVBpbmdSZXF1ZXN0UhFyZW1vdGVQaW5nUm'
    'VxdWVzdBJMChRyZW1vdGVfcGluZ19yZXNwb25zZRgJIAEoCzIaLnJlbW90ZS5SZW1vdGVQaW5n'
    'UmVzcG9uc2VSEnJlbW90ZVBpbmdSZXNwb25zZRJDChFyZW1vdGVfa2V5X2luamVjdBgKIAEoCz'
    'IXLnJlbW90ZS5SZW1vdGVLZXlJbmplY3RSD3JlbW90ZUtleUluamVjdBJNChVyZW1vdGVfaW1l'
    'X2tleV9pbmplY3QYFCABKAsyGi5yZW1vdGUuUmVtb3RlSW1lS2V5SW5qZWN0UhJyZW1vdGVJbW'
    'VLZXlJbmplY3QSTQoVcmVtb3RlX2ltZV9iYXRjaF9lZGl0GBUgASgLMhoucmVtb3RlLlJlbW90'
    'ZUltZUJhdGNoRWRpdFIScmVtb3RlSW1lQmF0Y2hFZGl0ElMKF3JlbW90ZV9pbWVfc2hvd19yZX'
    'F1ZXN0GBYgASgLMhwucmVtb3RlLlJlbW90ZUltZVNob3dSZXF1ZXN0UhRyZW1vdGVJbWVTaG93'
    'UmVxdWVzdBJGChJyZW1vdGVfdm9pY2VfYmVnaW4YHiABKAsyGC5yZW1vdGUuUmVtb3RlVm9pY2'
    'VCZWdpblIQcmVtb3RlVm9pY2VCZWdpbhJMChRyZW1vdGVfdm9pY2VfcGF5bG9hZBgfIAEoCzIa'
    'LnJlbW90ZS5SZW1vdGVWb2ljZVBheWxvYWRSEnJlbW90ZVZvaWNlUGF5bG9hZBJAChByZW1vdG'
    'Vfdm9pY2VfZW5kGCAgASgLMhYucmVtb3RlLlJlbW90ZVZvaWNlRW5kUg5yZW1vdGVWb2ljZUVu'
    'ZBI2CgxyZW1vdGVfc3RhcnQYKCABKAsyEy5yZW1vdGUuUmVtb3RlU3RhcnRSC3JlbW90ZVN0YX'
    'J0ElMKF3JlbW90ZV9zZXRfdm9sdW1lX2xldmVsGDIgASgLMhwucmVtb3RlLlJlbW90ZVNldFZv'
    'bHVtZUxldmVsUhRyZW1vdGVTZXRWb2x1bWVMZXZlbBJmCh5yZW1vdGVfYXBwX2xpbmtfbGF1bm'
    'NoX3JlcXVlc3QYWiABKAsyIi5yZW1vdGUuUmVtb3RlQXBwTGlua0xhdW5jaFJlcXVlc3RSGnJl'
    'bW90ZUFwcExpbmtMYXVuY2hSZXF1ZXN0');
