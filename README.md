# ForceAim Client Platform

A standalone private workspace for ForceAim client onboarding and content management. It has its own project folder, Netlify build, API function, Supabase schema, and setup instructions. It does not depend on the public ForceAim marketing website.

## Features

- Private admin and client experiences, with no public registration. Supabase Auth handles sign-in, invitations, password reset, and sessions.
- Six-step client onboarding covering contact details, Instagram account, coaching business, follower and performance baseline, content preferences, and review/submit. Progress is saved as the client goes.
- Admin client directory and workspaces, references with private video storage and external URLs, client-specific assignments, recording instructions, review tracking, and notifications.
- Private raw video uploads direct to Supabase Storage, upload progress, admin download/preview, independent edited versions, client approval or revision feedback, and status history.
- Content calendar with client-visible entries and manual performance reports, follower history, video metrics, and CSV export.
- Supabase PostgreSQL RLS policies and a private `client-videos` bucket. Admin actions that need service-role privileges run in the server-side Netlify Function.

## Local setup

Requirements: Node.js 24 and an existing Supabase project (the app is not connected to a Supabase account in this folder).

```sh
npm install
Copy-Item .env.example .env
# Fill the values described below in .env
npm run build
npm start
```

Open `http://127.0.0.1:4174/login`. `npm run dev` is an alias for the local Node server. Never commit `.env`; the ignore rules allow only the placeholder `.env.example` file.

## Create and configure Supabase

1. Create a new Supabase project. Copy the project URL, anon/publishable key, and service-role key from its API settings.
2. Apply the migrations in order using the Supabase SQL Editor or Supabase CLI: first `supabase/migrations/202610170001_platform.sql`, then `supabase/migrations/20261020083943_booking_and_instagram_metrics.sql`. The first creates platform tables, RLS, and private storage; the second adds tracked booking links/clicks, Calendly booking events, and additional metric columns. The second migration has already been applied to the connected Supabase project.
   The existing project’s original schema was applied manually and is not recorded in Supabase’s migration history. Do not run a full `supabase db push` against that existing project until the original migration history is reconciled; this added migration is recorded as `20261020083943`.
3. In Authentication → URL Configuration, set the Site URL to your Netlify site URL and add redirect URLs for `/invite` and `/reset` on that site, plus `http://localhost:4174/invite` and `http://localhost:4174/reset` for local development.
4. Configure an SMTP provider in Supabase Auth before inviting clients or sending password reset email. Email is sent by Supabase Auth; this app does not claim to send email itself.
5. Keep the bucket private and set its allowed size to fit the `MAX_VIDEO_SIZE_MB` value and your Supabase plan. Allowed upload types are MP4 and MOV (`video/mp4` and `video/quicktime`).

Required environment variables (set in `.env` locally and in Netlify for production):

| Name | Value |
| --- | --- |
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | The project anon/publishable key |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-only service-role key; never expose it in browser code |
| `APP_URL` | Local origin for local work, or exact Netlify site origin in production |
| `MAX_VIDEO_SIZE_MB` | Optional upload cap; defaults to 500 MB and must not exceed the Supabase bucket/plan limit |
| `CALENDLY_WEBHOOK_SIGNING_KEY` | Optional server-only signing key from the Calendly webhook subscription; enables verified booking and cancellation events |
| `META_APP_ID` | Meta Developer App ID; server-side Function variable |
| `META_APP_SECRET` | Meta Developer App secret; server-side Function variable only |
| `META_REDIRECT_URI` | Exact OAuth callback URL registered with Meta, for example `https://client-workspace.netlify.app/api/meta/callback` |
| `INSTAGRAM_TOKEN_ENCRYPTION_KEY` | Base64 encoding of a random 32-byte key used to encrypt Instagram access tokens at rest |

`SUPABASE_SERVICE_ROLE_KEY` is needed for invitations, notification/admin actions, and issuing privileged signed upload URLs. Do not set it as a `VITE_` or other browser-exposed variable.

## Connect a client's Instagram account

Instagram account connections are initiated from the agency admin workspace. Open `/admin/clients`, select the client, open the **Instagram** section, and choose **Connect Instagram through Meta**. The account owner must sign in on Instagram and grant access; the portal never asks for an Instagram password or security code. The returned account and encrypted access token are associated with the selected client workspace. Clients can view their connection status, but integration controls remain with the agency.

Before using the button:

1. Create/configure a Meta Developer App and enable **Instagram API with Instagram Login** for eligible professional accounts. Configure the OAuth redirect URI as exactly `https://client-workspace.netlify.app/api/meta/callback` (or your own site's `/api/meta/callback`) in Meta and set the same exact value in `META_REDIRECT_URI`.
2. Add `META_APP_ID`, `META_APP_SECRET`, `META_REDIRECT_URI`, and `INSTAGRAM_TOKEN_ENCRYPTION_KEY` to Netlify's server-side environment for Functions. Generate the encryption key with `node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"`. Never use the Meta secret, encryption key, or Supabase service-role key in frontend code.
3. For local use, set `META_REDIRECT_URI=http://localhost:4174/api/meta/callback` and add that exact callback URL to the Meta app. Use a local `.env` file only.
4. Redeploy the Netlify site after setting variables. Then use **Connect Instagram through Meta** from the chosen client's admin workspace.

This connection currently requests only `instagram_business_basic` and reads the authorized account's ID and username. It does not publish content or automatically sync Instagram insights. Meta app mode, tester roles, review, and permissions can affect who is allowed to authorize; complete any setup Meta requires for your app before treating the live connection as available.

## Create the first administrator

There is no public registration and client profiles cannot promote themselves. First create your own user in Supabase Authentication → Users. Then run this SQL in Supabase SQL Editor, replacing the email and name:

```sql
insert into public.profiles (id, role, client_id, full_name, email)
select id, 'admin', null, 'Your Name', email
from auth.users
where lower(email) = lower('you@example.com')
on conflict (id) do update
set role = 'admin', client_id = null, full_name = excluded.full_name, email = excluded.email;
```

Sign in at `/login`; the app routes administrator accounts to `/admin`.

## Invite a client and complete onboarding

1. Sign in as the administrator and open `/admin/clients`.
2. Select **Invite client** and provide the client's name, email, and business name. The application creates the client workspace and sends a Supabase Auth invitation.
3. The client opens the invitation email, chooses a password at `/invite`, signs in, and completes onboarding in `/portal/onboarding`.
4. Confirm the client appears in the admin directory and has the expected onboarding status.

## References, footage, edits, and approvals

1. At `/admin/references`, create a reference, upload an MP4/MOV or add an external Instagram/YouTube link, enter recording instructions, and assign/publish it to one or more clients.
2. The client reviews the assignment at `/portal/references`. **Record and upload** opens the upload form with that reference selected.
3. The client uploads raw MP4/MOV footage at `/portal/upload`. The browser sends the file directly to the private Supabase bucket using a signed upload URL, so the large video does not pass through the Netlify Function.
4. Review and download raw footage at `/admin/videos`. Upload an edited MP4 as a new version; the original stays separate. The client can preview the edit at `/portal/videos`, approve it, or request changes with feedback.
5. For an initial smoke test, use short non-sensitive sample files. Confirm the raw and edited files are private and available only to the assigned client and admin.

## Calendar and performance

- Admins create and schedule entries at `/admin/calendar`. Clients see only their own entries at `/portal/calendar`. A `Scheduled`/`Published` status is a workflow record; it does not publish to Instagram.
- Admins add manually reported follower snapshots, follows/unfollows, profile link taps, engagement, views, reach, likes, comments, shares, saves, leads, and calls at `/admin/performance`. Clients see dated results and trends at `/portal/results`. Instagram insights are manual in this release; connecting an Instagram account alone does not sync those metrics. Use Instagram's current **Views** metric for recent content rather than deprecated impressions.
- Admins can set a client's Calendly destination in **Performance Reports → Tracked Calendly booking link**. The portal generates a public `/api/book/<client-id>` link; put that link in the client's Instagram bio or CTA. Each redirect is recorded as a click (not a unique person), then the visitor is sent to the configured Calendly page. The client sees click totals and, once webhooks are configured, confirmed active bookings. The system does not store invitee names or email addresses.
- To count confirmed Calendly bookings automatically, create a Calendly webhook subscription for `invitee.created` and `invitee.canceled`, with `scheduled_events:read` and `webhooks:write` scopes. Set the callback to `https://<your-netlify-site>/api/webhooks/calendly`, then copy the webhook signing key into Netlify as `CALENDLY_WEBHOOK_SIGNING_KEY` and redeploy. The endpoint verifies the signature and a short replay window. The app only matches bookings that carry the tracked link's `utm_content`; bookings made through other URLs are not attributed. Creating the webhook subscription requires your Calendly developer account; the application does not create it automatically.

## Prepare a new GitHub repository and Netlify site

This project folder is independent of the existing marketing-site repository and has no GitHub remote or Netlify site linked. Create the new repository and connect it through your own GitHub/Netlify accounts when you are ready; no repository or external account has been created here.
After you create an empty repository in GitHub, from this folder you can initialize and push it with:

```sh
git init -b main
git add .
git commit -m "Initial ForceAim client platform"
git remote add origin https://github.com/<your-account>/<new-repository>.git
git push -u origin main
```

1. Upload/push the contents of this folder to a new, empty GitHub repository. Keep `netlify.toml` at the repository root.
2. In Netlify, create a site from that repository and deploy its `main` branch. The config sets Node 24, `npm run build`, `dist` as the publish directory, and `netlify/functions` as the Functions directory.
3. Set the required environment variables listed above in Netlify site environment settings. Set `APP_URL` to the site's exact HTTPS origin, and configure the same origin in Supabase Auth URL settings. Add `CALENDLY_WEBHOOK_SIGNING_KEY` only after creating the Calendly subscription.
4. Trigger a deploy after saving variables. Check the deploy log and the Function logs for `forceaim-api`.
5. Verify `/login`, sign in as admin, invite a test client, and complete one upload/review cycle. Create two client accounts and confirm each sees only its own workspace and files.

## Checks and verification limits

`npm run build` copies only this app's redirect page and icon to `dist`; the admin/client application is rendered by the Netlify Function. `node --check api/index.mjs`, `node --check netlify/functions/forceaim-api.mjs`, and `node --check server.mjs` check JavaScript syntax.

No Supabase project, credentials, Netlify site, email provider, or test client accounts are configured in this folder. Local checks cannot verify live authentication, invitations, RLS isolation, or Storage authorization. Complete those checks after setup; do not treat successful compilation as proof of live-service security.
