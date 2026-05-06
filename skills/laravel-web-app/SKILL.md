---
name: jeremy-laravel-web-app
description: Use when working on any of Jeremy's Laravel web applications — starting a new project, adding features, making architectural decisions, writing tests, designing UI, or setting up infrastructure. Use this skill whenever a Laravel + Vue/Inertia project is involved, even if the user hasn't explicitly asked for it. Covers the full preferred stack, conventions, and patterns for all of Jeremy's web apps.
---

# Jeremy's Laravel Web App

Guidelines for Jeremy's preferred method of building web applications. Follow these conventions on all projects.

## Preferred Stack

- **PHP + Laravel** (latest stable)
- **Vue 3 + Inertia.js** — Vue + Inertia starter kit for scaffolding
- **Pest** — PHP testing (TDD always)
- **Playwright** — E2E / frontend testing
- **Pint** — PHP code style fixer
- **Rector** — automated PHP refactoring
- **PHPstan** — static analysis at level 5
- **Shadcn-vue** — UI component library
- **Laravel Boost** — AI guidelines + skills
- **Wayfinder** — typed TypeScript route helpers (not Ziggy)
- **VeeValidate** — Vue form validation
- **Spatie Laravel Permission** — roles and permissions via enums
- **Spatie Laravel Media Library** — file uploads and attachments
- **Spatie Laravel Query Builder** — filtering and sorting for paginated collections

## Always Load These Skills

Invoke these skills at the appropriate moment — do not skip them:

| When | Skill |
|------|-------|
| Complex task or planning | `superpowers` — https://github.com/obra/superpowers |
| Any feature implementation | TDD: https://skills.laravel.cloud/skills/laravel-tdd-affaan-m |
| All Laravel work | Specialist: https://skills.laravel.cloud/skills/laravel-specialist |
| Auth, data handling, or user input | Security: https://skills.laravel.cloud/skills/laravel-security |
| New pages, components, or visual UI | Frontend design: https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md |
| Dashboards or app-like experiences | UI/UX: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/main/.claude/skills/ui-ux-pro-max/SKILL.md |

## New Project Setup

Read https://laravel.com/for/agents before starting. Check prerequisites:
```bash
php -v && composer -V && laravel --version && npm -v
```
If anything is missing, install via `php.new` (see the agent guide for platform commands).

Create the application (always `--vue`, never `--react` unless explicitly asked):
```bash
laravel new my-app --database=sqlite --vue --npm --boost --no-interaction
cd my-app
php artisan boost:install
php artisan boost:add-skill laravel-tdd-affaan-m
php artisan boost:add-skill laravel-specialist
php artisan boost:add-skill laravel-security
composer run dev
```

Load the generated `CLAUDE.md` or `AGENTS.md` immediately without asking the user to restart.

On existing projects: if a required skill is missing, offer to install it via `php artisan boost:add-skill <name>`.

## Composer Scripts

- `composer run lint` — fix Pint (PHP CS), JS/CSS style, run Rector. **Run after every code change.**
- `composer run ci:check` — verify lint is clean and run PHPStan level 5
- `composer run test` — run full Pest test suite

## Design

- **Mobile first** — treat mobile as a first-class citizen throughout
- **CSS variables everywhere** — define all colours, spacing, and type tokens as CSS variables
- **Tailwind custom theme everywhere** — extend Tailwind using those CSS variables; never hardcode raw values
- Use Playwright MCP to verify visual output in the browser when helpful

## Frontend

**Components and Layout**
- Abstract Vue components so they are reusable — never duplicate a component
- Single app layout with named slots for all content shared across pages
- Layouts accept props for `<head>` metadata — minimum a `title` prop for `<title>`
- Check for a Shadcn-vue component before building from scratch

**Types and State**
- Centralise shared TypeScript interfaces in a single `types.ts` file
- Manage global state via Inertia shared props — do not add Pinia unless specifically required

**Forms**
- Use **VeeValidate** for all form handling and validation
- Surface server-side validation errors through VeeValidate field errors

**Flash Messages**
- The app layout must support flash messages (success, error, warning, info)
- Read flash data from Inertia shared props on every page transition

**Routing**
- Use **Wayfinder** for all route references in TypeScript/Vue — never hardcode URL strings
- Run Wayfinder generation after adding routes

## Auth

- **Laravel Fortify** for the authentication backend
- Scaffold views using the **Vue + Inertia starter kit** (login, register, forgot password, user settings)
- **Branding rule:** whenever colours, fonts, or visual identity change, auth and user settings templates must be updated to match — they are never exempt from rebrand work

## Database

- Default to **SQLite** for new projects
- All models and queries must be compatible with MySQL and PostgreSQL — avoid SQLite-only syntax
- Never use `::all()` on any model unless explicitly instructed

## Backend / API Conventions

- All models passed to the frontend must go through an **API Resource** — never pass raw Eloquent models
- Use **flash messages** for user feedback on mutations
- Every collection must be **paginated**, even when the expected result set is small
- Use **Spatie Laravel Query Builder** for all filtering, sorting, and searching on paginated endpoints
- Prefer **PHP enums** everywhere — avoid magic strings
- Prefer an **existing package** over writing custom implementations

## Permissions

Use `spatie/laravel-permission` with **backed enums** (https://spatie.be/docs/laravel-permission/v7/basic-usage/enums). Seed/migrate permissions in code — never through a UI unless asked.

```php
enum PermissionsEnum: string {
    case VIEW_POSTS = 'view posts';
    case EDIT_POSTS = 'edit posts';
}
enum RolesEnum: string {
    case EDITOR = 'editor';
    case ADMIN  = 'admin';
}
```

Use `enum_value()` when creating roles/permissions via Eloquent; pass enum values directly to `hasPermissionTo`, `assignRole`, etc.

## Queue Workers

- **Redis queues** → use **Laravel Horizon**
- **Database queues** → offer to install **Laravel Queue Monitor** (https://github.com/romanzipp/Laravel-Queue-Monitor); add the `IsMonitored` trait to jobs

## Error Handling

- **Custom exceptions** preferred — create domain-specific exception classes
- User-facing error messages must be **descriptive and actionable**
- For 500-level errors: write full detail to logs and show a user-facing message directing them to check the logs (include a reference ID where possible)
- Never silently swallow exceptions

## Media / File Uploads

Use **Spatie Laravel Media Library** for all file upload and attachment needs. Define media collections on models; use conversions for image resizing.

## Testing

**Pest**
- Follow **TDD** — write the test before the implementation
- `Feature` tests: require database, use `RefreshDatabase`
- `Unit` tests: no database dependency
- Include architecture tests:
```php
arch('no all() calls')->expect('App\Http\Controllers')->not->toUse('Illuminate\Database\Eloquent\Builder::all');
arch('no debug helpers')->expect(['dd', 'dump', 'ray', 'var_dump'])->not->toBeUsed();
arch('enums used for permissions')->expect('App\Enums')->toBeEnums();
```

**Playwright** — use for all E2E and frontend tests; cover the golden path and key edge cases.

## Git

Conventional commits are **required**:
```
<type>(scope): <description>
Types: feat, fix, docs, style, refactor, test, chore, perf
```

## Documentation

- Maintain `docs/` with up-to-date feature documentation as features are implemented
- `README.md` must provide overview, features, and quick install — link to `docs/` for detail
- Keep `.env.example` up to date with every environment variable, documented with inline comments
- To persist AI context across sessions: add a Blade file to `.ai/guidelines/` then run `php artisan boost:install`
- If complex functionality is added, create a skill in `.ai/skills/{name}/SKILL.md` then run `php artisan boost:install`
- After installing any new package, run `php artisan boost:update --discover`

## Docker

- All projects target **Docker** deployment
- Architecture: **php-fpm + nginx** web container + **separate queue worker** container
- Build a **base image** with all system dependencies pre-installed to keep build times short
- All environment variables must be documented in `.env.example`

## Never Do

- Use `::all()` on any model
- Use magic strings for permissions or roles — use enums
- Hardcode route URLs — use Wayfinder
- Hardcode colour or spacing values — use CSS variables and the Tailwind custom theme
- Pass raw Eloquent models to the frontend — always use API Resources
- Duplicate Vue components
- Leave `dd()`, `dump()`, `ray()`, or `var_dump()` in committed code
- Write Feature tests without `RefreshDatabase`
- Write Unit tests that touch the database
- State something as fact without solid evidence
- Use scoped css in vue components, prefer stylesheet css
