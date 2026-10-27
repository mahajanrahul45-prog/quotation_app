// Read-only live configuration checks. Never logs tokens, passwords or API keys.
const {createRequire} = require('node:module');
const {join} = require('node:path');
const {readFileSync} = require('node:fs');
const cliRequire = createRequire(join(process.env.FIREBASE_TOOLS_ROOT || join(process.env.APPDATA,'npm','node_modules'),'firebase-tools','package.json'));
const auth = cliRequire('./lib/auth.js');
async function main() {
  const account = auth.getProjectDefaultAccount(process.cwd());
  const token = await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform']);
  async function get(url, authorized = true, method = 'GET', body) {
    const response = await fetch(url,{method,headers:{...(authorized ? {Authorization:`Bearer ${token.access_token}`} : {}),'Content-Type':'application/json'},body:body ? JSON.stringify(body) : undefined});
    return {status:response.status,data:await response.json()};
  }
  const project = 'elevatorquotationapp';
  for (const id of [project,'812581723084']) {
    const r = await get(`https://identitytoolkit.googleapis.com/admin/v2/projects/${id}/config`);
    console.log(JSON.stringify({check:'Auth config',id,status:r.status,email:r.data.signIn?.email,google:r.data.signIn?.google,error:r.data.error?.message}));
  }
  const google = await get(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/defaultSupportedIdpConfigs/google.com`);
  console.log(JSON.stringify({check:'Google provider',status:google.status,enabled:google.data.enabled,error:google.data.error?.message}));
  const master = await get(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:lookup`,true,'POST',{email:['mahajanrahul45@yahoo.com']});
  const uid = master.data.users?.[0]?.localId;
  if (uid) {
    const profile = await get(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/accounts/${uid}`);
    const f = profile.data.fields;
    console.log(JSON.stringify({check:'Master profile',status:profile.status,role:f?.role?.stringValue,enabled:f?.enabled?.booleanValue,allPermissionsGranted:Object.values(f?.permissions?.mapValue?.fields || {}).length === 6 && Object.values(f.permissions.mapValue.fields).every(v => v.booleanValue === true)}));
  } else console.log(JSON.stringify({check:'Master Auth account',status:master.status,exists:false}));
  const options = readFileSync('lib/firebase_options.dart','utf8');
  for (const platform of ['android','web','windows']) {
    const block = options.split(`static const FirebaseOptions ${platform} = FirebaseOptions(`)[1].split(');')[0];
    const key = block.match(/apiKey: '([^']+)'/)[1];
    const appId = block.match(/appId: '([^']+)'/)[1];
    const owner = await get(`https://apikeys.googleapis.com/v2/keys:lookupKey?keyString=${encodeURIComponent(key)}`);
    const appType = platform === 'android' ? 'androidApps' : 'webApps';
    const live = await get(`https://firebase.googleapis.com/v1beta1/projects/${project}/${appType}/${appId}/config`);
    let matches;
    if (platform === 'android' && live.data.configFileContents) {
      const cloud = JSON.parse(Buffer.from(live.data.configFileContents,'base64').toString());
      const local = JSON.parse(readFileSync('android/app/google-services.json','utf8'));
      matches = cloud.project_info.project_id === local.project_info.project_id && cloud.client.some(c => c.api_key?.some(k => k.current_key === key) && c.client_info.mobilesdk_app_id === appId);
    } else matches = live.data.apiKey === key && live.data.projectId === project && live.data.appId === appId;
    const probe = await get(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(key)}`,false,'POST',{email:'firebase-config-probe@example.invalid',password:'not-a-real-password',returnSecureToken:true});
    console.log(JSON.stringify({platform,keyOwnerStatus:owner.status,keyOwner:owner.data.parent,liveConfigStatus:live.status,configMatches:matches,authProbeStatus:probe.status,authProbeResult:probe.data.error?.message}));
  }
}
main().catch(e => {console.error(e.message);process.exitCode=1;});
