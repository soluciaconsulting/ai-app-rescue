---
title: 'Fixing "new row violates row-level security policy" in Supabase'
description: 'Learn why Supabase returns this RLS error and how to fix common insert policy, auth, and user_id issues.'
date: 'Jun 24, 2026'
category: Supabase
summary: "This error means your insert was blocked by Row Level Security. Here's why it happens and how to fix it for good."
image: 'img/blog/rls-supabase-cover.svg'
image_alt: 'Supabase row-level security policy error, fixed'
cta: 'Get your Supabase issue fixed'
---

If you've ever run an `insert` against Supabase and gotten back this:

```
new row violates row-level security policy for table "your_table"
```

...you've hit Postgres Row Level Security (RLS). It's not a bug. It's RLS doing exactly what it's designed to do: refusing to write a row because no policy explicitly *allows* that write. The fix is almost always one of a handful of things. Let's walk through them.

## What the error actually means

When RLS is enabled on a table, every row that gets inserted, updated, or selected has to pass a policy. If **no policy permits** the operation for the current user, Postgres rejects it. There is no "default allow." With RLS on and no matching `INSERT` policy, *every* insert fails, even from a logged-in user.

So this error means one of two things:

- There is no `INSERT` policy on the table at all, or
- There is one, but the row you're trying to insert doesn't satisfy its `WITH CHECK` condition.

## The 30-second checklist

Before diving deep, check these in order. One of them is almost certainly your problem:

1. Is RLS enabled but you have **no INSERT policy**? → Add one (below).
2. Does your policy compare `user_id` to `auth.uid()`, but you're **not actually sending a user_id**? → Set it.
3. Are you actually **logged in** when the request runs? → An expired or missing session makes `auth.uid()` return `null`.
4. Are you inserting a `user_id` that **doesn't match the logged-in user**? → It has to match.

## Fix 1: Add an INSERT policy

The most common cause. You enabled RLS (or Supabase enabled it for you) but never wrote a policy that allows inserts. Add one. For a typical table where each row belongs to a user:

```sql
-- Make sure RLS is on
alter table public.posts enable row level security;

-- Allow a logged-in user to insert rows they own
create policy "Users can insert their own posts"
on public.posts
for insert
to authenticated
with check ( auth.uid() = user_id );
```

The key part is `with check`. For inserts, that condition is evaluated against the *new* row. If it's `false`, you get the "new row violates" error. Here it's saying: the `user_id` on the row must equal the ID of the currently authenticated user.

## Fix 2: Actually send the user_id

If your policy checks `auth.uid() = user_id` but you never set `user_id` in the insert, it'll be `null`, the check fails, and you get the error. Set it explicitly from the client:

```js
const { data: { user } } = await supabase.auth.getUser();

const { error } = await supabase
  .from('posts')
  .insert({ title: 'Hello', user_id: user.id });
```

Better yet, stop relying on the client to send the right value. Default it in the database so it can't be spoofed or forgotten:

```sql
alter table public.posts
  alter column user_id set default auth.uid();
```

Now `user_id` is filled in automatically with the authenticated user's ID, and the policy passes without the client having to send anything.

## Fix 3: Make sure you're actually authenticated

If `auth.uid()` returns `null`, any policy that depends on it fails. This happens when:

- The user isn't logged in (no session).
- The session expired and wasn't refreshed.
- You're using the `anon` key from a server context where no user session is attached.

Confirm there's a real session before the insert runs:

```js
const { data: { session } } = await supabase.auth.getSession();
console.log(session?.user?.id); // should NOT be null/undefined
```

If that's `null` on the server (e.g. in a Next.js route handler or edge function), your Supabase client isn't forwarding the user's auth token. Use the SSR client (`@supabase/ssr`) so the request carries the user's cookies/JWT.

## Fix 4: Don't insert a user_id that isn't yours

If you hardcode or pass a different user's ID, the `with check` condition (`auth.uid() = user_id`) is `false` and the insert is correctly rejected. This is RLS protecting you. The inserted `user_id` must match the logged-in user. Let the database default it (Fix 2) and this class of bug disappears.

## Fix 5: Server-side writes that bypass RLS

Sometimes you legitimately need to insert rows on behalf of a system — a webhook, a cron job, a Stripe event — where there's no logged-in user. For those **trusted, server-only** contexts, use the `service_role` key, which bypasses RLS entirely:

```js
// SERVER ONLY. Never expose the service_role key to the browser.
import { createClient } from '@supabase/supabase-js';

const admin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);
```

**Warning:** the service role key has full read/write access and ignores every policy. It must never ship to the client or live in frontend code. Use it only in trusted server code, and prefer the proper RLS policies above for anything driven by an actual user.

## How to debug it fast

In the Supabase dashboard, go to **Authentication → Policies** (or **Database → Policies**) and look at the table. You want to see a policy with the `INSERT` command whose `WITH CHECK` matches what you're inserting. To inspect policies in SQL:

```sql
select * from pg_policies where tablename = 'posts';
```

Then ask yourself the one question that resolves 90% of these: *"Given the row I'm inserting and the user I'm logged in as, does the WITH CHECK condition evaluate to true?"* If you can't answer yes with certainty, that's your bug.

## Still stuck?

RLS is one of those things AI builders enable for you and then leave half-configured — secure-by-default, but broken-by-default. If your Supabase auth and policies are tangled and inserts, logins, or permissions aren't working the way they should, I fix exactly this kind of thing.
