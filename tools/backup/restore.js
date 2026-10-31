const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { decode, collections } = require('./serialize');

async function main() {
  const file = process.argv[2];
  const only = process.argv[3];
  if (!file) throw new Error('Usage: node backup/restore.js <backup.json> [collection]');
  if (only && !collections.includes(only)) throw new Error(`Unknown collection: ${only}`);

  const snapshot = JSON.parse(fs.readFileSync(path.resolve(file), 'utf8'));
  const keyPath = path.resolve(process.env.SERVICE_ACCOUNT_PATH || path.join(__dirname, '..', 'serviceAccountKey.json'));
  admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
  const db = admin.firestore();
  const writer = db.bulkWriter();

  let count = 0;
  for (const name of only ? [only] : collections) {
    for (const doc of snapshot.collections[name] || []) {
      writer.set(db.collection(name).doc(doc.id), decode(doc.data, admin));
      count += 1;
    }
  }
  await writer.close();
  console.log(`Restored ${count} documents from backup taken at ${snapshot.exportedAt}.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
