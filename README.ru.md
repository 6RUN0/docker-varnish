# Varnish Docker Image с s6-overlay и метриками Prometheus

Данный образ Docker на базе Debian предназначен для [Varnish Cache](https://varnish-cache.org), управляется через [s6-overlay](https://github.com/just-containers/s6-overlay) и включает:

- Сборку **Varnish** из исходников
- Дополнительные VMOD-модули (например, [varnish-modules](https://github.com/varnish/varnish-modules), [libvmod-dynamic](https://github.com/nigoroll/libvmod-dynamic))
- Оптимальные настройки для логирования и производительности
- Встроенный **экспортер Prometheus** для метрик [varnishstat](https://varnish-cache.org/docs/trunk/reference/varnishstat.html)
- Воспроизводимую сборку с фиксированными репозиториями, коммитами и контрольными суммами

---

## Оглавление

- [Особенности](#особенности)
- [Быстрый старт](#быстрый-старт)
- [Сервисы под управлением s6](#сервисы-под-управлением-s6)
- [Конфигурация](#конфигурация)
- [Файловая структура и тома](#файловая-структура-и-тома)
- [Обновление версий](#обновление-версий)
- [Примечания](#примечания)
- [Лицензия](#лицензия)
- [Ссылки](#ссылки)

---

## Особенности

- **Debian base**
  Используется образ на базе Debian с [s6-overlay](https://github.com/just-containers/s6-overlay) - системой инициализации и супервизором процессов.

- **Varnish из исходников**
  Varnish собирается из официального архива.

- **Дополнительные VMOD-модули**
  Включены популярные модули:
  - [varnish-modules](https://github.com/varnish/varnish-modules)
  - [libvmod-dynamic](https://github.com/nigoroll/libvmod-dynamic)
  - Дополнительные утилиты из [toolbox](https://github.com/varnish/toolbox) и [docker-varnish](https://github.com/varnish/docker-varnish) (примеры VCL)

- **Метрики Prometheus**
  В контейнере запускается [varnish_exporter](https://github.com/MooncellWiki/varnish_exporter), который собирает метрики и публикует их на настраиваемом адресе (по умолчанию `:9131`).

- **Структурированное логирование**
  [varnishncsa](https://varnish-cache.org/docs/trunk/reference/varnishncsa.html) работает как отдельный сервис, формат и фильтры логов настраиваются (например, для интеграции с Loki).

---

## Быстрый старт

### Сборка образа

```bash
docker build -t my-varnish .
```

### Запуск контейнера

Минимальный пример (Varnish слушает порт `6081` на хосте):

```bash
docker run --rm \
  -p 6081:6081 \
  my-varnish
```

Обычно подключают свой VCL и настраивают параметры окружения:

```bash
docker run --rm \
  -p 6081:6081 \
  -v $(pwd)/etc/varnish:/etc/varnish:ro \
  -e VARNISH_CONFIG_FILE=/etc/varnish/default.vcl \
  my-varnish
```

### Пример docker-compose

```yaml
services:
  varnish:
    image: my-varnish
    container_name: varnish
    restart: unless-stopped
    ports:
      - "6081:6081" # HTTP listener
      - "9131:9131" # Prometheus metrics (varnish_exporter)
    environment:
      VARNISH_LISTEN_HTTP: ":6081"
      VARNISH_MANAGEMENT_INTERFACE: "127.0.0.1:6082"
      VARNISH_CONFIG_FILE: "/etc/varnish/default.vcl"
      VARNISH_MEMORY_SIZE: "256m"
      VARNISHNCSA_FORMAT: "/etc/varnish/log_format_loki"
      VARNISHNCSA_FILTER: "/etc/varnish/log_filter_ge_400"
      VARNISH_EXPORTER_LISTEN_ADDRESS: ":9131"
      VARNISH_EXPORTER_TELEMETRY_PATH: "/metrics"
    volumes:
      - ./etc/varnish:/etc/varnish:ro
```

---

## Сервисы под управлением s6

Контейнер использует **s6-overlay** для управления несколькими процессами:

- **`svc-varnishd`** — основной демон Varnish ([varnishd](https://varnish-cache.org/docs/trunk/reference/varnishd.html)), HTTP и управляющий порт.
- **`svc-varnishncsa`** — сервис логирования, выводит логи в stdout/stderr в настраиваемом формате.
- **`svc-varnish-exporter`** — сервис экспорта метрик Prometheus, собирает статистику через varnishstat.

---

## Конфигурация

### Переменные окружения для Varnish

Все параметры можно переопределить через `docker run -e ...` или секцию `environment:` в `docker-compose.yml`.

| Переменная | Значение по умолчанию | Описание |
|------------|----------------------|----------|
| `VARNISH_CACHE_UID` | `101` | `UID` для `varnishd` и владельца `/var/lib/varnish` |
| `VARNISH_GID` | `101` | `GID` для процессов Varnish |
| `VARNISH_MANAGEMENT_INTERFACE` | `127.0.0.1:6082` | Управляющий интерфейс |
| `VARNISH_LISTEN_HTTP` | `:6081` | `HTTP` адрес для входящих соединений |
| `VARNISH_CONFIG_FILE` | ``/etc/varnish/default.vcl`` | Основной `VCL`-файл |
| `VARNISH_MEMORY_SIZE` | `256m` | Размер памяти для кеша |

### Переменные для логирования

| Переменная | Значение по умолчанию | Описание |
|------------|----------------------|----------|
| `VARNISHLOG_UID` | `102` | `UID` для `varnishncsa` |
| `VARNISHNCSA_FORMAT` | `/etc/varnish/log_format_loki` | Формат логов |
| `VARNISHNCSA_FILTER` | `/etc/varnish/log_filter_ge_400` | Фильтр логов |

### Переменные для экспорта метрик

| Переменная | Значение по умолчанию | Описание |
|------------|----------------------|----------|
| `VARNISH_EXPORTER_LISTEN_ADDRESS` | `:9131` | Адрес для экспорта метрик |
| `VARNISH_EXPORTER_TELEMETRY_PATH` | `/metrics` | `HTTP` путь для метрик |

---

## Файловая структура и тома

Важные пути внутри контейнера:

- `/etc/varnish` — конфигурация, VCL, форматы и фильтры логов
- `/var/lib/varnish` — хранилище Varnish
- `/var/log/varnish` — логи (если настроено)

Пример томов:

```yaml
volumes:
  - ./etc/varnish:/etc/varnish:ro
  - varnish-storage:/var/lib/varnish
  - varnish-logs:/var/log/varnish
```

---

## Обновление версий

1. Измените нужные переменные и ссылки в Dockerfile
2. Обновите фиксированные коммиты вспомогательных репозиториев
3. Пересоберите образ:

```bash
docker build -t my-varnish .
```

4. Задеплойте новый образ через Compose, Swarm, Kubernetes и т.д.

---

## Примечания

- В образе предполагаются системные пользователи с UID/GID, как указано выше. Если монтируете директории с хоста, убедитесь, что права совпадают.
- Конфигурация по умолчанию ориентирована на наблюдаемость. Всегда проверяйте `/etc/varnish/default.vcl` и настраивайте таймауты, правила кеширования и бэкенды под своё приложение.
- Не публикуйте управляющий порт Varnish наружу — это небезопасно!

---

## Лицензия

Данный репозиторий **не распространяет** Varnish или его модули напрямую. За лицензиями обращайтесь к соответствующим проектам:

- Varnish Cache — <https://varnish-cache.org/>
- varnish-modules — <https://github.com/varnish/varnish-modules>
- libvmod-dynamic — <https://github.com/nigoroll/libvmod-dynamic>
- varnish_exporter — <https://github.com/MooncellWiki/varnish_exporter>

## Ссылки

- [Varnish HTTP Cache](https://varnish-cache.org)
- [Varnish Official Image](https://hub.docker.com/_/varnish)
- [github.com/MooncellWiki/varnish_exporter](https://github.com/MooncellWiki/varnish_exporter)
- [github.com/gquintard](https://github.com/gquintard)
- [github.com/jonnenauha/prometheus_varnish_exporter](https://github.com/jonnenauha/prometheus_varnish_exporter)
- [github.com/otto-de/prometheus_varnish_exporter](https://github.com/otto-de/prometheus_varnish_exporter)
- [github.com/varnish](https://github.com/varnish)
- [github.com/varnishcache](https://github.com/varnishcache)
