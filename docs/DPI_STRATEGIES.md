# Стратегии обхода DPI

Рабочая заготовка для подбора стратегии под своего провайдера. Ничего из
этого не является «правильным ответом»: какой набор пробьёт блокировку,
зависит от конкретного оператора, и проверяется только замером.

## Где брать теорию

Официальное описание всех ключей nfqws, с объяснением что делает каждый режим
рассинхронизации — <https://github.com/bol-van/zapret/blob/master/docs/readme.md#nfqws>.
Это первоисточник; если нужно собрать свою стратегию с нуля, читать надо его.

Набор готовых стратегий под Windows, откуда взята таблица ниже —
<https://github.com/Flowseal/zapret-discord-youtube>.

## Как устроен отбор доменов

Важно понимать до того, как копировать чужие строки: **в logIn домены
отбирает sing-box, а не nfqws**. Ключи вида `--hostlist`, `--hostlist-domains`
и `--ipset` здесь не работают и отклоняются проверкой — трафик доходит до
очереди уже отфильтрованным по спискам секции.

Практическое следствие: внутри одной секции нельзя дать разные стратегии
разным сайтам. Нужны разные стратегии — заводите разные секции, у каждой свой
список и своя строка. Очереди назначаются автоматически (4000+ для Zapret,
4300+ для Zapret2), несколько DPI-секций работают одновременно.

## Что проверено на живой линии

Замерено 30.08.2026 на МГТС, по 12 запросов на хост. Роутер ASUS TUF-AX4200,
OpenWrt 24.10.5.

### Рабочая схема: две секции, по движку на каждую цель

Одна секция на обе цели не удержалась: подобранная строка закрывала то
YouTube, то Discord, а через час картина менялась. Развели по секциям — и
обе цели держатся стабильно.

| Секция | Движок | Список | Результат |
| --- | --- | --- | --- |
| `dpiYT` | Zapret | `youtube` | www.youtube.com 12/12 (0.13 с), yt3.ggpht.com 12/12 (0.12 с) |
| `dpiDS` | Zapret2 | `discord` | discord.com 12/12 (0.54 с), gateway.discord.gg 12/12 (0.17 с) |

Строка для секции YouTube (Zapret):

```
--filter-tcp=80 --dpi-desync=fake,multisplit --dpi-desync-split-pos=method+2 --dpi-desync-fooling=badseq --new --filter-tcp=443 --dpi-desync=fake,multisplit --dpi-desync-split-pos=1,midsld --dpi-desync-split-seqovl=681 --dpi-desync-fooling=badseq --dpi-desync-repeats=6 --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic=/opt/zapret/files/fake/quic_initial_www_google_com.bin
```

Строка для секции Discord (Zapret2):

```
--filter-tcp=80 --filter-l7=http --payload=http_req --lua-desync=fake:blob=fake_default_http:tcp_md5 --lua-desync=multisplit:pos=method+2 --new --filter-tcp=443 --filter-l7=tls --payload=tls_client_hello --lua-desync=fake:blob=fake_default_tls:tcp_md5:tcp_seq=-10000 --lua-desync=multidisorder:pos=1,midsld --new --filter-udp=443 --filter-l7=quic --payload=quic_initial --lua-desync=fake:blob=fake_default_quic:repeats=6
```

### Почему движки разные

Проверено, а не выбрано наугад. Перенос секции YouTube на Zapret2 с той же
строкой, что работает у Discord, даёт `www.youtube.com` 0/10 при полностью
рабочих очередях — то есть трафик через DPI идёт, но строка v2 этот домен не
пробивает. На Zapret первой версии тот же домен даёт 10/10.

Так что дело не в «двух движках ради двух секций»: у каждой цели своя
работающая строка, а строки написаны под разные версии. Две секции на одном
движке технически работают (очереди 4300 и 4301 набирались пакетами), просто
результат хуже.

### Порядок секций решает

DPI-секции должны стоять **выше** секции, которая гонит трафик в тоннель.
Правила проверяются сверху вниз, первое совпадение выигрывает, и если у
тоннельной секции в списках есть те же домены, она заберёт их себе.

Ошибка обходится дорого, потому что выглядит как успех: сайт открывается,
замеры зелёные — только идёт он через VPN, а не через DPI, со всеми
последствиями для пинга.

### Как убедиться, что трафик реально идёт через DPI

Не по спискам nftables: DPI-секция и тоннельная ставят **одинаковую** метку,
набор говорит лишь «завернуть в sing-box», а секцию выбирает уже он. Судить
по принадлежности адреса к набору бесполезно.

Смотреть надо счётчики очередей:

```sh
nft list ruleset | grep 'queue flags bypass'
```

Ненулевой счётчик у очереди секции означает, что её движок получает пакеты.
Ноль — трафик идёт мимо, какие бы красивые цифры ни давали замеры.

## Таблица стратегий Flowseal

Пути к заготовкам уже переписаны под расположение в OpenWrt
(`/opt/zapret/files/fake/`). Трёх файлов в пакете OpenWrt нет — `stun2.bin`,
`tls_clienthello_4pda_to.bin` и `tls_clienthello_sochi_park.bin` — вместо них
подставлены `stun.bin` и `tls_clienthello_max_ru.bin`. Это меняет поведение
стратегии, так что расхождения с оригиналом ожидаемы.

Колонка «Discord» — результат на МГТС, 4 запроса к `discord.com`. Пустая
клетка означает 0/4. Это **не** оценка стратегии вообще: у другого оператора
цифры будут другими, потому и нужен тестер.

| Стратегия | Discord | Строка |
| --- | --- | --- |
| general (ALT) | 1/4 | `--dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls=/opt/zapret/files/fake/stun.bin --dpi-desync-fake-tls=/opt/zapret/files/fake/tls_clienthello_www_google_com.bin --dpi-desync-fake-http=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |
| general (ALT10) |  | `--dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fake-tls=/opt/zapret/files/fake/stun.bin --dpi-desync-fake-tls=/opt/zapret/files/fake/tls_clienthello_max_ru.bin --dpi-desync-fake-http=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |
| general (ALT11) |  | `--dpi-desync=fake,multisplit --dpi-desync-split-seqovl=664 --dpi-desync-split-pos=1 --dpi-desync-fooling=ts --dpi-desync-repeats=8 --dpi-desync-split-seqovl-pattern=/opt/zapret/files/fake/tls_clienthello_max_ru.bin --dpi-desync-fake-tls=/opt/zapret/files/fake/stun.bin --dpi-desync-fake-tls=/opt/zapret/files/fake/tls_clienthello_max_ru.bin --dpi-desync-fake-http=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |
| general (ALT13) | 4/4 | `--dpi-desync=fake,hostfakesplit --dpi-desync-fooling=ts --dpi-desync-hostfakesplit-mod=host=mail.ru,altorder=1 --dpi-desync-repeats=5 --dpi-desync-fake-tls=/opt/zapret/files/fake/tls_clienthello_max_ru.bin --dpi-desync-fake-tls=/opt/zapret/files/fake/stun.bin --dpi-desync-fake-http=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |
| general (ALT2) |  | `--dpi-desync=multisplit --dpi-desync-split-seqovl=652 --dpi-desync-split-pos=2 --dpi-desync-split-seqovl-pattern=/opt/zapret/files/fake/tls_clienthello_www_google_com.bin` |
| general (ALT3) | 4/4 | `--dpi-desync=fake,hostfakesplit --dpi-desync-fake-tls-mod=rnd,dupsid,sni=ya.ru --dpi-desync-hostfakesplit-mod=host=ya.ru,altorder=1 --dpi-desync-fooling=ts --dpi-desync-fake-http=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |
| general (ALT4) | 3/4 | `--dpi-desync=fake,multisplit --dpi-desync-repeats=6 --dpi-desync-fooling=badseq --dpi-desync-badseq-increment=1000 --dpi-desync-fake-tls=/opt/zapret/files/fake/stun.bin --dpi-desync-fake-tls=/opt/zapret/files/fake/tls_clienthello_www_google_com.bin --dpi-desync-fake-http=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |
| general (ALT5) |  | `--dpi-desync=syndata,multidisorder` |
| general (ALT6) | 4/4 | `--dpi-desync=multisplit --dpi-desync-split-seqovl=681 --dpi-desync-split-pos=1 --dpi-desync-split-seqovl-pattern=/opt/zapret/files/fake/tls_clienthello_www_google_com.bin` |
| general (ALT7) | 4/4 | `--dpi-desync=multisplit --dpi-desync-split-pos=2,sniext+1 --dpi-desync-split-seqovl=679 --dpi-desync-split-seqovl-pattern=/opt/zapret/files/fake/tls_clienthello_www_google_com.bin` |
| general (ALT8) |  | `--dpi-desync=fake --dpi-desync-fake-tls-mod=none --dpi-desync-repeats=6 --dpi-desync-fooling=badseq --dpi-desync-badseq-increment=2 --dpi-desync-fake-http=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |
| general (ALT9) |  | `--dpi-desync=hostfakesplit --dpi-desync-repeats=4 --dpi-desync-fooling=ts,md5sig --dpi-desync-hostfakesplit-mod=host=ozon.ru` |
| general (EXP) |  | `--dpi-desync=fake,multisplit --dpi-desync-split-seqovl=480 --dpi-desync-split-pos=1 --dpi-desync-fooling=ts --dpi-desync-repeats=4 --dpi-desync-split-seqovl-pattern=/opt/zapret/files/fake/stun.bin --dpi-desync-fake-tls=/opt/zapret/files/fake/tls_clienthello_max_ru.bin --dpi-desync-fake-http=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |
| general (FAKE TLS AUTO ALT) |  | `--dpi-desync=fake,fakedsplit --dpi-desync-split-pos=1 --dpi-desync-fooling=badseq --dpi-desync-badseq-increment=2 --dpi-desync-repeats=8 --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --dpi-desync-fake-http=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |
| general (FAKE TLS AUTO ALT2) |  | `--dpi-desync=fake,multisplit --dpi-desync-split-seqovl=681 --dpi-desync-split-pos=1 --dpi-desync-fooling=badseq --dpi-desync-badseq-increment=10000000 --dpi-desync-repeats=8 --dpi-desync-split-seqovl-pattern=/opt/zapret/files/fake/tls_clienthello_www_google_com.bin --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --dpi-desync-fake-http=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |
| general (FAKE TLS AUTO ALT3) | 4/4 | `--dpi-desync=fake,multisplit --dpi-desync-split-seqovl=681 --dpi-desync-split-pos=1 --dpi-desync-fooling=ts --dpi-desync-repeats=8 --dpi-desync-split-seqovl-pattern=/opt/zapret/files/fake/tls_clienthello_www_google_com.bin --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --dpi-desync-fake-http=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |
| general (FAKE TLS AUTO) | не стартует | `--dpi-desync=fake,multidisorder --dpi-desync-split-pos=1,midsld --dpi-desync-repeats=11 --dpi-desync-fooling=badseq --dpi-desync-fake-tls=0x00000000 --dpi-desync-fake-tls=^! --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --dpi-desync-fake-http=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |
| general (SIMPLE FAKE ALT) | 4/4 | `--dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fooling=badseq --dpi-desync-badseq-increment=2 --dpi-desync-fake-tls=/opt/zapret/files/fake/stun.bin --dpi-desync-fake-tls=/opt/zapret/files/fake/tls_clienthello_www_google_com.bin --dpi-desync-fake-http=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |
| general (SIMPLE FAKE) | 4/4 | `--dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fake-tls=/opt/zapret/files/fake/tls_clienthello_www_google_com.bin --dpi-desync-fake-http=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |
| general |  | `--dpi-desync=multisplit --dpi-desync-split-seqovl=568 --dpi-desync-split-pos=1 --dpi-desync-split-seqovl-pattern=/opt/zapret/files/fake/tls_clienthello_max_ru.bin` |

## Тестер

В установленном пакете `loghorizon blockcheck` перебирает строки из файла и
меряет каждую. Репозиторный `tools/dpi-strategy-test.sh` запускает тот же
backend. Запускать на самом роутере:

```sh
loghorizon blockcheck -s dpiDS -f strategies.txt -t discord.com,www.youtube.com
```

Формат файла — имя, символ табуляции, строка стратегии. Скрипт применяет
каждую через UCI и перезапускает службу, потому что только так применяются
списки секции и правила nftables. Исходная стратегия восстанавливается в
конце, в том числе если прервать скрипт.

### Чему верить в его выводе

- **Выдержка обязательна.** Сразу после перезапуска sing-box ещё догружает
  наборы правил, и часть трафика идёт мимо DPI. Замер в этот момент показывает
  красивые числа, не имеющие отношения к стратегии. Скрипт ждёт 22 секунды.
- **Одиночный запрос ничего не значит.** Разброс большой: один и тот же хост
  на четырёх попытках даёт 4/4, а на восьми — 0/8. Меньше 8 запросов на хост
  выводы делать нельзя.
- **Мерять надо с роутера.** У клиента за роутером может быть свой обход
  (ExitLag и подобное), и тогда замер вообще не про logIn.
- **Одинаковые числа у всех стратегий — признак поломки стенда**, а не
  открытия. Значит стратегия не применяется, и результат надо выбросить.
- **Потеря обычного доступа вызывает немедленный откат.** Перед замерами
  проверяется нейтральный HTTPS-адрес; две неудачи возвращают исходную стратегию.
- **Ошибку отката скрывать нельзя.** Успешное завершение печатается только после
  возврата исходного UCI-значения и успешного перезапуска службы.
- Рядом с долей успешных запросов выводится среднее время ответа (`avg=...ms`).
