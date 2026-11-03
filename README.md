# RobloxProject

Основная игра проекта находится в каталоге [NightRaid](NightRaid/). Корневой Rojo-проект — вспомогательная стартовая заготовка; для разработки игры используйте конфигурации внутри `NightRaid`.

## Требования

- [Roblox Studio](https://www.roblox.com/create)
- [Aftman](https://github.com/LPGhatguy/aftman) — менеджер инструментов проекта
- Rojo 7.7.1 и Selene 0.32.0 (устанавливаются через Aftman по файлу `NightRaid/aftman.toml`)

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

## Статический анализ Luau

Selene проверяет исходный код на распространённые ошибки и проблемные конструкции без запуска игры:

```bash
selene src
```

Настройки Roblox/Luau находятся в `NightRaid/selene.toml`.

## Сборка файлов place

```bash
rojo build default.project.json --output NightRaid.rbxlx
rojo build test.project.json --output NightRaidTests.rbxlx
```

GitHub Actions автоматически запускает Selene и проверяет, что обе конфигурации Rojo собираются при изменениях в `NightRaid/**` и при Pull Request в `main`. Проверка Selene анализирует исходники, но не заменяет запуск игровых тестов в Roblox Studio.
