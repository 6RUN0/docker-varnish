# Образ Docker с Varnish, s6-overlay и метриками Prometheus

Debian-образ Docker для [Varnish Cache](https://varnish-cache.org), управляемый [s6-overlay](https://github.com/just-containers/s6-overlay), с:

- Собранным из исходников **Varnish**
- Дополнительными VMOD-модулями (например, [varnish-modules](https://github.com/varnish/varnish-modules),
  [libvmod-dynamic](https://github.com/nigoroll/libvmod-dynamic))
- Мнением автора по умолчанию для логирования и тюнинга
- Встроенным **Prometheus exporter** для метрик [varnishstat](https://varnish-cache.org/docs/trunk/reference/varnishstat.html)
- Воспроизводимой сборкой за счёт закреплённых репозиториев, коммитов и чек-сумм

---

## Содержание

- [Особенности](#особенности)
- [Быстрый старт](#быстрый-старт)
- [Сервисы под управлением s6](#сервисы-под-управлением-s6)
- [Конфигурация](#конфигурация)
- [Файловая структура и тома](#файловая-структура-и-тома)
- [Обновление версий](#обновление-версий)
- [Заметки и оговорки](#заметки-и-оговорки)
- [Лицензия](#лицензия)
- [См. также](#см-также)

Этот образ спроектирован как:

- Простой в запуске в продакшене
- Наблюдаемый (логи + метрики)
- Конфигурируемый через переменные окружения
- Снова собираемый и аудируемый

---

## Особенности

- **База на Debian**
  Используется образ на базе Debian с [s6-overlay](https://github.com/just-containers/s6-overlay)
  в качестве init-системы и процесс-супервизора.

- **Varnish, собранный из исходников**
  Varnish собирается из официального исходного тарбола.

- **Дополнительные VMOD-модули**
  Включены наиболее часто используемые модули, такие как:
  - [varnish-modules](https://github.com/varnish/varnish-modules)
  - [libvmod-dynamic](https://github.com/nigoroll/libvmod-dynamic)
  - Дополнительные утилиты Varnish из репозиториев [toolbox](https://github.com/varnish/toolbox)
    и [docker-varnish](https://github.com/varnish/docker-varnish)
    (например, примерные VCL-файлы).

- **Метрики Prometheus**
  Включён процесс [varnish_exporter](https://github.com/MooncellWiki/varnish_exporter),
  управляемый s6 и публикующий метрики на настраиваемом адресе (по умолчанию `:9131`).

- **Структурированное логирование**
  [varnishncsa](https://varnish-cache.org/docs/trunk/reference/varnishncsa.html) запускается отдельным сервисом,
  использует настраиваемый формат и фильтры (например, оптимизирован для загрузки в Loki).

---

## Быстрый старт

### Сборка образа

```bash
docker build -t my-varnish .
```

Вы можете переопределять аргументы сборки (см. [Аргументы сборки](#аргументы-сборки)):

### Запуск контейнера

Минимальный пример (Varnish слушает на порту хоста `6081`):

```bash
docker run --rm \
  -p 6081:6081 \
  my-varnish
```

Обычно вы будете монтировать свой VCL и настраивать параметры рантайма:

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
      # varnishd
      VARNISH_LISTEN_HTTP: ":6081"
      VARNISH_MANAGEMENT_INTERFACE: "127.0.0.1:6082"
      VARNISH_CONFIG_FILE: "/etc/varnish/default.vcl"
      VARNISH_MEMORY_SIZE: "256m"
      # varnishncsa logging
      VARNISHNCSA_FORMAT: "/etc/varnish/log_format_loki"
      VARNISHNCSA_FILTER: "/etc/varnish/log_filter_ge_400"
      # Prometheus exporter
      VARNISH_EXPORTER_LISTEN_ADDRESS: ":9131"
      VARNISH_EXPORTER_TELEMETRY_PATH: "/metrics"
    volumes:
      - ./etc/varnish:/etc/varnish:ro
```

---

## Сервисы под управлением s6

Контейнер использует **s6-overlay** для управления несколькими процессами:

- **`svc-varnishd`**
  Основной демон Varnish ([varnishd](https://varnish-cache.org/docs/trunk/reference/varnishd.html)), поднимает HTTP-лисенер и management-порт.

- **`svc-varnishncsa`**
  Запускает [varnishncsa](https://varnish-cache.org/docs/trunk/reference/varnishncsa.html) на переднем плане и отправляет access-логи в stdout/stderr в настраиваемом формате.

- **`svc-varnish-exporter`**
  Запускает [varnish_exporter](https://github.com/MooncellWiki/varnish_exporter) для метрик Prometheus,
  опрашивающий [varnishstat](https://varnish-cache.org/docs/trunk/reference/varnishstat.html)
  у работающего экземпляра Varnish.

Сервисы определены в `rootfs/etc/s6-overlay/s6-rc.d/` и автоматически запускаются при старте контейнера.

---

## Конфигурация

### Аргументы сборки

Эти аргументы используются только на этапе сборки образа (`docker build --build-arg ...`).
Точные значения по умолчанию и закреплённые хэши коммитов см. в `Dockerfile`.

| ARG | Описание |
|-----|----------|
| `DEBIAN_GOLANG_BASE_IMAGE` | Базовый образ для сборки [varnish_exporter](https://github.com/MooncellWiki/varnish_exporter) (Go toolchain). |
| `DEBIAN_BASE_IMAGE` | Базовый образ для финального runtime-образа с [s6-overlay](https://github.com/just-containers/s6-overlay). |
| `VARNISH_VERSION` | Версия Varnish для сборки (например, `8.0.0`). |
| `VARNISH_REPO_PACKAGE` | Git-репозиторий с Debian-пакетами для Varnish ([pkg-varnish-cache](https://github.com/varnishcache/pkg-varnish-cache)). |
| `VARNISH_REPO_PACKAGE_COMMIT` | Закреплённый коммит [pkg-varnish-cache](https://github.com/varnishcache/pkg-varnish-cache) для воспроизводимой сборки. |
| `VARNISH_DIST_URL` | URL исходного tarball Varnish. |
| `VARNISH_DIST_SHA512` | SHA-512 чек-сумма исходного tarball Varnish. |
| `VARNISH_REPO_ALL_PACKAGER` | Репозиторий [all-packager](https://github.com/varnish/all-packager) (используется для сборки [varnish-modules](https://github.com/varnish/varnish-modules)). |
| `VARNISH_REPO_ALL_PACKAGER_COMMIT` | Закреплённый коммит [all-packager](https://github.com/varnish/all-packager). |
| `VARNISH_MODULES_VERSION` | Версия [varnish-modules](https://github.com/varnish/varnish-modules) для сборки. |
| `VARNISH_MODULES_DIST_URL` | URL исходного tarball [varnish-modules](https://github.com/varnish/varnish-modules). |
| `VARNISH_MODULES_SHA512SUM` | SHA-512 чек-сумма tarball [varnish-modules](https://github.com/varnish/varnish-modules). |
| `VARNISH_REPO_TOOLBOX` | Репозиторий Varnish [toolbox](https://github.com/varnish/toolbox) (вспомогательные скрипты, VCL и т. д.). |
| `VARNISH_REPO_TOOLBOX_COMMIT` | Закреплённый коммит [toolbox](https://github.com/varnish/toolbox). |
| `VMOD_DYNAMIC_REPO` | Репозиторий [libvmod-dynamic](https://github.com/nigoroll/libvmod-dynamic). |
| `VMOD_DYNAMIC_REPO_COMMIT` | Закреплённый коммит [libvmod-dynamic](https://github.com/nigoroll/libvmod-dynamic). |
| `VARNISH_REPO_DOCKER` | Официальный репозиторий [docker-varnish](https://github.com/varnish/docker-varnish) (дефолтный VCL и полезные скрипты). |
| `VARNISH_REPO_DOCKER_COMMIT` | Закреплённый коммит [docker-varnish](https://github.com/varnish/docker-varnish). |
| `VARNISH_EXPORTER_REPO` | Репозиторий проекта [varnish_exporter](https://github.com/MooncellWiki/varnish_exporter). |
| `VARNISH_EXPORTER_REPO_COMMIT` | Закреплённый коммит [varnish_exporter](https://github.com/MooncellWiki/varnish_exporter), используемый при сборке. |

> **Подсказка:** При обновлении версии Varnish или VMOD меняйте `*_VERSION` и связанные URL/чек-суммы/коммиты в одном коммите, чтобы сохранить воспроизводимость сборки.

---

### Переменные окружения рантайма – `svc-varnishd` (varnishd)

Эти переменные читаются в скрипте сервиса `svc-varnishd` и мапятся на параметры [varnishd](https://varnish-cache.org/docs/trunk/reference/varnishd.html).

| Переменная | Значение по умолчанию | Описание |
|-----------|------------------------|----------|
| `VARNISH_CACHE_UID` | `101` | UID для `varnishd` и владельца `/var/lib/varnish`. |
| `VARNISH_GID` | `101` | GID для процессов Varnish. |
| `VARNISH_MANAGEMENT_INTERFACE` | `127.0.0.1:6082` | Адрес/порт management-интерфейса (используется `varnishadm`). |
| `VARNISH_LISTEN_HTTP` | `:6081` | HTTP-лисенер для входящего трафика (`-a`). |
| `VARNISH_CONFIG_FILE` | `/etc/varnish/default.vcl` | Основной VCL-файл, загружаемый при старте. |
| `VARNISH_CONNECT_TIMEOUT` | `3.5` | [connect_timeout](https://varnish-cache.org/docs/trunk/reference/varnishd.html#connect-timeout), таймаут подключения к backend'ам по умолчанию. |
| `VARNISH_HTTP_REQ_HDR_LEN` | `8k` | [http_req_hdr_len](https://varnish-cache.org/docs/trunk/reference/varnishd.html#http-req-hdr-len), максимальная длина любого заголовка HTTP-запроса клиента. |
| `VARNISH_HTTP_RESP_HDR_LEN` | `8k` | [http_resp_hdr_len](https://varnish-cache.org/docs/trunk/reference/varnishd.html#http-resp-hdr-len), максимальная длина любого заголовка HTTP-ответа backend'а. |
| `VARNISH_HTTP_REQ_SIZE` | `32k` | [http_req_size](https://varnish-cache.org/docs/trunk/reference/varnishd.html#http-req-size), максимальный размер HTTP-запроса клиента, с которым будет работать Varnish. |
| `VARNISH_NUKE_LIMIT` | `50` | [nuke_limit](https://varnish-cache.org/docs/trunk/reference/varnishd.html#nuke-limit), максимум объектов, которые будут удалены при освобождении места под тело объекта. |
| `VARNISH_THREAD_POOLS` | `2` | [thread_pools](https://varnish-cache.org/docs/trunk/reference/varnishd.html#thread-pools), число пулов рабочих потоков. |
| `VARNISH_WORKSPACE_BACKEND` | `96k` | [workspace_backend](https://varnish-cache.org/docs/trunk/reference/varnishd.html#workspace-backend), объём workspace для backend HTTP req/resp. |
| `VARNISH_WORKSPACE_CLIENT` | `96k` | [workspace_client](https://varnish-cache.org/docs/trunk/reference/varnishd.html#workspace-client), объём workspace для HTTP req/resp клиента. |
| `VARNISH_WORKSPACE_SESSION` | `0.75k` | [workspace_session](https://varnish-cache.org/docs/trunk/reference/varnishd.html#workspace-session), размер выделения под структуру сессии и workspace. |
| `VARNISH_WORKSPACE_THREAD` | `2k` | [workspace_thread](https://varnish-cache.org/docs/trunk/reference/varnishd.html#workspace-thread), объём вспомогательного workspace на поток. |
| `VARNISH_MEMORY_SIZE` | `256m` | Размер кэша для `-s malloc,<size>`. См. [storage backend](https://varnish-cache.org/docs/trunk/reference/varnishd.html#storage-backend). |

Все эти значения можно переопределить во время запуска контейнера с помощью `docker run -e ...`
или через `environment:` в `docker-compose.yml`.

---

### Переменные окружения рантайма – `svc-varnishncsa` (access-логи)

Сервис `svc-varnishncsa` запускает [varnishncsa](https://varnish-cache.org/docs/trunk/reference/varnishncsa.html)
и выводит access-логи в stdout/stderr.

| Переменная | Значение по умолчанию | Описание |
|-----------|------------------------|----------|
| `VARNISHLOG_UID` | `102` | UID процесса `varnishncsa`. |
| `VARNISH_GID` | `101` | GID для `varnishncsa`. |
| `VARNISHNCSA_FORMAT` | `/etc/varnish/log_format_loki` | Путь к файлу со строкой формата `varnishncsa`. |
| `VARNISHNCSA_FILTER` | `/etc/varnish/log_filter_ge_400` | Путь к файлу с фильтром `varnishncsa`. |

Вы можете примонтировать собственные файлы формата/фильтра в `/etc/varnish/`,
чтобы кастомизировать вывод логов, например, для интеграции с Loki, ELK и т. д.

---

### Переменные окружения рантайма – `svc-varnish-exporter` (Prometheus exporter)

Сервис `svc-varnish-exporter` запускает Prometheus exporter, который собирает статистику
с запущенного экземпляра Varnish.

| Переменная | Значение по умолчанию | Описание |
|-----------|------------------------|----------|
| `VARNISHLOG_UID` | `102` | UID процесса `varnish_exporter`. |
| `VARNISH_GID` | `101` | GID для `varnish_exporter`. |
| `VARNISH_EXPORTER_LISTEN_ADDRESS` | `:9131` | Адрес/порт HTTP-сервера экспортера. |
| `VARNISH_EXPORTER_TELEMETRY_PATH` | `/metrics` | HTTP-путь для метрик Prometheus. |

Чтобы сделать метрики доступными вне контейнера, пробросьте порт экспортера:

```yaml
ports:
  - "9131:9131"
```

---

## Файловая структура и тома

Ключевые пути внутри контейнера:

- `/etc/varnish` – конфигурационные файлы, VCL, определения формата/фильтров логов.
- `/var/lib/varnish` – хранилище Varnish (индексы malloc, runtime-данные).
- `/var/log/varnish` – логи varnishncsa (если настроено логирование в файлы).

Типичные тома:

```yaml
volumes:
  - ./etc/varnish:/etc/varnish:ro
  - varnish-storage:/var/lib/varnish
  - varnish-logs:/var/log/varnish
```

---

## Обновление версий

Чтобы обновить Varnish или любой из VMOD-модулей:

1. Отредактируйте соответствующие `*_VERSION` и URL/чек-суммы в `Dockerfile`.
2. При необходимости обновите закреплённые коммиты (`*_COMMIT`) вспомогательных репозиториев.
3. Пересоберите образ:

   ```bash
   docker build -t my-varnish .
   ```

4. Задеплойте новый образ через ваш обычный workflow (Compose, Swarm, Kubernetes и т. д.).

---

## Заметки и оговорки

- Образ предполагает наличие системных пользователей,
  соответствующих `VARNISH_CACHE_UID` / `VARNISHLOG_UID` / `VARNISH_GID`.
  Если вы переопределяете эти ID или монтируете директории хоста с определёнными владельцами,
  убедитесь, что сопоставление UID/GID корректно.
  По умолчанию создаются следующие пользователи/группы:

```bash
cat /etc/passwd
...
varnish:x:100:101::/nonexistent:/usr/sbin/nologin
vcache:x:101:101::/nonexistent:/usr/sbin/nologin
varnishlog:x:102:101::/nonexistent:/usr/sbin/nologin
```

```bash
cat /etc/group
...
varnish:x:101:
```

- Конфигурация по умолчанию субъективна и оптимизирована под наблюдаемость.
  Обязательно проверьте `/etc/varnish/default.vcl` и настройте таймауты,
  правила кеширования и backend'ы под ваше приложение.

---

## Лицензия

Этот репозиторий **не** распространяет Varnish или его модули напрямую.
См. лицензии соответствующих upstream-проектов:

- Varnish Cache – <https://varnish-cache.org/>
- varnish-modules – <https://github.com/varnish/varnish-modules>
- libvmod-dynamic – <https://github.com/nigoroll/libvmod-dynamic>
- varnish_exporter – <https://github.com/MooncellWiki/varnish_exporter>

## См. также

- [Varnish HTTP Cache](https://varnish-cache.org)
- [Официальный образ Varnish](https://hub.docker.com/_/varnish)
- [github.com/MooncellWiki/varnish_exporter](https://github.com/MooncellWiki/varnish_exporter)
- [github.com/gquintard](https://github.com/gquintard)
- [github.com/jonnenauha/prometheus_varnish_exporter](https://github.com/jonnenauha/prometheus_varnish_exporter)
- [github.com/otto-de/prometheus_varnish_exporter](https://github.com/otto-de/prometheus_varnish_exporter)
- [github.com/varnish](https://github.com/varnish)
- [github.com/varnishcache](https://github.com/varnishcache)
