import 'package:shared_backend_channel/shared_backend_channel.dart';

/// Enveloppe du canal applicatif, v1, pour piloter un [AppChannel] de test.
AppChannelEnvelope envelopeOf(
  String type,
  Map<String, Object?> data, {
  String session = 's1',
}) => AppChannelEnvelope(
  version: 1,
  type: type,
  session: session,
  tMs: 10,
  data: data,
);
