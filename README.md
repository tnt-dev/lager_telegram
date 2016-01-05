# Lager Telegram backend

This is a Telegram backend for Lager. It sends Lager logs using Telegram bots.

## Usage

Add to your `rebar.config`:

``` erlang
{lager_telegram_backend, ".*",
 {git, "https://github.com/tnt-dev/lager_telegram_backend.git", "master"}}
```

## Configuration

Example of handler configuration:

``` erlang
{lager_telegram_backend, [{level, error},
                          {token, "BOT_TOKEN"},
                          {chat_id, 123456},
                          {retry_times, 5},
                          {retry_interval, 10}]}
```
