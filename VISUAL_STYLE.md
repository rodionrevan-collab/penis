# VISUAL_STYLE.md — визуальный стандарт «Три в ряд»

## Цель
Увести проект от прототипного procedural-art к цельному 2D-стилю коммерческой tropical match-3 игры.

## Базовый стиль
- Яркая тропическая палитра: бирюзовая вода, тёплый песок, зелень, коралл и золотые акценты.
- Объекты имеют мягкие тени, чёткий контур и небольшой объём.
- Игровые фишки должны хорошо читаться при размере клетки около 78 px.
- Спецфишки имеют собственный узнаваемый рисунок и не зависят от формы базовой фишки.
- Квадрат 2×2 создаёт отдельный «пропеллер», а не обычное исчезновение четырёх фишек.
- Карта уровней использует ровную змейку из 5 уровней в ряд; центры узлов выровнены по сетке.
- Состояния узлов: зелёный + галочка только для пройденных, красный для доступных, серый для заблокированных.
- Интерфейс использует тот же язык цветов, но остаётся достаточно тёмным для контраста игрового поля.

## Уже подключено
### UI и эффекты
- art/ui/board_frame.svg
- art/ui/cell.svg
- art/ui/selection.svg
- art/ui/star_filled.svg
- art/ui/star_empty.svg
- art/ui/level_completed.svg
- art/ui/level_available.svg
- art/ui/level_locked.svg
- art/ui/booster_hammer.svg
- art/ui/booster_moves.svg
- art/ui/booster_shuffle.svg
- art/fx/match_burst.svg
- art/fx/combo_ring.svg
- art/fx/special_ray.svg
- art/fx/propeller_trail.svg
- art/island/map_pin.svg
- art/island/unlocked_zone_badge.svg

### Фоны
- art/backgrounds/menu_background.svg
- art/backgrounds/game_background.svg
- art/backgrounds/island_map_background.svg
- art/backgrounds/level_map_background.svg

### Базовые фишки
- art/gems/gem_red.svg
- art/gems/gem_blue.svg
- art/gems/gem_green.svg
- art/gems/gem_yellow.svg
- art/gems/gem_purple.svg
- art/gems/gem_orange.svg

### Спецфишки
- art/specials/horizontal.svg
- art/specials/vertical.svg
- art/specials/bomb.svg
- art/specials/rainbow.svg

### Препятствия
- art/obstacles/vine_blocker.svg
- art/obstacles/coconut.svg
- art/obstacles/tide_swirl.svg
- art/obstacles/cursed_totem.svg
- art/obstacles/monkey.svg
- art/obstacles/fog.svg
- art/obstacles/fire_stone.svg
- art/obstacles/final_totem.svg
- art/obstacles/spider.svg

### Остров
- NPC: Lisa, Tom, Keeper, Merchant.
- Объекты: bridge, hut, jungle path, dock, pirate cove, lighthouse, cave, village.
- Отдельный сундук.
- Интерактивы: lantern, pirate chart, ancient lock, trade scale.
- Активности: compass, rune, goods, trade order.
- Map pin и badge для разблокированных зон.

## Правило дальнейшей разработки
Новый игровой объект сначала получает отдельный 2D-ассет, затем подключается к логике. Новые важные объекты не должны снова превращаться в Label с символом или простую геометрическую заглушку.

## Следующий визуальный блок
1. Проверка нового ассет-пака в Godot 4.7.2 и корректировка масштабов после реального запуска.
2. Полировка экрана результата, карты уровней и главного меню.
3. Отдельный проход мелких UI/UX багов и выравнивания элементов.
4. Проверка обменов/каскадов после визуального прохода.
5. Затем — финальный аудит всех механик и прогрессии без изменения рабочей логики.