// Run with the Google account that owns the Firebase project signed into the
// Firebase CLI. No service-account key or password is saved in this repository.
const {createRequire} = require('node:module');
const {join} = require('node:path');
const {randomUUID} = require('node:crypto');
const {readFileSync} = require('node:fs');
const project = process.argv[2];
const email = process.argv[3]?.toLowerCase();
if (!project || !email?.includes('@')) {
  console.error('Usage: node tools/setup_firebase.cjs <project-id> <master-email>');
  process.exit(1);
}
const configured = JSON.parse(readFileSync('firebase.json','utf8')).flutter.platforms.android.default.projectId;
if (project !== configured) throw new Error(`Refusing to configure ${project}: app is configured for ${configured}.`);
const globalModules = process.env.FIREBASE_TOOLS_ROOT || join(process.env.APPDATA || '', 'npm', 'node_modules');
const cliRequire = createRequire(join(globalModules,'firebase-tools','package.json'));
const auth = cliRequire('./lib/auth.js');
async function main() {
  const account = auth.getProjectDefaultAccount(process.cwd());
  if (!account?.tokens?.refresh_token) throw new Error('Authorize the project owner with firebase login:add, then select it with firebase login:use.');
  const token = await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
  async function request(url, method = 'GET', body) {
    const response = await fetch(url, {method, headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'}, body:body ? JSON.stringify(body) : undefined});
    const data = await response.json();
    if (!response.ok) throw new Error(`${method} failed (${response.status}): ${data.error?.message || 'Unknown error'}`);
    return data;
  }
  // Fail before any mutation if this account cannot access the intended project.
  await request(`https://firebase.googleapis.com/v1beta1/projects/${project}`);
  await request(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config?updateMask=signIn.email.enabled,signIn.email.passwordRequired`, 'PATCH', {signIn:{email:{enabled:true,passwordRequired:true}}});
  const base = `https://identitytoolkit.googleapis.com/v1/projects/${project}`;
  const lookup = await request(`${base}/accounts:lookup`,'POST',{email:[email]});
  let uid = lookup.users?.[0]?.localId;
  if (!uid) {
    uid = randomUUID();
    const result = await request(`${base}/accounts:batchCreate`,'POST',{users:[{localId:uid,email,emailVerified:false}],allowOverwrite:false,sanityCheck:true});
    if (result.error?.length) throw new Error(`Master account could not be created: ${result.error[0].message}`);
    console.log(`Created Firebase Auth account for ${email}. Use Forgot password in the app to set your password privately.`);
  }
  const url = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/accounts/${uid}`;
  let existing;
  try { existing = await request(url); }
  catch (error) { if (!error.message.includes('(404)')) throw error; }
  if (existing) {
    if (existing.fields?.role?.stringValue !== 'master' || existing.fields?.email?.stringValue !== email) throw new Error('An existing account profile has a different role. Review it in Firebase before assigning master access.');
    console.log('Existing master profile retained.');
    return;
  }
  const grants = Object.fromEntries(['quotations','customers','products','maintenance','service','settings'].map(k => [k,{booleanValue:true}]));
  await request(`${url}?currentDocument.exists=false`, 'PATCH', {fields:{email:{stringValue:email},role:{stringValue:'master'},masterUid:{stringValue:uid},enabled:{booleanValue:true},permissions:{mapValue:{fields:grants}},createdAt:{timestampValue:new Date().toISOString()}}});
  console.log(`Master profile configured for ${email} in ${project}. No password was printed or stored.`);
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
