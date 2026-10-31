import { readFileSync } from 'fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, deleteDoc, runTransaction, increment, serverTimestamp, GeoPoint } from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'demo-harvesthub',
  firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
});

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const now = new Date();
    await setDoc(doc(db, 'users/cust'), { name: 'Ayesha', email: 'a@x.pk', phone: '+923001234567', address: 'House 1, Street 2', role: 'customer', isActive: true, createdAt: now });
    await setDoc(doc(db, 'users/farm'), { name: 'Raza', email: 'r@x.pk', phone: '+923001234568', address: '', role: 'farmer', isActive: true, createdAt: now });
    await setDoc(doc(db, 'users/boss'), { name: 'Admin', email: 'admin@x.pk', phone: '+923001234560', address: '', role: 'admin', isActive: true, createdAt: now });
    await setDoc(doc(db, 'users/farm2'), { name: 'Malik', email: 'm@x.pk', phone: '+923001234569', address: '', role: 'farmer', isActive: true, createdAt: now });
    await setDoc(doc(db, 'products/p1'), { farmerId: 'farm', categoryId: 'fruits', itemName: 'Mango', itemNameLower: 'mango', description: '', pricePerUnit: 100, unit: 'kg', stockQty: 10, imageUrl: null, isAvailable: true, createdAt: now, updatedAt: now });
    await setDoc(doc(db, 'cart_items/cust_p1'), { customerId: 'cust', productId: 'p1', quantity: 2, addedAt: now });
    await setDoc(doc(db, 'pickup_slots/s1'), { farmerId: 'farm', slotTime: new Date(Date.now() + 86400000), capacity: 5, booked: 0, isActive: true });
    await setDoc(doc(db, 'pickup_slots/s2'), { farmerId: 'farm2', slotTime: new Date(Date.now() + 86400000), capacity: 5, booked: 0, isActive: true });
    await setDoc(doc(db, 'orders/done'), { customerId: 'cust', farmerId: 'farm', items: [], totalPrice: 200, promoCode: null, discount: 0, status: 'Completed', pickupSlotId: null, pickupSlotTime: null, deliveryAddr: 'House 1, Street 2', customerRating: null, createdAt: now, updatedAt: now });
    await setDoc(doc(db, 'products/p2'), { farmerId: 'farm2', categoryId: 'dairy', itemName: 'Ghee', itemNameLower: 'ghee', description: '', pricePerUnit: 2200, unit: 'kg', stockQty: 10, imageUrl: null, isAvailable: true, createdAt: now, updatedAt: now });
    await setDoc(doc(db, 'orders/gone'), { customerId: 'cust', farmerId: 'farm', items: [{ productId: 'p1', itemName: 'Mango', qty: 2, pricePerUnit: 100, subtotal: 200 }], totalPrice: 200, promoCode: null, discount: 0, status: 'Cancelled', pickupSlotId: null, pickupSlotTime: null, deliveryAddr: 'House 1, Street 2', customerRating: null, createdAt: now, updatedAt: now });
    await setDoc(doc(db, 'orders/live'), { customerId: 'cust', farmerId: 'farm', items: [{ productId: 'p1', itemName: 'Mango', qty: 2, pricePerUnit: 100, subtotal: 200 }], totalPrice: 200, promoCode: null, discount: 0, status: 'Pending', pickupSlotId: null, pickupSlotTime: null, deliveryAddr: 'House 1, Street 2', customerRating: null, createdAt: now, updatedAt: now });
    await setDoc(doc(db, 'farmers/farm'), { userId: 'farm', marketId: null, businessName: 'Raza Orchards', description: '', rating: 4, ratingSum: 8, ratingCount: 2, imageUrl: null, isVerified: true, createdAt: now });
    await setDoc(doc(db, 'orders/rated'), { customerId: 'cust', farmerId: 'farm', items: [], totalPrice: 200, promoCode: null, discount: 0, status: 'Completed', pickupSlotId: null, pickupSlotTime: null, deliveryAddr: 'House 1, Street 2', customerRating: 4, createdAt: now, updatedAt: now });
    await setDoc(doc(db, 'notifications/n1'), { userId: 'cust', type: 'order_status', message: 'hi', relatedId: 'done', isRead: false, createdAt: now });
    await setDoc(doc(db, 'notifications/n2'), { userId: 'farm', type: 'new_order', message: 'hi', relatedId: 'done', isRead: false, createdAt: now });
  });
}

const customer = () => env.authenticatedContext('cust', { email: 'a@x.pk', email_verified: true }).firestore();
const farmer = () => env.authenticatedContext('farm', { email: 'r@x.pk', email_verified: true }).firestore();

function order(slotId) {
  return { customerId: 'cust', customerName: 'Ayesha', farmerId: 'farm', items: [{ productId: 'p1', itemName: 'Mango', qty: 2, pricePerUnit: 100, subtotal: 200 }],
    totalPrice: 200, promoCode: null, discount: 0, status: 'Pending', pickupSlotId: slotId, pickupSlotTime: new Date(),
    deliveryAddr: 'House 1, Street 2', customerRating: null, createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
}

const results = [];
async function check(name, expectOk, fn) {
  await seed();
  try {
    await (expectOk ? assertSucceeds(fn()) : assertFails(fn()));
    results.push(`PASS  ${name}`);
  } catch (e) {
    results.push(`FAIL  ${name}: ${e.message.split('\n')[0]}`);
  }
}

await check('checkout transaction (stock -2, cart delete, slot +1, order)', true, () => {
  const db = customer();
  return runTransaction(db, async (tx) => {
    await tx.get(doc(db, 'products/p1'));
    await tx.get(doc(db, 'pickup_slots/s1'));
    tx.update(doc(db, 'products/p1'), { stockQty: increment(-2) });
    tx.delete(doc(db, 'cart_items/cust_p1'));
    tx.update(doc(db, 'pickup_slots/s1'), { booked: increment(1) });
    tx.set(doc(db, 'orders/o1'), order('s1'));
  });
});
await check('customer sets stock to 0 directly', false, () => updateDoc(doc(customer(), 'products/p1'), { stockQty: 0 }));
await check('customer lowers stock without cart delete', false, () => updateDoc(doc(customer(), 'products/p1'), { stockQty: increment(-2) }));
await check('customer adds stock without any order (+2)', false, () => updateDoc(doc(customer(), 'products/p1'), { stockQty: increment(2) }));

function orderWith(items, totalPrice) {
  return { ...order(null), items, totalPrice };
}
const mango = (qty, price = 100, name = 'Mango') => ({ productId: 'p1', itemName: name, qty, pricePerUnit: price, subtotal: qty * price });

await check('order with a lower price than the product', false, () =>
  setDoc(doc(customer(), 'orders/cheap'), orderWith([mango(2, 1)], 2)));
await check('order total lower than its items', false, () =>
  setDoc(doc(customer(), 'orders/short'), orderWith([mango(2)], 50)));
await check('order with a wrong item name', false, () =>
  setDoc(doc(customer(), 'orders/rename'), orderWith([mango(2, 100, 'Desi Ghee')], 200)));
await check("order item from another farmer's product", false, () =>
  setDoc(doc(customer(), 'orders/mixed'), orderWith([{ productId: 'p2', itemName: 'Ghee', qty: 1, pricePerUnit: 2200, subtotal: 2200 }], 2200)));
await check('order with 8 items', false, () =>
  setDoc(doc(customer(), 'orders/big'), orderWith(Array.from({ length: 8 }, () => mango(1)), 800)));

const cancelWithRestock = (orderId, add) => () => {
  const db = customer();
  return runTransaction(db, async (tx) => {
    await tx.get(doc(db, `orders/${orderId}`));
    await tx.get(doc(db, 'products/p1'));
    tx.update(doc(db, 'products/p1'), { stockQty: increment(add), lastRestockOrderId: orderId });
    tx.update(doc(db, `orders/${orderId}`), { status: 'Cancelled', updatedAt: serverTimestamp() });
  });
};
await check('customer cancels order and stock comes back', true, cancelWithRestock('live', 2));
await check('farmer cancels order and stock comes back', true, () => {
  const db = farmer();
  return runTransaction(db, async (tx) => {
    await tx.get(doc(db, 'orders/live'));
    await tx.get(doc(db, 'products/p1'));
    tx.update(doc(db, 'products/p1'), { stockQty: increment(2), lastRestockOrderId: 'live' });
    tx.update(doc(db, 'orders/live'), { status: 'Cancelled', updatedAt: serverTimestamp() });
  });
});
await check('order sent with decimal numbers like the Flutter app (100.0)', true, async () => {
  const b64 = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const token = `${b64({ alg: 'none', typ: 'JWT' })}.${b64({ sub: 'cust', user_id: 'cust', email: 'a@x.pk', email_verified: true, iat: 0, exp: 9999999999, aud: 'demo-harvesthub', iss: 'https://securetoken.google.com/demo-harvesthub' })}.`;
  const num = (value) => ({ doubleValue: value });
  const response = await fetch('http://127.0.0.1:8080/v1/projects/demo-harvesthub/databases/(default)/documents:commit', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({
      writes: [{
        update: {
          name: 'projects/demo-harvesthub/databases/(default)/documents/orders/flutter',
          fields: {
            customerId: { stringValue: 'cust' }, customerName: { stringValue: 'Ayesha' }, farmerId: { stringValue: 'farm' },
            items: { arrayValue: { values: [{ mapValue: { fields: {
              productId: { stringValue: 'p1' }, itemName: { stringValue: 'Mango' }, qty: { integerValue: '2' },
              pricePerUnit: num(100.0), subtotal: num(200.0) } } }] } },
            totalPrice: num(200.0), promoCode: { nullValue: null }, discount: num(0.0), status: { stringValue: 'Pending' },
            pickupSlotId: { nullValue: null }, pickupSlotTime: { nullValue: null },
            deliveryAddr: { stringValue: 'House 1, Street 2' }, customerRating: { nullValue: null },
          },
        },
        updateTransforms: [
          { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
          { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
        ],
      }],
    }),
  });
  if (!response.ok) throw new Error(`HTTP ${response.status}: ${(await response.text()).slice(0, 200)}`);
});
await check('stock back more than the order had', false, cancelWithRestock('live', 5));
await check('stock back for an order that was already cancelled', false, () =>
  updateDoc(doc(customer(), 'products/p1'), { stockQty: increment(2), lastRestockOrderId: 'gone' }));
await check('stock back without cancelling the order', false, () =>
  updateDoc(doc(customer(), 'products/p1'), { stockQty: increment(2), lastRestockOrderId: 'live' }));
await check('customer fills slot (+3)', false, () => updateDoc(doc(customer(), 'pickup_slots/s1'), { booked: 3 }));
await check('customer frees own booking (-1 after +1)', true, async () => {
  await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'pickup_slots/s1'), { booked: 1 }));
  return updateDoc(doc(customer(), 'pickup_slots/s1'), { booked: increment(-1) });
});
await check('order using another farmer\'s slot', false, () => setDoc(doc(customer(), 'orders/o2'), order('s2')));
await check('order without a slot', true, () => setDoc(doc(customer(), 'orders/o3'), order(null)));
await check('order with someone else\'s name', false, () => setDoc(doc(customer(), 'orders/o4'), { ...order(null), customerName: 'Bilal' }));

await check('customer deletes own notification', true, () => deleteDoc(doc(customer(), 'notifications/n1')));
await check("customer deletes someone else's notification", false, () => deleteDoc(doc(customer(), 'notifications/n2')));
await check('customer clears address on completed order', true, () => updateDoc(doc(customer(), 'orders/done'), { deliveryAddr: 'Account deleted' }));
await check('customer clears address and name on completed order', true, () => updateDoc(doc(customer(), 'orders/done'), { deliveryAddr: 'Account deleted', customerName: 'Deleted customer' }));
await check('customer renames themselves on an old order', false, () => updateDoc(doc(customer(), 'orders/done'), { deliveryAddr: 'Account deleted', customerName: 'Someone' }));
await check('customer clears address on active order', false, () => updateDoc(doc(customer(), 'orders/live'), { deliveryAddr: 'Account deleted' }));
await check('customer writes other text into address', false, () => updateDoc(doc(customer(), 'orders/done'), { deliveryAddr: 'Somewhere else' }));
await check('customer deletes own user doc', true, () => deleteDoc(doc(customer(), 'users/cust')));
await check('farmer deletes own user doc', false, () => deleteDoc(doc(farmer(), 'users/farm')));
await check('customer deletes another user doc', false, () => deleteDoc(doc(customer(), 'users/farm')));

await check('customer rates a completed order (order + farmer together)', true, () => {
  const db = customer();
  return runTransaction(db, async (tx) => {
    await tx.get(doc(db, 'orders/done'));
    await tx.get(doc(db, 'farmers/farm'));
    tx.update(doc(db, 'orders/done'), { customerRating: 5 });
    tx.update(doc(db, 'farmers/farm'), { ratingSum: 13, ratingCount: 3, rating: 13 / 3, lastRatedOrderId: 'done' });
  });
});
await check('customer changes farmer rating without an order', false, () =>
  updateDoc(doc(customer(), 'farmers/farm'), { ratingSum: 9, ratingCount: 3, rating: 3 }));
await check('customer reuses an order that was already rated', false, () =>
  updateDoc(doc(customer(), 'farmers/farm'), { ratingSum: 12, ratingCount: 3, rating: 4, lastRatedOrderId: 'rated' }));
await check('stars on farmer differ from stars on order', false, () => {
  const db = customer();
  return runTransaction(db, async (tx) => {
    await tx.get(doc(db, 'orders/done'));
    tx.update(doc(db, 'orders/done'), { customerRating: 5 });
    tx.update(doc(db, 'farmers/farm'), { ratingSum: 9, ratingCount: 3, rating: 3, lastRatedOrderId: 'done' });
  });
});
await check('farmer edits own rating', false, () =>
  updateDoc(doc(farmer(), 'farmers/farm'), { rating: 5 }));

const adminDb = () => env.authenticatedContext('boss', { email: 'admin@x.pk', email_verified: true }).firestore();
const market = (extra = {}) => ({
  marketName: 'Hirabad Sabzi Mandi', address: 'Main Road, Hirabad, Hyderabad',
  gpsCoordinates: new GeoPoint(25.39, 68.37), operatingHours: 'Daily 7 AM - 1 PM', activeStatus: true, ...extra,
});
await check('admin adds a valid market', true, () => setDoc(doc(adminDb(), 'farmers_markets/m1'), market()));
await check('admin adds a market with a one-letter name', false, () => setDoc(doc(adminDb(), 'farmers_markets/m2'), market({ marketName: 'H' })));
await check('admin adds a market with an unknown field', false, () => setDoc(doc(adminDb(), 'farmers_markets/m3'), market({ owner: 'x' })));
await check('customer adds a market', false, () => setDoc(doc(customer(), 'farmers_markets/m4'), market()));

const report = (extra = {}) => ({
  farmerId: 'farm', period: 'daily', startDate: new Date(), endDate: new Date(),
  totalOrders: 2, revenue: 400, topProducts: [{ productId: 'p1', itemName: 'Mango', qty: 4 }],
  generatedAt: serverTimestamp(), ...extra,
});
await check('farmer saves a valid report', true, () => setDoc(doc(farmer(), 'reports/r1'), report()));
await check('farmer saves a report with an unknown field', false, () => setDoc(doc(farmer(), 'reports/r2'), report({ bonus: 1 })));
await check('farmer saves a report with negative revenue', false, () => setDoc(doc(farmer(), 'reports/r3'), report({ revenue: -5 })));

console.log(results.join('\n'));
await env.cleanup();
