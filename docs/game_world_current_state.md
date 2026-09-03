# Текущее состояние игрового мира

> Актуально на 2026-09-03 для `HEAD 76adad0` и текущего незакоммиченного worktree.
> Это рабочая карта фактической реализации. Перед изменением ядра сначала проверь
> `git diff` и затем обнови этот документ.

## Краткий итог

Сейчас реализован **технический concept demo**, а не матч MOBA. Он доказывает,
что одна и та же детерминированная Rust-логика может исполняться из CLI-симулятора
и из Godot 4.7 через GDExtension.

Реализованы:

- один персонаж без identity, характеристик, здоровья и способностей;
- движение в двух координатах с фиксированным тиком 60 Hz;
- целочисленная позиция: `1000` единиц = `1` метр;
- ограничение аналогового ввода единичной окружностью;
- прямоугольная карта и запрет выхода центра персонажа за её границы;
- жизненный цикл `Running -> Stopped`;
- хранение каждого рассчитанного snapshot;
- локальная Godot-демонстрация и smoke test.

Не реализованы сервер, сеть, несколько сущностей, бои, способности, крипы,
предметы, цели матча, authoritative snapshots, prediction/reconciliation,
rollback/replay, коллизии мира и навигация.

## Архитектурные границы

```text
Godot input (Vector2, f32)
        |
        v
moba_godot::PredictionWorld        crates/godot_bridge
        | quantize to i16
        v
match_runtime::MatchRuntime        crates/match_runtime
        | one advance = one tick
        v
match_core::World                  crates/match_core
        | fixed-point deterministic rules
        v
WorldSnapshot

simulator binary -----------------> MatchRuntime -> World
```

### `match_core`

Файл: `crates/match_core/src/lib.rs`.

Это единственное место с правилами мира. Публичный API:

- `TICKS_PER_SECOND = 60`;
- `UNITS_PER_METER = 1000`;
- `FixedVec2` — целочисленная координата;
- `MovementIntent` — нормализованный ввод с осями `i16`;
- `WorldConfig` и `WorldConfigError`;
- `WorldSnapshot` — tick, позиция и приватный дробный остаток движения;
- `World::{new, snapshot, config, advance}`.

`World::advance` рассчитывает смещение только целыми числами. Неделимый остаток
переносится на следующие тики. Затем позиция независимо по X/Y ограничивается
границами карты. При попытке пройти сквозь границу остаток соответствующей оси
сбрасывается.

`WorldConfig::concept_demo()`:

| Параметр | Значение |
|---|---:|
| Половина карты | 10 x 6 м |
| Половина размера персонажа | 0.4 м |
| Допустимый центр | X: ±9.6 м, Y: ±5.6 м |
| Скорость | 4 м/с |
| Spawn | (0, 0) |

### `match_runtime`

Файл: `crates/match_runtime/src/lib.rs`.

`MatchRuntime` владеет `World`, `Vec<WorldSnapshot>` и `MatchStatus`. Внешнего
clock/scheduler нет: каждый вызов `advance(intent)` означает ровно один tick.
История начинается со snapshot tick 0, поэтому текущий инвариант:

```text
history_len == current.tick + 1
```

Runtime умеет читать snapshot по tick или `Duration` и необратимо остановить
матч с первой причиной остановки. Он не хранит inputs и не умеет восстановить
мир из snapshot.

### `simulator`

Файл: `crates/simulator/src/main.rs`.

Это фиксированный smoke binary, а не полноценный симулятор. Он без аргументов
прогоняет `MovementIntent::RIGHT` в течение 65 игровых секунд и печатает итог.
Нет сценариев, seed, ботов, файла входов, assertions результата, replay API или
структурированного отчёта.

Текущий вывод:

```text
SIMULATOR_CONCEPT_PASS time=1:05 tick=3900 position=(9.600, 0.000)m history_states=3901
```

### Godot bridge

Файлы:

- `crates/godot_bridge/src/lib.rs`;
- `client/native/moba_godot.gdextension`;
- `client/scripts/simulation/prediction_demo.gd`;
- `client/tests/prediction_world_runtime_test.gd`.

`PredictionWorld : RefCounted` экспортирует в Godot:

```text
advance(Vector2) -> Vector2
current_position() -> Vector2
current_tick() -> int
game_time_seconds() -> float
position_at_time(float) -> Vector2
reset() -> void
```

Входной `Vector2` ограничивается длиной 1, квантуется в `i16` и только после
этого попадает в deterministic core. Позиция возвращается как метры в `f32`.
Один `_physics_process` вызывает один tick; `_delta` не используется. Совпадение
с 60 Hz сейчас зависит от стандартной частоты physics Godot, но setting явно не
зафиксирован.

Активная main scene действительно запускает этот demo. Старые сцены лучника,
крипов и боя существуют отдельно и Rust-ядро не используют.

## Инварианты, которые уже выражены кодом

1. Валидная конфигурация требует положительные размер персонажа и скорость.
2. Персонаж должен помещаться на карте, а spawn — лежать в допустимой области.
3. Длина `MovementIntent` не превышает максимальную длину аналогового ввода.
4. Один `advance` всегда увеличивает tick ровно на один.
5. Позиция остаётся внутри границ карты.
6. Одинаковое начальное состояние и одинаковые inputs дают одинаковый итоговый snapshot.
7. Остановленный runtime больше не изменяет мир.
8. Tick 0 присутствует в истории; каждый успешный advance добавляет один snapshot.

Пункты 1, 3, 4, 7 и часть граничных случаев пока недостаточно покрыты тестами.

## Проверенное качество

На 2026-09-03 выполнен полный `./tools/check.sh`:

- `cargo fmt --check` — успешно;
- `cargo clippy --workspace --all-targets -- -D warnings` — успешно;
- `cargo test --workspace` — 6 Rust-тестов успешно;
- сборка `moba_godot` — успешно;
- `gdformat`, `gdlint`, anti-slop/complexity gate — успешно;
- проверка всех GDScript файлов Godot 4.7.1 — успешно;
- headless запуск main scene — успешно;
- Godot integration test — `PREDICTION_WORLD_RUNTIME_PASS`.

Существующие содержательные тесты:

| Область | Кейсы |
|---|---|
| core | 4 м за 60 тиков; запрет выхода за X; ограничение диагонали |
| runtime | snapshot на 65 секунде; одинаковый итог при одинаковом вводе; запрет advance после stop |
| Godot bridge | 60 правых тиков дают 4 м; snapshot на 1 секунде равен current |
| simulator | отдельных тестов нет |

## Подтверждённые дефекты и опасные контракты

### P0 до настоящего networking/prediction

1. **Prediction/reconciliation отсутствуют.** `PredictionWorld` — только локальный
   world. Нет input sequence/tick, authoritative snapshot, ack, divergence,
   restore, rollback и replay.
2. **Snapshot нельзя восстановить.** История состояний без истории inputs и API
   восстановления не позволяет reconciliation или воспроизводимый replay.
3. **Нет entity/player identity.** Один `MovementIntent` управляет единственным
   неименованным персонажем.
4. **Нет wire DTO/serialization/versioning.** Публичные Rust-типы пока не являются
   сетевым контрактом.

### P1 корректность и эксплуатация текущего прототипа

1. **Преобразование tick/time не является обратимым.** Из-за двух округлений вниз
   `tick_to_duration(1)` даёт `16_666_666 ns`, а `duration_to_tick` возвращает `0`.
   Поэтому `snapshot_at_time(runtime.game_time())` на большинстве тиков возвращает
   предыдущий snapshot. Тесты проверяют только целые секунды.
2. **История растёт без лимита.** `WorldSnapshot` занимает 40 байт на текущей
   платформе: около 2.4 KB/s и 8.64 MB/час на один runtime без учёта capacity.
3. **Ошибки bridge скрываются или превращаются в panic.** `expect` стоит на создании
   и advance; отсутствующий snapshot возвращается как `Vector2.ZERO`, который
   неотличим от валидной позиции. `position_at_time(+inf)` способен вызвать panic.
4. **Частота Godot не закреплена контрактом.** Изменение physics rate или пропуски
   вызовов меняют соотношение wall time и game time.
5. **Валидация `WorldConfig` не защищает весь диапазон `i64`.** Публичные экстремальные
   значения могут привести к overflow/панике в `abs`, умножении скорости,
   сложении позиции или расчёте границы.
6. **Поведение дробного остатка у стены не определено.** Он сбрасывается только
   при целочисленном пересечении границы. Точное касание с ненулевым остатком
   или малый outward input с нулевым delta может повлиять на последующий разворот.
7. **Simulator печатает `PASS` без проверки ожидаемого результата.** Кроме того,
   tick берётся из исторического snapshot, а позиция — из `current`; сейчас они
   совпадают только потому, что после lookup симуляция не продолжается.

### P1 доставка на мобильные платформы

1. Android preset экспортирует только `x86_64`; это demo для эмулятора, не сборка
   для обычных `arm64` устройств.
2. Скрипта воспроизводимой cross-build/copy/install-проверки нет. Native `.so` и
   APK являются ignored generated artifacts.
3. iOS path заявлен в `.gdextension`, но framework/preset/pipeline отсутствуют.
4. `run_android_test.sh` только запускает уже установленное приложение. Он не
   собирает, не устанавливает и не проверяет игровой результат.

## Gameplay: документация против реализации

Документы описывают целевую MOBA: битву двух армий, три линии обороны, пленение
короля, разные типы крипов, contested drops, лесных мобов, караван, предметы,
зелья и сложных универсальных героев. В коде мира ни одна из этих механик пока
не представлена.

| Домен | Документ | Реализация в Rust world |
|---|---|---|
| Победа/оборона/король | `docs/gameplay/игра_на_карте.md` | нет |
| Крипы, лагеря, караван | тот же документ | нет |
| Drops, инвентарь, предметы, зелья | тот же документ | нет |
| Типы урона/резисты | `docs/gameplay/тип_урона.md` | нет |
| Герои и способности | `docs/gameplay/**` | нет |
| Здоровье, урон, лечение, щиты, control | несколько hero docs | нет |
| Пространственные объекты/телепорт/силы | `Vitruta.md` | нет |
| Тепло и elemental interaction | `азхаран/Концепт.md` | нет |
| Ауры и комбинации состояний | `кирелиан/**` | нет |
| Командные мини-игры способностей | `ТребованияКГероям.md` | только design principle |

Gameplay-документы в основном концептуальные и не задают точные численные
контракты, порядок систем, stacking, targeting, cooldown, длительности,
interrupt rules или разрешение одновременных событий. Их нельзя напрямую
реализовать без отдельных решений/spec/ADR.

## Рассогласования документации

- `README.md` говорит, что активен только клиент, но текущий worktree уже содержит
  Rust workspace, shared core, runtime и simulator.
- Сломанная ссылка `docs/архитектура.md -> simulator/README.md` при этом аудите
  заменена ссылкой на данный документ.
- ADR 0001 не обещает shared code и считает prediction будущим решением, тогда как
  concept demo уже выбрал shared deterministic Rust и назван `PredictionWorld`.
  ADR имеет статус «ЧЕРНОВИК», поэтому решение нужно явно пересмотреть, а не
  считать автоматически отменённым.
- Rust workspace и вся интеграция в момент исследования ещё untracked. До commit
  текущий результат легко потерять и он не существует в `HEAD 76adad0`.

## Рекомендуемый порядок развития

1. **Зафиксировать фундаментальные контракты ADR:** authoritative server, tick rate,
   fixed-point policy, input DTO, entity IDs, system order, snapshot/versioning.
2. **Исправить текущий фундамент:** time round-trip, bounded history policy,
   безопасный config, явные bridge errors, тесты инвариантов и property cases.
3. **Добавить replay-ready input timeline:** tick + player/entity + sequence,
   deterministic ordering, сохранение inputs, state hash, restore/resimulate.
4. **Разделить WorldState и systems:** entity registry, movement, collision,
   health/damage/effects; не начинать со сложного ECS без измеримой причины.
5. **Сделать simulator инструментом:** сценарии из данных, assertions, seed,
   headless batch runs, отчёт и первый divergent tick.
6. **Вертикальный gameplay slice:** два героя + крипы + один objective + победа.
   Не реализовывать сразу все геройские концепты.
7. **Только затем networking:** authoritative snapshot/ack, client prediction,
   rollback/replay и presentation interpolation.
8. **После стабилизации ABI:** Android arm64 и iOS build/test pipeline.

## Правило актуализации

При любом изменении `crates/match_core`, `crates/match_runtime`, `crates/simulator`,
`crates/godot_bridge` или их публичного Godot-контракта обновляй:

1. разделы архитектуры/API/инвариантов этого файла;
2. матрицу тестов и список известных рисков;
3. дату и commit/worktree context в начале;
4. результат `./tools/check.sh`.
