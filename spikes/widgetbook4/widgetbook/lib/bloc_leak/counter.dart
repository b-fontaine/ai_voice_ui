import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

sealed class CounterEvent {}

final class CounterIncremented extends CounterEvent {}

/// Bloc minimal pour reproduire l'issue Widgetbook #1984.
class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc(super.initial) {
    on<CounterIncremented>((event, emit) => emit(state + 1));
  }
}

/// Vue « feature » qui lit le Bloc fourni par un ancêtre.
class CounterView extends StatelessWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<CounterBloc>().state;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('count=$count', key: const Key('count')),
        FilledButton(
          onPressed: () => context.read<CounterBloc>().add(CounterIncremented()),
          child: const Text('+1'),
        ),
      ],
    );
  }
}
