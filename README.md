# logIn

> English version: [README.en.md](README.en.md)

`logIn` — проект маршрутизации и управления DPI для OpenWrt. Репозиторий: <https://github.com/AxelNerv/LogIn>. `loghorizon` — внутреннее пространство имён будущих пакетов, служб и конфигов.

Фундамент собран на базе [Forkop](https://github.com/ushan0v/forkop), который сам является форком [Podkop](https://github.com/itdoginfo/podkop). Маршрутизация, подписки, диагностика и провайдеры DPI работают как раньше, пока поверх них строится новая оболочка продукта и поэтапный переезд рантайма на собственные имена.

## Установка

```sh
sh <(wget -O - https://raw.githubusercontent.com/AxelNerv/LogIn/main/install.sh)
```

Установщик берёт пакеты из релизов `AxelNerv/LogIn`, сам определяет формат (ipk для OpenWrt 24.10, apk для 25.12 и новее) и доставляет зависимости. Пакеты собираются с `PKGARCH:=all`, поэтому подходят любому роутеру.

## Удаление

```sh
sh <(wget -O - https://raw.githubusercontent.com/AxelNerv/LogIn/main/uninstall.sh)
```

Останавливает службу, возвращает dnsmasq, снимает правила firewall и удаляет пакеты — включая sing-box и движки DPI, которые logIn ставил сам. После этого роутер готов принять другой пакет маршрутизации: проверено установкой podkop сразу следом.

Флаг `--keep-config` сохраняет `/etc/config/loghorizon`, `--keep-components` оставляет sing-box и движки DPI.

## Текущий этап

- Брендинг `logIn` в LuCI.
- Operator Calm как единственное направление интерфейса.
- Собственное пространство имён `loghorizon`: пакеты, служба, конфиг, пути.
- Миграция с podkop при установке; с forkop мигрировать неоткуда.
- Основной профиль — роутеры с 256 МБ ОЗУ, планируется Lite для 128 МБ.

## Проверки фронтенда локально

```sh
cd fe-app-loghorizon && yarn install --frozen-lockfile && yarn lint --max-warnings=0 && yarn test --run && yarn build
```

Собранный бандл LuCI лежит в `luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon/main.js` и **закоммичен в репозиторий**. CI падает, если пересборка меняет этот файл, поэтому после любой правки в `fe-app-loghorizon/src` пересобирай.

Проверки бэкенда — обычные bash-скрипты:

```sh
printf '%s\0' tests/*.sh | xargs -0 -n1 -P4 bash
```

## Переводы

Строки интерфейса пишутся в исходниках по-английски и переводятся на русский через gettext. Извлекатель видит **только строковые литералы внутри `_()`** — строка, собранная из переменной, в каталог не попадёт и останется английской. После добавления или правки любого текста интерфейса:

```sh
cd fe-app-loghorizon && yarn locales:actualize
```

Затем заполни новые пустые `msgstr ""` в `locales/loghorizon.ru.po` и выполни `node distribute-locales.js`.

## Прототип интерфейса

Открой `design/logIn Operator Calm.html` в браузере. Operator Calm — единственное направление: тёмное, спокойное, ориентированное на состояние и достаточно лёгкое для LuCI. Интерфейс **только тёмный** и намеренно не подстраивается под тему LuCI.

## Документы проекта

- [Фундамент и миграция пространства имён](docs/FOUNDATION.md)
- [Информационная архитектура](docs/INFORMATION_ARCHITECTURE.md)
- [Профили маршрутизации и управляемые сети](docs/ROUTING_AND_NETWORKS.md)
- [Чеклист релиза](docs/RELEASE_CHECKLIST.md)
- [Факты о продукте](product-facts.md)
- [Основа бренда](brand-spec.md)

## Лицензия и атрибуция

Код роутера — производная работа под GPL-2.0-or-later. Копирайты и уведомления об авторстве, унаследованные от Forkop и Podkop, обязаны остаться на месте: это условие лицензии, а не вопрос оформления. Самостоятельно разработанные компоненты документируются отдельно по мере появления.
