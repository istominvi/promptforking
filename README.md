# Promptforking

Сервис-галерея AI-генераций с механикой форкинга промптов. Каждая публикация — узел в дереве: её можно форкнуть, переписать промпт или параметры и опубликовать поверх. Спринт 1: каркас, аутентификация через Supabase magic link, пустая лента.

## Локальный запуск

```bash
pnpm install
cp .env.example .env.local   # заполни Supabase URL и ключ
pnpm dev
```

Открывай [localhost:3000](http://localhost:3000).

## Проверки

```bash
pnpm lint
pnpm format:check
pnpm typecheck
pnpm build
```

## Деплой

`git push` в `main` → Vercel автосборка. Env-переменные (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`) ставятся в Vercel → Project Settings → Environment Variables.

## Документация

- [AGENTS.md](AGENTS.md) — общие правила для AI-агентов.
- [CLAUDE.md](CLAUDE.md) — Claude-специфичные инструкции.
- [docs/](docs/) — onboarding-чеклист, архив агент-промптов.
- [supabase/migrations/](supabase/migrations/) — схема БД, нумерованные миграции.
