const {createRequire}=require('node:module');
const {join}=require('node:path');
const {readFileSync}=require('node:fs');
const req=createRequire(join(process.env.APPDATA,'npm','node_modules','firebase-tools','package.json'));
const auth=req('./lib/auth.js');
(async()=>{
 const account=auth.getProjectDefaultAccount(process.cwd());
 const token=await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform']);
 async function call(url,body){const r=await fetch(url,{method:body?'POST':'GET',headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});const d=await r.json();if(!r.ok)throw Error(d.error?.message || String(r.status));return d;}
 const project='elevatorquotationapp';
 const release=await call(`https://firebaserules.googleapis.com/v1/projects/${project}/releases/cloud.firestore`);
 const rules=await call(`https://firebaserules.googleapis.com/v1/${release.rulesetName}`);
 console.log(JSON.stringify({liveRulesMatchWorkspace:rules.source.files.some(f=>f.content.replace(/\r\n/g,'\n').trim()===readFileSync('firestore.rules','utf8').replace(/\r\n/g,'\n').trim())}));
 const root=`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
 const accounts=await call(`${root}:runQuery`,{structuredQuery:{from:[{collectionId:'accounts'}],where:{fieldFilter:{field:{fieldPath:'role'},op:'EQUAL',value:{stringValue:'user'}}}}});
 for(const [i,row] of accounts.filter(r=>r.document).entries()){
  const doc=row.document;const fields=doc.fields;
  const url=`https://firestore.googleapis.com/v1/${doc.name}/data/service/values/service_body_template`;
  let revision='not saved';try{revision=(await call(url)).fields?.revision?.integerValue;}catch(e){if(!e.message.includes('not found'))throw e;}
  console.log(JSON.stringify({userNumber:i+1,enabled:fields.enabled?.booleanValue,serviceGranted:fields.permissions?.mapValue?.fields?.service?.booleanValue,bodySettingsRevision:revision}));
 }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
