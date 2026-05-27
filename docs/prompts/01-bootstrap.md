# Промпт для Claude Code — спринт 1: бутстрап проекта Promptforking

> Скопируй всё содержимое ниже одним сообщением в Claude Code, запущенный в пустой папке `~/dev/promptforking` (или где тебе удобно).

---

## Контекст

Мы создаём **Promptforking** — сервис-галерею AI-генераций с механикой форкинга промптов и шаблонами с переменными. Это первый спринт: только каркас, аутентификация, базовая схема БД и пустая лента. Никакой бизнес-логики генерации пока нет.

Я хочу работать в стиле, описанном в `CLAUDE.md` проекта Picket: **думай до кода, минимум кода, хирургические правки, проверяемые цели**. Если что-то неясно — спрашивай до того, как писать.

## Стек (зафиксирован, не пересматриваем)

- **Next.js 15** с App Router, TypeScript strict
- **Tailwind CSS v4**
- **pnpm**
- **Supabase**: Postgres + Auth (`@supabase/ssr` для серверного рендеринга)
- **ESLint** + **Prettier** + базовый **Husky** pre-commit с lint-staged
- **Vercel** для деплоя

ORM **не используем**: сырой Supabase JS client + типы, сгенерированные через `supabase gen types typescript`.

## Что должно получиться в конце спринта

1. Рабочий Next.js проект, который:
   - запускается локально через `pnpm dev`,
   - линтуется и форматируется без ошибок,
   - деплоится на Vercel и открывается по живому URL,
   - подключён к Supabase через env-переменные.
2. В Supabase применена первая миграция со схемой БД (см. ниже).
3. Реализована регистрация и вход через email + magic link.
4. Главная страница `/` показывает заглушку ленты («лента пока пуста») и в правом верхнем углу — состояние «войти / выйти». Никаких других страниц пока не нужно.
5. Репозиторий запушен в GitHub, Vercel автоматически собирает на каждый push в `main`.
6. В корне репо лежат `README.md`, `AGENTS.md`, `CLAUDE.md` с актуальной короткой информацией для агентов.

## Acceptance criteria (по которым я буду проверять)

- [ ] `pnpm dev` поднимает приложение на `localhost:3000`, главная отдаёт 200 OK
- [ ] `pnpm lint` и `pnpm format:check` проходят без ошибок
- [ ] `pnpm build` проходит без ошибок и предупреждений
- [ ] Сайт открывается на `*.vercel.app` после `git push`
- [ ] В Supabase применена миграция `0001_init.sql`, в `public` существуют таблицы: `profiles`, `models`, `generations`
- [ ] На странице `/login` можно ввести email, получить magic link, кликнуть, попасть назад с залогиненным состоянием
- [ ] После логина в правом верхнем углу главной видно email пользователя и кнопку «Выйти»
- [ ] При первом логине автоматически создаётся запись в `profiles` (через триггер)

## Схема БД для первой миграции

Создай миграцию `0001_init.sql` со следующими таблицами. RLS включён везде, политики — простейшие (см. ниже).

### `profiles`

Расширяет `auth.users`. Создаётся автоматически триггером после регистрации.

| Поле           | Тип         | Note                                    |
| -------------- | ----------- | --------------------------------------- |
| `id`           | uuid PK     | FK на `auth.users.id` ON DELETE CASCADE |
| `username`     | text UNIQUE | nullable на старте                      |
| `display_name` | text        | nullable                                |
| `avatar_url`   | text        | nullable                                |
| `created_at`   | timestamptz | default now()                           |

RLS: чтение всем, апдейт только `auth.uid() = id`.

### `models`

Справочник доступных моделей у провайдеров.

| Поле             | Тип         | Note                             |
| ---------------- | ----------- | -------------------------------- |
| `id`             | text PK     | например `fal-ai/flux-pro`       |
| `provider`       | text        | enum-like: `replicate` или `fal` |
| `display_name`   | text        |                                  |
| `kind`           | text        | пока только `image`              |
| `default_params` | jsonb       | дефолтные параметры модели       |
| `is_active`      | boolean     | default true                     |
| `created_at`     | timestamptz | default now()                    |

RLS: чтение всем, запись только service role.

Seed-данные (вставить прямо в миграции): 3–5 моделей, например `fal-ai/flux-pro`, `fal-ai/flux-schnell`, `black-forest-labs/flux-1.1-pro` через Replicate. Конкретные дефолтные параметры — на твоё усмотрение, минимально разумные.

### `generations`

Центральная таблица — узел в дереве. Каждая генерация = один пост в ленте.

| Поле             | Тип         | Note                                                |
| ---------------- | ----------- | --------------------------------------------------- |
| `id`             | uuid PK     | default `gen_random_uuid()`                         |
| `author_id`      | uuid        | FK на `profiles.id`, ON DELETE SET NULL             |
| `parent_id`      | uuid        | FK на `generations.id` ON DELETE SET NULL, nullable |
| `root_id`        | uuid        | FK на `generations.id`, NOT NULL (для корня = self) |
| `model_id`       | text        | FK на `models.id`                                   |
| `prompt`         | text        | NOT NULL                                            |
| `model_params`   | jsonb       | default `'{}'::jsonb`                               |
| `image_url`      | text        | URL от провайдера, nullable пока генерации нет      |
| `status`         | text        | `pending` / `succeeded` / `failed`                  |
| `error`          | text        | nullable                                            |
| `content_rating` | text        | default `'sfw'` (под будущее)                       |
| `is_public`      | boolean     | default true                                        |
| `created_at`     | timestamptz | default now()                                       |

Индексы: `(parent_id)`, `(root_id)`, `(author_id)`, `(created_at DESC)`, `(model_id)`.

RLS:

- SELECT: разрешён всем для `is_public = true AND status = 'succeeded'`. Для `author_id = auth.uid()` — всегда.
- INSERT: только если `author_id = auth.uid()`.
- UPDATE: только владелец.
- DELETE: только владелец.

Constraint: если `parent_id IS NULL`, то `root_id = id` (для корней). Это проверяется триггером BEFORE INSERT.

### Триггер `handle_new_user`

После INSERT в `auth.users` — создавать строку в `public.profiles` с тем же `id`.

---

## Структура проекта

```
promptforking/
├── .env.example
├── .gitignore
├── .prettierrc
├── .eslintrc.json
├── package.json
├── tsconfig.json
├── next.config.ts
├── tailwind.config.ts
├── postcss.config.mjs
├── README.md
├── AGENTS.md
├── CLAUDE.md
├── supabase/
│   └── migrations/
│       └── 0001_init.sql
├── src/
│   ├── app/
│   │   ├── layout.tsx
│   │   ├── page.tsx              # главная с заглушкой ленты
│   │   ├── login/
│   │   │   └── page.tsx
│   │   ├── auth/
│   │   │   └── callback/
│   │   │       └── route.ts      # OAuth-колбэк Supabase
│   │   └── api/
│   │       └── auth/
│   │           └── signout/
│   │               └── route.ts
│   ├── components/
│   │   └── header.tsx            # с логином/логаутом
│   ├── lib/
│   │   ├── supabase/
│   │   │   ├── client.ts         # для use client
│   │   │   ├── server.ts         # для server components
│   │   │   └── middleware.ts     # для refresh сессии
│   │   └── types.ts              # сгенерированные типы Supabase
│   └── middleware.ts             # рефреш сессии
└── ...
```

## Env-переменные

В `.env.example`:

```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
# Эти нужны только для разработки/тестов и НЕ деплоятся на Vercel:
REPLICATE_API_TOKEN=
FAL_API_KEY=
```

В `.gitignore`: стандартное Next.js плюс `.env.local`, `.env.*.local`.

## Документация в репо

### `README.md`

Минимум: что это за проект (одним абзацем), как запустить локально, как задеплоить, ссылка на `docs/` (пока пусто).

### `AGENTS.md`

Общие правила для всех агентов (Claude Code, Codex):

- Стек и команды (`pnpm dev`, `pnpm lint`, `pnpm build`).
- Принципы (отсылка к CLAUDE.md с тезисами «думай до кода, минимум кода, хирургические правки, проверяемые цели»).
- Где лежит схема БД (Supabase, миграции в `supabase/migrations/`).
- Как применять миграции (через Supabase Dashboard SQL Editor или MCP, если настроен).
- Запрет на коммит секретов.

### `CLAUDE.md`

Скопировать **полностью** содержимое из `/Users/user/Documents/picket/CLAUDE.md` (Vladimir уже использовал его в Picket) с правкой «Picket» → «Promptforking» там, где это про название. Принципы «Think Before Coding / Simplicity First / Surgical Changes / Goal-Driven Execution» — оставить как есть. Раздел про Supabase MCP — оставить, он применим.

## Порядок работы

1. **Сначала спроси у меня значения env-переменных** (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `GITHUB_REPO_URL`, `REPLICATE_API_TOKEN`, `FAL_API_KEY`). Я положу их тебе в чат — не пытайся искать сам.
2. Создай локальную структуру: `pnpm dlx create-next-app@latest promptforking --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --use-pnpm`. Затем доустанови `@supabase/supabase-js`, `@supabase/ssr`, `prettier`, `husky`, `lint-staged`.
3. Напиши миграцию `0001_init.sql` и **сначала покажи мне её на ревью**, прежде чем применять. Когда я подтвержу — применяй через Supabase (через MCP, если доступен, или дай мне SQL для ручного применения).
4. После применения миграции — `supabase gen types typescript --project-id <id> > src/lib/types.ts`. Если CLI не настроен — сгенерируй типы любым другим способом или попроси меня их добавить.
5. Реализуй каркас аутентификации (`/login` со страницей magic link, `/auth/callback` для обработки колбэка, `middleware.ts` для рефреша сессии).
6. Сделай главную страницу с заглушкой ленты и Header'ом.
7. Инициализируй git, сделай первый коммит, добавь remote, запушь в `main`.
8. **Подскажи мне**, какие переменные окружения нужно добавить в Vercel — я добавлю их через веб-интерфейс, после чего сделаю «Import Project» в Vercel.
9. После деплоя — пройди по acceptance criteria выше и отметь каждое.

## Что НЕ нужно делать в этом спринте

- ❌ Никакой логики генерации (никаких вызовов Replicate/fal.ai).
- ❌ Никаких таблиц `templates`, `template_versions`, `likes`, `favorites`, `forks_edges` — это всё во втором спринте.
- ❌ Никакого UI редактора шаблонов.
- ❌ Никакой загрузки картинок в R2.
- ❌ Никакого Stripe и тарифов.
- ❌ Никаких сложных «фич на будущее» — только то, что в acceptance criteria.

Если по ходу видишь, что что-то из вышеперечисленного «логично сделать заодно» — **не делай**, скажи мне, и мы решим, переносить ли это в текущий спринт или в следующий.

---

Поехали. Начни с пункта 1: попроси у меня значения env-переменных.
