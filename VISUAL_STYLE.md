# VISUAL_STYLE.md — визуальный стандарт «Три в ряд»

## Цель
Увести проект от прототипного procedural-art к цельному 2D-стилю коммерческой tropical match-3 игры.

## Базовый стиль
- Яркая тропическая палитра: бирюзовая вода, тёплый песок, зелень, коралл и золотые акценты.
- Объекты имеют мягкие тени, чёткий контур и небольшой объём.
- Игровые фишки должны хорошо читаться при размере клетки около 78 px.
- Спецфишки имеют собственный узнаваемый рисунок и не зависят от формы базовой фишки.
- Интерфейс использует тот же язык цветов, но остаётся достаточно тёмным для контраста игрового поля.

## Уже подключено
### Фоны
- art/backgrounds/menu_background.svg
- art/backgrounds/game_background.svg
- art/backgrounds/island_map_background.svg

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
- art/specials/map_fragment.svg

### Препятствия
- art/obstacles/vine_blocker.svg
- art/obstacles/coconut.svg
- art/obstacles/fire_stone.svg
- art/obstacles/spider.svg

### Остров
- NPC: Lisa, Tom, Keeper, Merchant.
- Объекты: bridge, hut, jungle path, dock, pirate cove, lighthouse, cave, village.
- Отдельный сундук.

## Правило дальнейшей разработки
Новый игровой объект сначала получает отдельный 2D-ассет, затем подключается к логике. Новые важные объекты не должны снова превращаться в Label с символом или простую геометрическую заглушку.

## Следующий визуальный блок
1. Полная замена procedural-спецэффектов.
2. Улучшение рамки и клетки игрового поля.
3. Анимации фишек и спецфишек.
4. Полировка UI уровней, результата и бустеров.
5. Замена оставшихся procedural-объектов острова.
6. Затем отдельный проход мелких UI/UX багов.