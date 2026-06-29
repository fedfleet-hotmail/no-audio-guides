# Fleet Guardian

A comprehensive fleet management and vehicle damage inspection application. Drivers use PIN-based authentication to perform pre-trip and return inspections, mark damage on vehicle blueprints, and complete vehicle sessions. Administrators manage drivers, vehicles, damage approvals, and fleet analytics through a full-featured dashboard.

**Tech Stack:** React + TypeScript + Vite (frontend) | Supabase (backend/database/auth/storage) | Tailwind CSS + Radix UI (styling)

---

## Table of Contents

- [1. Project Overview](#1-project-overview)
- [2. Frontend Documentation](#2-frontend-documentation)
- [3. Backend Documentation](#3-backend-documentation)
- [4. Database Documentation](#4-database-documentation)
- [5. Environment Variables](#5-environment-variables)
- [6. Project Setup & Installation](#6-project-setup--installation)
- [7. Project Structure](#7-project-structure)
- [8. Key Architectural Decisions](#8-key-architectural-decisions)
- [9. Rebuild Checklist](#9-rebuild-checklist)

---

## 1. Project Overview

Fleet Guardian is a single-page application (SPA) for managing vehicle fleets, driver inspections, and damage tracking. The application supports two user roles:

- **Drivers**: Register with employee number + PIN, perform pre-trip inspections, mark existing/new damage on vehicle blueprints, complete return inspections with checklist items and photos
- **Administrators**: Manage drivers (create, reset PINs, deactivate), manage vehicles (add, edit, archive, upload blueprint images), approve/reject driver-reported damage, view dashboards and reports, export data to CSV

Core features:
- Vehicle session management (start/return workflow)
- Pre-trip and return inspection checklists with photo capture
- Visual damage marking on vehicle blueprints (front/rear/left/right/top views)
- Damage approval workflow (driver-reported → admin review → approved/rejected)
- Admin dashboard with charts (Recharts) and statistics
- Row Level Security (RLS) policies for data isolation

---

## 2. Frontend Documentation

### Framework & Build Tool

- **React 19** with **TypeScript 5.8**
- **Vite 7.3** as the build tool with path aliases configured via `vite-tsconfig-paths`

```typescript
// vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import tsconfigPaths from "vite-tsconfig-paths";

export default defineConfig({
  plugins: [react(), tailwindcss(), tsconfigPaths()],
  server: { host: "::", port: 8080 },
});
```

### Routing

**react-router-dom v7** with lazy-loaded routes and route guards:

| Path | Component | Guard |
|------|-----------|-------|
| `/` | Landing | None |
| `/driver/login` | DriverLogin | None |
| `/driver/*` | Driver routes | `DriverGuard` |
| `/admin/login` | AdminLogin | None |
| `/admin/*` | Admin routes | `AdminGuard` |

```typescript
// Route guard pattern
<Route element={<DriverGuard />}>
  <Route path="/driver" element={<DriverMenu />} />
  <Route path="/driver/start" element={<DriverStartSelect />} />
  // ...
</Route>
```

### State Management & Data Fetching

**@tanstack/react-query v5** for server state:

```typescript
// Query pattern
const { data } = useQuery<Vehicle[]>({
  queryKey: ["vehicles"],
  queryFn: async () => {
    const { data, error } = await supabase.from("vehicle_summary").select("*");
    if (error) throw error;
    return data;
  },
});

// Mutation pattern
const save = useMutation({
  mutationFn: async (payload) => {
    const { error } = await supabase.from("vehicles").insert(payload);
    if (error) throw error;
  },
  onSuccess: () => qc.invalidateQueries({ queryKey: ["vehicles"] }),
});
```

### UI Component Library

**Radix UI Primitives** (headless, accessible):

| Component | Package |
|-----------|---------|
| Accordion | `@radix-ui/react-accordion` |
| Alert Dialog | `@radix-ui/react-alert-dialog` |
| Aspect Ratio | `@radix-ui/react-aspect-ratio` |
| Avatar | `@radix-ui/react-avatar` |
| Checkbox | `@radix-ui/react-checkbox` |
| Collapsible | `@radix-ui/react-collapsible` |
| Context Menu | `@radix-ui/react-context-menu` |
| Dialog | `@radix-ui/react-dialog` |
| Dropdown Menu | `@radix-ui/react-dropdown-menu` |
| Hover Card | `@radix-ui/react-hover-card` |
| Label | `@radix-ui/react-label` |
| Menubar | `@radix-ui/react-menubar` |
| Navigation Menu | `@radix-ui/react-navigation-menu` |
| Popover | `@radix-ui/react-popover` |
| Progress | `@radix-ui/react-progress` |
| Radio Group | `@radix-ui/react-radio-group` |
| Scroll Area | `@radix-ui/react-scroll-area` |
| Select | `@radix-ui/react-select` |
| Separator | `@radix-ui/react-separator` |
| Slider | `@radix-ui/react-slider` |
| Slot | `@radix-ui/react-slot` |
| Switch | `@radix-ui/react-switch` |
| Tabs | `@radix-ui/react-tabs` |
| Toggle | `@radix-ui/react-toggle` |
| Toggle Group | `@radix-ui/react-toggle-group` |
| Tooltip | `@radix-ui/react-tooltip` |

### Styyling

- **Tailwind CSS v4** via `@tailwindcss/vite` plugin
- **tailwind-merge** for conditional class merging
- **class-variance-authority (CVA)** for component variants
- **clsx** for conditional classes
- **tw-animate-css** for animation utilities

```typescript
// Component style pattern
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva("inline-flex items-center...", {
  variants: {
    variant: { default: "bg-primary...", outline: "border..." },
    size: { default: "h-10...", sm: "h-8..." },
  },
});
```

### Forms & Validation

- **react-hook-form v7** for form state management
- **@hookform/resolvers** for schema integration
- **zod v3** for runtime validation

```typescript
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";

const schema = z.object({
  name: z.string().min(1, "Name is required"),
  pin: z.string().length(4, "PIN must be 4 digits"),
});

const { register, handleSubmit, formState: { errors } } = useForm({
  resolver: zodResolver(schema),
});
```

### Charts & Data Visualization

**recharts v2** for dashboard charts:

```typescript
import { BarChart, Bar, XAxis, YAxis, ResponsiveContainer } from "recharts";

<ResponsiveContainer width="100%" height={300}>
  <BarChart data={data}>
    <XAxis dataKey="name" />
    <YAxis />
    <Bar dataKey="value" fill="hsl(var(--primary))" />
  </BarChart>
</ResponsiveContainer>
```

### Date Handling

- **date-fns v4** for date manipulation and formatting
- **react-day-picker v9** for calendar/date selection

### Other UI Utilities

| Library | Purpose |
|---------|---------|
| `embla-carousel-react` | Carousel/slider functionality |
| `input-otp` | OTP/PIN input with individual digit boxes |
| `lucide-react` | Icon library (200+ icons used) |
| `react-resizable-panels` | Resizable panel layouts |
| `sonner` | Toast notifications |
| `vaul` | Mobile drawer component |
| `cmdk` | Command palette / search |

### Path Aliases

Configured in `tsconfig.json`:

```json
{
  "compilerOptions": {
    "paths": { "@/*": ["./src/*"] }
  }
}
```

Usage: `import { Button } from "@/components/ui/button";`

### Linting & Formatting

- **ESLint 9** with `typescript-eslint`
- **eslint-plugin-react-hooks** for hooks rules
- **eslint-plugin-react-refresh** for Fast Refresh compatibility
- **Prettier 3** with `eslint-config-prettier`

---

## 3. Backend Documentation

### Backend-as-a-Service: Supabase

**@supabase/supabase-js v2** provides:

1. **Authentication**
   - Admin auth: Supabase email/password (via `supabase.auth.signInWithPassword`)
   - Driver auth: Custom PIN verification via RPC (`verify_driver_pin`)
   - Session storage: `sessionStorage` for drivers, Supabase auth for admins

2. **Database Access**
   - Direct table queries with RLS enforcement
   - Security-definer RPCs for sensitive operations (driver creation, PIN reset)

3. **Storage Buckets**
   - Vehicle blueprint images
   - Inspection photos
   - Damage photos
   - Vehicle base photos
   - Vehicle logbooks

### Supabase Client Setup

```typescript
// src/lib/supabase.ts
import { createClient } from "@supabase/supabase-js";

const url = import.meta.env.VITE_SUPABASE_URL as string;
const anon = import.meta.env.VITE_SUPABASE_ANON_KEY as string;

export const supabase = createClient(url, anon, {
  auth: { persistSession: true, autoRefreshToken: true, storageKey: "fg-admin-auth" },
});
```

### Authentication Patterns

**Admin Login:**
```typescript
// Email/password via Supabase Auth, then role check via RPC
const { data } = await supabase.auth.signInWithPassword({ email, password });
const { data: isAdmin } = await supabase.rpc("has_role", { _user_id: data.user.id, _role: "admin" });
```

**Driver Login:**
```typescript
// PIN verification via security-definer RPC
const { data } = await supabase.rpc("verify_driver_pin", {
  p_employee_number: "EMP001",
  p_pin: "1234",
});
// Returns: { driver_id, employee_number, name, surname }
```

---

## 4. Database Documentation

### Database: Supabase (PostgreSQL)

All tables have Row Level Security (RLS) enabled.

### Tables

#### `user_roles`
Maps Supabase Auth users to roles.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK, default `gen_random_uuid()` |
| `user_id` | `uuid` | FK → `auth.users.id`, NOT NULL |
| `role` | `text` | CHECK (`role = 'admin'`) |
| `created_at` | `timestamptz` | NOT NULL, default `now()` |

#### `drivers`
Driver accounts with PIN authentication.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK |
| `name` | `text` | NOT NULL |
| `surname` | `text` | NOT NULL |
| `employee_number` | `text` | UNIQUE, NOT NULL |
| `pin_hash` | `text` | (bcrypt hash via pgcrypto) |
| `active` | `boolean` | NOT NULL, default `true` |
| `mobile` | `text` | |
| `licence_number` | `text` | |
| `licence_type` | `text` | CHECK (`local` or `international`) |
| `licence_category` | `text` | |
| `cpc_valid` | `boolean` | default `false` |
| `cpc_expiry_date` | `date` | |

#### `vehicles`
Fleet vehicles.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK |
| `registration_number` | `text` | UNIQUE, NOT NULL |
| `make` | `text` | NOT NULL |
| `model` | `text` | NOT NULL |
| `year` | `integer` | |
| `vin` | `text` | |
| `status` | `text` | CHECK (`available`, `assigned`, `maintenance`, `archived`) |
| `archived` | `boolean` | default `false` |
| `road_licence_date` | `date` | |
| `road_licence_due` | `date` | |
| `last_service_date` | `date` | |
| `service_due_date` | `date` | |

#### `vehicle_sessions`
Driver-vehicle assignments.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK |
| `driver_id` | `uuid` | FK → `drivers.id` |
| `vehicle_id` | `uuid` | FK → `vehicles.id` |
| `started_at` | `timestamptz` | default `now()` |
| `ended_at` | `timestamptz` | |
| `status` | `text` | CHECK (`active`, `completed`) |
| `odometer_start` | `numeric` | |
| `odometer_end` | `numeric` | |

#### `inspections`
Pre-trip and return checklists.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK |
| `driver_id` | `uuid` | FK → `drivers.id` |
| `vehicle_id` | `uuid` | FK → `vehicles.id` |
| `session_id` | `uuid` | FK → `vehicle_sessions.id` |
| `inspection_type` | `text` | CHECK (`pre_trip`, `return`) |
| `items_pass_count` | `integer` | default `0` |
| `items_issue_count` | `integer` | default `0` |

#### `inspection_items`
Individual checklist item results.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK |
| `inspection_id` | `uuid` | FK → `inspections.id` |
| `item_name` | `text` | NOT NULL |
| `result` | `text` | CHECK (`pass`, `issue`) |
| `notes` | `text` | |

#### `inspection_item_photos`
Photos attached to inspection items.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK |
| `inspection_item_id` | `uuid` | FK → `inspection_items.id` |
| `photo_url` | `text` | NOT NULL |

#### `damage_markers`
Damage locations on vehicle blueprints.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK |
| `vehicle_id` | `uuid` | FK → `vehicles.id` |
| `driver_id` | `uuid` | FK → `drivers.id` |
| `damage_type` | `text` | NOT NULL |
| `description` | `text` | |
| `status` | `text` | CHECK (`open`, `in_review`, `repaired`, `closed`) |
| `view` | `blueprint_view` | ENUM (`front`, `rear`, `left`, `right`, `top`) |
| `x_coordinate` | `numeric` | NOT NULL |
| `y_coordinate` | `numeric` | NOT NULL |
| `source` | `damage_source` | ENUM (`baseline`, `driver`) |
| `approved` | `boolean` | default `false` |
| `approved_at` | `timestamptz` | |
| `approved_by` | `uuid` | FK → `auth.users.id` |
| `rejection_reason` | `text` | |
| `session_id` | `uuid` | FK → `vehicle_sessions.id` |
| `reported_during` | `text` | CHECK (`pre_trip`, `return`) |

#### `damage_marker_photos`
Photos of damage.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK |
| `damage_marker_id` | `uuid` | FK → `damage_markers.id` |
| `photo_url` | `text` | NOT NULL |
| `approved` | `boolean` | default `false` |

#### `vehicle_blueprints`
Annotated vehicle images per view.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK |
| `vehicle_id` | `uuid` | FK → `vehicles.id` |
| `blueprint_image` | `text` | NOT NULL |
| `view` | `blueprint_view` | NOT NULL |
| `updated_at` | `timestamptz` | default `now()` |

#### `vehicle_base_photos`
Reference photos for damage comparison.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK |
| `vehicle_id` | `uuid` | FK → `vehicles.id` |
| `photo_url` | `text` | NOT NULL |
| `view` | `blueprint_view` | |
| `label` | `text` | |

#### `checklist_items`
Global checklist configuration.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK |
| `item_text` | `text` | NOT NULL |
| `item_order` | `integer` | default `0` |
| `is_active` | `boolean` | default `true` |
| `checklist_type` | `text` | CHECK (`pre_trip`, `return`) |
| `item_key` | `text` | UNIQUE |

#### `vehicle_checklist_items`
Per-vehicle checklist overrides.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK |
| `vehicle_id` | `uuid` | FK → `vehicles.id` |
| `checklist_item_id` | `uuid` | FK → `checklist_items.id` |
| `enabled` | `boolean` | default `true` |

#### `vehicle_logbooks`
Uploaded logbook files.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK |
| `vehicle_id` | `uuid` | FK → `vehicles.id` |
| `file_path` | `text` | NOT NULL |
| `file_name` | `text` | NOT NULL |

#### `vehicle_repairs`
Repair history.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PK |
| `vehicle_id` | `uuid` | FK → `vehicles.id` |
| `repair_date` | `date` | NOT NULL |
| `description` | `text` | NOT NULL |
| `cost` | `numeric(10,2)` | |
| `resolved` | `boolean` | default `false` |

### Views

#### `vehicle_summary`
Aggregated vehicle statistics for admin list view.

```sql
SELECT 
  v.id, v.registration_number, v.make, v.model, v.year, v.vin, v.status, v.archived,
  (session stats), (damage stats), (latest inspection)
FROM vehicles v
LEFT JOIN session_stats ss ON ...
LEFT JOIN damage_stats ds ON ...
LEFT JOIN latest_inspection li ON ...;
```

### Row Level Security Policies

**Admin (authenticated users with `has_role(auth.uid(), 'admin')`):**
- Full CRUD on all tables

**Anon (drivers using anon key):**
- `vehicles`: SELECT only
- `vehicle_blueprints`: SELECT only (public)
- `vehicle_sessions`: SELECT, INSERT
- `inspections`, `inspection_items`, `inspection_item_photos`: SELECT, INSERT
- `damage_markers`: SELECT (baseline or approved only), INSERT
- `damage_marker_photos`: SELECT (approved only), INSERT
- `checklist_items`: SELECT (active items only)

### RPC Functions

| Function | Caller | Purpose |
|----------|--------|---------|
| `verify_driver_pin(employee_number, pin)` | anon | Driver PIN authentication |
| `create_driver(name, surname, employee_number, pin)` | authenticated | Admin creates new driver |
| `set_driver_pin(driver_id, pin)` | authenticated | Admin resets driver PIN |
| `has_role(user_id, role)` | authenticated | Check admin role |
| `start_vehicle_session(driver_id, vehicle_id, marker_ids)` | anon | Begin vehicle assignment |
| `complete_vehicle_session(session_id)` | anon | End vehicle session |
| `get_vehicle_checklist(vehicle_id, type)` | anon, authenticated | Get checklist items |
| `get_vehicle_enabled_checklist(vehicle_id, type)` | anon, authenticated | Get enabled items only |

### Storage Buckets

| Bucket | Public | Purpose |
|--------|--------|---------|
| `vehicle-blueprints` | Yes | Vehicle blueprint images |
| `vehicle-base-photos` | Yes | Reference photos for damage comparison |
| `inspection-photos` | No | Inspection checklist photos |
| `damage-photos` | No | Damage marker photos |
| `vehicle-logbooks` | No | Uploaded logbook files |

---

## 5. Environment Variables

### `.env.example`

```bash
# Supabase Configuration
# Get these from: Project Settings → API

VITE_SUPABASE_URL=https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here

# Note: VITE_ prefix is required for Vite to expose to client code
# The anon key is safe to expose publicly - RLS policies protect your data
```

### Required Variables

| Variable | Description | Source |
|----------|-------------|--------|
| `VITE_SUPABASE_URL` | Supabase project URL | Project Settings → API |
| `VITE_SUPABASE_ANON_KEY` | Anonymous/public API key | Project Settings → API |

---

## 6. Project Setup & Installation

### Prerequisites

- **Node.js 20+** or **Bun** (recommended)
- Supabase account

### Installation Steps

```bash
# 1. Clone the repository
git clone <repo-url>
cd fleet-guardian

# 2. Copy environment file
cp .env.example .env

# 3. Edit .env with your Supabase credentials
# VITE_SUPABASE_URL=https://xxx.supabase.co
# VITE_SUPABASE_ANON_KEY=eyJ...

# 4. Install dependencies
bun install
# or: npm install

# 5. Start development server
bun run dev
# or: npm run dev
```

### Available Scripts

```bash
bun run dev      # Start dev server on http://localhost:8080
bun run build    # Production build to ./dist
bun run preview  # Preview production build
bun run lint     # Run ESLint
bun run format   # Format with Prettier
```

### Node.js Requirements

- Node.js 20.x or higher
- Bun 1.x (alternative)

---

## 7. Project Structure

```
fleet-guardian/
├── .env                      # Environment variables (not in git)
├── .gitignore
├── bunfig.toml              # Bun configuration
├── components.json           # shadcn/ui component config
├── eslint.config.js         # ESLint 9 flat config
├── index.html               # HTML entry point
├── package.json
├── tsconfig.json            # TypeScript config with @/* path alias
├── vite.config.ts           # Vite config with code splitting
├── public/
│   └── _redirects           # Netlify SPA routing
├── supabase/
│   ├── migrations/          # SQL migrations (applied in order)
│   ├── functions/           # Edge Functions
│   └── seed.sql             # Demo data
└── src/
    ├── main.tsx             # App entry point
    ├── App.tsx              # Route configuration
    ├── styles.css           # Global styles + Tailwind
    ├── components/
    │   ├── ui/              # Radix UI / shadcn components
    │   ├── guards/          # Route guards (AdminGuard, DriverGuard)
    │   └── layout/          # Shell components (AdminShell, DriverShell)
    ├── hooks/
    │   └── use-mobile.tsx   # Mobile detection hook
    ├── lib/
    │   ├── supabase.ts      # Supabase client
    │   ├── auth/
    │   │   ├── adminAuth.ts # Admin auth (email/password)
    │   │   └── driverAuth.ts# Driver auth (PIN)
    │   ├── storage.ts       # Storage helpers (signed URLs)
    │   ├── checklist.ts     # Checklist utilities
    │   ├── csv.ts           # CSV export utilities
    │   └── utils.ts         # General utilities (cn, etc.)
    └── pages/
        ├── Landing.tsx      # Role selection page
        ├── admin/           # Admin pages
        │   ├── Login.tsx
        │   ├── Dashboard.tsx
        │   ├── Drivers/
        │   ├── Vehicles/
        │   ├── Sessions/
        │   ├── Inspections.tsx
        │   ├── Damages.tsx
        │   ├── Reports.tsx
        │   └── Checklists.tsx
        └── driver/          # Driver pages
            ├── Login.tsx
            ├── Menu.tsx
            ├── StartVehicle/
            └── ReturnVehicle/
```

---

## 8. Key Architectural Decisions

### Radix UI + Tailwind CSS

**Why:** Headless UI primitives (Radix) combined with utility-first CSS (Tailwind) provides:
- Full accessibility (ARIA) out of the box
- Complete design control without fighting framework defaults
- Smaller bundle size than full component libraries
- Easy theming via CSS variables

### TanStack Query for Server State

**Why:**
- Automatic caching, background refetching, and stale-while-revalidate
- Simple optimistic updates and cache invalidation
- Eliminates manual state management for API data
- Devtools for debugging

```typescript
// Example: automatic cache invalidation on mutation
const qc = useQueryClient();
const save = useMutation({
  mutationFn: saveDriver,
  onSuccess: () => qc.invalidateQueries({ queryKey: ["drivers"] }),
});
```

### Supabase as Backend/Database

**Why:**
- Built-in authentication with multiple providers
- Row Level Security (RLS) for fine-grained access control
- Real-time subscriptions (available if needed)
- Storage buckets with policies
- PostgreSQL extensions (pgcrypto for PIN hashing)
- No server maintenance required

### Custom Driver PIN Authentication

**Why not Supabase Auth for drivers:**
- Drivers don't have email addresses
- PIN-based authentication is simpler for field workers
- Admins manage PINs centrally
- Drivers cannot reset their own PINs (security requirement)

Implementation:
- `verify_driver_pin` RPC uses bcrypt via `pgcrypto` extension
- `create_driver` and `set_driver_pin` RPCs hash PINs with `extensions.gen_salt('bf')`
- PIN storage: bcrypt hash in `drivers.pin_hash` column

### Security-Definer RPCs

**Why:** Some operations require elevated privileges:
- `create_driver`: Creates driver with hashed PIN (admin only)
- `set_driver_pin`: Updates PIN hash (admin only)
- `verify_driver_pin`: Compares PIN against hash (anon/driver)
- `start_vehicle_session`: Handles session state transitions

All use `set search_path = public` with schema-qualified calls to `extensions.crypt` and `extensions.gen_salt`.

---

## 9. Rebuild Checklist

Follow these steps to rebuild the project from scratch:

### Phase 1: Supabase Project Setup

- [ ] Create new Supabase project at https://supabase.com
- [ ] Note project URL and anon key from Settings → API
- [ ] Enable pgcrypto extension (usually auto-enabled, verify in SQL: `SELECT * FROM pg_extension WHERE extname = 'pgcrypto';`)

### Phase 2: Database Schema

- [ ] Run base schema migration (creates tables, types, indexes, RLS)
- [ ] Run RLS policies migration (admin and anon policies)
- [ ] Run vehicle_summary view migration
- [ ] Run pgcrypto schema fix migration (schema-qualify functions)
- [ ] Run seed migration (default checklist items)
- [ ] Verify tables exist: `SELECT tablename FROM pg_tables WHERE schemaname = 'public';`

### Phase 3: Storage Buckets

- [ ] Create `vehicle-blueprints` bucket (public)
- [ ] Create `vehicle-base-photos` bucket (public)
- [ ] Create `inspection-photos` bucket (private)
- [ ] Create `damage-photos` bucket (private)
- [ ] Create `vehicle-logbooks` bucket (private)
- [ ] Add storage policies (already in migrations)

### Phase 4: Admin User Setup

- [ ] Go to Authentication → Users → Add user
- [ ] Create admin account (email + password)
- [ ] Copy user UUID
- [ ] Run SQL: `INSERT INTO user_roles (user_id, role) VALUES ('<uuid>', 'admin');`

### Phase 5: Local Development

- [ ] `git init && git clone <repo>` or create from template
- [ ] `cp .env.example .env`
- [ ] Fill in `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`
- [ ] `bun install` (or `npm install`)
- [ ] `bun run dev` → verify at http://localhost:8080

### Phase 6: Configure Frontend

- [ ] Install dependencies (see package.json)
- [ ] Configure `tsconfig.json` with `paths: { "@/*": ["./src/*"] }`
- [ ] Configure `vite.config.ts` with plugins and code splitting
- [ ] Set up Tailwind CSS via `@tailwindcss/vite`
- [ ] Create `src/lib/supabase.ts` with client setup

### Phase 7: Routing & Guards

- [ ] Set up `react-router-dom` with lazy loading
- [ ] Create `DriverGuard` (checks sessionStorage for driver session)
- [ ] Create `AdminGuard` (checks Supabase auth + `has_role` RPC)
- [ ] Configure nested routes for `/driver/*` and `/admin/*`

### Phase 8: Authentication

- [ ] Implement `driverAuth.ts`:
  - `loginDriver(employee_number, pin)` → calls `verify_driver_pin` RPC
  - Stores session in sessionStorage with TTL
- [ ] Implement `adminAuth.ts`:
  - `adminLogin(email, password)` → Supabase auth + role check
  - `useAdminSession()` hook with `onAuthStateChange`

### Phase 9: Build & Deploy

- [ ] `bun run build` → outputs to `./dist`
- [ ] Test production build: `bun run preview`
- [ ] Deploy to Netlify/Vercel/Cloudflare Pages
- [ ] Set environment variables in hosting platform
- [ ] Verify SPA routing works (via `_redirects` or rewrites)

### Phase 10: Verification

- [ ] Test driver login with demo credentials (`EMP001` / `1234`)
- [ ] Test admin login with created admin account
- [ ] Test vehicle session start/return flow
- [ ] Test damage marker creation and approval workflow
- [ ] Test CSV exports on reports page

---

## Demo Credentials

After running seed migrations:

| Role | Identifier | Password |
|------|------------|----------|
| Driver | `EMP001` | `1234` |
| Admin | (your email) | (your password) |

---

## License

MIT
