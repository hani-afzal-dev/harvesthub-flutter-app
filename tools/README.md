# HarvestHub tools

These scripts run on a PC with Node 18 or newer. They are not part of the app.

## One-time setup

1. Firebase console > Project settings > Service accounts > Generate new private key.
2. Save the file as `tools/serviceAccountKey.json`. It is git-ignored. Never commit it.
3. `cd tools && npm install`

## Seed demo data

```
npm run seed:dry     # checks the data, writes nothing
npm run seed         # creates Auth users and Firestore documents
```

Running it again is safe: documents use fixed ids and Auth users are updated, not duplicated. It creates 7 categories, 3 markets, 3 farmers, 6 customers, 1 admin, 28 products, 30 pickup slots, 12 orders, follows, wishlists and 3 unread notifications. All seeded accounts have a verified email so orders work without an inbox. Product photos are added with `npm run images` (see below).

## Product, category and farmer photos

Put photos in these folders, named after the item as it appears in the app (case, spaces and dashes do not matter):

```
images/products/sindhri-mango.jpg
images/products/Basmati Rice.png
images/categories/fruits.jpg
images/categories/herbs-and-spices.jpg
images/farmers/raza-orchards.jpg
```

JPG, PNG or WEBP, under 10 MB each. Then:

```
npm run images:dry   # shows which photo goes to which item, uploads nothing
npm run images       # uploads to Cloudinary and saves the link in Firestore
```

It needs `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY` and `CLOUDINARY_API_SECRET` in `tools/.env`. That file stays on this PC: it is git-ignored and never packed into the app, so the Cloudinary secret is not inside the APK. Each photo is stored as `harvesthub/<folder>/<document id>`, so running it again replaces the old photo instead of adding a copy. The end of each section lists the items that still have no photo.

Running `npm run seed` again keeps any photo links that are already saved.

The app never deletes photos itself, because that needs the Cloudinary secret. To remove photos that were replaced or whose product was deleted:

```
npm run images:cleanup              # lists photos no product, category or farmer uses
npm run images:cleanup -- --delete  # deletes them
```

Photos uploaded in the last 24 hours are skipped so a form that is still open is never affected. If this Cloudinary account is shared with other projects, check the list before using --delete.

## Security rules tests

```
npm run test:rules
```

Starts the local Firestore emulator (needs Java), loads `../firestore.rules` and runs 42 checks: a real checkout, a real cancellation with stock returned, a real rating, a valid market, a valid farmer report and an order with the customer's own name must pass, while a customer changing stock directly, sending a lower price or total, adding more than 7 products, using another farmer's product or slot, returning stock without cancelling, rating a farmer without a completed order, deleting someone else's data, or saving a report with extra fields or negative revenue must be blocked. Nothing touches the live database.

## Backup and restore

```
npm run backup                                  # writes tools/backups/harvesthub-YYYY-MM-DD.json
node backup/restore.js backups/harvesthub-2026-09-24.json           # restores everything
node backup/restore.js backups/harvesthub-2026-09-24.json products  # restores one collection
```

Restore overwrites documents with the same id. It does not delete documents that were created after the backup.

## Scheduled backup (Spark plan)

Managed Firestore exports need the Blaze plan, so the SRS "scheduled auto-backup" is done with `.github/workflows/firestore-backup.yml`. It runs every night at 21:30 UTC and keeps 30 days of files.

Add two repository secrets: `FIREBASE_SERVICE_ACCOUNT` (the full JSON) and `BACKUP_PASSPHRASE` (any long random text). The file is encrypted before upload because it contains customer emails and phone numbers. To read one:

```
openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:YOUR_PASSPHRASE -in harvesthub-2026-09-24.json.enc -out backup.json
```

A nightly run reads every document once, which is far below the free 50,000 reads per day at this data size.
