const fs = require('fs')
const path = require('path')
const self = GetCurrentResourceName()
const dir = path.join(GetResourcePath(self), 'cache')
const safe = (name) => typeof name === 'string' && /^[\w-]+\.\w+$/.test(name)

exports('spool', (name, b64) => {
  if (GetInvokingResource() !== self || !safe(name) || typeof b64 !== 'string') return null
  fs.mkdirSync(dir, { recursive: true })
  fs.writeFileSync(path.join(dir, name), Buffer.from(b64, 'base64'))
  return `cache/${name}`
})

exports('unspool', (name) => {
  if (GetInvokingResource() === self && safe(name)) fs.rm(path.join(dir, name), { force: true }, () => {})
})
