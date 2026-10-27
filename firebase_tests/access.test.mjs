import { readFileSync } from 'node:fs';
import { before, after, test } from 'node:test';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, collection, getDocs, query, where, writeBatch, deleteDoc } from 'firebase/firestore';

let env;
const permissions = { quotations: true, customers: false, products: false, maintenance: false, service: false, settings: false };
const all = Object.fromEntries(Object.keys(permissions).map(k => [k, true]));
const profile = (email, masterUid, role = 'user', grants = permissions) => ({email, masterUid, role, enabled: true, permissions: grants});
const metadata = {revision: 1, chunks: 1, deleted: false, updatedAt: new Date(), updatedBy: 'alice'};
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-quotation-access', firestore: {host: '127.0.0.1', port: 8080, rules: readFileSync('../firestore.rules', 'utf8')}});
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    for (const [uid, data] of Object.entries({master: profile('master@example.com','master','master',all), alice: profile('alice@example.com','master'), bob: profile('bob@example.com','master'), outsider: profile('other@example.com','other-master'), 'other-master': profile('other-master@example.com','other-master','master',all), disabled: {...profile('disabled@example.com','master'), enabled: false}})) await setDoc(doc(db,'accounts',uid),data);
    for (const uid of ['master','alice','bob','outsider','disabled']) {
      await setDoc(doc(db,`accounts/${uid}/data/quotations/values/quotations`),metadata);
      await setDoc(doc(db,`accounts/${uid}/data/quotations/values/quotations/chunks/1_0`),{payload:'test'});
    }
    await setDoc(doc(db,'accounts/alice/data/settings/values/company_name'),metadata);
    await setDoc(doc(db,'invitations/new@example.com'), {email:'new@example.com',masterUid:'master',enabled:true,permissions,updatedAt:new Date()});
  });
});
after(async () => { await env?.cleanup(); });
function db(uid, email = `${uid}@example.com`, verified = true) { return env.authenticatedContext(uid, {email,email_verified:verified}).firestore(); }
test('No anonymous access', async () => {
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'accounts/alice/data/quotations/values/quotations')));
});
test('Users read only own granted data, including chunks', async () => {
  await assertSucceeds(getDoc(doc(db('alice'),'accounts/alice/data/quotations/values/quotations')));
  await assertSucceeds(getDocs(collection(db('alice'),'accounts/alice/data/quotations/values')));
  for (const uid of ['master','bob']) {
    await assertFails(getDoc(doc(db('alice'),`accounts/${uid}/data/quotations/values/quotations`)));
    await assertFails(getDoc(doc(db('alice'),`accounts/${uid}/data/quotations/values/quotations/chunks/1_0`)));
  }
  await assertFails(getDoc(doc(db('alice'),'accounts/alice/data/settings/values/company_name')));
});
test('Master reads own and managed users, never unrelated workspaces', async () => {
  for (const uid of ['master','alice','bob']) await assertSucceeds(getDoc(doc(db('master'),`accounts/${uid}/data/quotations/values/quotations`)));
  await assertFails(getDoc(doc(db('master'),'accounts/outsider/data/quotations/values/quotations')));
  await assertSucceeds(getDocs(query(collection(db('master'),'accounts'),where('masterUid','==','master'),where('role','==','user'))));
  await assertFails(getDocs(collection(db('alice'),'accounts')));
});
test('Users cannot promote themselves, grant permissions or write master data', async () => {
  for (const data of [{role:'master'},{masterUid:'alice'},{permissions:all},{enabled:false}]) await assertFails(updateDoc(doc(db('alice'),'accounts/alice'),data));
  await assertFails(setDoc(doc(db('alice'),'accounts/master/data/quotations/values/new'),metadata));
  await assertFails(setDoc(doc(db('alice'),'accounts/alice/data/quotations/values/company_name'),metadata));
});
test('Master can revoke user access but cannot mutate user identity', async () => {
  await assertSucceeds(updateDoc(doc(db('master'),'accounts/bob'),{permissions:{...permissions,quotations:false}}));
  await assertFails(getDoc(doc(db('bob'),'accounts/bob/data/quotations/values/quotations')));
  await assertFails(updateDoc(doc(db('master'),'accounts/bob'),{role:'master'}));
  await assertFails(updateDoc(doc(db('master'),'accounts/bob'),{masterUid:'other-master'}));
});
test('Disabled users lose all business-data access', async () => {
  await assertFails(getDoc(doc(db('disabled'),'accounts/disabled/data/quotations/values/quotations')));
});
test('Only invited, verified email owners can create exact user profile', async () => {
  const data = {...profile('new@example.com','master'),createdAt:new Date()};
  await assertFails(setDoc(doc(db('new-user','new@example.com',false),'accounts/new-user'),data));
  await assertFails(setDoc(doc(db('new-user','new@example.com'),'accounts/new-user'),{...data,role:'master'}));
  await assertFails(setDoc(doc(db('new-user','new@example.com'),'accounts/new-user'),{...data,permissions:all}));
  await assertSucceeds(setDoc(doc(db('new-user','new@example.com'),'accounts/new-user'),data));
  await assertFails(setDoc(doc(db('uninvited'),'accounts/uninvited'),{...data,email:'uninvited@example.com'}));
});
test('Invitations are managed only by their owning master', async () => {
  await assertFails(setDoc(doc(db('alice'),'invitations/attack@example.com'),{email:'attack@example.com',masterUid:'master',permissions:all,enabled:true,updatedAt:new Date()}));
  await assertFails(updateDoc(doc(db('other-master'),'invitations/new@example.com'),{permissions:all}));
  await assertSucceeds(getDoc(doc(db('new-user','new@example.com'),'invitations/new@example.com')));
  await assertFails(getDoc(doc(db('alice'),'invitations/new@example.com')));
});
test('Atomic payload writes and revision checks work', async () => {
  const store = db('alice');
  const batch = writeBatch(store);
  batch.set(doc(store,'accounts/alice/data/quotations/values/quotations'),{...metadata,revision:2});
  batch.set(doc(store,'accounts/alice/data/quotations/values/quotations/chunks/2_0'),{payload:'new'});
  batch.delete(doc(store,'accounts/alice/data/quotations/values/quotations/chunks/1_0'));
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(doc(store,'accounts/alice/data/quotations/values/quotations'),{...metadata,revision:2}));
  await assertFails(deleteDoc(doc(store,'accounts/alice/data/quotations/values/quotations')));
});
test('Legacy global collections are denied', async () => {
  await assertFails(getDoc(doc(db('master'),'customers/legacy')));
});

test('Service-only building lists stay private to their owner and managed master', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    const store = ctx.firestore();
    await setDoc(doc(store,'accounts/technician'),profile('tech@example.com','master','user',{...permissions,quotations:false,service:true}));
  });
  const path = 'accounts/technician/data/service/values/service_buildings';
  const technician = db('technician');
  const batch = writeBatch(technician);
  batch.set(doc(technician,path),{...metadata,updatedBy:'technician'});
  batch.set(doc(technician,`${path}/chunks/1_0`),{payload:'building-list'});
  await assertSucceeds(batch.commit());
  await assertSucceeds(getDoc(doc(db('technician'),path)));
  await assertSucceeds(getDoc(doc(db('master'),path)));
  await assertFails(getDoc(doc(db('alice'),path)));
  await assertFails(getDoc(doc(db('other-master'),path)));
  await assertFails(getDoc(doc(db('technician'),'accounts/master/data/customers/values/customers')));
  await assertFails(setDoc(doc(db('technician'),'accounts/technician/data/customers/values/customers'),{...metadata,updatedBy:'technician'}));
});

test('Common directory is readable across document types without report access', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    const admin = ctx.firestore();
    for (const [feature, key] of [['customers','customers'],['service','service_buildings'],['service','service_reports']]) {
      await setDoc(doc(admin,`accounts/alice/data/${feature}/values/${key}`),metadata);
      await setDoc(doc(admin,`accounts/alice/data/${feature}/values/${key}/chunks/1_0`),{payload:'directory'});
    }
  });
  for (const [feature, key] of [['customers','customers'],['service','service_buildings']]) {
    await assertSucceeds(getDoc(doc(db('alice'),`accounts/alice/data/${feature}/values/${key}`)));
    await assertSucceeds(getDoc(doc(db('alice'),`accounts/alice/data/${feature}/values/${key}/chunks/1_0`)));
    await assertFails(getDoc(doc(db('outsider'),`accounts/alice/data/${feature}/values/${key}`)));
    await assertFails(getDoc(doc(db('alice'),`accounts/master/data/${feature}/values/${key}`)));
  }
  await assertFails(getDoc(doc(db('alice'),'accounts/alice/data/service/values/service_reports')));
  await assertFails(setDoc(doc(db('alice'),'accounts/alice/data/customers/values/customers'),{...metadata,revision:2}));
});

test('Only master can approve and only selected invited users can read shared customers', async () => {
  const data = {customer: {customerName:'Approved Tower',_ownerUid:'master'}, approvedEmails:['alice@example.com'],updatedBy:'master',updatedAt:new Date()};
  const path = 'accounts/master/customerShares/approved-tower';
  await assertSucceeds(setDoc(doc(db('master'),path),data));
  await assertSucceeds(getDoc(doc(db('alice'),path)));
  await assertSucceeds(getDocs(query(collection(db('alice'),'accounts/master/customerShares'),where('approvedEmails','array-contains','alice@example.com'))));
  await assertFails(getDocs(collection(db('alice'),'accounts/master/customerShares')));
  await assertFails(getDoc(doc(db('bob'),path)));
  await assertFails(getDoc(doc(db('outsider','alice@example.com'),path)));
  await assertFails(getDoc(doc(db('disabled','alice@example.com'),path)));
  await assertFails(setDoc(doc(db('alice'),path),{...data,approvedEmails:['bob@example.com']}));
  await assertFails(setDoc(doc(db('other-master'),path),data));
  await assertSucceeds(updateDoc(doc(db('master'),path),{approvedEmails:[]}));
  await assertFails(getDoc(doc(db('alice'),path)));
});

test('Only owning master can update managed customer payload and revision', async () => {
  const path = 'accounts/alice/data/customers/values/customers';
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(), path), {...metadata, revision: 1});
    await setDoc(doc(ctx.firestore(), `${path}/chunks/1_0`), {payload: 'old'});
  });
  for (const actor of ['bob', 'other-master']) {
    await assertFails(setDoc(doc(db(actor), path), {...metadata, revision: 2, updatedBy: actor}));
    await assertFails(setDoc(doc(db(actor), `${path}/chunks/2_0`), {payload: 'changed'}));
    await assertFails(deleteDoc(doc(db(actor), `${path}/chunks/1_0`)));
  }
  const masterDb = db('master');
  const batch = writeBatch(masterDb);
  batch.set(doc(masterDb, path), {...metadata, revision: 2, updatedBy: 'master'});
  batch.set(doc(masterDb, `${path}/chunks/2_0`), {payload: 'changed'});
  batch.delete(doc(masterDb, `${path}/chunks/1_0`));
  await assertSucceeds(batch.commit());
});
