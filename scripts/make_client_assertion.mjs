#!/usr/bin/env node
// Usage:
// node make_client_assertion.mjs --key ./client-keys/private.pem --kid KID --client-id api-client --aud https://.../token
import fs from 'fs'
import path from 'path'
import { createPrivateKey } from 'crypto'
import * as jose from './node_modules/jose/index.js'

function arg(name, def) {
  const idx = process.argv.indexOf(name)
  if (idx === -1) return def
  return process.argv[idx+1]
}

const keyPath = arg('--key')
const kid = arg('--kid', 'api-client-demo')
const clientId = arg('--client-id', 'api-client')
const aud = arg('--aud')
if (!keyPath || !aud) {
  console.error('usage: make_client_assertion.mjs --key <private.pem> --kid <kid> --client-id <id> --aud <token-url>')
  process.exit(1)
}

const privatePem = fs.readFileSync(keyPath, 'utf8')
const pk = createPrivateKey({ key: privatePem })

const now = Math.floor(Date.now()/1000)
const payload = {
  iss: clientId,
  sub: clientId,
  aud,
  iat: now,
  exp: now + 60, // 60s
  jti: crypto.randomUUID()
}

const jwt = await new jose.SignJWT(payload)
  .setProtectedHeader({ alg: 'RS256', kid })
  .sign(pk)

process.stdout.write(jwt)