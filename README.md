# RobloxProject

Основная игра проекта находится в каталоге [NightRaid](NightRaid/). Корневой Rojo-проект — вспомогательная стартовая заготовка; для разработки игры используйте конфигурации внутри `NightRaid`.

## Требования

- [Roblox Studio](https://www.roblox.com/create)
- [Aftman](https://github.com/LPGhatguy/aftman) — менеджер инструментов проекта
- Rojo 7.7.1 (устанавливается через Aftman по файлу `NightRaid/aftman.toml`)

## Установка инструментов

Откройте терминал в каталоге `NightRaid`:

```bash
cd NightRaid
aftman install
```

## Запуск игры

Из каталога `NightRaid` выполните:

```bash
rojo serve default.project.json
```

Подключитесь к серверу через Rojo Plugin в Roblox Studio.

## Запуск автотестов

Тесты запускаются отдельно от обычной игры:

```bash
rojo serve test.project.json
```

После подключения Rojo Plugin запустите игру кнопкой Play и смотрите результат в окне Output. Сейчас набор содержит 37 проверок.

## Сборка файлов place

```bash
rojo build default.project.json --output NightRaid.rbxlx
rojo build test.project.json --output NightRaidTests.rbxlx
```

GitHub Actions автоматически проверяет, что обе конфигурации Rojo собираются при изменениях в `NightRaid/**` и при Pull Request в `main`. Эта проверка собирает проекты, но не запускает игровой код в Roblox Studio.
