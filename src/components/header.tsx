import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export async function Header() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <header className="flex items-center gap-4 border-b border-zinc-200 px-6 py-3 dark:border-zinc-800">
      <Link href="/" className="font-semibold tracking-tight">
        Promptforking
      </Link>
      <div className="ml-auto flex items-center gap-3 text-sm">
        {user ? (
          <>
            <span className="text-zinc-500">{user.email}</span>
            <form action="/api/auth/signout" method="post">
              <button
                type="submit"
                className="rounded-md border border-zinc-300 px-3 py-1.5 hover:bg-zinc-100 dark:border-zinc-700 dark:hover:bg-zinc-900"
              >
                Выйти
              </button>
            </form>
          </>
        ) : (
          <Link
            href="/login"
            className="rounded-md border border-zinc-300 px-3 py-1.5 hover:bg-zinc-100 dark:border-zinc-700 dark:hover:bg-zinc-900"
          >
            Войти
          </Link>
        )}
      </div>
    </header>
  );
}
