const { spawn } = require('child_process');
const path = require('path');

// Parse args
const args = process.argv.slice(2);
let env = { ...process.env };
const nextArgs = [];

for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === '--acorde_port') {
    if (i + 1 < args.length) {
      const port = args[i + 1];
      console.log(`\x1b[36m> Relix: Using custom ACORDE port: ${port}\x1b[0m`);
      env.NEXT_PUBLIC_ACORDE_URI = `http://localhost:${port}`;
      i++; // Skip next arg (value)
    }
  } else {
    nextArgs.push(arg);
  }
}

// Default log
if (!env.NEXT_PUBLIC_ACORDE_URI) {
  console.log(`\x1b[36m> Relix: Using default ACORDE URI: http://localhost:7331\x1b[0m`);
}

// Spawn Next.js
const next = spawn('next', ['dev', ...nextArgs], {
  stdio: 'inherit',
  env: env,
  shell: true
});

next.on('exit', (code) => {
  process.exit(code);
});
