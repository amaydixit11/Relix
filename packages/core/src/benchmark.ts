import { noteService } from './services/index';
import { randomBytes } from 'crypto';

/**
 * Benchmark Suite for Relix
 * Generates dummy notes and measures performance of core operations.
 */
export class Benchmark {
  private async measure(name: string, fn: () => Promise<void>) {
    console.time(name);
    const start = performance.now();
    await fn();
    const end = performance.now();
    console.timeEnd(name);
    return end - start;
  }

  /**
   * Generate dummy notes
   */
  async generateNotes(count: number) {
    console.log(`Generating ${count} notes...`);
    
    // Create in chunks to avoid overwhelming the daemon
    const chunkSize = 50;
    const chunks = Math.ceil(count / chunkSize);
    
    const tags = ['work', 'personal', 'ideas', 'project', 'journal', 'archive', 'draft'];
    
    await this.measure(`create-${count}`, async () => {
      for (let i = 0; i < chunks; i++) {
        const promises = [];
        for (let j = 0; j < chunkSize; j++) {
          if (i * chunkSize + j >= count) break;
          
          const id = randomBytes(4).toString('hex');
          const title = `Benchmark Note ${id}`;
          const body = `This is a benchmark note created for performance testing.\n\n## Section 1\nLorem ipsum dolor sit amet.\n\n## Links\n[[Benchmark Note ${randomBytes(4).toString('hex')}]]`;
          const noteTags = [tags[Math.floor(Math.random() * tags.length)]];
          
          promises.push(noteService.create(title, body, noteTags));
        }
        await Promise.all(promises);
        process.stdout.write('.');
      }
      console.log('\nDone.');
    });
  }

  /**
   * Run read performance tests
   */
  async runReadTests() {
    console.log('\nRunning read tests...');
    
    await this.measure('list-all', async () => {
      const notes = await noteService.list();
      console.log(`\nListed ${notes.length} notes`);
    });
  }

  /**
   * Run all benchmarks
   */
  async run(count: number = 1000) {
    console.log('=== Relix Benchmark Suite ===');
    console.log(`Target: ${count} notes\n`);
    
    try {
      await this.generateNotes(count);
      await this.runReadTests();
    } catch (err) {
      console.error('Benchmark failed:', err);
    }
  }
}

// Run if called directly
if (require.main === module) {
  const count = process.argv[2] ? parseInt(process.argv[2]) : 100;
  new Benchmark().run(count);
}
