/**
 * Google Earth Binary Patcher — runs in browser (SD Card Builder web app)
 * Patches libembeddedearth.so for MMI3G+ Google Earth restoration.
 * 
 * Two code patches (image validation bypass):
 *   PATCH 1 @ 0x343d20: mov #1,r0; rts; nop (force return TRUE)
 *   PATCH 2 @ 0x3470a0: rts; nop (skip function)
 * 
 * Usage:
 *   const result = patchLibEmbeddedEarth(arrayBuffer);
 *   // result.patched = patched ArrayBuffer
 *   // result.success = true/false
 *   // result.patches = [{offset, original, applied}]
 */

const GE_PATCHES = [
  {
    name: "Image Validation Bypass",
    offset: 0x343d20,
    original: [0x86, 0x2f, 0x1f, 0xc7, 0x96, 0x2f],
    patch:    [0x01, 0xe0, 0x0b, 0x00, 0x09, 0x00],
    desc: "Forces image validation to return TRUE (mov #1,r0; rts; nop)"
  },
  {
    name: "Post-Validation Skip", 
    offset: 0x3470a0,
    original: [0x86, 0x2f, 0x2d, 0xc7],
    patch:    [0x0b, 0x00, 0x09, 0x00],
    desc: "Skips DRM/metadata processing (rts; nop)"
  }
];

function patchLibEmbeddedEarth(buffer) {
  const data = new Uint8Array(buffer.slice(0));
  const results = [];
  let allOk = true;

  for (const p of GE_PATCHES) {
    // Verify original bytes
    const current = Array.from(data.slice(p.offset, p.offset + p.original.length));
    const isOriginal = current.every((b, i) => b === p.original[i]);
    const isPatched = current.every((b, i) => b === p.patch[i]);

    if (isPatched) {
      results.push({ ...p, status: "already_patched", current });
    } else if (isOriginal) {
      // Apply patch
      for (let i = 0; i < p.patch.length; i++) {
        data[p.offset + i] = p.patch[i];
      }
      results.push({ ...p, status: "applied", current });
    } else {
      results.push({ ...p, status: "mismatch", current });
      allOk = false;
    }
  }

  return {
    patched: data.buffer,
    success: allOk,
    patches: results,
    size: data.length
  };
}

/**
 * GEE Encryption — XOR with rotating 1016-byte key
 * From open-source google/earthenterprise (Apache 2.0)
 */
const GEE_DEFAULT_KEY = new Uint8Array([
  0x45,0xf4,0xbd,0x0b,0x79,0xe2,0x6a,0x45,0x22,0x05,0x92,0x2c,0x17,0xcd,0x06,0x71,
  0xf8,0x49,0x10,0x46,0x67,0x51,0x00,0x42,0x25,0xc6,0xe8,0x61,0x2c,0x66,0x29,0x08,
  // ... (full 1016 bytes embedded in build)
]);

/**
 * Custom dbRoot Builder
 * Takes the template dbRoot, replaces server URLs, re-encrypts
 */
function buildCustomDbRoot(templateBuffer, geoHost, authHost) {
  // Template is: 8-byte header + 1016-byte key + encrypted(KhPkt(etStruct))
  const template = new Uint8Array(templateBuffer);
  const header = template.slice(0, 8);
  const key = template.slice(8, 8 + 1016);
  const encrypted = template.slice(8 + 1016);

  // Decrypt
  const decrypted = geeCodec(encrypted, key);
  
  // Decompress KhPkt: magic(4) + size(4) + zlib(data)
  const magic = new DataView(decrypted.buffer).getUint32(0, true);
  if (magic !== 0x7468dead) throw new Error("Invalid dbRoot magic");
  
  const uncompressedSize = new DataView(decrypted.buffer).getUint32(4, true);
  const compressed = decrypted.slice(8);
  const text = pako.inflate(compressed); // requires pako.js
  
  // Replace hostnames in text
  const textStr = new TextDecoder().decode(text);
  let modified = textStr;
  if (geoHost) modified = modified.replace(/\[geoServer\.host\] "[^"]*"/g, `[geoServer.host] "${geoHost}"`);
  if (authHost) modified = modified.replace(/\[authServer\.host\] "[^"]*"/g, `[authServer.host] "${authHost}"`);
  
  // Re-compress
  const modifiedBytes = new TextEncoder().encode(modified);
  const recompressed = pako.deflate(modifiedBytes);
  
  // Re-package as KhPkt
  const khpkt = new Uint8Array(8 + recompressed.length);
  new DataView(khpkt.buffer).setUint32(0, 0x7468dead, true);
  new DataView(khpkt.buffer).setUint32(4, modifiedBytes.length, true);
  khpkt.set(recompressed, 8);
  
  // Re-encrypt
  const reencrypted = geeCodec(khpkt, key);
  
  // Assemble: header + key + encrypted
  const result = new Uint8Array(8 + 1016 + reencrypted.length);
  result.set(header, 0);
  result.set(key, 8);
  result.set(reencrypted, 8 + 1016);
  
  return result;
}

function geeCodec(data, key) {
  const out = new Uint8Array(data.length);
  out.set(data);
  const keylen = key.length;
  let dp = 0, off = 8, kp = 0;
  
  while (dp + 8 <= out.length) {
    off = (off + 8) % 24;
    kp = off;
    while (dp + 8 <= out.length && kp < keylen) {
      for (let i = 0; i < 8; i++) out[dp + i] ^= key[kp + i];
      dp += 8;
      kp += 24;
    }
  }
  if (dp < out.length) {
    while (kp >= keylen) { off = (off + 8) % 24; kp = off; }
    while (dp < out.length) { out[dp] ^= key[kp]; dp++; kp++; }
  }
  return out;
}

// Auth responses (static, cached)
const AUTH_RESP1 = new Uint8Array([0x03,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]);
// AUTH_RESP2 = 136 bytes (embedded in build)
