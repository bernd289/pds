'use strict';

// Test suite for wrap-sqlite
// Mirrors common better-sqlite3 usage patterns

const Database = require('./index.js');

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  ✓ ${name}`);
    passed++;
  } catch (err) {
    console.error(`  ✗ ${name}`);
    console.error(`    ${err.message}`);
    failed++;
  }
}

function assert(condition, msg) {
  if (!condition) throw new Error(msg || 'Assertion failed');
}

function assertEqual(a, b, msg) {
  if (a !== b) throw new Error(msg || `Expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
}

// ─── Setup ───────────────────────────────────────────────────────────────────

console.log('\n wrap-sqlite tests\n');

const db = new Database(':memory:');
db.exec(`
  CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER);
  INSERT INTO users VALUES (1, 'Alice', 30);
  INSERT INTO users VALUES (2, 'Bob', 25);
  INSERT INTO users VALUES (3, 'Carol', 35);
`);

// ─── Basic SELECT ─────────────────────────────────────────────────────────────

console.log('Basic queries:');

test('.get() returns single row', () => {
  const row = db.prepare('SELECT * FROM users WHERE id = 1').get();
  assertEqual(row.name, 'Alice');
  assertEqual(row.age, 30);
});

test('.all() returns all rows', () => {
  const rows = db.prepare('SELECT * FROM users').all();
  assertEqual(rows.length, 3);
});

test('.get() with positional param', () => {
  const row = db.prepare('SELECT * FROM users WHERE id = ?').get(2);
  assertEqual(row.name, 'Bob');
});

test('.all() with named param', () => {
  const rows = db.prepare('SELECT * FROM users WHERE age > :minAge').all({ minAge: 28 });
  assertEqual(rows.length, 2);
});

test('.iterate() returns iterator', () => {
  const stmt = db.prepare('SELECT * FROM users');
  const names = [];
  for (const row of stmt.iterate()) {
    names.push(row.name);
  }
  assertEqual(names.length, 3);
  assertEqual(names[0], 'Alice');
});

// ─── INSERT / UPDATE / DELETE ─────────────────────────────────────────────────

console.log('\nMutating queries:');

test('.run() INSERT returns changes + lastInsertRowid', () => {
  const info = db.prepare('INSERT INTO users (name, age) VALUES (?, ?)').run('Dave', 40);
  assertEqual(info.changes, 1);
  assert(info.lastInsertRowid > 0);
});

test('.run() UPDATE returns changes count', () => {
  const info = db.prepare("UPDATE users SET age = 99 WHERE name = 'Dave'").run();
  assertEqual(info.changes, 1);
});

test('.run() DELETE returns changes count', () => {
  const info = db.prepare("DELETE FROM users WHERE name = 'Dave'").run();
  assertEqual(info.changes, 1);
});

// ─── Transactions ─────────────────────────────────────────────────────────────

console.log('\nTransactions:');

test('.transaction() commits on success', () => {
  const insertMany = db.transaction((users) => {
    const stmt = db.prepare('INSERT INTO users (name, age) VALUES (?, ?)');
    for (const u of users) stmt.run(u.name, u.age);
  });
  insertMany([{ name: 'Eve', age: 22 }, { name: 'Frank', age: 28 }]);
  const rows = db.prepare('SELECT * FROM users').all();
  assert(rows.length >= 5);
});

test('.transaction() rolls back on error', () => {
  const failTx = db.transaction(() => {
    db.prepare('INSERT INTO users (name, age) VALUES (?, ?)').run('Ghost', 0);
    throw new Error('intentional rollback');
  });
  const beforeCount = db.prepare('SELECT COUNT(*) as c FROM users').get().c;
  try { failTx(); } catch (_) {}
  const afterCount = db.prepare('SELECT COUNT(*) as c FROM users').get().c;
  assertEqual(beforeCount, afterCount);
});

// ─── Pragma ───────────────────────────────────────────────────────────────────

console.log('\nPragmas:');

test('.pragma() returns array', () => {
  const result = db.pragma('journal_mode');
  assert(Array.isArray(result));
  assert(result.length > 0);
});

test('.pragma() with simple:true returns value', () => {
  const mode = db.pragma('journal_mode', { simple: true });
  assertEqual(typeof mode, 'string');
});

// ─── Custom Functions ─────────────────────────────────────────────────────────

console.log('\nCustom functions:');

test('.function() registers scalar UDF', () => {
  db.function('double', (x) => x * 2);
  const row = db.prepare('SELECT double(age) as d FROM users WHERE id = 1').get();
  assertEqual(row.d, 60);
});

// ─── .columns() ──────────────────────────────────────────────────────────────

console.log('\nMetadata:');

test('.columns() returns column info', () => {
  const cols = db.prepare('SELECT id, name FROM users').columns();
  assertEqual(cols.length, 2);
  assertEqual(cols[0].name, 'id');
  assertEqual(cols[1].name, 'name');
});

// ─── .raw() / .pluck() ───────────────────────────────────────────────────────

console.log('\nResult modes:');

test('.raw() returns arrays instead of objects', () => {
  const rows = db.prepare('SELECT id, name FROM users').raw().all();
  assert(Array.isArray(rows[0]), 'row should be array');
  assertEqual(rows[0][1], 'Alice');
});

// ─── Properties ──────────────────────────────────────────────────────────────

console.log('\nDatabase properties:');

test('.open is true for open db', () => {
  assert(db.open === true);
});

test('.memory is true for :memory: db', () => {
  assert(db.memory === true);
});

test('.name is the filename', () => {
  assertEqual(db.name, ':memory:');
});

// ─── Error handling ───────────────────────────────────────────────────────────

console.log('\nError handling:');

test('SQL error thrown on bad query', () => {
  let threw = false;
  try {
    db.prepare('SELECT * FROM nonexistent_table').all();
  } catch (_) {
    threw = true;
  }
  assert(threw, 'Should throw on invalid table');
});

test('.run() on SELECT statement throws', () => {
  let threw = false;
  try {
    db.prepare('SELECT 1').run();
  } catch (_) {
    threw = true;
  }
  assert(threw);
});

test('.get() on INSERT statement throws', () => {
  let threw = false;
  try {
    db.prepare('INSERT INTO users (name, age) VALUES (?, ?)').get('X', 1);
  } catch (_) {
    threw = true;
  }
  assert(threw);
});

// ─── Close ────────────────────────────────────────────────────────────────────

console.log('\nClose:');

test('.close() marks db as closed', () => {
  const tmp = new Database(':memory:');
  tmp.close();
  assertEqual(tmp.open, false);
});

// ─── Summary ──────────────────────────────────────────────────────────────────

console.log(`\n─────────────────────────────`);
console.log(`  ${passed} passed, ${failed} failed`);
if (failed === 0) {
  console.log(`  All tests passed! 🎉`);
} else {
  console.log(`  Some tests failed ❌`);
  process.exit(1);
}
