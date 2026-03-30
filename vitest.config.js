import { defineConfig } from 'vitest/config';
import { resolve } from 'path';
import { existsSync } from 'fs';

// Resolve @hotwired/stimulus from local node_modules or global NODE_PATH.
// On CI, packages are installed globally in /usr/local/lib/node_modules
// but Vite only searches local node_modules.
function resolveStimulusPath() {
  const localPath = resolve('node_modules/@hotwired/stimulus');
  if (existsSync(localPath)) { return localPath; }

  const globalPath = '/usr/local/lib/node_modules/@hotwired/stimulus';
  if (existsSync(globalPath)) { return globalPath; }

  return '@hotwired/stimulus';
}

export default defineConfig({
  resolve: {
    alias: {
      '@hotwired/stimulus': resolveStimulusPath()
    }
  },
  test: {
    environment: 'jsdom',
    include: ['test/javascript/**/*.test.js'],
    setupFiles: ['test/javascript/setup.js'],
    reporters: ['default', 'junit'],
    outputFile: { junit: 'test-results/junit.xml' },
    testTimeout: 10000
  }
});
