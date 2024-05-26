# dcape-app-traefik

> Приложение ядра [dcape](https://github.com/dopos/dcape), reverse-proxy сервисов.

[![GitHub Release][1]][2] [![GitHub code size in bytes][3]]() [![GitHub license][4]][5]

[1]: https://img.shields.io/github/release/dopos/dcape-app-traefik.svg
[2]: https://github.com/dopos/dcape-app-traefik/releases
[3]: https://img.shields.io/github/languages/code-size/dopos/dcape-app-traefik.svg
[4]: https://img.shields.io/github/license/dopos/dcape-app-traefik.svg
[5]: LICENSE

 Роль в dcape | Сервис | Docker images
 --- | --- | ---
 router | [traefik](https://traefik.io/) | [traefik](https://hub.docker.com/_/traefik)

## Назначение

Агрегация и проксирование www-сервисов развернутых приложений по заданному имени с поддержкой сертификатов [Let's Encrypt](https://letsencrypt.org/)

Traefik - ключевой сервис **dcape**. Он решает следующие задачи:

* при запуске контейнера проанализировать его метки (`label`) и добавить контейнер в систему проксирования внешних http(s) запросов, определяя целевой контейнер по имени хоста
* если конфигурацией предусмотрена работа через TLS - проверить наличие сертификата и, при необходимости, получить или обновить его через сервис [Let's Encrypt](https://letsencrypt.org/)

## Особенности

### Варианты файла конфигурации {#configs}

В составе **dcape** есть три варианта файла конфигурации **traefik**:

* [traefik.local.yml](https://github.com/dopos/dcape/blob/v2/apps/traefik/traefik.local.yml) - использование DCAPE на локальном компьютере без поддержки TLS
* [traefik.acme-http.yml](https://github.com/dopos/dcape/blob/v2/apps/traefik/traefik.acme-http.yml) - https с получением сертификатов по протоколу `HTTP-01`
* [traefik.acme.yml](https://github.com/dopos/dcape/blob/v2/apps/traefik/traefik.acme.yml) - https с получением сертификатов по протоколу `HTTP-01` и `DNS-01` (для поддержки wildcard-доменов)

При выполнении команды `make apply`, по значению параметра `ACME` определяется вариант конфигурации и соответствующий файл копируется в `var/traefik/traefik.yml` с заменой переменных (если его еще нет).

### Ограничение видимости контейнеров

Для того, чтобы конкретный экземпляр traefik отреагировал на запуск контейнера, в конфигурации контейнера надо указать две метки:

```docker-compose.yml
    labels:
      - traefik.enable=true
      - dcape.traefik.tag=${DCAPE_TAG}
```

Если не задана первая из этих меток, контейнер не будет виден никакому экземпляру traefik. Значение второй метки позволяет запустить на одном хосте несколько экземпляров traefik и привязывать контейнер только к тому экземпляру, у которого совпадает значение `DCAPE_TAG`.

Такая функциональность обеспечивается следующими настройками traefik:

```var/traefik/traefik.yml
providers:
  docker:
    exposedByDefault: false
    constraints: Label(`dcape.traefik.tag`,`=DCAPE_TAG=`)
```

### Поддержка wildcard-доменов

Dcape поддерживает протокол TLS с использованием ключей [Let's Encrypt](https://ru.wikipedia.org/wiki/Let%E2%80%99s_Encrypt).

Для получения сертификатов по протоколу `DNS-01` необходим доступ к АПИ сервера DNS. В состав dcape для этого включен сервер [powerdns](/dcape/baseapps/powerdns/). Если параметр `ACME` имеет значение `wild`, при выполнении команды `make apply` создается файл `var/traefik/traefik.env` с настройками для доступа к АПИ локальной копии [powerdns](/dcape/coreapps/powerdns/)

## Настройки контейнера для работы с TLS

Ниже в примерах использованы следующие параметры конфигурации:

* `APP_TAG` - уникальный тег контейнера, может формироваться автоматически из значения `APP_SITE`
* `USE_TLS` - использовать TLS
* `APP_SITE` - основной hostname контейнера
* `APP_ACME_DOMAIN` - wildcard-домен контейнера

### HTTP-01, индивидуальные сертификаты

```docker-compose.yml
    labels:
      - traefik.http.routers.${APP_TAG}.tls=${USE_TLS}
      - traefik.http.routers.${APP_TAG}.tls.certresolver=letsEncrypt
```

### DNS-01, wildcard-домен

```docker-compose.yml
    labels:
      - traefik.http.routers.${APP_TAG}.tls=${USE_TLS}
      - traefik.http.routers.${APP_TAG}.tls.certresolver=letsEncrypt
      - traefik.http.routers.${APP_TAG}.tls.domains[0].main=${APP_SITE}
      - traefik.http.routers.${APP_TAG}.tls.domains[0].sans=${APP_ACME_DOMAIN}
```

### Тестирование

Файл конфигурации traefik включает строку

```var/traefik/traefik.yml
      # caServer: "https://acme-staging-v02.api.letsencrypt.org/directory"
```

В период настройки, во избежание бана со стороны Letsencrypt, рекомендуется ее раскомментировать для работы через тестовый канал (выписывается Fake сертификат), а после полной отладки механизма, удалить.

## Несколько копий dcape на одном сервере

dcape позволяет запуск нескольких экемпляров на одном сервере, для этого они должны использовать разные порты. Поэтому TLS с обновлением сертификатов будет доступен только тому экземпляру, который слушает порт 443.

Для запуска второго экземпляра необходимо разместить его в другом каталоге (или использовать другие значения параметров `CFG`, `DCAPE_VAR`) и изменить в его настройках:

* порты в параметрах `TRAEFIK_LISTEN` и `TRAEFIK_LISTEN_SSL`
* параметр `DCAPE_TAG`

---

## Install

Приложение разворачивается в составе [dcape](https://github.com/dopos/dcape).

## License

The MIT License (MIT), see [LICENSE](LICENSE).

Copyright (c) 2023-2024 Aleksei Kovrizhkin <lekovr+dopos@gmail.com>
