# AGENTS.md

Общие правила для AI-агентов (Claude Code, Codex и т.д.) на проекте Promptforking.

## Стек

- Next.js 16 (App Router) + TypeScript strict, React 19
- Tailwind v4
- Supabase: Postgres + Auth (`@supabase/ssr`)
- pnpm 11
- ESLint 9 (flat config) + Prettier
- Husky + lint-staged pre-commit
- Vercel (auto-deploy on push to `main`)

## Команды

```bash
pnpm dev          # localhost:3000
pnpm build        # next build
pnpm lint         # ESLint
pnpm format       # Prettier write
pnpm format:check # Prettier verify
pnpm typecheck    # tsc --noEmit
```

## Принципы

Подробнее в [CLAUDE.md](CLAUDE.md). Короткие тезисы:

1. **Думай до кода.** Прежде чем писать — назови предположения, тёмные места — в вопросы.
2. **Минимум кода.** Только то, что попросили; никаких преждевременных абстракций.
3. **Хирургические правки.** Не трогай то, что не сломано.
4. **Проверяемые цели.** Каждая задача — с критерием успеха.

## База данных

- Схема живёт в Supabase (Postgres). Миграции — в [`supabase/migrations/`](supabase/migrations/), пронумерованы `NNNN_description.sql`.
- Применение:
  - Через Supabase MCP (`apply_migration`), если настроен.
  - Иначе вручную через Supabase Dashboard → SQL Editor.
- TypeScript-типы — [`src/lib/types.ts`](src/lib/types.ts), регенерируются:
  - через MCP `generate_typescript_types`, либо
  - `supabase gen types typescript --project-id qetnlelsvstjyfsbqlap --schema public > src/lib/types.ts`
- **Не правь миграции, уже применённые в проде.** Новое изменение — новая миграция.

## Секреты

- `.env.local` не коммитится (см. `.gitignore`).
- Никогда не клади токены, ключи, пароли в код, в коммиты, в PR-описания, в CLAUDE.md/AGENTS.md/README.
- Service-role ключ Supabase используется только в server-only коде (route handlers, server actions). Никогда не помечай его `NEXT_PUBLIC_*`.

## Чеклист перед коммитом

- `pnpm lint` чист
- `pnpm format:check` чист
- `pnpm typecheck` чист
- `pnpm build` проходит без ошибок и предупреждений
- В коммите нет `.env.local` или других секретов

Pre-commit hook (husky + lint-staged) автоматически прогоняет `eslint --fix` и `prettier --write` по staged-файлам.
