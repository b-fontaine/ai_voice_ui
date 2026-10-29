// Les barrels sont importés pour vérifier que les paquets se résolvent et
// se compilent avec l'app ; ils ne portent pas encore de symboles.
// ignore_for_file: unused_import

import 'package:entity_session/entity_session.dart';
import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/di/injection.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';

void main() {
  test('configureDependencies initialise une instance GetIt isolée', () {
    final getIt = GetIt.asNewInstance();

    expect(() => configureDependencies(getIt), returnsNormally);
    expect(liveEnvironment.name, 'live');
  });
}
