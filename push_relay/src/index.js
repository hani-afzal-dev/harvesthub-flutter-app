const GOOGLE_KEYS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const MAX_IDS = 50;
const MAX_AGE_MS = 10 * 60 * 1000;

let cachedKeys = null;
let cachedKeysUntil = 0;
let cachedAccessToken = null;
let cachedAccessTokenUntil = 0;

function base64UrlDecode(text) {
  const padded = text.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(text.length / 4) * 4, '=');
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function base64UrlEncode(input) {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : new Uint8Array(input);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function googleKeys() {
  if (cachedKeys && Date.now() < cachedKeysUntil) return cachedKeys;
  const response = await fetch(GOOGLE_KEYS_URL);
  if (!response.ok) throw new Error('Could not load Google signing keys');
  const body = await response.json();
  cachedKeys = body.keys;
  cachedKeysUntil = Date.now() + 60 * 60 * 1000;
  return cachedKeys;
}

async function verifyIdToken(token, projectId) {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('Malformed token');
  const header = JSON.parse(new TextDecoder().decode(base64UrlDecode(parts[0])));
  const payload = JSON.parse(new TextDecoder().decode(base64UrlDecode(parts[1])));
  if (header.alg !== 'RS256') throw new Error('Unexpected algorithm');

  const now = Math.floor(Date.now() / 1000);
  if (payload.aud !== projectId) throw new Error('Wrong audience');
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) throw new Error('Wrong issuer');
  if (!payload.sub || typeof payload.sub !== 'string') throw new Error('Missing subject');
  if (payload.exp <= now || payload.iat > now + 300) throw new Error('Token expired');

  const jwk = (await googleKeys()).find((key) => key.kid === header.kid);
  if (!jwk) throw new Error('Unknown signing key');
  const key = await crypto.subtle.importKey(
    'jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify'],
  );
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5', key, base64UrlDecode(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!valid) throw new Error('Bad signature');
  return payload.sub;
}

async function serviceAccessToken(serviceAccount) {
  if (cachedAccessToken && Date.now() < cachedAccessTokenUntil) return cachedAccessToken;
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64UrlEncode(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const pem = serviceAccount.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${claims}`),
  );
  const assertion = `${header}.${claims}.${base64UrlEncode(signature)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) throw new Error('Could not get a Google access token');
  const body = await response.json();
  cachedAccessToken = body.access_token;
  cachedAccessTokenUntil = Date.now() + (body.expires_in - 120) * 1000;
  return cachedAccessToken;
}

async function readNotification(projectId, accessToken, notifId) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/notifications/${encodeURIComponent(notifId)}`;
  const response = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (response.status === 404) return null;
  if (!response.ok) throw new Error(`Firestore read failed (${response.status})`);
  const body = await response.json();
  const fields = body.fields || {};
  return {
    userId: fields.userId?.stringValue,
    type: fields.type?.stringValue,
    message: fields.message?.stringValue,
    relatedId: fields.relatedId?.stringValue,
    createdAt: fields.createdAt?.timestampValue,
  };
}

async function uuidFor(text) {
  const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text)));
  hash[6] = (hash[6] & 0x0f) | 0x40;
  hash[8] = (hash[8] & 0x3f) | 0x80;
  const hex = [...hash.slice(0, 16)].map((b) => b.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

function getHeadingForType(type) {
  switch (type) {
    case 'restock_alert':
      return 'Back in stock';
    case 'new_order':
      return 'New order received';
    case 'slot_cancelled':
      return 'Pickup slot cancelled';
    case 'booking_modified':
      return 'Pickup booking changed';
    case 'order_status':
      return 'Order update';
    default:
      return 'HarvestHub';
  }
}

async function sendPush(env, notifId, notification) {
  const data = { userId: notification.userId, type: notification.type };
  if (notification.relatedId) data.relatedId = notification.relatedId;
  const heading = getHeadingForType(notification.type);
  const response = await fetch('https://api.onesignal.com/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      Authorization: `Key ${env.ONESIGNAL_REST_API_KEY}`,
    },
    body: JSON.stringify({
      app_id: env.ONESIGNAL_APP_ID,
      idempotency_key: await uuidFor(notifId),
      include_aliases: { external_id: [notification.userId] },
      target_channel: 'push',
      headings: { en: heading },
      contents: { en: notification.message },
      priority: 10,
      android_accent_color: 'FF3B6D11',
      android_visibility: 1,
      data,
    }),
  });
  return response.ok;
}

const GEMINI_MODELS = ['gemini-3.5-flash-lite', 'gemini-3.6-flash'];
const GEMINI_TIMEOUT_MS = 8000;
const CHAT_LIMIT_PER_MINUTE = 20;
const MAX_QUESTION_LENGTH = 500;
const chatHits = new Map();

function allowChat(uid) {
  const now = Date.now();
  const recent = (chatHits.get(uid) || []).filter((time) => now - time < 60000);
  if (recent.length >= CHAT_LIMIT_PER_MINUTE) {
    chatHits.set(uid, recent);
    return false;
  }
  recent.push(now);
  chatHits.set(uid, recent);
  return true;
}

async function askGemini(env, question) {
  const prompt = 'You are the HarvestHub Farm Products Assistant. Answer briefly and only about '
    + `fruits, vegetables, farming, nutrition, or storage. Question: ${question}`;
  for (const model of GEMINI_MODELS) {
    let response;
    try {
      response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'x-goog-api-key': env.GEMINI_API_KEY },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: { thinkingConfig: { thinkingLevel: 'minimal' } },
          }),
          signal: AbortSignal.timeout(GEMINI_TIMEOUT_MS),
        },
      );
    } catch (error) {
      return null;
    }
    if (response.status === 404 || response.status === 429 || response.status >= 500) continue;
    if (!response.ok) return null;
    const body = await response.json();
    const text = body.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text === 'string' && text.trim()) return text.trim();
    return null;
  }
  return null;
}

async function handleChat(request, env, uid) {
  if (!allowChat(uid)) return json(429, { error: 'Too many questions. Wait a minute and try again.' });
  let question;
  try {
    const body = await request.json();
    question = typeof body.question === 'string' ? body.question.trim() : '';
  } catch (error) {
    return json(400, { error: 'Invalid body' });
  }
  if (!question || question.length > MAX_QUESTION_LENGTH) {
    return json(400, { error: 'Invalid question' });
  }
  const answer = await askGemini(env, question);
  if (!answer) return json(503, { error: 'Assistant unavailable' });
  return json(200, { answer });
}

async function handleNotify(request, env) {
  let ids;
  try {
    const body = await request.json();
    ids = body.notificationIds;
  } catch (error) {
    return json(400, { error: 'Invalid body' });
  }
  if (!Array.isArray(ids) || ids.length === 0 || ids.length > MAX_IDS
      || !ids.every((id) => typeof id === 'string' && /^[A-Za-z0-9_-]{1,100}$/.test(id))) {
    return json(400, { error: 'Invalid notification ids' });
  }

  const serviceAccount = JSON.parse(env.GOOGLE_SERVICE_ACCOUNT);
  const accessToken = await serviceAccessToken(serviceAccount);
  let sent = 0;
  let skipped = 0;

  for (const notifId of [...new Set(ids)]) {
    const notification = await readNotification(env.FIREBASE_PROJECT_ID, accessToken, notifId);
    const age = notification?.createdAt ? Date.now() - Date.parse(notification.createdAt) : Infinity;
    if (!notification || !notification.userId || !notification.message || age > MAX_AGE_MS || age < -60000) {
      skipped++;
      continue;
    }
    if (env.DRY_RUN === 'true' || await sendPush(env, notifId, notification)) {
      sent++;
    } else {
      skipped++;
    }
  }

  return json(200, { sent, skipped });
}

export default {
  async fetch(request, env) {
    const path = new URL(request.url).pathname;
    if (request.method !== 'POST' || (path !== '/notify' && path !== '/chat')) {
      return json(404, { error: 'Not found' });
    }

    const auth = request.headers.get('Authorization') || '';
    if (!auth.startsWith('Bearer ')) return json(401, { error: 'Missing token' });
    let uid;
    try {
      uid = await verifyIdToken(auth.slice(7), env.FIREBASE_PROJECT_ID);
    } catch (error) {
      return json(401, { error: 'Invalid token' });
    }

    if (path === '/chat') return handleChat(request, env, uid);
    return handleNotify(request, env);
  },
};
