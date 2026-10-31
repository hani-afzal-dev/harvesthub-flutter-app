const fs = require('fs');
const path = require('path');

const dryRun = process.argv.includes('--dry-run');
const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'seed_data.json'), 'utf8'));

const emailPattern = /^[a-z0-9]+([._-][a-z0-9]+)*@[a-z0-9]+([.-][a-z0-9]+)*\.[a-z]{2,}$/;
const namePattern = /^[a-zA-Z\s'-]{2,60}$/;
const phonePattern = /^\+[1-9][0-9]{7,14}$/;
const units = ['kg', 'litre', 'dozen', 'piece'];

function checkAccount(account) {
  const problems = [];
  if (!emailPattern.test(account.email)) problems.push('email');
  if (!namePattern.test(account.name)) problems.push('name');
  if (!phonePattern.test(account.phone)) problems.push('phone');
  const pw = account.password;
  if (pw.length < 8 || !/[A-Z]/.test(pw) || !/[0-9]/.test(pw) || !/[^A-Za-z0-9\s]/.test(pw)) problems.push('password');
  if (problems.length) throw new Error(`Invalid seed account ${account.email}: ${problems.join(', ')}`);
}

function slotTime(dayOffset, index) {
  const time = new Date();
  time.setDate(time.getDate() + dayOffset);
  time.setHours(index === 0 ? 10 : 16, 0, 0, 0);
  return time;
}

function build() {
  const accounts = [
    { role: 'admin', ...data.accounts.admin, key: 'admin' },
    ...data.accounts.farmers.map((f) => ({ role: 'farmer', ...f })),
    ...data.accounts.customers.map((c) => ({ role: 'customer', ...c })),
  ];
  accounts.forEach(checkAccount);

  const productByKey = {};
  data.products.forEach((p) => {
    if (!units.includes(p.unit)) throw new Error(`Bad unit on ${p.key}`);
    if (p.name.length < 2 || p.description.length > 500 || p.price <= 0 || p.stock < 0) throw new Error(`Bad product ${p.key}`);
    productByKey[p.key] = p;
  });

  const slots = [];
  data.accounts.farmers.forEach((f) => {
    for (let day = 1; day <= 5; day += 1) {
      for (let index = 0; index < 2; index += 1) {
        slots.push({ id: `slot_${f.key}_${day}_${index}`, farmer: f.key, time: slotTime(day, index), capacity: 5, booked: 0 });
      }
    }
  });
  const slotById = Object.fromEntries(slots.map((s) => [s.id, s]));

  const customers = Object.fromEntries(data.accounts.customers.map((c) => [c.key, c]));
  const ratings = {};
  const orders = data.orders.map((o) => {
    const items = o.items.map(([productKey, qty]) => {
      const product = productByKey[productKey];
      if (!product) throw new Error(`Order ${o.key} uses unknown product ${productKey}`);
      if (product.farmer !== o.farmer) throw new Error(`Order ${o.key} mixes farmers`);
      return { productId: `p_${productKey}`, itemName: product.name, qty, pricePerUnit: product.price, subtotal: product.price * qty };
    });
    const created = new Date(Date.now() - o.daysAgo * 24 * 60 * 60 * 1000);
    let slotId = null;
    let pickupTime = new Date(created.getTime() + 24 * 60 * 60 * 1000);
    if (o.slot) {
      slotId = `slot_${o.slot[0]}_${o.slot[1]}_${o.slot[2]}`;
      const slot = slotById[slotId];
      if (!slot) throw new Error(`Order ${o.key} uses unknown slot ${slotId}`);
      slot.booked += 1;
      pickupTime = slot.time;
    }
    if (o.rating) {
      ratings[o.farmer] = ratings[o.farmer] || { sum: 0, count: 0 };
      ratings[o.farmer].sum += o.rating;
      ratings[o.farmer].count += 1;
    }
    return { o, items, created, slotId, pickupTime, total: items.reduce((sum, i) => sum + i.subtotal, 0), address: customers[o.customer].address };
  });
  return { accounts, slots, orders, ratings };
}

async function existingImages(db, collection) {
  const snap = await db.collection(collection).select('imageUrl').get();
  const found = {};
  snap.docs.forEach((doc) => {
    const url = doc.get('imageUrl');
    if (url) found[doc.id] = url;
  });
  return found;
}

async function main() {
  const plan = build();
  const customers = Object.fromEntries(data.accounts.customers.map((c) => [c.key, c]));
  console.log(`Accounts: ${plan.accounts.length}, categories: ${data.categories.length}, markets: ${data.markets.length}`);
  console.log(`Products: ${data.products.length}, slots: ${plan.slots.length}, orders: ${plan.orders.length}, promo codes: ${data.promoCodes.length}`);
  if (dryRun) {
    console.log('Dry run finished. Nothing was written.');
    return;
  }

  const admin = require('firebase-admin');
  const keyPath = path.resolve(process.env.SERVICE_ACCOUNT_PATH || path.join(__dirname, '..', 'serviceAccountKey.json'));
  admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
  const db = admin.firestore();
  const auth = admin.auth();
  const { Timestamp, GeoPoint } = admin.firestore;
  const ts = (date) => Timestamp.fromDate(date);
  const now = ts(new Date());

  const uids = {};
  for (const account of plan.accounts) {
    let user;
    try {
      user = await auth.getUserByEmail(account.email);
      await auth.updateUser(user.uid, { password: account.password, emailVerified: true, disabled: false });
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
      user = await auth.createUser({ email: account.email, password: account.password, displayName: account.name, emailVerified: true });
    }
    uids[account.key] = user.uid;
  }

  const images = {
    categories: await existingImages(db, 'categories'),
    farmers: await existingImages(db, 'farmers'),
    products: await existingImages(db, 'products'),
  };
  const keptImages = Object.values(images).reduce((sum, group) => sum + Object.keys(group).length, 0);
  if (keptImages) console.log(`Keeping ${keptImages} existing image links`);

  const writer = db.bulkWriter();
  const set = (collection, id, doc) => writer.set(db.collection(collection).doc(id), doc);

  data.categories.forEach((c) => set('categories', c.id, { name: c.name, description: c.description, imageUrl: images.categories[c.id] || null, isActive: true }));
  data.markets.forEach((m) => set('farmers_markets', m.id, {
    marketName: m.marketName, address: m.address, gpsCoordinates: new GeoPoint(m.lat, m.lng), operatingHours: m.operatingHours, activeStatus: true,
  }));

  plan.accounts.forEach((a) => set('users', uids[a.key], {
    name: a.name, email: a.email, phone: a.phone, address: a.address || '', role: a.role, isActive: true, fcmToken: null, createdAt: now,
  }));

  data.accounts.farmers.forEach((f) => {
    const rating = plan.ratings[f.key] || { sum: 0, count: 0 };
    set('farmers', uids[f.key], {
      userId: uids[f.key], marketId: f.market, businessName: f.businessName, description: f.description,
      rating: rating.count ? rating.sum / rating.count : 0, ratingSum: rating.sum, ratingCount: rating.count,
      imageUrl: images.farmers[uids[f.key]] || null, isVerified: f.verified, createdAt: now,
    });
  });

  data.products.forEach((p) => set('products', `p_${p.key}`, {
    farmerId: uids[p.farmer], categoryId: p.category, itemName: p.name, itemNameLower: p.name.toLowerCase(), description: p.description,
    pricePerUnit: p.price, unit: p.unit, stockQty: p.stock, imageUrl: images.products[`p_${p.key}`] || null, isAvailable: true, createdAt: now, updatedAt: now,
  }));

  plan.slots.forEach((s) => set('pickup_slots', s.id, {
    farmerId: uids[s.farmer], slotTime: ts(s.time), capacity: s.capacity, booked: s.booked, isActive: true,
  }));

  plan.orders.forEach(({ o, items, created, slotId, pickupTime, total, address }) => {
    set('orders', `order_${o.key}`, {
      customerId: uids[o.customer], customerName: customers[o.customer].name, farmerId: uids[o.farmer], items, totalPrice: total, promoCode: null, discount: 0, status: o.status,
      pickupSlotId: slotId, pickupSlotTime: ts(pickupTime), deliveryAddr: address, customerRating: o.rating || null,
      createdAt: ts(created), updatedAt: ts(created),
    });
  });

  data.follows.forEach(([customer, farmer]) => set('followed_farmers', `${uids[customer]}_${uids[farmer]}`, {
    customerId: uids[customer], farmerId: uids[farmer], followedAt: now,
  }));
  data.wishlists.forEach(([customer, product]) => set('wishlists', `${uids[customer]}_p_${product}`, {
    customerId: uids[customer], productId: `p_${product}`, addedAt: now,
  }));

  data.promoCodes.forEach((p) => set('promo_codes', p.code, {
    code: p.code, type: p.type, value: p.value, minOrder: p.minOrder, maxDiscount: p.maxDiscount, active: p.active,
    expiresAt: ts(new Date(Date.now() + p.daysValid * 24 * 60 * 60 * 1000)), createdAt: now,
  }));

  set('notifications', 'new_order_order_o7', {
    userId: uids.ali, type: 'new_order', message: 'You have a new order from Ayesha Khan.', relatedId: 'order_o7', isRead: false, createdAt: now,
  });
  set('notifications', 'seed_status_o8', {
    userId: uids.bilal, type: 'order_status', message: 'Your order was confirmed by Malik Dairy and Pulses.', relatedId: 'order_o8', isRead: false, createdAt: now,
  });
  set('notifications', 'seed_lowstock_chana', {
    userId: uids.ayesha, type: 'restock_alert', message: 'Chana Dal is running low.', relatedId: 'p_chana', isRead: false, createdAt: now,
  });

  await writer.close();
  console.log('Seed finished. Log in with the accounts listed in README.md.');
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
