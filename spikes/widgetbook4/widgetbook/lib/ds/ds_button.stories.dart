import 'package:flutter/widgets.dart';
import 'package:ds_spike/ds_spike.dart';
import 'package:widgetbook/widgetbook.dart';

part 'ds_button.stories.g.dart';

const meta = Meta(DsButton.new);
const tonalMeta = Meta(DsButton.tonal);

final $Default = _Story(
  args: _Args(
    label: StringArg('Valider'),
    onPressed: Arg.fixed(() {}),
  ),
);

final $Disabled = _Story(
  args: _Args(
    label: StringArg('Valider'),
    onPressed: Arg.fixed(null),
  ),
);

final $Tonal = _TonalStory(
  args: _TonalArgs(
    label: StringArg('Annuler'),
    onPressed: Arg.fixed(() {}),
  ),
);
