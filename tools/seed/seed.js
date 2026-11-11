/**
 * HarvestHub — Unified Database Seed Script
 * 
 * Sets up clean, production-ready seed data in Firebase Auth and Firestore.
 * Contains only solo-developer accounts for Hani Afzal (Customer, Farmer, Admin).
 * 
 * Usage:
 *   node seed/seed.js            # Live seed against Firebase
 *   node seed/seed.js --dry-run  # Validates data schemas without writing
 */

const fs = require('fs');
const path = require('path');

const dryRun = process.argv.includes('--dry-run');

// --- 1. Account Definitions (Solo: Hani Afzal) ---
const accounts = {
  admin: {
    key: 'admin',
    email: 'admin@harvesthub.test',
    password: 'Admin@Harvest26',
    name: 'Hani Afzal (Admin)',
    phone: '+923331234567',
    address: 'HarvestHub Headquarters, Latifabad, Hyderabad',
    role: 'admin',
  },
  farmer: {
    key: 'afzal_farm',
    email: 'hani.farmer@harvesthub.test',
    password: 'Farmer@Harvest26',
    name: 'Hani Afzal',
    phone: '+923001112221',
    market: 'latifabad',
    businessName: 'Afzal Green Orchards',
    description: 'Family orchard and fresh farm enterprise owned by Hani Afzal. Sindhri mangoes, organic vegetables, pure village dairy, farm-milled grains, and culinary herbs, harvested fresh daily.',
    verified: true,
    role: 'farmer',
  },
  customer: {
    key: 'hani',
    email: 'hani.afzal@harvesthub.test',
    password: 'Customer@Harvest26',
    name: 'Hani Afzal',
    phone: '+923211234567',
    address: 'House 45, Street 12, Gulshan-e-Iqbal, Hyderabad',
    role: 'customer',
  },
};

// Deprecated test accounts to purge from Firebase Auth
const oldEmailsToDelete = [
  'ali.raza@harvesthub.test',
  'sana.malik@harvesthub.test',
  'imran.shaikh@harvesthub.test',
  'ayesha.khan@harvesthub.test',
  'bilal.ahmed@harvesthub.test',
  'hamza.qureshi@harvesthub.test',
  'sara.memon@harvesthub.test',
  'usman.siddiqui@harvesthub.test',
  'fatima.baloch@harvesthub.test',
  'rida.farmer@harvesthub.test',
  'rida.rahima@harvesthub.test',
  'ummema.farmer@harvesthub.test',
  'ummema.hayee@harvesthub.test',
];

// --- 2. Categories ---
const categories = [
  { id: 'fruits', name: 'Fruits', description: 'Seasonal fruit picked fresh from local orchards.' },
  { id: 'vegetables', name: 'Vegetables', description: 'Fresh vegetables harvested daily.' },
  { id: 'organic', name: 'Organic Products', description: 'Grown without chemical fertilizers or synthetic sprays.' },
  { id: 'dairy', name: 'Dairy', description: 'Fresh buffalo milk, yogurt, desi butter, and pure ghee.' },
  { id: 'pulses', name: 'Pulses', description: 'Lentils, chickpeas, and beans, cleaned and sorted by hand.' },
  { id: 'herbs-spices', name: 'Herbs and Spices', description: 'Fresh culinary herbs and sun-dried ground spices.' },
  { id: 'grains', name: 'Grains', description: 'Stone-ground whole wheat, aged basmati, and whole grains.' },
];

// --- 3. Farmers Markets ---
const markets = [
  {
    id: 'latifabad',
    marketName: 'Latifabad Farmers Market',
    address: 'Unit 8, Latifabad, Hyderabad, Sindh',
    lat: 25.402,
    lng: 68.329,
    operatingHours: 'Sat-Sun 8:00 AM - 2:00 PM',
  },
  {
    id: 'qasimabad',
    marketName: 'Qasimabad Fresh Bazaar',
    address: 'Main Road, Qasimabad, Hyderabad, Sindh',
    lat: 25.4247,
    lng: 68.315,
    operatingHours: 'Daily 7:00 AM - 12:00 PM',
  },
  {
    id: 'saddar',
    marketName: 'Saddar Organic Corner',
    address: 'Saddar Bazaar, Hyderabad, Sindh',
    lat: 25.396,
    lng: 68.3578,
    operatingHours: 'Fri-Sun 9:00 AM - 5:00 PM',
  },
];

// --- 4. Products Catalog (All linked to Afzal Green Orchards) ---
const products = [
  // Fruits
  { key: 'mango', category: 'fruits', name: 'Sindhri Mango', description: 'Sweet, fibre-free Sindhri mangoes from Hyderabad orchards.', price: 320, unit: 'kg', stock: 60 },
  { key: 'guava', category: 'fruits', name: 'Guava', description: 'Firm white guavas, sweet and crunchy.', price: 140, unit: 'kg', stock: 40 },
  { key: 'orange', category: 'fruits', name: 'Kinnow Orange', description: 'Juicy kinnow oranges with thin peel.', price: 180, unit: 'dozen', stock: 25 },
  { key: 'banana', category: 'fruits', name: 'Banana', description: 'Sweet Sindh bananas, sold by the dozen.', price: 150, unit: 'dozen', stock: 35 },
  { key: 'pomegranate', category: 'fruits', name: 'Pomegranate', description: 'Sweet Kandhari pomegranates with deep red seeds.', price: 380, unit: 'kg', stock: 25 },

  // Vegetables
  { key: 'tomato', category: 'vegetables', name: 'Sindhri Tamatar', description: 'Ripe red juicy tomatoes fresh from our field.', price: 90, unit: 'kg', stock: 75 },
  { key: 'potato', category: 'vegetables', name: 'Potato', description: 'Fresh farm potatoes, perfect for curries and baking.', price: 70, unit: 'kg', stock: 120 },
  { key: 'onion', category: 'vegetables', name: 'Onion', description: 'Red onions, naturally cured and sorted.', price: 90, unit: 'kg', stock: 100 },
  { key: 'spinach', category: 'vegetables', name: 'Spinach', description: 'Tender palak leaves, washed and bundled fresh.', price: 60, unit: 'piece', stock: 40 },
  { key: 'okra', category: 'vegetables', name: 'Okra', description: 'Small, tender fresh bhindi harvested at sunrise.', price: 160, unit: 'kg', stock: 30 },

  // Dairy
  { key: 'milk', category: 'dairy', name: 'Buffalo Milk', description: 'Fresh pure buffalo milk from farm cattle, unadulterated.', price: 190, unit: 'litre', stock: 45 },
  { key: 'ghee', category: 'dairy', name: 'Desi Ghee', description: 'Slow-cooked traditional golden ghee from grass-fed cream.', price: 2200, unit: 'kg', stock: 15 },
  { key: 'yogurt', category: 'dairy', name: 'Set Yogurt', description: 'Thick creamy dahi set naturally every morning.', price: 220, unit: 'kg', stock: 25 },

  // Pulses
  { key: 'masoor', category: 'pulses', name: 'Masoor Dal', description: 'Cleaned red split lentils, stone-free.', price: 260, unit: 'kg', stock: 45 },
  { key: 'chana', category: 'pulses', name: 'Chana Dal', description: 'Sun-dried split yellow gram, sorted and cleaned.', price: 240, unit: 'kg', stock: 30 },
  { key: 'moong', category: 'pulses', name: 'Moong Dal', description: 'Split yellow moong dal, sorted by hand.', price: 280, unit: 'kg', stock: 50 },
  { key: 'mash', category: 'pulses', name: 'Mash Dal', description: 'Washed urad dal for dal makhani and dahi baray.', price: 360, unit: 'kg', stock: 35 },

  // Grains
  { key: 'wheat', category: 'grains', name: 'Whole Wheat', description: 'High-protein grain from current season harvest.', price: 110, unit: 'kg', stock: 200 },
  { key: 'rice', category: 'grains', name: 'Basmati Rice', description: 'Aged long-grain aromatic basmati rice.', price: 340, unit: 'kg', stock: 80 },
  { key: 'sella', category: 'grains', name: 'Sella Rice', description: 'Parboiled long-grain rice ideal for biryani and pulao.', price: 300, unit: 'kg', stock: 90 },
  { key: 'bajra', category: 'grains', name: 'Millet (Bajra)', description: 'Whole pearl millet for healthy rotis and porridge.', price: 150, unit: 'kg', stock: 60 },

  // Organic
  { key: 'carrot', category: 'organic', name: 'Organic Carrot', description: 'Naturally grown organic red carrots, sweet and juicy.', price: 130, unit: 'kg', stock: 45 },
  { key: 'honey', category: 'organic', name: 'Organic Honey', description: 'Raw pure Sidr honey harvested near organic flowering fields.', price: 1400, unit: 'kg', stock: 20 },
  { key: 'brownrice', category: 'organic', name: 'Organic Brown Rice', description: 'Unpolished nutrient-rich brown rice, chemical-free.', price: 420, unit: 'kg', stock: 40 },
  { key: 'gur', category: 'organic', name: 'Organic Jaggery (Gur)', description: 'Traditional unrefined cane sugar, zero additives or sulfur.', price: 280, unit: 'kg', stock: 35 },

  // Herbs & Spices
  { key: 'mint', category: 'herbs-spices', name: 'Fresh Mint', description: 'Fresh pudina bunches, cut fresh each morning.', price: 40, unit: 'piece', stock: 50 },
  { key: 'coriander', category: 'herbs-spices', name: 'Fresh Coriander', description: 'Vibrant green fragrant dhania bunches.', price: 30, unit: 'piece', stock: 60 },
  { key: 'turmeric', category: 'herbs-spices', name: 'Turmeric Powder', description: 'Pure ground haldi from sun-dried whole turmeric roots.', price: 700, unit: 'kg', stock: 20 },
];

// --- 5. Promo Codes ---
const promoCodes = [
  { code: 'FRESH20', type: 'percent', value: 20, minOrder: 200, maxDiscount: 50, active: true, daysValid: 60 },
  { code: 'FARM100', type: 'flat', value: 100, minOrder: 1000, maxDiscount: 100, active: true, daysValid: 30 },
  { code: 'HARVEST25', type: 'percent', value: 25, minOrder: 500, maxDiscount: 200, active: true, daysValid: 45 },
  { code: 'WELCOME50', type: 'flat', value: 50, minOrder: 300, maxDiscount: 50, active: true, daysValid: 60 },
];

// Validation patterns
const emailPattern = /^[a-z0-9]+([._-][a-z0-9]+)*@[a-z0-9]+([.-][a-z0-9]+)*\.[a-z]{2,}$/;
const units = ['kg', 'litre', 'dozen', 'piece'];

function validateData() {
  const accountList = [accounts.admin, accounts.farmer, accounts.customer];
  accountList.forEach((acc) => {
    if (!emailPattern.test(acc.email)) throw new Error(`Invalid email: ${acc.email}`);
    if (acc.password.length < 8) throw new Error(`Password too short: ${acc.email}`);
  });

  products.forEach((p) => {
    if (!units.includes(p.unit)) throw new Error(`Invalid unit: ${p.unit} on ${p.key}`);
    if (p.price <= 0 || p.stock < 0) throw new Error(`Invalid price/stock on ${p.key}`);
  });

  console.log(`Validation PASSED: 3 solo accounts, ${categories.length} categories, ${markets.length} markets, ${products.length} products, ${promoCodes.length} promo codes.`);
}

async function existingImages(db, collection) {
  try {
    const snap = await db.collection(collection).select('imageUrl').get();
    const found = {};
    snap.docs.forEach((doc) => {
      const url = doc.get('imageUrl');
      if (url) found[doc.id] = url;
    });
    return found;
  } catch (_) {
    return {};
  }
}

async function deleteCollection(db, collectionName) {
  const colRef = db.collection(collectionName);
  const snap = await colRef.get();
  if (snap.empty) return;
  console.log(`Purging ${snap.size} docs from ${collectionName}...`);
  const batchSize = 400;
  let batch = db.batch();
  let count = 0;
  for (const doc of snap.docs) {
    batch.delete(doc.ref);
    count++;
    if (count % batchSize === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  if (count % batchSize !== 0) {
    await batch.commit();
  }
}

async function main() {
  console.log('=== HarvestHub Solo Seed (Hani Afzal) ===');
  validateData();

  if (dryRun) {
    console.log('[DRY-RUN] Schema verified successfully. No changes were written to Firebase.');
    return;
  }

  const admin = require('firebase-admin');
  const keyPath = path.resolve(process.env.SERVICE_ACCOUNT_PATH || path.join(__dirname, '..', 'serviceAccountKey.json'));

  if (!fs.existsSync(keyPath)) {
    throw new Error(`Service account key not found at ${keyPath}. Save it from Firebase Console > Project settings > Service accounts.`);
  }

  admin.initializeApp({
    credential: admin.credential.cert(require(keyPath)),
  });

  const db = admin.firestore();
  const auth = admin.auth();
  const { Timestamp, GeoPoint } = admin.firestore;
  const ts = (date) => Timestamp.fromDate(date);
  const now = ts(new Date());

  // --- Step 1: Clean old test accounts from Auth ---
  console.log('Cleaning deprecated test accounts from Firebase Auth...');
  for (const email of oldEmailsToDelete) {
    try {
      const u = await auth.getUserByEmail(email);
      await auth.deleteUser(u.uid);
      console.log(`  Removed old test user: ${email}`);
    } catch (e) {
      if (e.code !== 'auth/user-not-found') {
        console.warn(`  Warning on ${email}:`, e.message);
      }
    }
  }

  // --- Step 2: Preserve Cloudinary image links ---
  const catImages = await existingImages(db, 'categories');
  const prodImages = await existingImages(db, 'products');
  const farmerImages = await existingImages(db, 'farmers');
  console.log(`Preserved existing images: ${Object.keys(catImages).length} categories, ${Object.keys(prodImages).length} products.`);

  // --- Step 3: Purge old Firestore collections ---
  const collectionsToPurge = [
    'orders',
    'notifications',
    'wishlists',
    'followed_farmers',
    'pickup_slots',
    'products',
    'farmers',
    'users',
    'promo_codes',
  ];
  for (const col of collectionsToPurge) {
    await deleteCollection(db, col);
  }

  // --- Step 4: Create or update Hani Afzal Auth accounts ---
  console.log('Configuring Firebase Auth accounts for Hani Afzal...');
  const uids = {};
  const activeAccounts = [accounts.admin, accounts.farmer, accounts.customer];

  for (const acc of activeAccounts) {
    let user;
    try {
      user = await auth.getUserByEmail(acc.email);
      await auth.updateUser(user.uid, {
        password: acc.password,
        displayName: acc.name,
        emailVerified: true,
        disabled: false,
      });
      console.log(`  Updated user: ${acc.email} (${user.uid})`);
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        user = await auth.createUser({
          email: acc.email,
          password: acc.password,
          displayName: acc.name,
          emailVerified: true,
        });
        console.log(`  Created user: ${acc.email} (${user.uid})`);
      } else {
        throw e;
      }
    }
    uids[acc.key] = user.uid;
  }

  // Personal Google Account mapping (if exists)
  let personalUid = null;
  try {
    const personal = await auth.getUserByEmail('haniafzal96@gmail.com');
    personalUid = personal.uid;
    console.log(`  Mapped Google account: haniafzal96@gmail.com (${personalUid})`);
  } catch (_) {}

  // --- Step 5: Write Firestore collections ---
  console.log('Writing Firestore documents...');
  const writer = db.bulkWriter();
  const set = (collection, id, doc) => writer.set(db.collection(collection).doc(id), doc);

  // Categories
  categories.forEach((c) => {
    set('categories', c.id, {
      name: c.name,
      description: c.description,
      imageUrl: catImages[c.id] || null,
      isActive: true,
    });
  });

  // Markets
  markets.forEach((m) => {
    set('farmers_markets', m.id, {
      marketName: m.marketName,
      address: m.address,
      gpsCoordinates: new GeoPoint(m.lat, m.lng),
      operatingHours: m.operatingHours,
      activeStatus: true,
    });
  });

  // Users (Admin, Farmer, Customer)
  activeAccounts.forEach((a) => {
    set('users', uids[a.key], {
      name: a.name,
      email: a.email,
      phone: a.phone,
      address: a.address || '',
      role: a.role,
      isActive: true,
      fcmToken: null,
      createdAt: now,
    });
  });

  if (personalUid) {
    set('users', personalUid, {
      name: 'Hani Afzal',
      email: 'haniafzal96@gmail.com',
      phone: '+923211234567',
      address: 'House 45, Street 12, Gulshan-e-Iqbal, Hyderabad',
      role: 'customer',
      isActive: true,
      fcmToken: null,
      createdAt: now,
    });
  }

  // Farmer profile (Afzal Green Orchards)
  const sampleFarmerImg = Object.values(farmerImages)[0] || null;
  set('farmers', uids.afzal_farm, {
    userId: uids.afzal_farm,
    marketId: accounts.farmer.market,
    businessName: accounts.farmer.businessName,
    description: accounts.farmer.description,
    rating: 5.0,
    ratingSum: 50,
    ratingCount: 10,
    imageUrl: sampleFarmerImg,
    isVerified: true,
    createdAt: now,
  });

  // Products (All linked to Hani Afzal / afzal_farm)
  products.forEach((p) => {
    set('products', `p_${p.key}`, {
      farmerId: uids.afzal_farm,
      categoryId: p.category,
      itemName: p.name,
      itemNameLower: p.name.toLowerCase(),
      description: p.description,
      pricePerUnit: p.price,
      unit: p.unit,
      stockQty: p.stock,
      imageUrl: prodImages[`p_${p.key}`] || null,
      isAvailable: p.stock > 0,
      createdAt: now,
      updatedAt: now,
    });
  });

  // Pickup Slots for Afzal Green Orchards (Next 5 days)
  for (let day = 0; day <= 4; day++) {
    for (let slotIdx = 0; slotIdx < 2; slotIdx++) {
      const d = new Date();
      d.setDate(d.getDate() + day);
      d.setHours(slotIdx === 0 ? 10 : 16, 0, 0, 0);

      const slotId = `slot_afzal_farm_d${day}_s${slotIdx}`;
      set('pickup_slots', slotId, {
        farmerId: uids.afzal_farm,
        slotTime: ts(d),
        capacity: 10,
        booked: day === 0 ? 2 : 0,
        isActive: true,
      });
    }
  }

  // Orders (Between Customer Hani Afzal and Farmer Hani Afzal)
  const sampleOrders = [
    {
      id: 'order_101',
      items: [
        { productId: 'p_tomato', itemName: 'Sindhri Tamatar', qty: 5, pricePerUnit: 90, subtotal: 450 },
        { productId: 'p_banana', itemName: 'Banana', qty: 2, pricePerUnit: 150, subtotal: 300 },
      ],
      total: 750,
      status: 'Confirmed',
      minutesAgo: 15,
      rating: null,
    },
    {
      id: 'order_102',
      items: [
        { productId: 'p_mango', itemName: 'Sindhri Mango', qty: 4, pricePerUnit: 320, subtotal: 1280 },
      ],
      total: 1280,
      status: 'Completed',
      minutesAgo: 1440,
      rating: 5,
    },
    {
      id: 'order_103',
      items: [
        { productId: 'p_milk', itemName: 'Buffalo Milk', qty: 3, pricePerUnit: 190, subtotal: 570 },
        { productId: 'p_ghee', itemName: 'Desi Ghee', qty: 1, pricePerUnit: 2200, subtotal: 2200 },
      ],
      total: 2770,
      status: 'Completed',
      minutesAgo: 2880,
      rating: 5,
    },
    {
      id: 'order_104',
      items: [
        { productId: 'p_spinach', itemName: 'Spinach', qty: 3, pricePerUnit: 60, subtotal: 180 },
        { productId: 'p_okra', itemName: 'Okra', qty: 2, pricePerUnit: 160, subtotal: 320 },
      ],
      total: 500,
      status: 'ReadyForPickup',
      minutesAgo: 60,
      rating: null,
    },
  ];

  sampleOrders.forEach((so) => {
    const createdDate = new Date(Date.now() - so.minutesAgo * 60 * 1000);
    const pickupDate = new Date(Date.now() + 24 * 60 * 60 * 1000);

    set('orders', so.id, {
      customerId: uids.hani,
      customerName: 'Hani Afzal',
      farmerId: uids.afzal_farm,
      items: so.items,
      totalPrice: so.total,
      promoCode: null,
      discount: 0,
      status: so.status,
      pickupSlotId: 'slot_afzal_farm_d1_s0',
      pickupSlotTime: ts(pickupDate),
      deliveryAddr: accounts.customer.address,
      customerRating: so.rating,
      createdAt: ts(createdDate),
      updatedAt: ts(createdDate),
    });
  });

  if (personalUid) {
    const pDate = new Date(Date.now() - 20 * 60 * 1000);
    set('orders', 'order_personal_1', {
      customerId: personalUid,
      customerName: 'Hani Afzal',
      farmerId: uids.afzal_farm,
      items: [
        { productId: 'p_mango', itemName: 'Sindhri Mango', qty: 3, pricePerUnit: 320, subtotal: 960 },
        { productId: 'p_tomato', itemName: 'Sindhri Tamatar', qty: 2, pricePerUnit: 90, subtotal: 180 },
      ],
      totalPrice: 1140,
      promoCode: 'FRESH20',
      discount: 50,
      status: 'Confirmed',
      pickupSlotId: 'slot_afzal_farm_d1_s0',
      pickupSlotTime: ts(new Date(Date.now() + 24 * 60 * 60 * 1000)),
      deliveryAddr: 'House 45, Street 12, Gulshan-e-Iqbal, Hyderabad',
      customerRating: null,
      createdAt: ts(pDate),
      updatedAt: ts(pDate),
    });
  }

  // Followed Farmers & Wishlist
  set('followed_farmers', `${uids.hani}_${uids.afzal_farm}`, {
    customerId: uids.hani,
    farmerId: uids.afzal_farm,
    followedAt: now,
  });

  const wishlistProducts = ['mango', 'tomato', 'milk', 'honey', 'ghee'];
  wishlistProducts.forEach((key) => {
    set('wishlists', `${uids.hani}_p_${key}`, {
      customerId: uids.hani,
      productId: `p_${key}`,
      addedAt: now,
    });
  });

  if (personalUid) {
    set('followed_farmers', `${personalUid}_${uids.afzal_farm}`, {
      customerId: personalUid,
      farmerId: uids.afzal_farm,
      followedAt: now,
    });
    set('wishlists', `${personalUid}_p_mango`, {
      customerId: personalUid,
      productId: 'p_mango',
      addedAt: now,
    });
  }

  // Promo Codes
  promoCodes.forEach((p) => {
    set('promo_codes', p.code, {
      code: p.code,
      type: p.type,
      value: p.value,
      minOrder: p.minOrder,
      maxDiscount: p.maxDiscount,
      active: p.active,
      expiresAt: ts(new Date(Date.now() + p.daysValid * 24 * 60 * 60 * 1000)),
      createdAt: now,
    });
  });

  // Notifications (Customer & Farmer Hani Afzal)
  const notificationsList = [
    {
      id: 'notif_customer_1',
      userId: uids.hani,
      type: 'order_status',
      title: 'Order Confirmed',
      message: 'Your order #101 has been confirmed by Afzal Green Orchards.',
      relatedId: 'order_101',
      minutesAgo: 5,
      isRead: false,
    },
    {
      id: 'notif_customer_2',
      userId: uids.hani,
      type: 'order_status',
      title: 'Ready for Pickup',
      message: 'Your fresh farm order is packed and ready for pickup at Latifabad Farmers Market.',
      relatedId: 'order_101',
      minutesAgo: 18,
      isRead: false,
    },
    {
      id: 'notif_customer_3',
      userId: uids.hani,
      type: 'restock_alert',
      title: 'Fresh Harvest Restocked',
      message: 'Sindhri Tamatar and Desi Palak have just been restocked by Afzal Green Orchards!',
      relatedId: 'p_tomato',
      minutesAgo: 45,
      isRead: false,
    },
    {
      id: 'notif_customer_4',
      userId: uids.hani,
      type: 'promo_alert',
      title: 'Welcome to HarvestHub!',
      message: 'Welcome Hani Afzal! Use promo code FRESH20 to enjoy 20% off your fresh harvest basket today.',
      relatedId: null,
      minutesAgo: 120,
      isRead: true,
    },
    {
      id: 'notif_farmer_1',
      userId: uids.afzal_farm,
      type: 'new_order',
      title: 'New Order Received',
      message: 'You have a new farm order from Hani Afzal (5 kg Sindhri Tamatar, 2 dozen Banana).',
      relatedId: 'order_101',
      minutesAgo: 6,
      isRead: false,
    },
    {
      id: 'notif_farmer_2',
      userId: uids.afzal_farm,
      type: 'daily_summary',
      title: 'Harvest Schedule',
      message: 'Morning Harvest Schedule: 4 pickup orders scheduled for today at Latifabad Farmers Market.',
      relatedId: null,
      minutesAgo: 180,
      isRead: true,
    },
  ];

  notificationsList.forEach((n) => {
    const notifTime = new Date(Date.now() - n.minutesAgo * 60 * 1000);
    set('notifications', n.id, {
      userId: n.userId,
      type: n.type,
      title: n.title,
      message: n.message,
      relatedId: n.relatedId,
      isRead: n.isRead,
      createdAt: ts(notifTime),
    });
  });

  await writer.close();
  console.log('✅ Seed completed successfully! Seeded accounts for Hani Afzal (Admin, Farmer, Customer).');
}

main().catch((error) => {
  console.error('Seed Error:', error.message);
  process.exit(1);
});
