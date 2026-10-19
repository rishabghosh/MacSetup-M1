# Stack Conventions — tee_jutsu_v1

## Project Structure

```
src/
  components/          Shared React components
    ui/                Radix-based primitive components (button, dialog, etc.)
    auth/              Auth-related components
    common/            Layout helpers (HeaderBar, etc.)
    order/             Order flow components
  features/            Feature modules (domain-driven)
    shipmojo/          Shipping integration
      ui/              React components
      server/          Cloudflare-compatible server logic
      client/          Client-side utilities/hooks
      domain/          Types, pure functions, validation
  pages/               Astro pages
    api/               API route handlers (*.ts)
  lib/                 Shared library (Supabase client, etc.)
  hooks/               React hooks
  types/               Global TypeScript types
  constants/           Runtime constants (routes, labels, storage keys, etc.)
  config/              App-level configuration
```

## Framework: Astro v5

- Pages are `.astro` files. Server logic (DB calls, auth checks) goes in the frontmatter (`---` block).
- React components are "islands" — rendered client-side only when given a `client:*` directive.
  - `client:load` — hydrate immediately on page load
  - `client:idle` — hydrate when browser is idle
  - `client:visible` — hydrate when component enters viewport
- API routes are in `src/pages/api/` and export named HTTP method handlers (`GET`, `POST`, etc.).

## React 19

- Functional components with hooks only. No class components.
- Server components are NOT used (Cloudflare adapter uses Astro islands instead).
- Prefer small, focused components. Keep logic in hooks or domain utilities.

## TypeScript

- Strict mode enabled. Always type function parameters and return values for exported functions.
- Prefer `interface` for object shapes, `type` for unions/aliases.
- Global types in `src/types/`. Feature-specific types in `src/features/<name>/domain/types.ts`.
- Avoid `any`. Use `unknown` and narrow down.

## Tailwind CSS v3

- All styling via Tailwind utility classes.
- `cn()` from `src/utils.ts` for conditional/merged classes:
  ```ts
  import { cn } from '@/utils';
  <div className={cn('base-class', condition && 'conditional-class')} />
  ```
- Custom design tokens in `tailwind.config.*` if needed.
- No inline styles unless absolutely necessary (e.g., dynamic values not expressible as utilities).

## Radix UI

- Used for headless accessible primitives: `Dialog`, `Popover`, `DropdownMenu`, `Select`, `Checkbox`, etc.
- Components in `src/components/ui/` wrap Radix primitives with Tailwind styling.
- Always use the `src/components/ui/` version rather than importing Radix directly in feature code.

## State Management: nanostores

```ts
import { atom, map } from 'nanostores';
import { useStore } from '@nanostores/react';
import { persistentAtom } from '@nanostores/persistent';

// Simple atom
export const $count = atom(0);

// Map (object)
export const $user = map({ id: '', name: '' });

// Persistent (localStorage)
export const $cart = persistentAtom('cart', [], { encode: JSON.stringify, decode: JSON.parse });

// In React component
const count = useStore($count);
```

- Stores live in `src/store.ts` (global) or co-located with the feature that owns them.
- Prefer nanostores over `useState` for state shared across components or that needs to persist.
- Use `useState` only for purely local, ephemeral UI state (e.g., a dropdown open/closed flag).

## Supabase JS v2

- Client initialized in `src/lib/`. Import from there, never initialize inline.
- Auth: Supabase Auth. User session via `supabase.auth.getUser()` on server, or stored in nanostores on client.
- DB queries: typed using generated types. Use `.select()`, `.insert()`, `.update()`, `.delete()`.
- Row Level Security (RLS) is enabled — server-side queries use the service role client, client-side uses the anon client.

## Cloudflare Workers (Server Code)

- Deployed via `@astrojs/cloudflare` adapter.
- **No Node.js built-ins** (`fs`, `path`, `crypto`, etc.) in server code. Use Web APIs instead.
- Environment variables accessed via `Astro.locals.runtime.env` in Astro pages, or `context.env` in API routes.
- Files in `*/server/` directories or suffixed `.server.ts` are server-only. Never import them client-side.
- CPU-intensive work is not suitable for Cloudflare Workers — keep server logic lightweight.

## Sanity v3 (CMS)

- Client configured in `src/lib/` or via `@sanity/astro`.
- Content fetched server-side in Astro frontmatter using GROQ queries.
- Types in `src/types/sanity.ts`.
- Portable Text rendered with `astro-portabletext`.

## Razorpay (Payments)

- Server-side only. Payment order creation in API routes.
- Types in `src/types/payment.ts`.
- Never expose the Razorpay key secret client-side.

## Import Conventions

- Use path aliases (e.g., `@/components/...`, `@/lib/...`) as configured in `tsconfig.json`.
- Index files (`index.ts`) re-export the public API of a feature or directory.
- Barrel exports are fine for features; avoid deep imports into feature internals from outside the feature.

## File Naming

- React components: `PascalCase.tsx`
- Hooks: `use<Name>.ts`
- Utilities/services: `camelCase.ts`
- Server-only files: `<name>.server.ts` or placed in a `server/` subdirectory
- Astro pages: `kebab-case.astro` (maps to URL slug)
- Constants: `camelCase.ts`, grouped by domain in `src/constants/runtime/`
