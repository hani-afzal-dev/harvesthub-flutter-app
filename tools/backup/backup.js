const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { encode, collections } = require('./serialize');

async function main() {
  const keyPath = path.resolve(process.env.SERVICE_ACCOUNT_PATH || path.join(__dirname, '..', 'serviceAccountKey.json'));
  admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
  const db = admin.firestore();

  const snapshot = { exportedAt: new Date().toISOString(), collections: {} };
  for (const name of collections) {
    const result = await db.collection(name).get();
    snapshot.collections[name] = result.docs.map((doc) => ({ id: doc.id, data: encode(doc.data(), admin) }));
    console.log(`${name}: ${result.size}`);
  }

  const outDir = path.resolve(process.env.BACKUP_DIR || path.join(__dirname, '..', 'backups'));
  fs.mkdirSync(outDir, { recursive: true });
  const stamp = snapshot.exportedAt.slice(0, 10);
  const file = path.join(outDir, `harvesthub-${stamp}.json`);
  fs.writeFileSync(file, JSON.stringify(snapshot, null, 2));
  console.log(`Backup written to ${file}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
