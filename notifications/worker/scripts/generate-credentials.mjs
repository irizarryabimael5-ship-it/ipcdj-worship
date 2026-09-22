import crypto from 'node:crypto';

const ecdh=crypto.createECDH('prime256v1');
ecdh.generateKeys();

const credentials={
  VAPID_PUBLIC_KEY:ecdh.getPublicKey(undefined,'uncompressed').toString('base64url'),
  VAPID_PRIVATE_KEY:ecdh.getPrivateKey().toString('base64url'),
  ADMIN_TOKEN:crypto.randomBytes(32).toString('base64url')
};

if(Buffer.from(credentials.VAPID_PUBLIC_KEY,'base64url').length!==65){
  throw new Error('Unexpected VAPID public key length');
}
if(Buffer.from(credentials.VAPID_PRIVATE_KEY,'base64url').length!==32){
  throw new Error('Unexpected VAPID private key length');
}

process.stdout.write(JSON.stringify(credentials,null,2)+'\n');
