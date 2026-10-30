// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:feature_agent_activity/feature_agent_activity.dart' as _i6;
import 'package:feature_voice_session/feature_voice_session.dart' as _i679;
import 'package:genesis_canvas/app/config/genesis_config.dart' as _i32;
import 'package:genesis_canvas/app/di/app_module.dart' as _i580;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_backend_channel/shared_backend_channel.dart' as _i769;
import 'package:shared_core/shared_core.dart' as _i464;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final appModule = _$AppModule();
    gh.factory<_i679.TranscriptBloc>(() => appModule.transcriptBloc());
    gh.factory<_i6.AgentActivityBloc>(() => appModule.agentActivityBloc());
    gh.lazySingleton<_i464.AppClock>(() => appModule.clock());
    gh.lazySingleton<_i679.WebRtcPlatform>(() => appModule.webRtcPlatform());
    gh.lazySingleton<_i769.VoiceRelay>(
      () => appModule.voiceRelay(gh<_i32.GenesisConfig>()),
      dispose: _i580.closeVoiceRelay,
    );
    gh.lazySingleton<_i769.CanvasResetClient>(
      () => appModule.canvasResetClient(gh<_i32.GenesisConfig>()),
      dispose: _i580.closeCanvasResetClient,
    );
    gh.lazySingleton<_i769.CanvasActionClient>(
      () => appModule.canvasActionClient(gh<_i32.GenesisConfig>()),
      dispose: _i580.closeCanvasActionClient,
    );
    gh.lazySingleton<_i769.AppChannel>(
      () => appModule.appChannel(gh<_i32.GenesisConfig>(), gh<StringSink>()),
    );
    gh.factory<_i679.VoiceSession>(
      () => appModule.voiceSession(
        gh<_i580.VoiceTransportFactory>(),
        gh<_i769.VoiceRelay>(),
        gh<_i769.AppChannel>(),
        gh<_i580.EnvelopeLogFactory>(),
        gh<_i32.GenesisConfig>(),
      ),
    );
    return this;
  }
}

class _$AppModule extends _i580.AppModule {}
