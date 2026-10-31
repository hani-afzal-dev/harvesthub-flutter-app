const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const keyPath = path.resolve(__dirname, '..', 'serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(require(keyPath)),
});``

const db = admin.firestore();
const auth = admin.auth();
const { Timestamp, GeoPoint } = admin.firestore;
const ts = (date) => Timestamp.fromDate(date);
const now = ts(new Date());

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
  'hhh@gmail.com',
  'h@gmail.com',
  'hhhju@gmail.com',
];

const newAccounts = {
  admin: {
    key: 'admin',
    email: 'admin@harvesthub.test',
    password: 'Admin@Harvest26',
    name: 'Hani Afzal (Admin)',
    phone: '+923331234567',
    address: 'HarvestHub Headquarters, Latifabad, Hyderabad',
    role: 'admin',
  },
  farmers: [
    {
      key: 'afzal_farm',
      email: 'hani.farmer@harvesthub.test',
      password: 'Farmer@Harvest26',
      name: 'Hani Afzal',
      phone: '+923001112221',
      market: 'latifabad',
      businessName: 'Afzal Green Orchards',
      description: 'Family orchard owned by Hani Afzal. Sindhri mangoes, organic tomatoes, and seasonal greens, picked fresh daily.',
      verified: true,
      role: 'farmer',
      imageHint: 'orchard',
    },
    {
      key: 'rahima_dairy',
      email: 'rida.farmer@harvesthub.test',
      password: 'Farmer@Harvest26',
      name: 'Rida Rahima',
      phone: '+923001112222',
      market: 'qasimabad',
      businessName: 'Rahima Dairy & Pulses',
      description: 'Pure village buffalo milk, desi butter, desi ghee, and hand-cleaned organic lentils and pulses.',
      verified: true,
      role: 'farmer',
      imageHint: 'dairy',
    },
    {
      key: 'hayee_harvest',
      email: 'ummema.farmer@harvesthub.test',
      password: 'Farmer@Harvest26',
      name: 'Ummema Abdul Hayee',
      phone: '+923001112223',
      market: 'saddar',
      businessName: 'Hayee Organic Harvest',
      description: '100% certified pesticide-free organic vegetables, spinach, bell peppers, and fresh culinary herbs.',
      verified: true,
      role: 'farmer',
      imageHint: 'organic',
    },
  ],
  customers: [
    {
      key: 'hani',
      email: 'hani.afzal@harvesthub.test',
      password: 'Customer@Harvest26',
      name: 'Hani Afzal',
      phone: '+923211234567',
      address: 'House 45, Street 12, Gulshan-e-Iqbal, Hyderabad',
      role: 'customer',
    },
    {
      key: 'rida',
      email: 'rida.rahima@harvesthub.test',
      password: 'Customer@Harvest26',
      name: 'Rida Rahima',
      phone: '+923211234568',
      address: 'Flat 8, Block 6, Qasimabad, Hyderabad',
      role: 'customer',
    },
    {
      key: 'ummema',
      email: 'ummema.hayee@harvesthub.test',
      password: 'Customer@Harvest26',
      name: 'Ummema Abdul Hayee',
      phone: '+923211234569',
      address: 'House 19, Sector 11-A, Latifabad, Hyderabad',
      role: 'customer',
    },
  ],
};

const products = [
  { key: 'mango', farmer: 'afzal_farm', category: 'fruits', name: 'Sindhri Mango', description: 'Sweet, fibre-free Sindhri mangoes. Sold by the kg.', price: 320, unit: 'kg', stock: 60 },
  { key: 'tomato', farmer: 'afzal_farm', category: 'vegetables', name: 'Sindhri Tamatar', description: 'Ripe red juicy tomatoes fresh from our field.', price: 90, unit: 'kg', stock: 75 },
  { key: 'guava', farmer: 'afzal_farm', category: 'fruits', name: 'Guava', description: 'Firm white guavas, sweet and crunchy.', price: 140, unit: 'kg', stock: 40 },
  { key: 'orange', farmer: 'afzal_farm', category: 'fruits', name: 'Kinnow Orange', description: 'Juicy kinnow with thin skin.', price: 180, unit: 'dozen', stock: 25 },
  { key: 'banana', farmer: 'afzal_farm', category: 'fruits', name: 'Banana', description: 'Sweet Sindh bananas, sold by the dozen.', price: 150, unit: 'dozen', stock: 35 },
  { key: 'potato', farmer: 'afzal_farm', category: 'vegetables', name: 'Potato', description: 'Fresh farm potatoes, good for curries and fries.', price: 70, unit: 'kg', stock: 120 },
  { key: 'onion', farmer: 'afzal_farm', category: 'vegetables', name: 'Onion', description: 'Red onions, dried and sorted.', price: 90, unit: 'kg', stock: 100 },
  { key: 'mint', farmer: 'afzal_farm', category: 'herbs-spices', name: 'Fresh Mint', description: 'Fresh pudina bunches, cut this morning.', price: 40, unit: 'piece', stock: 50 },
  { key: 'pomegranate', farmer: 'afzal_farm', category: 'fruits', name: 'Pomegranate', description: 'Sweet Kandhari pomegranates with deep red seeds.', price: 380, unit: 'kg', stock: 25 },

  { key: 'milk', farmer: 'rahima_dairy', category: 'dairy', name: 'Buffalo Milk', description: 'Fresh pure buffalo milk, not boiled or diluted.', price: 190, unit: 'litre', stock: 45 },
  { key: 'ghee', farmer: 'rahima_dairy', category: 'dairy', name: 'Desi Ghee', description: 'Slow-cooked traditional ghee from buffalo cream.', price: 2200, unit: 'kg', stock: 15 },
  { key: 'yogurt', farmer: 'rahima_dairy', category: 'dairy', name: 'Set Yogurt', description: 'Thick creamy yogurt set fresh every morning.', price: 220, unit: 'kg', stock: 25 },
  { key: 'masoor', farmer: 'rahima_dairy', category: 'pulses', name: 'Masoor Dal', description: 'Cleaned red lentils, stone-free.', price: 260, unit: 'kg', stock: 45 },
  { key: 'chana', farmer: 'rahima_dairy', category: 'pulses', name: 'Chana Dal', description: 'Split chickpeas, sun dried and cleaned.', price: 240, unit: 'kg', stock: 30 },
  { key: 'moong', farmer: 'rahima_dairy', category: 'pulses', name: 'Moong Dal', description: 'Split yellow moong, sorted by hand.', price: 280, unit: 'kg', stock: 50 },
  { key: 'mash', farmer: 'rahima_dairy', category: 'pulses', name: 'Mash Dal', description: 'White urad dal for daal makhani and haleem.', price: 360, unit: 'kg', stock: 35 },
  { key: 'wheat', farmer: 'rahima_dairy', category: 'grains', name: 'Whole Wheat', description: 'Stone-milling grade wheat from this season.', price: 110, unit: 'kg', stock: 200 },
  { key: 'rice', farmer: 'rahima_dairy', category: 'grains', name: 'Basmati Rice', description: 'Aged basmati, long fragrant grain.', price: 340, unit: 'kg', stock: 80 },
  { key: 'sella', farmer: 'rahima_dairy', category: 'grains', name: 'Sella Rice', description: 'Parboiled long grain rice for biryani.', price: 300, unit: 'kg', stock: 90 },

  { key: 'spinach', farmer: 'hayee_harvest', category: 'vegetables', name: 'Spinach', description: 'Tender palak, washed and bundled.', price: 60, unit: 'piece', stock: 40 },
  { key: 'okra', farmer: 'hayee_harvest', category: 'vegetables', name: 'Okra', description: 'Small, tender fresh bhindi.', price: 160, unit: 'kg', stock: 30 },
  { key: 'carrot', farmer: 'hayee_harvest', category: 'organic', name: 'Organic Carrot', description: 'Organic carrots, sweet and crunchy.', price: 130, unit: 'kg', stock: 45 },
  { key: 'turmeric', farmer: 'hayee_harvest', category: 'herbs-spices', name: 'Turmeric Powder', description: 'Ground from farm-dried turmeric roots.', price: 700, unit: 'kg', stock: 20 },
  { key: 'coriander', farmer: 'hayee_harvest', category: 'herbs-spices', name: 'Fresh Coriander', description: 'Green fragrant dhania bunches.', price: 30, unit: 'piece', stock: 60 },
  { key: 'honey', farmer: 'hayee_harvest', category: 'organic', name: 'Organic Honey', description: 'Raw sidr honey from hives next to our organic fields.', price: 1400, unit: 'kg', stock: 20 },
  { key: 'brownrice', farmer: 'hayee_harvest', category: 'organic', name: 'Organic Brown Rice', description: 'Unpolished brown rice grown without chemical sprays.', price: 420, unit: 'kg', stock: 40 },
  { key: 'gur', farmer: 'hayee_harvest', category: 'organic', name: 'Organic Jaggery (Gur)', description: 'Made from our own sugarcane, no added colour.', price: 280, unit: 'kg', stock: 35 },
  { key: 'bajra', farmer: 'hayee_harvest', category: 'grains', name: 'Millet (Bajra)', description: 'Whole pearl millet for rotis and khichdi.', price: 150, unit: 'kg', stock: 60 },
];

const categories = [
  { id: 'fruits', name: 'Fruits', description: 'Seasonal fruit picked from local orchards.' },
  { id: 'vegetables', name: 'Vegetables', description: 'Fresh vegetables harvested this week.' },
  { id: 'organic', name: 'Organic Products', description: 'Grown without chemical fertilizers or sprays.' },
  { id: 'dairy', name: 'Dairy', description: 'Milk, yogurt, butter and ghee from village dairies.' },
  { id: 'pulses', name: 'Pulses', description: 'Lentils and beans, cleaned and packed by farmers.' },
  { id: 'herbs-spices', name: 'Herbs and Spices', description: 'Fresh herbs and sun-dried spices.' },
  { id: 'grains', name: 'Grains', description: 'Wheat, rice and other whole grains.' },
];

const markets = [
  { id: 'latifabad', marketName: 'Latifabad Farmers Market', address: 'Unit 8, Latifabad, Hyderabad, Sindh', lat: 25.402, lng: 68.329, operatingHours: 'Sat-Sun 8:00 AM - 2:00 PM' },
  { id: 'qasimabad', marketName: 'Qasimabad Fresh Bazaar', address: 'Main Road, Qasimabad, Hyderabad, Sindh', lat: 25.4247, lng: 68.315, operatingHours: 'Daily 7:00 AM - 12:00 PM' },
  { id: 'saddar', marketName: 'Saddar Organic Corner', address: 'Saddar Bazaar, Hyderabad, Sindh', lat: 25.396, lng: 68.3578, operatingHours: 'Fri-Sun 9:00 AM - 5:00 PM' },
];

const promoCodes = [
  { code: 'FRESH20', type: 'percent', value: 20, minOrder: 200, maxDiscount: 50, active: true, daysValid: 60 },
  { code: 'FARM100', type: 'flat', value: 100, minOrder: 1000, maxDiscount: 100, active: true, daysValid: 30 },
  { code: 'CODEFORGE25', type: 'percent', value: 25, minOrder: 500, maxDiscount: 200, active: true, daysValid: 30 },
  { code: 'HACKATHON50', type: 'flat', value: 50, minOrder: 300, maxDiscount: 50, active: true, daysValid: 30 },
];

async function deleteCollection(collectionName) {
  const colRef = db.collection(collectionName);
  const snap = await colRef.get();
  if (snap.empty) return;
  console.log(`Deleting ${snap.size} docs from ${collectionName}...`);
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

async function existingImages(collection) {
  const snap = await db.collection(collection).select('imageUrl').get();
  const found = {};
  snap.docs.forEach((doc) => {
    const url = doc.get('imageUrl');
    if (url) found[doc.id] = url;
  });
  return found;
}

async function run() {
  console.log('=== Cleaning old test accounts from Firebase Auth ===');
  for (const email of oldEmailsToDelete) {
    try {
      const u = await auth.getUserByEmail(email);
      await auth.deleteUser(u.uid);
      console.log(`Deleted auth user: ${email} (${u.uid})`);
    } catch (e) {
      if (e.code !== 'auth/user-not-found') {
        console.warn(`Error deleting ${email}:`, e.message);
      }
    }
  }

  console.log('=== Preserving existing Cloudinary image links ===');
  const catImages = await existingImages('categories');
  const prodImages = await existingImages('products');
  const farmerImages = await existingImages('farmers');

  console.log(`Preserved ${Object.keys(catImages).length} category images, ${Object.keys(prodImages).length} product images`);

  console.log('=== Purging old Firestore collections ===');
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
    await deleteCollection(col);
  }

  console.log('=== Setting up Firebase Auth accounts ===');
  const uids = {};
  const allAccountsToCreate = [
    newAccounts.admin,
    ...newAccounts.farmers,
    ...newAccounts.customers,
  ];

  for (const acc of allAccountsToCreate) {
    let user;
    try {
      user = await auth.getUserByEmail(acc.email);
      await auth.updateUser(user.uid, {
        password: acc.password,
        displayName: acc.name,
        emailVerified: true,
        disabled: false,
      });
      console.log(`Updated user: ${acc.email} -> UID: ${user.uid}`);
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        user = await auth.createUser({
          email: acc.email,
          password: acc.password,
          displayName: acc.name,
          emailVerified: true,
        });
        console.log(`Created user: ${acc.email} -> UID: ${user.uid}`);
      } else {
        throw e;
      }
    }
    uids[acc.key] = user.uid;
  }

  // Also check if personal account haniafzal96@gmail.com exists in auth
  let personalUid = null;
  try {
    const personal = await auth.getUserByEmail('haniafzal96@gmail.com');
    personalUid = personal.uid;
    console.log(`Found personal Google user: haniafzal96@gmail.com -> UID: ${personalUid}`);
  } catch (_) {}

  let personalHaniKhanUid = null;
  try {
    const p = await auth.getUserByEmail('hanikhan1162009@gmail.com');
    personalHaniKhanUid = p.uid;
    console.log(`Found personal Google user: hanikhan1162009@gmail.com -> UID: ${personalHaniKhanUid}`);
  } catch (_) {}

  console.log('=== Writing fresh Firestore collections ===');
  const writer = db.bulkWriter();
  const set = (collection, id, doc) => writer.set(db.collection(collection).doc(id), doc);

  // 1. Categories
  categories.forEach((c) => {
    set('categories', c.id, {
      name: c.name,
      description: c.description,
      imageUrl: catImages[c.id] || null,
      isActive: true,
    });
  });

  // 2. Markets
  markets.forEach((m) => {
    set('farmers_markets', m.id, {
      marketName: m.marketName,
      address: m.address,
      gpsCoordinates: new GeoPoint(m.lat, m.lng),
      operatingHours: m.operatingHours,
      activeStatus: true,
    });
  });

  // 3. Users
  allAccountsToCreate.forEach((a) => {
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

  if (personalHaniKhanUid) {
    set('users', personalHaniKhanUid, {
      name: 'Hani Khan',
      email: 'hanikhan1162009@gmail.com',
      phone: '+923211234560',
      address: 'House 14, Latifabad, Hyderabad',
      role: 'customer',
      isActive: true,
      fcmToken: null,
      createdAt: now,
    });
  }

  // Sample farmer image pool from previous seed
  const sampleFarmerImageUrls = Object.values(farmerImages);
  const getFarmerImg = (index) => sampleFarmerImageUrls[index % sampleFarmerImageUrls.length] || null;

  // 4. Farmers
  newAccounts.farmers.forEach((f, idx) => {
    set('farmers', uids[f.key], {
      userId: uids[f.key],
      marketId: f.market,
      businessName: f.businessName,
      description: f.description,
      rating: 4.9,
      ratingSum: 49,
      ratingCount: 10,
      imageUrl: getFarmerImg(idx),
      isVerified: f.verified,
      createdAt: now,
    });
  });

  // 5. Products
  products.forEach((p) => {
    const farmerUid = uids[p.farmer];
    set('products', `p_${p.key}`, {
      farmerId: farmerUid,
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

  // 6. Pickup slots (for next 5 days)
  const slotIds = [];
  newAccounts.farmers.forEach((f) => {
    for (let day = 0; day <= 4; day++) {
      for (let slotIdx = 0; slotIdx < 2; slotIdx++) {
        const d = new Date();
        d.setDate(d.getDate() + day);
        d.setHours(slotIdx === 0 ? 10 : 16, 0, 0, 0);

        const slotId = `slot_${f.key}_d${day}_s${slotIdx}`;
        slotIds.push(slotId);
        set('pickup_slots', slotId, {
          farmerId: uids[f.key],
          slotTime: ts(d),
          capacity: 8,
          booked: day === 0 ? 2 : 0,
          isActive: true,
        });
      }
    }
  });

  // 7. Orders
  const sampleOrders = [
    {
      id: 'order_101',
      customerKey: 'hani',
      farmerKey: 'afzal_farm',
      items: [
        { productId: 'p_tomato', itemName: 'Sindhri Tamatar', qty: 5, pricePerUnit: 90, subtotal: 450 },
        { productId: 'p_banana', itemName: 'Banana', qty: 2, pricePerUnit: 150, subtotal: 300 },
      ],
      total: 750,
      status: 'Confirmed',
      minutesAgo: 15,
      slotOffsetHours: 24,
      rating: null,
    },
    {
      id: 'order_102',
      customerKey: 'rida',
      farmerKey: 'afzal_farm',
      items: [
        { productId: 'p_mango', itemName: 'Sindhri Mango', qty: 4, pricePerUnit: 320, subtotal: 1280 },
      ],
      total: 1280,
      status: 'Completed',
      minutesAgo: 1440, // 1 day
      slotOffsetHours: -20,
      rating: 5,
    },
    {
      id: 'order_103',
      customerKey: 'hani',
      farmerKey: 'rahima_dairy',
      items: [
        { productId: 'p_milk', itemName: 'Buffalo Milk', qty: 3, pricePerUnit: 190, subtotal: 570 },
        { productId: 'p_ghee', itemName: 'Desi Ghee', qty: 1, pricePerUnit: 2200, subtotal: 2200 },
      ],
      total: 2770,
      status: 'Completed',
      minutesAgo: 2880, // 2 days
      slotOffsetHours: -40,
      rating: 5,
    },
    {
      id: 'order_104',
      customerKey: 'ummema',
      farmerKey: 'hayee_harvest',
      items: [
        { productId: 'p_spinach', itemName: 'Spinach', qty: 3, pricePerUnit: 60, subtotal: 180 },
        { productId: 'p_okra', itemName: 'Okra', qty: 2, pricePerUnit: 160, subtotal: 320 },
      ],
      total: 500,
      status: 'ReadyForPickup',
      minutesAgo: 90,
      slotOffsetHours: 4,
      rating: null,
    },
  ];

  sampleOrders.forEach((so) => {
    const cust = newAccounts.customers.find((c) => c.key === so.customerKey);
    const createdDate = new Date(Date.now() - so.minutesAgo * 60 * 1000);
    const pickupDate = new Date(Date.now() + so.slotOffsetHours * 60 * 60 * 1000);

    set('orders', so.id, {
      customerId: uids[so.customerKey],
      customerName: cust.name,
      farmerId: uids[so.farmerKey],
      items: so.items,
      totalPrice: so.total,
      promoCode: null,
      discount: 0,
      status: so.status,
      pickupSlotId: `slot_${so.farmerKey}_d1_s0`,
      pickupSlotTime: ts(pickupDate),
      deliveryAddr: cust.address,
      customerRating: so.rating,
      createdAt: ts(createdDate),
      updatedAt: ts(createdDate),
    });
  });

  // Also clone order_101 for personalUid if present
  if (personalUid) {
    const personalOrderDate = new Date(Date.now() - 12 * 60 * 1000);
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
      createdAt: ts(personalOrderDate),
      updatedAt: ts(personalOrderDate),
    });
  }

  // 8. Follows & Wishlists
  newAccounts.customers.forEach((c) => {
    newAccounts.farmers.forEach((f) => {
      set('followed_farmers', `${uids[c.key]}_${uids[f.key]}`, {
        customerId: uids[c.key],
        farmerId: uids[f.key],
        followedAt: now,
      });
    });
    set('wishlists', `${uids[c.key]}_p_mango`, {
      customerId: uids[c.key],
      productId: 'p_mango',
      addedAt: now,
    });
    set('wishlists', `${uids[c.key]}_p_tomato`, {
      customerId: uids[c.key],
      productId: 'p_tomato',
      addedAt: now,
    });
    set('wishlists', `${uids[c.key]}_p_milk`, {
      customerId: uids[c.key],
      productId: 'p_milk',
      addedAt: now,
    });
  });

  if (personalUid) {
    newAccounts.farmers.forEach((f) => {
      set('followed_farmers', `${personalUid}_${uids[f.key]}`, {
        customerId: personalUid,
        farmerId: uids[f.key],
        followedAt: now,
      });
    });
    set('wishlists', `${personalUid}_p_mango`, {
      customerId: personalUid,
      productId: 'p_mango',
      addedAt: now,
    });
  }

  // 9. Promo codes
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

  // 10. Notifications (recent with minutes-ago timestamps)
  const notificationsList = [
    // Notifications for Customer Hani Afzal
    {
      id: 'notif_hani_1',
      userId: uids.hani,
      type: 'order_status',
      title: 'Order Confirmed',
      message: 'Your order #849201 has been confirmed by Afzal Green Orchards.',
      relatedId: 'order_101',
      minutesAgo: 5,
      isRead: false,
    },
    {
      id: 'notif_hani_2',
      userId: uids.hani,
      type: 'order_status',
      title: 'Ready for Pickup',
      message: 'Your fresh farm order is packed and ready for pickup at Latifabad Farmers Market.',
      relatedId: 'order_101',
      minutesAgo: 18,
      isRead: false,
    },
    {
      id: 'notif_hani_3',
      userId: uids.hani,
      type: 'restock_alert',
      title: 'Fresh Stock Available',
      message: 'Sindhri Tamatar and Desi Palak have just been restocked by Afzal Green Orchards!',
      relatedId: 'p_tomato',
      minutesAgo: 45,
      isRead: false,
    },
    {
      id: 'notif_hani_4',
      userId: uids.hani,
      type: 'promo_alert',
      title: 'Welcome to HarvestHub!',
      message: 'Welcome Hani Afzal! Use promo code FRESH20 to enjoy 20% off your fresh harvest basket today.',
      relatedId: null,
      minutesAgo: 120,
      isRead: true,
    },
    {
      id: 'notif_hani_5',
      userId: uids.hani,
      type: 'crop_doctor_update',
      title: 'Crop Doctor Advisory',
      message: 'Seasonal advisory: Check tomato and mango leaves for early blight and fungal spots.',
      relatedId: null,
      minutesAgo: 240,
      isRead: false,
    },

    // Notifications for Farmer Hani Afzal (Afzal Green Orchards)
    {
      id: 'notif_farmer_1',
      userId: uids.afzal_farm,
      type: 'new_order',
      title: 'New Order Received',
      message: 'You have a new order from Hani Afzal (5 kg Sindhri Tamatar, 2 dozen Banana).',
      relatedId: 'order_101',
      minutesAgo: 6,
      isRead: false,
    },
    {
      id: 'notif_farmer_2',
      userId: uids.afzal_farm,
      type: 'new_order',
      title: 'New Order Received',
      message: 'New farm order received from Rida Rahima (4 kg Sindhri Mango).',
      relatedId: 'order_102',
      minutesAgo: 35,
      isRead: false,
    },
    {
      id: 'notif_farmer_3',
      userId: uids.afzal_farm,
      type: 'daily_summary',
      title: 'Harvest Schedule',
      message: 'Morning Harvest Schedule: 6 pickup orders scheduled for today at Latifabad Farmers Market.',
      relatedId: null,
      minutesAgo: 180,
      isRead: true,
    },

    // Notifications for Rida Rahima
    {
      id: 'notif_rida_1',
      userId: uids.rida,
      type: 'order_status',
      title: 'Order Completed',
      message: 'Your order of Sindhri Mango was completed. Thank you for supporting local farmers!',
      relatedId: 'order_102',
      minutesAgo: 60,
      isRead: true,
    },

    // Notifications for Ummema Abdul Hayee
    {
      id: 'notif_ummema_1',
      userId: uids.ummema,
      type: 'order_status',
      title: 'Ready for Pickup',
      message: 'Your order #104 is ready for pickup at Saddar Organic Corner.',
      relatedId: 'order_104',
      minutesAgo: 15,
      isRead: false,
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

  // Duplicate notifications for personalUid if present
  if (personalUid) {
    const personalNotifs = [
      {
        id: 'notif_p_1',
        type: 'order_status',
        title: 'Order Confirmed',
        message: 'Your order #849201 has been confirmed by Afzal Green Orchards.',
        relatedId: 'order_personal_1',
        minutesAgo: 10,
        isRead: false,
      },
      {
        id: 'notif_p_2',
        type: 'restock_alert',
        title: 'Fresh Stock Available',
        message: 'Sindhri Tamatar and Desi Palak have just been restocked by Afzal Green Orchards!',
        relatedId: 'p_tomato',
        minutesAgo: 30,
        isRead: false,
      },
      {
        id: 'notif_p_3',
        type: 'promo_alert',
        title: 'Welcome to HarvestHub!',
        message: 'Welcome Hani Afzal! Use promo code FRESH20 to enjoy 20% off your fresh harvest basket today.',
        relatedId: null,
        minutesAgo: 90,
        isRead: true,
      },
    ];
    personalNotifs.forEach((n) => {
      set('notifications', n.id, {
        userId: personalUid,
        type: n.type,
        title: n.title,
        message: n.message,
        relatedId: n.relatedId,
        isRead: n.isRead,
        createdAt: ts(new Date(Date.now() - n.minutesAgo * 60 * 1000)),
      });
    });
  }

  await writer.close();
  console.log('=== Fresh Seed Completed Successfully! ===');
  console.log('All old test accounts removed, new Code Forge accounts created.');
}

run().catch((err) => {
  console.error('Fatal error during seed:', err);
  process.exit(1);
});
