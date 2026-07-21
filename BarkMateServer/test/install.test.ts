import { SELF } from 'cloudflare:test';
import { describe, it, expect } from 'vitest';

// Verifies wrangler's Text-import (`rules: type=Text`) actually bundles
// scripts/install.sh.txt and docs/cli-setup.md into the worker, AND that the
// new public routes bypass bearerAuth.

describe('GET /install.sh', () => {
  it('serves the bash installer as text/x-shellscript', async () => {
    const response = await SELF.fetch('http://localhost/install.sh');
    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toMatch(/text\/x-shellscript/);

    const body = await response.text();
    expect(body.startsWith('#!/usr/bin/env bash')).toBe(true);
    expect(body).toContain('bark-push');
    expect(body).toContain('https://barkagent.we2.xyz/install.sh');
  });
});

describe('GET /uninstall.sh', () => {
  it('serves the bash uninstaller as text/x-shellscript', async () => {
    const response = await SELF.fetch('http://localhost/uninstall.sh');
    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toMatch(/text\/x-shellscript/);

    const body = await response.text();
    expect(body.startsWith('#!/usr/bin/env bash')).toBe(true);
    expect(body).toContain('bark-push');
    expect(body).toContain('BARK_RESTORE');
  });
});

describe('GET /docs/cli-setup', () => {
  it('renders cli-setup.md as HTML', async () => {
    const response = await SELF.fetch('http://localhost/docs/cli-setup');
    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toMatch(/text\/html/);

    const body = await response.text();
    expect(body).toContain('<!doctype html>');
    expect(body).toContain('<h1');
    expect(body).toContain('BarkMate CLI');
    // Ensure the markdown renderer ran (not raw markdown leaking through)
    expect(body).not.toContain('## 快速开始');
    expect(body).toContain('<h2');
  });
});

describe('GET /docs/cli-setup.md', () => {
  it('serves the raw markdown', async () => {
    const response = await SELF.fetch('http://localhost/docs/cli-setup.md');
    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toMatch(/text\/markdown/);

    const body = await response.text();
    expect(body.startsWith('# BarkMate CLI 接入')).toBe(true);
  });
});
