const fs = require('fs');
const path = require('path');

const reallyDelete = process.argv.includes('--delete');
const minAgeHours = 24;

function readEnv() {
  const envPath = path.resolve(process.env.ENV_PATH || path.join(__dirname, '..', '.env'));
  const values = {};
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (match) values[match[1]] = match[2].replace(/^["']|["']$/g, '');
  }
  for (const key of ['CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET']) {
    if (!values[key]) throw new Error(`${key} is missing in tools/.env`);
  }
  return values;
}

function publicIdFromUrl(url) {
  const marker = '/image/upload/';
  const index = url.indexOf(marker);
  if (index < 0) return null;
  let rest = url.slice(index + marker.length).split('/');
  const version = rest.findIndex((part) => /^v\d+$/.test(part));
  if (version >= 0) rest = rest.slice(version + 1);
  const joined = rest.join('/');
  const dot = joined.lastIndexOf('.');
  return dot > 0 ? joined.slice(0, dot) : joined;
}

async function cloudinary(env, pathAndQuery, method = 'GET') {
  const auth = Buffer.from(`${env.CLOUDINARY_API_KEY}:${env.CLOUDINARY_API_SECRET}`).toString('base64');
  const response = await fetch(`https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD_NAME}/${pathAndQuery}`, {
    method,
    headers: { Authorization: `Basic ${auth}` },
    signal: AbortSignal.timeout(60000),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.error?.message || `HTTP ${response.status}`);
  return body;
}

async function main() {
  const env = readEnv();
  const admin = require('firebase-admin');
  const keyPath = path.resolve(process.env.SERVICE_ACCOUNT_PATH || path.join(__dirname, '..', 'serviceAccountKey.json'));
  admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
  const db = admin.firestore();

  const used = new Set();
  for (const collection of ['products', 'categories', 'farmers']) {
    const snap = await db.collection(collection).select('imageUrl').get();
    snap.docs.forEach((doc) => {
      const url = doc.get('imageUrl');
      const id = url ? publicIdFromUrl(url) : null;
      if (id) used.add(id);
    });
  }
  console.log(`Photos still used by the app: ${used.size}`);

  const cutoff = Date.now() - minAgeHours * 60 * 60 * 1000;
  const unused = [];
  let cursor = null;
  do {
    const query = `resources/image/upload?max_results=500${cursor ? `&next_cursor=${cursor}` : ''}`;
    const page = await cloudinary(env, query);
    for (const resource of page.resources || []) {
      if (used.has(resource.public_id)) continue;
      if (new Date(resource.created_at).getTime() > cutoff) continue;
      unused.push(resource.public_id);
    }
    cursor = page.next_cursor || null;
  } while (cursor);

  if (unused.length === 0) {
    console.log('Nothing to clean up.');
    return;
  }
  console.log(`Photos not used anywhere (older than ${minAgeHours}h): ${unused.length}`);
  unused.forEach((id) => console.log(`  ${id}`));

  if (!reallyDelete) {
    console.log('\nNothing was deleted. Run "npm run images:cleanup -- --delete" to remove these photos.');
    return;
  }

  for (let i = 0; i < unused.length; i += 100) {
    const batch = unused.slice(i, i + 100);
    const params = batch.map((id) => `public_ids[]=${encodeURIComponent(id)}`).join('&');
    await cloudinary(env, `resources/image/upload?${params}`, 'DELETE');
  }
  console.log(`Deleted ${unused.length} unused photos.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
