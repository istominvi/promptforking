import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { LoginForm } from "./login-form";

export default async function LoginPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user) redirect("/");

  return (
    <main className="mx-auto flex w-full max-w-md flex-1 flex-col items-center justify-center px-6 py-12">
      <h1 className="mb-2 text-2xl font-semibold tracking-tight">Войти в Promptforking</h1>
      <p className="mb-6 text-sm text-zinc-500">Введи email — пришлём magic link.</p>
      <LoginForm />
    </main>
  );
}
