/// API publique de shared_backend_channel.
library;

export 'src/app_channel.dart'
    show AppChannel, AppChannelFailure, AppChannelFailureKind;
export 'src/app_channel_envelope.dart'
    show
        AppChannelEnvelope,
        AppChannelFormatException,
        AppChannelTypes,
        maxEnvelopeLength;
export 'src/web_socket_app_channel.dart' show WebSocketAppChannel;
