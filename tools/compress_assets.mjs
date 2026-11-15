#!/usr/bin/env node
// Pre-compress built assets for tools/asset_pipeline.rb (#4623).
//
// Usage: node tools/compress_assets.mjs <dir>
//
// For every file <dir>/<name>.min, writes <name>.gzip, <name>.br and <name>.zstd next to it,
// using the settings the pipeline has always used: gzip at the default level, Brotli
// quality 11, zstd level 19. Each output is decompressed and compared
// with its input before it's written, and any failure exits non-zero so the build stops
// before anything is uploaded. Node's zlib runs these on its thread pool, so files compress
// in parallel. Doing this in Node means the build host doesn't compile the brotli and
// zstd-ruby native gems on every run.
import { readdir, readFile, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { promisify } from 'node:util'
import zlib from 'node:zlib'

const dir = process.argv[2]
if (!dir) {
  console.error('usage: compress_assets.mjs <dir>')
  process.exit(2)
}

const { constants } = zlib
const ZSTD_AVAILABLE = typeof zlib.zstdCompress === 'function'

const encodings = [
  {
    ext: 'gzip',
    compress: promisify(zlib.gzip),
    decompress: promisify(zlib.gunzip),
  },
  {
    ext: 'br',
    compress: (buf) => promisify(zlib.brotliCompress)(buf, {
      params: {
        [constants.BROTLI_PARAM_QUALITY]: 11,
        [constants.BROTLI_PARAM_SIZE_HINT]: buf.length,
      },
    }),
    decompress: promisify(zlib.brotliDecompress),
  },
]
// zstd is required, not optional: Application::best_compression_type sends zstd-capable
// browsers to the zstd/ copies, so skipping them would break those pages.
if (!ZSTD_AVAILABLE) {
  console.error('Asset compression failed: this Node has no zstd support (Node 22.15+ / 23.8+ required)')
  process.exit(1)
}
encodings.push({
  ext: 'zstd',
  compress: (buf) => promisify(zlib.zstdCompress)(buf, {
    params: { [constants.ZSTD_c_compressionLevel]: 19 },
  }),
  decompress: promisify(zlib.zstdDecompress),
})

const files = (await readdir(dir)).filter((name) => name.endsWith('.min'))

async function compressFile(name) {
  const source = await readFile(path.join(dir, name))
  const base = name.slice(0, -'.min'.length)
  for (const { ext, compress, decompress } of encodings) {
    const out = await compress(source)
    const back = await decompress(out)
    if (!back.equals(source)) throw new Error(`${ext} round-trip mismatch for ${base}`)
    await writeFile(path.join(dir, `${base}.${ext}`), out)
  }
}

// Bound the number of files in flight; zlib's own thread pool does the parallel work.
const queue = [...files]
const workers = Array.from({ length: Math.min(16, queue.length) }, async () => {
  while (queue.length) await compressFile(queue.shift())
})

try {
  await Promise.all(workers)
  console.log(`Compressed ${files.length} files (${encodings.map((e) => e.ext).join(', ')})`)
} catch (err) {
  console.error(`Asset compression failed: ${err.message}`)
  process.exit(1)
}
