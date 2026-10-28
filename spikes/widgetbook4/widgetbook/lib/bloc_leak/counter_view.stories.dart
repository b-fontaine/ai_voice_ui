import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook/widgetbook.dart';

import 'counter.dart';

part 'counter_view.stories.g.dart';

const meta = Meta(CounterView.new);

// Variante A — reproduction de #1984 : Bloc injecté par `setup`, sans clé.
final $SetupZero = _Story(
  setup: (context, child, args) =>
      BlocProvider(create: (_) => CounterBloc(0), child: child),
);

final $SetupHundred = _Story(
  setup: (context, child, args) =>
      BlocProvider(create: (_) => CounterBloc(100), child: child),
);

// Variante B — contournement candidat : même chose, mais clé unique par story.
final $KeyedZero = _Story(
  setup: (context, child, args) => BlocProvider(
    key: const ValueKey('keyed-0'),
    create: (_) => CounterBloc(0),
    child: child,
  ),
);

final $KeyedHundred = _Story(
  setup: (context, child, args) => BlocProvider(
    key: const ValueKey('keyed-100'),
    create: (_) => CounterBloc(100),
    child: child,
  ),
);
