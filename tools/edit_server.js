/*
  edit_server.js — 여러 사람이 **같은 설정을 동시에** 고치는 편집 서버.

    node tools/edit_server.js [포트]

  기본 포트 7001. 저장소는 SQLite(`config_edits.db`)이고, Node에 들어 있는
  `node:sqlite`를 쓰므로 `npm install`이 없다.

  --------------------------------------------------------------------------
  DB가 벌어 주는 것

  처음에는 JSON 파일 하나였다. 여럿이 붙으면서 파일로는 못 하는 것들이 생겼다.

    이력      누가 · 언제 · 무엇을 · 무엇에서 무엇으로 바꿨는지 전부 남는다
    되돌리기  칸 하나를 이전 값으로 되돌린다. 카드 한 장을 통째로도 된다
    스냅샷    지금 상태에 이름을 붙여 두고 나중에 그대로 돌아온다
    충돌 감지 내가 보던 값이 그 사이 바뀌었으면 알려 준다 (조용히 덮지 않는다)
    검색      누가 고친 것만, 어떤 카드의 것만, 최근 것만 골라 본다
    원자성    한 번의 제출은 전부 반영되거나 전부 안 된다 (반쯤 쓰인 상태가 없다)

  `config_edits.json`은 바뀔 때마다 **함께 내보낸다.** `apply_config_edits.luau`가
  그 파일을 읽으므로 소스 반영 절차는 그대로다.

  --------------------------------------------------------------------------
  충돌 규칙: **칸 단위 마지막 쓰기 우선 + 알림**

  다른 칸을 고치는 것은 서로 방해하지 않는다. 같은 칸이면 나중 것이 남되,
  덮어쓴 사실을 이력에 남기고 원래 보던 사람에게 알린다.
*/

const fs = require("fs");
const http = require("http");
const path = require("path");
const os = require("os");
const { DatabaseSync } = require("node:sqlite");

const ROOT = path.resolve(__dirname, "..");
const PAGE = path.join(ROOT, "config_editor.html");
const DB_PATH = path.join(ROOT, "config_edits.db");
const EXPORT = path.join(ROOT, "config_edits.json");
const PORT = Number(process.argv[2]) || 7001;

const db = new DatabaseSync(DB_PATH);
db.exec(`
  PRAGMA journal_mode = WAL;

  -- 지금 값. 칸 하나가 한 줄이다.
  CREATE TABLE IF NOT EXISTS edits (
    scope TEXT NOT NULL,
    key   TEXT NOT NULL,
    field TEXT NOT NULL,
    sub   TEXT NOT NULL DEFAULT '',
    value TEXT,               -- JSON으로 담는다. 숫자·문자열·불린을 한 칸에 담기 위해서.
    who   TEXT,
    at    INTEGER,
    PRIMARY KEY (scope, key, field, sub)
  );

  -- 바뀐 내력. 되돌리기와 "누가 고쳤나"가 여기서 나온다.
  CREATE TABLE IF NOT EXISTS history (
    id     INTEGER PRIMARY KEY AUTOINCREMENT,
    scope TEXT, key TEXT, field TEXT, sub TEXT,
    before TEXT, after TEXT,
    who    TEXT, at INTEGER
  );
  CREATE INDEX IF NOT EXISTS history_at ON history(at DESC);
  CREATE INDEX IF NOT EXISTS history_key ON history(key);

  -- 이름 붙인 지점. 통째로 되돌아올 수 있다.
  CREATE TABLE IF NOT EXISTS snapshots (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT, body TEXT, who TEXT, at INTEGER
  );

  CREATE TABLE IF NOT EXISTS meta (k TEXT PRIMARY KEY, v TEXT);
`);

/* 처음 켜는 것이라면 예전 JSON을 그대로 들여온다. 작업을 잃지 않게. */
function importLegacy() {
  const already = db.prepare("SELECT COUNT(*) AS n FROM edits").get().n;
  if (already > 0 || !fs.existsSync(EXPORT)) return;
  try {
    const old = JSON.parse(fs.readFileSync(EXPORT, "utf8"));
    let brought = 0;
    for (const scope of Object.keys(old)) {
      if (typeof old[scope] !== "object" || old[scope] === null) continue;
      for (const key of Object.keys(old[scope])) {
        const entry = old[scope][key];
        if (typeof entry !== "object" || entry === null) continue;
        for (const field of Object.keys(entry)) {
          const value = entry[field];
          if (value !== null && typeof value === "object") {
            for (const sub of Object.keys(value)) {
              write({ scope, key, field, sub, value: value[sub] }, "가져옴");
              brought++;
            }
          } else {
            write({ scope, key, field, value }, "가져옴");
            brought++;
          }
        }
      }
    }
    if (brought > 0) console.log(`[edit] 예전 config_edits.json 에서 ${brought}칸을 들여왔습니다.`);
  } catch (e) {
    console.error(`[edit] 예전 JSON을 읽지 못했습니다: ${e.message}`);
  }
}

const readOne = db.prepare("SELECT value FROM edits WHERE scope=? AND key=? AND field=? AND sub=?");
const upsert = db.prepare(`
  INSERT INTO edits (scope,key,field,sub,value,who,at) VALUES (?,?,?,?,?,?,?)
  ON CONFLICT(scope,key,field,sub) DO UPDATE SET value=excluded.value, who=excluded.who, at=excluded.at
`);
const remove = db.prepare("DELETE FROM edits WHERE scope=? AND key=? AND field=? AND sub=?");
const logIt = db.prepare(`
  INSERT INTO history (scope,key,field,sub,before,after,who,at) VALUES (?,?,?,?,?,?,?,?)
`);

/*
  칸 하나를 쓴다. 이전 값을 이력에 함께 남긴다.
  value가 null이면 "원래대로 되돌림"이라 줄을 지운다.
*/
function write(change, who) {
  const { scope, key, field } = change;
  const sub = change.sub === undefined || change.sub === null ? "" : String(change.sub);
  if (!scope || !key || !field) return null;

  const previous = readOne.get(scope, key, field, sub);
  const before = previous ? previous.value : null;
  const after = change.value === null || change.value === undefined ? null : JSON.stringify(change.value);
  if (before === after) return null;

  const now = Date.now();
  if (after === null) remove.run(scope, key, field, sub);
  else upsert.run(scope, key, field, sub, after, who, now);
  logIt.run(scope, key, field, sub, before, after, who, now);
  return { scope, key, field, sub, before, after, who, at: now };
}

/* DB를 편집기·적용기가 쓰는 JSON 모양으로 편다. */
function buildState() {
  const state = { version: Number(meta("version") || 0) };
  for (const row of db.prepare("SELECT * FROM edits").all()) {
    if (!state[row.scope]) state[row.scope] = {};
    if (!state[row.scope][row.key]) state[row.scope][row.key] = {};
    const value = row.value === null ? null : JSON.parse(row.value);
    if (row.sub === "") {
      state[row.scope][row.key][row.field] = value;
    } else {
      if (!state[row.scope][row.key][row.field]) state[row.scope][row.key][row.field] = {};
      state[row.scope][row.key][row.field][row.sub] = value;
    }
  }
  const last = db.prepare("SELECT at FROM history ORDER BY id DESC LIMIT 1").get();
  if (last) {
    const when = new Date(last.at);
    state.savedAt = when.toISOString();
    state.savedAtLocal =
      when.getFullYear() +
      "-" + String(when.getMonth() + 1).padStart(2, "0") +
      "-" + String(when.getDate()).padStart(2, "0") +
      " " + String(when.getHours()).padStart(2, "0") +
      ":" + String(when.getMinutes()).padStart(2, "0");
  }
  return state;
}

function meta(k, v) {
  if (v === undefined) {
    const row = db.prepare("SELECT v FROM meta WHERE k=?").get(k);
    return row ? row.v : null;
  }
  db.prepare("INSERT INTO meta(k,v) VALUES(?,?) ON CONFLICT(k) DO UPDATE SET v=excluded.v").run(k, String(v));
  return v;
}

/*
  `apply_config_edits.luau`가 읽는 JSON을 함께 내보낸다.
  DB로 옮기면서도 소스 반영 절차는 그대로 두려는 것이다.
*/
let exportTimer = null;
function exportJson() {
  if (exportTimer) return;
  exportTimer = setTimeout(() => {
    exportTimer = null;
    const tmp = EXPORT + ".tmp";
    fs.writeFileSync(tmp, JSON.stringify(buildState(), null, 2));
    fs.renameSync(tmp, EXPORT);
  }, 400);
}

const clients = new Set();
const presence = new Map();

function broadcast(event, payload) {
  const line = `event: ${event}\ndata: ${JSON.stringify(payload)}\n\n`;
  for (const client of clients) {
    try {
      client.write(line);
    } catch (e) {
      clients.delete(client);
    }
  }
}

function peopleHere() {
  const now = Date.now();
  const alive = [];
  for (const [who, seen] of presence) {
    if (now - seen.at > 20000) presence.delete(who);
    else alive.push({ who, where: seen.where });
  }
  return alive;
}

function recent(limit, filter) {
  let sql = "SELECT * FROM history";
  const args = [];
  if (filter && filter.key) {
    sql += " WHERE key = ?";
    args.push(filter.key);
  } else if (filter && filter.who) {
    sql += " WHERE who = ?";
    args.push(filter.who);
  }
  sql += " ORDER BY id DESC LIMIT ?";
  args.push(Math.min(Number(limit) || 40, 300));
  return db.prepare(sql).all(...args).map((row) => ({
    id: row.id,
    scope: row.scope,
    key: row.key,
    field: row.field,
    sub: row.sub,
    before: row.before === null ? null : JSON.parse(row.before),
    after: row.after === null ? null : JSON.parse(row.after),
    who: row.who,
    at: row.at,
  }));
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    let raw = "";
    request.on("data", (chunk) => {
      raw += chunk;
      if (raw.length > 8e6) reject(new Error("본문이 너무 큽니다"));
    });
    request.on("end", () => {
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch (e) {
        reject(e);
      }
    });
  });
}

function json(response, body, status) {
  response.writeHead(status || 200, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  });
  response.end(JSON.stringify(body));
}

/* 한 번의 제출을 통째로 반영한다. 중간에 실패하면 아무것도 남지 않는다. */
function commit(changes, who) {
  const applied = [];
  db.exec("BEGIN");
  try {
    for (const change of changes) {
      const row = write(change, who);
      if (row) applied.push(row);
    }
    db.exec("COMMIT");
  } catch (e) {
    db.exec("ROLLBACK");
    throw e;
  }
  if (applied.length > 0) {
    meta("version", Number(meta("version") || 0) + 1);
    exportJson();
  }
  return applied;
}

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url, "http://localhost");

  if (url.pathname === "/" || url.pathname === "/index.html") {
    if (!fs.existsSync(PAGE)) {
      response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      response.end("config_editor.html 이 없습니다.\n  lune run tools/build_config_editor.luau");
      return;
    }
    response.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" });
    response.end(fs.readFileSync(PAGE));
    return;
  }

  if (url.pathname === "/state") {
    json(response, { state: buildState(), people: peopleHere(), history: recent(30) });
    return;
  }

  if (url.pathname === "/history") {
    json(response, {
      history: recent(url.searchParams.get("limit"), {
        key: url.searchParams.get("key"),
        who: url.searchParams.get("who"),
      }),
    });
    return;
  }

  if (url.pathname === "/events") {
    response.writeHead(200, {
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    });
    response.write(`event: hello\ndata: ${JSON.stringify({ version: meta("version") || 0 })}\n\n`);
    clients.add(response);
    const beat = setInterval(() => {
      try { response.write(": beat\n\n"); } catch (e) {}
    }, 15000);
    request.on("close", () => {
      clearInterval(beat);
      clients.delete(response);
    });
    return;
  }

  if (url.pathname === "/edit" && request.method === "POST") {
    let body;
    try {
      body = await readBody(request);
    } catch (e) {
      json(response, { ok: false, reason: e.message }, 400);
      return;
    }
    const who = body.who || "누군가";
    let applied;
    try {
      applied = commit(Array.isArray(body.changes) ? body.changes : [], who);
    } catch (e) {
      json(response, { ok: false, reason: e.message }, 500);
      return;
    }
    if (applied.length > 0) {
      broadcast("changed", { who, changes: applied, version: Number(meta("version")) });
      broadcast("history", { history: recent(30) });
    }
    json(response, { ok: true, applied: applied.length });
    return;
  }

  /* 이력 한 줄을 되돌린다. 되돌린 것 자체도 이력에 남는다. */
  if (url.pathname === "/undo" && request.method === "POST") {
    const body = await readBody(request).catch(() => ({}));
    const row = db.prepare("SELECT * FROM history WHERE id=?").get(Number(body.id));
    if (!row) {
      json(response, { ok: false, reason: "그런 이력이 없습니다." }, 404);
      return;
    }
    const who = body.who || "누군가";
    const applied = commit([{
      scope: row.scope, key: row.key, field: row.field,
      sub: row.sub === "" ? null : row.sub,
      value: row.before === null ? null : JSON.parse(row.before),
    }], who + " (되돌림)");
    broadcast("changed", { who, changes: applied, version: Number(meta("version")) });
    broadcast("history", { history: recent(30) });
    json(response, { ok: true, applied: applied.length });
    return;
  }

  if (url.pathname === "/snapshots") {
    if (request.method === "POST") {
      const body = await readBody(request).catch(() => ({}));
      db.prepare("INSERT INTO snapshots (name, body, who, at) VALUES (?,?,?,?)")
        .run(body.name || "이름 없음", JSON.stringify(buildState()), body.who || "누군가", Date.now());
      broadcast("snapshots", { snapshots: listSnapshots() });
      json(response, { ok: true, snapshots: listSnapshots() });
      return;
    }
    json(response, { snapshots: listSnapshots() });
    return;
  }

  /* 스냅샷으로 되돌아간다. 지금 값들을 그 시점 값으로 전부 덮는다. */
  if (url.pathname === "/restore" && request.method === "POST") {
    const body = await readBody(request).catch(() => ({}));
    const row = db.prepare("SELECT * FROM snapshots WHERE id=?").get(Number(body.id));
    if (!row) {
      json(response, { ok: false, reason: "그런 스냅샷이 없습니다." }, 404);
      return;
    }
    const target = JSON.parse(row.body);
    const changes = [];
    // 지금 있는 칸을 전부 지우고
    for (const current of db.prepare("SELECT scope,key,field,sub FROM edits").all()) {
      changes.push({
        scope: current.scope, key: current.key, field: current.field,
        sub: current.sub === "" ? null : current.sub, value: null,
      });
    }
    // 스냅샷의 칸을 다시 넣는다
    for (const scope of Object.keys(target)) {
      if (typeof target[scope] !== "object" || target[scope] === null) continue;
      for (const key of Object.keys(target[scope])) {
        const entry = target[scope][key];
        if (typeof entry !== "object" || entry === null) continue;
        for (const field of Object.keys(entry)) {
          const value = entry[field];
          if (value !== null && typeof value === "object") {
            for (const sub of Object.keys(value)) changes.push({ scope, key, field, sub, value: value[sub] });
          } else {
            changes.push({ scope, key, field, value });
          }
        }
      }
    }
    const who = (body.who || "누군가") + ` (스냅샷 "${row.name}" 복원)`;
    const applied = commit(changes, who);
    broadcast("reload", { reason: "snapshot" });
    broadcast("history", { history: recent(30) });
    json(response, { ok: true, applied: applied.length });
    return;
  }

  if (url.pathname === "/presence" && request.method === "POST") {
    const body = await readBody(request).catch(() => ({}));
    if (body.who) {
      presence.set(body.who, { at: Date.now(), where: body.where || "" });
      broadcast("people", { people: peopleHere() });
    }
    json(response, { ok: true, people: peopleHere() });
    return;
  }

  response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
  response.end("없는 주소입니다.");
});

function listSnapshots() {
  return db.prepare("SELECT id, name, who, at FROM snapshots ORDER BY id DESC LIMIT 50").all();
}

importLegacy();
exportJson();

server.listen(PORT, "0.0.0.0", () => {
  const addresses = [];
  for (const list of Object.values(os.networkInterfaces())) {
    for (const entry of list || []) {
      if (entry.family === "IPv4" && !entry.internal) addresses.push(entry.address);
    }
  }
  const rows = db.prepare("SELECT COUNT(*) AS n FROM edits").get().n;
  const logged = db.prepare("SELECT COUNT(*) AS n FROM history").get().n;
  console.log(`[edit] 편집 서버가 떴습니다. 포트 ${PORT}`);
  console.log(`[edit]   이 컴퓨터   http://localhost:${PORT}`);
  for (const address of addresses) console.log(`[edit]   같은 망에서 http://${address}:${PORT}`);
  console.log(`[edit] DB          ${DB_PATH}  (칸 ${rows}개 · 이력 ${logged}줄)`);
  console.log(`[edit] 내보내기    ${EXPORT}`);
  console.log(`[edit] 소스 반영   lune run tools/apply_config_edits.luau config_edits.json`);
  console.log(`[edit] 인터넷 공유 cloudflared tunnel --url http://localhost:${PORT}`);
});
