// One-shot docs screenshotter for Wazy.
// Serves build/web, seeds demo data via localStorage, captures each screen.
// Run: node tool/capture_screens.mjs
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const ROOT = process.cwd();
const WEB = path.join(ROOT, 'build', 'web');
const OUT = path.join(ROOT, 'docs', 'images');
const PORT = 8734;
const BASE = `http://127.0.0.1:${PORT}`;

const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css',
  '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml', '.wasm': 'application/wasm', '.ttf': 'font/ttf',
  '.otf': 'font/otf', '.map': 'application/json', '.ico': 'image/x-icon',
};

function serve() {
  return new Promise((resolve) => {
    const server = http.createServer(async (req, res) => {
      try {
        let p = decodeURIComponent(new URL(req.url, BASE).pathname);
        if (p === '/') p = '/index.html';
        let file = path.join(WEB, p);
        if (!existsSync(file) || !p.includes('.')) file = path.join(WEB, 'index.html');
        const data = await readFile(file);
        res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] ?? 'application/octet-stream' });
        res.end(data);
      } catch {
        res.writeHead(500); res.end('error');
      }
    });
    server.listen(PORT, '127.0.0.1', () => resolve(server));
  });
}

const require = createRequire(path.join(
  process.env.HOME, '.vscode', 'extensions', 'danielsanmedium.dscodegpt-3.24.68', 'standalone', 'package.json'));
const { chromium } = require('patchright');

const D = (offset) => new Date(Date.now() + offset * 86400000);

const SEED = {
  // shared_preferences on web reads keys with the "flutter." prefix AND
  // jsonEncodes every value: a Dart String must be stored double-encoded,
  // booleans as plain true/false.
  'flutter.hasOnboarded': 'true',
  'flutter.hasSeenWelcome': 'true',
  'flutter.local_documents_v1': JSON.stringify(JSON.stringify([
    {
      collectionId: 'personal', id: 'doc-visa-1', displayName: 'Work Visa — GDRFA',
      docType: 'visa', expiryDate: 'Expiry', daysRemaining: 0, isExpired: false, isActive: true,
      description: 'Employment residence visa, file no 2011/2231', location: 'GDRFA / ICP / MOHRE',
      reminderStatus: 0, urgencyPriority: 0, documentDate: null,
      renewalFee: 3200, renewalSteps: null, renewalAuthorities: null,
      renewalWarning: null, expiresAt: D(55).toISOString(),
      fileName: 'work_visa_2026.pdf', filePath: null, fileSize: 184320,
      renewalHistory: [], customReminderDays: null, updatedAt: new Date().toISOString(),
    },
    {
      collectionId: 'personal', id: 'doc-licence-1', displayName: 'Dubai Trade Licence',
      docType: 'tradeLicence', expiryDate: 'Expiry', daysRemaining: 0, isExpired: false, isActive: true,
      description: 'DED licence no 754221, LLC — general trading', location: 'Dubai DED',
      reminderStatus: 1, urgencyPriority: 1, documentDate: null,
      renewalFee: 12850, renewalSteps: null, renewalAuthorities: null,
      renewalWarning: null, expiresAt: D(21).toISOString(),
      fileName: null, filePath: null, fileSize: null,
      renewalHistory: [], customReminderDays: [90, 45, 14], updatedAt: new Date().toISOString(),
    },
    {
      collectionId: 'personal', id: 'doc-eid-1', displayName: 'Emirates ID — Hassan R.',
      docType: 'emiratesId', expiryDate: 'Expiry', daysRemaining: 0, isExpired: false, isActive: true,
      description: null, location: 'ICP', reminderStatus: 0, urgencyPriority: 0,
      documentDate: null, renewalFee: 370, renewalSteps: null, renewalAuthorities: null,
      renewalWarning: null, expiresAt: D(8).toISOString(),
      fileName: null, filePath: null, fileSize: null,
      renewalHistory: [], customReminderDays: null, updatedAt: new Date().toISOString(),
    },
    {
      collectionId: 'personal', id: 'doc-ins-1', displayName: 'Vehicle Insurance — Land Cruiser',
      docType: 'insurance', expiryDate: 'Expiry', daysRemaining: 0, isExpired: false, isActive: true,
      description: 'Comprehensive, policy no INS-88410', location: 'Oman Insurance',
      reminderStatus: 0, urgencyPriority: 0, documentDate: null,
      renewalFee: 2450, renewalSteps: null, renewalAuthorities: null,
      renewalWarning: null, expiresAt: D(120).toISOString(),
      fileName: null, filePath: null, fileSize: null,
      renewalHistory: [], customReminderDays: null, updatedAt: new Date().toISOString(),
    },
    {
      collectionId: 'personal', id: 'doc-pass-1', displayName: 'Passport — Hassan R.',
      docType: 'passport', expiryDate: 'Expiry', daysRemaining: 0, isExpired: false, isActive: true,
      description: null, location: 'IGD Dubai', reminderStatus: 0, urgencyPriority: 0,
      documentDate: null, renewalFee: 0, renewalSteps: null, renewalAuthorities: null,
      renewalWarning: null, expiresAt: D(720).toISOString(),
      fileName: null, filePath: null, fileSize: null,
      renewalHistory: [], customReminderDays: null, updatedAt: new Date().toISOString(),
    },
    ])),
  'flutter.financeRecords.v1': JSON.stringify(JSON.stringify({
    transactions: [
      { id: 't1', collectionId: 'personal', kind: 'expense', category: 'rent', title: 'Office rent — Business Bay', amount: 8500, currency: 'AED', occurredAt: D(-32).toISOString(), note: null, documentId: null },
      { id: 't2', collectionId: 'personal', kind: 'expense', category: 'salaries', title: 'Staff salaries — September', amount: 24000, currency: 'AED', occurredAt: D(-2).toISOString(), note: null, documentId: null },
      { id: 't3', collectionId: 'personal', kind: 'expense', category: 'utilities', title: 'DEWA — September', amount: 1240, currency: 'AED', occurredAt: D(-4).toISOString(), note: null, documentId: null },
      { id: 't4', collectionId: 'personal', kind: 'expense', category: 'utilities', title: 'DEWA — August', amount: 910, currency: 'AED', occurredAt: D(-35).toISOString(), note: null, documentId: null },
      { id: 't5', collectionId: 'personal', kind: 'expense', category: 'utilities', title: 'DEWA — July', amount: 850, currency: 'AED', occurredAt: D(-63).toISOString(), note: null, documentId: null },
      { id: 't6', collectionId: 'personal', kind: 'expense', category: 'software', title: 'Microsoft 365', amount: 310, currency: 'AED', occurredAt: D(-3).toISOString(), note: null, documentId: null },
      { id: 't7', collectionId: 'personal', kind: 'expense', category: 'transport', title: 'Salik recharge', amount: 200, currency: 'AED', occurredAt: D(-6).toISOString(), note: null, documentId: null },
      { id: 't8', collectionId: 'personal', kind: 'income', category: 'sales', title: 'Client payment — Al Noor Trading', amount: 62000, currency: 'AED', occurredAt: D(-8).toISOString(), note: null, documentId: null },
      { id: 't9', collectionId: 'personal', kind: 'expense', category: 'renewals', title: 'Trade licence renewal fee', amount: 12850, currency: 'AED', occurredAt: D(-10).toISOString(), note: 'Estimated — due in 3 weeks', documentId: null },
      { id: 't10', collectionId: 'personal', kind: 'expense', category: 'foodAndBeverages', title: 'Team lunch — Business Bay', amount: 430, currency: 'AED', occurredAt: D(-1).toISOString(), note: null, documentId: null },
    ],
    budgets: [
      { id: 'b1', collectionId: 'personal', category: 'rent', monthlyLimit: 8500 },
      { id: 'b2', collectionId: 'personal', category: 'salaries', monthlyLimit: 24000 },
      { id: 'b3', collectionId: 'personal', category: 'utilities', monthlyLimit: 1000 },
      { id: 'b4', collectionId: 'personal', category: 'software', monthlyLimit: 500 },
    ],
    envelopes: [
      { id: 'e1', collectionId: 'personal', name: 'Licence renewal fund', targetAmount: 15000, savedAmount: 11000, monthlyContribution: 2500, documentId: null },
      { id: 'e2', collectionId: 'personal', name: 'Visa renewal fund', targetAmount: 5000, savedAmount: 3200, monthlyContribution: 800, documentId: null },
    ],
    recurring: [
      { id: 'r1', collectionId: 'personal', kind: 'expense', category: 'rent', title: 'Office rent', amount: 8500, currency: 'AED', frequency: 'monthly', dayOfMonth: 5, startDate: D(-60).toISOString(), endDate: null, isActive: true, lastLoggedAt: D(-32).toISOString() },
      { id: 'r2', collectionId: 'personal', kind: 'income', category: 'sales', title: 'Retainer — client', amount: 30000, currency: 'AED', frequency: 'monthly', dayOfMonth: 20, startDate: D(-90).toISOString(), endDate: null, isActive: true, lastLoggedAt: D(-8).toISOString() },
    ],
    overallBudgets: {},
  })),
};

async function main() {
  const server = await serve();
  const browser = await chromium.launch({
    channel: 'chromium-headless-shell',
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  });
  const page = await browser.newPage({ viewport: { width: 1284, height: 2778 }, deviceScaleFactor: 2 });

  // Seed BEFORE the app boots: local-only mode reads localStorage via SharedPreferences.
  await page.goto(`${BASE}/`, { waitUntil: 'domcontentloaded' });
  await page.evaluate((seed) => {
    localStorage.clear();
    for (const [k, v] of Object.entries(seed)) localStorage.setItem(k, v);
  }, SEED);

  const shots = [
    { name: '01_splash', waitMs: 2500 },
    { name: '02_onboarding', go: '/#/onboarding' },
    { name: '03_home', go: '/#/home', waitMs: 4500 },
    { name: '04_documents_list', go: '/#/documents', waitMs: 2500 },
    { name: '05_document_detail', go: '/#/document/doc-licence-1', waitMs: 2500 },
    { name: '06_upload_scan', go: '/#/scan', waitMs: 2000 },
    { name: '07_expiry_list', go: '/#/expiry-list', waitMs: 2000 },
    { name: '08_global_search', go: '/#/search', waitMs: 2000 },
    { name: '09_money', go: '/#/money', waitMs: 3000 },
    { name: '10_cash_flow', go: '/#/cash-flow-forecast', waitMs: 3000 },
    { name: '11_profile', go: '/#/profile', waitMs: 2500 },
  ];

  for (const s of shots) {
    if (s.go) {
      // Full reload on each route so Flutter state resets cleanly, then
      // go_router serves the deep link directly.
      await page.goto(`${BASE}${s.go}`, { waitUntil: 'domcontentloaded' });
    }
    await page.waitForTimeout(s.waitMs ?? 2500);
    await page.screenshot({ path: path.join(OUT, `${s.name}.png`) });
    console.log('captured', s.name);
  }

  await browser.close();
  server.close();
  console.log('DONE');
}

main().catch((e) => { console.error(e); process.exit(1); });
