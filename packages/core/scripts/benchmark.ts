import { Benchmark } from '../src/benchmark';

const count = process.argv[2] ? parseInt(process.argv[2]) : 100;
console.log(`Starting benchmark for ${count} notes...`);

new Benchmark().run(count)
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err);
    process.exit(1);
  });
