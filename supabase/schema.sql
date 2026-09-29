-- Porcelain Tactics 편집기 — Supabase 스키마.
-- Supabase 대시보드 → SQL Editor → New query 에 통째로 붙여넣고 Run.
--
-- **몇 번을 다시 돌려도 안전하다**(idempotent). 고칠 때마다 이 파일을 통째로
-- 다시 돌리면 된다.
--
-- edit_server.js(Node + SQLite)가 하던 것과 같은 모양이다: 지금 값(edits),
-- 바뀐 내력(history), 이름 붙인 지점(snapshots).

create table if not exists edits (
  scope text not null,
  key   text not null,
  field text not null,
  sub   text not null default '',
  value jsonb,
  who   text,
  at    bigint,
  primary key (scope, key, field, sub)
);

create table if not exists history (
  id     bigint generated always as identity primary key,
  scope  text,
  key    text,
  field  text,
  sub    text,
  before jsonb,
  after  jsonb,
  who    text,
  at     bigint
);
create index if not exists history_at on history (at desc);
create index if not exists history_key on history (key);

create table if not exists snapshots (
  id   bigint generated always as identity primary key,
  name text,
  body jsonb,
  who  text,
  at   bigint
);

-- ===========================================================================
-- 칸 하나를 고치는 **원자적** 함수.
--
-- 이게 없으면 브라우저가 "지금 값 읽기 → 새 값 쓰기 → 이력 남기기"를 세 번
-- 나눠서 하는데, 그 사이에 다른 사람(혹은 같은 사람의 다음 타자)이 끼어들면
--
--   A가 "공명 워"를 읽음 ─┐
--   B가 "공명 워"를 읽음 ─┤ 둘 다 같은 옛 값을 봤다
--   A가 "공명 원"을 씀   ─┤
--   B가 "공명 원"을 씀   ─┘ A의 결과가 덮여 사라진다
--
-- 실제로 이력에 이 흔적이 그대로 남았다(같은 before를 가진 줄이 둘씩).
-- 게다가 늦게 출발한 요청이 먼저 도착하면 **옛 값이 최신 값을 덮는다** —
-- 두 사람 화면이 서로 달라지던 진짜 원인이 이것이다.
--
-- 여기서는 셋을 한 트랜잭션으로 묶고, 같은 칸을 고치는 요청끼리는 advisory
-- lock으로 줄을 세운다. 다른 칸끼리는 서로 안 기다린다.
-- ===========================================================================
create or replace function apply_edit(
  p_scope text,
  p_key   text,
  p_field text,
  p_sub   text,
  p_value jsonb,
  p_who   text
) returns void
language plpgsql
as $$
declare
  v_sub    text := coalesce(p_sub, '');
  v_before jsonb;
  v_now    bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
begin
  -- 같은 칸을 고치는 요청끼리만 줄을 세운다.
  perform pg_advisory_xact_lock(hashtext(p_scope || '|' || p_key || '|' || p_field || '|' || v_sub));

  select value into v_before from edits
   where scope = p_scope and key = p_key and field = p_field and sub = v_sub;

  -- 값이 그대로면 이력을 더럽히지 않는다.
  if v_before is not distinct from p_value then
    return;
  end if;

  if p_value is null then
    delete from edits
     where scope = p_scope and key = p_key and field = p_field and sub = v_sub;
  else
    insert into edits (scope, key, field, sub, value, who, at)
    values (p_scope, p_key, p_field, v_sub, p_value, p_who, v_now)
    on conflict (scope, key, field, sub)
      do update set value = excluded.value, who = excluded.who, at = excluded.at;
  end if;

  insert into history (scope, key, field, sub, before, after, who, at)
  values (p_scope, p_key, p_field, v_sub, v_before, p_value, p_who, v_now);
end;
$$;

-- === 접근 권한 ===
--
-- 이 편집기는 로그인이 없다 — 링크를 아는 사람은 누구나 고칠 수 있는 게
-- 원래 설계다(예전 로컬 서버도 같았다). anon key로 붙는 모든 요청을 그대로
-- 허용한다. **service_role key는 여기 어디에도 쓰지 않는다** — 그건
-- RLS를 통째로 건너뛰는 키라 브라우저에 실리면 안 된다.

alter table edits     enable row level security;
alter table history   enable row level security;
alter table snapshots enable row level security;

drop policy if exists "anon full access" on edits;
drop policy if exists "anon full access" on history;
drop policy if exists "anon full access" on snapshots;

create policy "anon full access" on edits     for all using (true) with check (true);
create policy "anon full access" on history   for all using (true) with check (true);
create policy "anon full access" on snapshots for all using (true) with check (true);

-- === 실시간 ===
--
-- 남이 고친 칸이 그 자리에서 보이려면(예전의 SSE) 이 표들을 realtime
-- publication에 넣어야 한다. 이미 들어 있으면 그냥 넘어간다.

do $$
begin
  begin
    alter publication supabase_realtime add table edits;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table history;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table snapshots;
  exception when duplicate_object then null;
  end;
end $$;
