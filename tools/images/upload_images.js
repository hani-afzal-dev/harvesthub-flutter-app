const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const dryRun = process.argv.includes('--dry-run');
const extensions = ['.jpg', '.jpeg', '.png', '.webp'];
const maxBytes = 10 * 1024 * 1024;
const mimeTypes = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp' };

const groups = [
  { folder: 'products', collection: 'products', nameField: 'itemName', touchUpdatedAt: true },
  { folder: 'categories', collection: 'categories', nameField: 'name', touchUpdatedAt: false },
  { folder: 'farmers', collection: 'farmers', nameField: 'businessName', touchUpdatedAt: false },
];

function slug(text) {
  return String(text).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

function readEnv() {
  const envPath = path.resolve(process.env.ENV_PATH || path.join(__dirname, '..', '.env'));
  const values = {};
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (match) values[match[1]] = match[2].replace(/^["']|["']$/g, '');
  }
  for (const key of ['CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET']) {
    if (!values[key]) throw new Error(`${key} is missing in .env`);
  }
  return values;
}

function localPhotos(folder) {
  const dir = path.join(__dirname, folder);
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir)
    .filter((file) => extensions.includes(path.extname(file).toLowerCase()))
    .map((file) => ({ file: path.join(dir, file), key: slug(path.parse(file).name) }));
}

async function upload(env, filePath, publicId) {
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const toSign = `invalidate=true&overwrite=true&public_id=${publicId}&timestamp=${timestamp}${env.CLOUDINARY_API_SECRET}`;
  const signature = crypto.createHash('sha1').update(toSign).digest('hex');

  const form = new FormData();
  const type = mimeTypes[path.extname(filePath).toLowerCase()];
  form.append('file', new Blob([fs.readFileSync(filePath)], { type }), path.basename(filePath));
  form.append('public_id', publicId);
  form.append('overwrite', 'true');
  form.append('invalidate', 'true');
  form.append('timestamp', timestamp);
  form.append('api_key', env.CLOUDINARY_API_KEY);
  form.append('signature', signature);

  const response = await fetch(`https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD_NAME}/image/upload`, {
    method: 'POST',
    body: form,
    signal: AbortSignal.timeout(60000),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok || !body.secure_url) {
    throw new Error(body.error?.message || `HTTP ${response.status}`);
  }
  return body.secure_url;
}

async function main() {
  const env = readEnv();
  const admin = require('firebase-admin');
  const keyPath = path.resolve(process.env.SERVICE_ACCOUNT_PATH || path.join(__dirname, '..', 'serviceAccountKey.json'));
  admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
  const db = admin.firestore();

  let uploaded = 0;
  let failed = 0;

  for (const group of groups) {
    const photos = localPhotos(group.folder);
    const snap = await db.collection(group.collection).get();
    const docsByKey = {};
    snap.docs.forEach((doc) => {
      const key = slug(doc.get(group.nameField) || '');
      if (key) docsByKey[key] = doc;
    });

    console.log(`\n${group.folder}: ${photos.length} photos, ${snap.size} documents`);

    const matchedKeys = new Set();
    for (const photo of photos) {
      const doc = docsByKey[photo.key];
      if (!doc) {
        console.log(`  ? ${path.basename(photo.file)} does not match any ${group.nameField}`);
        continue;
      }
      matchedKeys.add(photo.key);

      const size = fs.statSync(photo.file).size;
      if (size > maxBytes) {
        console.log(`  x ${path.basename(photo.file)} is larger than 10 MB, skipped`);
        failed += 1;
        continue;
      }

      const label = doc.get(group.nameField);
      if (dryRun) {
        console.log(`  - ${label} <- ${path.basename(photo.file)}`);
        continue;
      }

      try {
        const url = await upload(env, photo.file, `harvesthub/${group.folder}/${doc.id}`);
        const changes = { imageUrl: url };
        if (group.touchUpdatedAt) changes.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await doc.ref.update(changes);
        console.log(`  ok ${label}`);
        uploaded += 1;
      } catch (error) {
        console.log(`  x ${label}: ${error.message}`);
        failed += 1;
      }
    }

    const missing = Object.keys(docsByKey)
      .filter((key) => !matchedKeys.has(key) && !docsByKey[key].get('imageUrl'))
      .map((key) => `${key}.jpg`);
    if (missing.length) console.log(`  still without a photo: ${missing.join(', ')}`);
  }

  if (dryRun) {
    console.log('\nDry run finished. Nothing was uploaded or changed.');
    return;
  }
  console.log(`\nUploaded ${uploaded}, failed ${failed}.`);
  if (failed) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
