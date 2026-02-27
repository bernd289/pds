'use strict';

// wrap-sqlite
// A drop-in shim for better-sqlite3 that maps to node:sqlite (built-in)
// https://github.com/WiseLibs/better-sqlite3/blob/master/docs/api.md
// Tested against @atproto/pds 0.4.x + Kysely 0.22.x SqliteDialect

const sqlite = require('node:sqlite');
const { DatabaseSync } = sqlite;

// ─── Error normalizer ────────────────────────────────────────────────────────
// node:sqlite: err.code = 'ERR_SQLITE_ERROR', err.errcode = 'SQLITE_BUSY'
// better-sqlite3: err.code = 'SQLITE_BUSY'
// @atproto/pds retrySqlite() checks err.code → normalize to match better-sqlite3.
function normalizeSqliteError(err) {
  if (err && typeof err === 'object' && err.errcode && err.code === 'ERR_SQLITE_ERROR') {
    err.code = err.errcode;
  }
  return err;
}

function wrapCall(fn) {
  try {
    return fn();
  } catch (err) {
    throw normalizeSqliteError(err);
  }
}

// ─── Integer normalizer ──────────────────────────────────────────────────────
// node:sqlite always returns BigInt for lastInsertRowid/changes.
// better-sqlite3 returns number by default.
// Normalize BigInt → number when safely representable (covers all practical rowids).
function normalizeInt(val) {
  if (typeof val === 'bigint') {
    return val <= BigInt(Number.MAX_SAFE_INTEGER) && val >= BigInt(Number.MIN_SAFE_INTEGER)
      ? Number(val)
      : val;
  }
  return val;
}

// ─── TCL intercept ───────────────────────────────────────────────────────────
// node:sqlite cannot prepare() TCL statements (BEGIN/COMMIT/ROLLBACK/SAVEPOINT).
// Kysely calls db.prepare('begin').run([]) → shim delegates to exec() instead.
const TCL_RE = /^\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)(\s|$)/i;

function makeTclShim(db, sql) {
  return {
    reader: false,
    readonly: false,
    source: sql,
    run(_params)     { wrapCall(() => db.exec(sql)); return { changes: 0, lastInsertRowid: 0 }; },
    all(_params)     { return []; },
    get(_params)     { return undefined; },
    iterate(_params) { return [][Symbol.iterator](); },
    columns()        { return []; },
    pluck()          { return this; },
    raw()            { return this; },
    safeIntegers()   { return this; },
    expand()         { return this; },
  };
}

// ─── Statement Wrapper ───────────────────────────────────────────────────────

class Statement {
  #stmt;
  #returnsData;

  constructor(stmt, returnsData) {
    this.#stmt        = stmt;
    this.#returnsData = returnsData;
    this.reader   = returnsData;
    this.readonly = returnsData;
    this.source   = stmt.sourceSQL;
  }

  get expandedSQL() { return this.#stmt.expandedSQL; }
  get sourceSQL()   { return this.#stmt.sourceSQL; }

  #call(method, args) {
    return wrapCall(() => {
      if (args.length === 0) {
        return this.#stmt[method]();
      }
      if (args.length === 1 && Array.isArray(args[0])) {
        return this.#stmt[method](...args[0]);
      }
      if (args.length === 1 && args[0] !== null && typeof args[0] === 'object') {
        return this.#stmt[method](args[0]);
      }
      return this.#stmt[method](...args);
    });
  }

  run(...args) {
    if (this.#returnsData) {
      throw new TypeError('This statement returns data. Use .get(), .all() or .iterate() instead.');
    }
    const result = this.#call('run', args);
    return {
      changes: normalizeInt(result.changes),
      lastInsertRowid: normalizeInt(result.lastInsertRowid),
    };
  }

  get(...args) {
    if (!this.#returnsData) {
      throw new TypeError('This statement does not return data. Use .run() instead.');
    }
    return this.#call('get', args);
  }

  all(...args) {
    if (!this.#returnsData) {
      throw new TypeError('This statement does not return data. Use .run() instead.');
    }
    return this.#call('all', args);
  }

  iterate(...args) {
    if (!this.#returnsData) {
      throw new TypeError('This statement does not return data. Use .run() instead.');
    }
    return this.#call('iterate', args);
  }

  columns() {
    return this.#stmt.columns().map(col => ({
      name: col.name,
      column: col.column,
      table: col.table,
      database: col.database,
      type: col.type,
    }));
  }

  pluck(enabled = true) {
    this.#stmt.setReturnArrays(enabled);
    this._pluck = enabled;
    return this;
  }

  expand(_enabled = true) {
    console.warn('wrap-sqlite: .expand() is not supported by node:sqlite — ignored');
    return this;
  }

  raw(enabled = true) {
    this.#stmt.setReturnArrays(enabled);
    return this;
  }

  safeIntegers(enabled = true) {
    this.#stmt.setReadBigInts(enabled);
    return this;
  }

  allowBareNamedParameters(enabled = true) {
    this.#stmt.setAllowBareNamedParameters(enabled);
    return this;
  }

  allowUnknownNamedParameters(enabled = true) {
    this.#stmt.setAllowUnknownNamedParameters(enabled);
    return this;
  }

  bind(..._args) {
    throw new Error('wrap-sqlite: .bind() is not supported. Pass parameters directly to .run()/.get()/.all().');
  }
}

// ─── Database Wrapper ────────────────────────────────────────────────────────

let savepointSeq = 0;

class Database {
  #db;
  #stmtCache = new Map();

  constructor(filename, options = {}) {
    const opts = {};

    if (options.readonly) opts.readOnly = true;
    if (options.fileMustExist) opts.open = false;

    // Pass through all native node:sqlite v24 DatabaseSync options.
    const nativeOpts = [
      'readBigInts',
      'returnArrays',
      'allowBareNamedParameters',
      'allowUnknownNamedParameters',
      'allowExtension',
      'enableForeignKeyConstraints',
      'enableDoubleQuotedStringLiterals',
      'defensive',
    ];
    for (const key of nativeOpts) {
      if (options[key] !== undefined) opts[key] = options[key];
    }

    this.#db = new DatabaseSync(filename, opts);

    // @atproto/pds passes timeout: 0 ("no wait, I retry myself via retrySqlite").
    // Do NOT pass timeout: 0 to node:sqlite — it may be interpreted as "throw BUSY immediately".
    // Only set busy_timeout when caller explicitly requests a positive value.
    if (options.timeout > 0) {
      wrapCall(() => this.#db.exec(`PRAGMA busy_timeout = ${options.timeout}`));
    }

    // Do NOT set journal_mode = WAL here — @atproto/pds calls ensureWal() itself.

    this.name     = filename;
    this.memory   = filename === ':memory:';
    this.readonly = !!options.readonly;
  }

  // better-sqlite3 uses .open; node:sqlite uses .isOpen — expose as boolean
  get open() { return this.#db.isOpen === true; }

  // better-sqlite3 uses .inTransaction; node:sqlite uses .isTransaction
  get inTransaction() { return this.#db.isTransaction === true; }

  prepare(sql) {
    this.#assertOpen();
    if (TCL_RE.test(sql.trim())) {
      return makeTclShim(this.#db, sql.trim());
    }
    return wrapCall(() => {
      const stmt = this.#db.prepare(sql);
      const returnsData = /^\s*(SELECT|WITH|PRAGMA|EXPLAIN|RETURNING)/i.test(sql.trim());
      return new Statement(stmt, returnsData);
    });
  }

  prepareCache(sql) {
    this.#assertOpen();
    if (this.#stmtCache.has(sql)) return this.#stmtCache.get(sql);
    const stmt = this.prepare(sql);
    this.#stmtCache.set(sql, stmt);
    return stmt;
  }

  exec(sql) {
    this.#assertOpen();
    return wrapCall(() => {
      this.#db.exec(sql);
      return this;
    });
  }

  transaction(fn) {
    this.#assertOpen();
    const db = this.#db;

    // Mirrors better-sqlite3 nesting behavior:
    //   outer call  → BEGIN [mode] … COMMIT / ROLLBACK
    //   nested call → SAVEPOINT sp_N … RELEASE / ROLLBACK TO sp_N
    function makeRunner(beginMode) {
      return function runner(...args) {
        if (db.isTransaction) {
          const sp = `sp_${++savepointSeq}`;
          wrapCall(() => db.exec(`SAVEPOINT ${sp}`));
          try {
            const result = fn.call(this, ...args);
            wrapCall(() => db.exec(`RELEASE ${sp}`));
            return result;
          } catch (err) {
            try { wrapCall(() => db.exec(`ROLLBACK TO ${sp}`)); } catch (_) {}
            try { wrapCall(() => db.exec(`RELEASE ${sp}`));     } catch (_) {}
            throw normalizeSqliteError(err);
          }
        } else {
          wrapCall(() => db.exec(beginMode ? `BEGIN ${beginMode}` : 'BEGIN'));
          try {
            const result = fn.call(this, ...args);
            wrapCall(() => db.exec('COMMIT'));
            return result;
          } catch (err) {
            try { wrapCall(() => db.exec('ROLLBACK')); } catch (_) {}
            throw normalizeSqliteError(err);
          }
        }
      };
    }

    const runTransaction     = makeRunner('');
    runTransaction.deferred  = makeRunner('DEFERRED');
    runTransaction.immediate = makeRunner('IMMEDIATE');
    runTransaction.exclusive = makeRunner('EXCLUSIVE');
    return runTransaction;
  }

  function(name, options, fn) {
    this.#assertOpen();
    if (typeof options === 'function') { fn = options; options = {}; }
    this.#db.function(name, options, fn);
    return this;
  }

  aggregate(name, options) {
    this.#assertOpen();
    this.#db.aggregate(name, options);
    return this;
  }

  pragma(source, options = {}) {
    this.#assertOpen();
    const simple = options.simple;
    return wrapCall(() => {
      const stmt = this.#db.prepare(`PRAGMA ${source}`);
      const rows = stmt.all();
      if (simple) {
        if (rows.length === 0) return undefined;
        return Object.values(rows[0])[0];
      }
      return rows;
    });
  }

  // backup() is a top-level function in node:sqlite (returns Promise)
  backup(destination, options = {}) {
    return sqlite.backup(this.#db, destination, options);
  }

  createSession(options = {}) {
    this.#assertOpen();
    return this.#db.createSession(options);
  }

  applyChangeset(changeset, options = {}) {
    this.#assertOpen();
    return this.#db.applyChangeset(changeset, options);
  }

  loadExtension(path) {
    this.#assertOpen();
    this.#db.loadExtension(path);
    return this;
  }

  enableLoadExtension(allow) {
    this.#assertOpen();
    this.#db.enableLoadExtension(allow);
    return this;
  }

  enableDefensive(active) {
    this.#assertOpen();
    this.#db.enableDefensive(active);
    return this;
  }

  setAuthorizer(callback) {
    this.#assertOpen();
    this.#db.setAuthorizer(callback);
    return this;
  }

  location(dbName) {
    this.#assertOpen();
    return this.#db.location(dbName);
  }

  // For deferred open (when fileMustExist option was used)
  openDatabase() {
    if (!this.#db.isOpen) this.#db.open();
    return this;
  }

  close() {
    this.#stmtCache.clear();
    if (this.#db.isOpen) this.#db.close();
    return this;
  }

  [Symbol.dispose]() { this.close(); }

  // better-sqlite3 compat stubs
  table(_name, _definition) {
    throw new Error('wrap-sqlite: .table() (virtual tables) is not supported by node:sqlite');
  }
  serialize(_options) {
    throw new Error('wrap-sqlite: .serialize() is not supported by node:sqlite');
  }
  defaultSafeIntegers(_enabled = true) {
    console.warn('wrap-sqlite: .defaultSafeIntegers() not supported globally — use stmt.safeIntegers()');
    return this;
  }
  unsafeMode(_enabled) {
    console.warn('wrap-sqlite: .unsafeMode() is not supported by node:sqlite — ignored');
    return this;
  }

  #assertOpen() {
    if (!this.#db.isOpen) throw new Error('The database connection is not open');
  }
}

// ─── Exports ─────────────────────────────────────────────────────────────────

module.exports = Database;
module.exports.default = Database;
module.exports.constants = sqlite.constants;
module.exports.SqliteError = class SqliteError extends Error {
  constructor(message, code) {
    super(message);
    this.name = 'SqliteError';
    this.code = code;
  }
};
