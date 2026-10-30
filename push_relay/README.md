# HarvestHub push relay

A small Cloudflare Worker (free plan) that holds the secret keys the app must never ship with: it sends push notifications (OneSignal REST key) and answers assistant questions (Gemini API key). Every request needs a valid Firebase ID token.

How it works:

1. The app writes a notification document to Firestore. Firestore rules already decide who may notify whom.
2. The app calls `POST /notify` with the document ids and the user's Firebase ID token.
3. The worker checks the token, reads each notification with a service account, and only pushes notifications that exist and are less than 10 minutes old. The pushed text is always the text stored in Firestore.

The assistant calls `POST /chat` with `{"question": "..."}`. The worker checks the token, allows 20 questions per user per minute and up to 500 characters, then asks Gemini and returns `{"answer": "..."}`. If it fails, the app falls back to its offline answers.

## Deploy (once)

Needs Node 18+ and a free Cloudflare account (https://dash.cloudflare.com/sign-up).

```
cd push_relay
npx wrangler login
npx wrangler secret put ONESIGNAL_APP_ID
npx wrangler secret put ONESIGNAL_REST_API_KEY
npx wrangler secret put GEMINI_API_KEY
npx wrangler secret put GOOGLE_SERVICE_ACCOUNT < ../tools/serviceAccountKey.json
npx wrangler deploy
```

For the first three secrets, paste the values from `push_relay/.dev.vars` when asked.
In PowerShell use this for `GOOGLE_SERVICE_ACCOUNT` instead:

```
Get-Content ..\tools\serviceAccountKey.json -Raw | npx wrangler secret put GOOGLE_SERVICE_ACCOUNT
```

`wrangler deploy` prints a URL such as `https://harvesthub-push.<your-name>.workers.dev`. Put it in the project `.env`:

```
PUSH_RELAY_URL=https://harvesthub-push.<your-name>.workers.dev
```

Then rebuild the app. While `PUSH_RELAY_URL` is empty the app still saves every notification, so the in-app bell and badge keep working; only the phone pop-up is skipped.

## After deploying

- Older APKs contain the old Gemini key. In Google AI Studio create a new API key, delete the old one, and run `npx wrangler secret put GEMINI_API_KEY` with the new key.
- Older APKs contain the old OneSignal REST key. In OneSignal go to Settings > Keys & IDs, create a new REST API key, delete the old one, and run `npx wrangler secret put ONESIGNAL_REST_API_KEY` again with the new key.
- Optional, safer: in Google Cloud IAM create a separate service account with only the "Cloud Datastore Viewer" role and use its key for `GOOGLE_SERVICE_ACCOUNT` instead of the admin key.

`.dev.vars` is git-ignored and is not part of the app.
