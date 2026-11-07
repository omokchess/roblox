"""check_roblox_api.py — src/**/*.luau 를 로블록스 공식 API 목록(tools/roblox_api/API-Dump.json)과 대조한다. (2026-11-07)

  python tools/check_roblox_api.py            # 프로젝트 루트에서. 문제가 있으면 줄 번호와 함께 출력, 종료코드 1
  python tools/check_roblox_api.py src/client  # 일부만

잡는 것
  - Instance.new("X") — 없는 클래스, NotCreatable
  - `local v = Instance.new("X")` 뒤의 `v.Prop = ...` — 없는 속성, ReadOnly, NotScriptable, 플러그인 전용
  - 어떤함수("X", { Key = ..., ... }) 처럼 첫 인자가 클래스 이름이고 둘째가 표 리터럴인 호출(make 류) — 표의 키
  - Enum.A.B — 없는 Enum·항목 / 속성에 다른 Enum 항목을 넣음(Prop = Enum.Other.X)
  - NumberRange.new(숫자, 숫자) min>max, 키포인트 시간 리터럴이 0~1 밖
한계: 변수 범위는 단순 추적(같은 이름 재사용은 마지막 대입을 따름). 불러온 표/동적 키는 못 본다 — 실행 쪽 검사(tools/roblox_api.luau)가 본다.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DUMP = ROOT / "tools" / "roblox_api" / "API-Dump.json"
if not DUMP.exists():
    sys.exit("API-Dump.json 이 없습니다 — bash tools/roblox_api/fetch.sh")

dump = json.loads(DUMP.read_text(encoding="utf8"))
CLASSES = {}
for c in dump["Classes"]:
    props, other = {}, {}
    for m in c["Members"]:
        if m["MemberType"] == "Property":
            props[m["Name"]] = m
        else:
            other[m["Name"]] = m["MemberType"]
    CLASSES[c["Name"]] = {"super": c.get("Superclass"), "props": props, "other": other, "tags": set(c.get("Tags") or [])}
ENUMS = {e["Name"]: {i["Name"] for i in e["Items"]} for e in dump["Enums"]}
# 덤프에 없지만 스튜디오에 있는 항목(extra.json)
for _enum, _items in json.loads((DUMP.parent / "extra.json").read_text(encoding="utf8")).get("EnumItems", {}).items():
    ENUMS.setdefault(_enum, set()).update(_items)


def find_prop(cls, name):
    while cls and cls in CLASSES:
        info = CLASSES[cls]
        if name in info["props"]:
            return info["props"][name], None
        if name in info["other"]:
            return None, info["other"][name]
        cls = info["super"]
    return None, None


def prop_problem(cls, name):
    """그 클래스에 name 을 '쓸 수' 있는가. 문제 있으면 설명, 없으면 None."""
    prop, other = find_prop(cls, name)
    if other:
        return f"{cls}.{name} 은 속성이 아니라 {other}"
    if prop is None:
        return f"{cls} 에 없는 속성 '{name}'"
    tags = set(prop.get("Tags") or [])
    if "ReadOnly" in tags:
        return f"{cls}.{name} 은 읽기 전용(ReadOnly)"
    if "NotScriptable" in tags:
        return f"{cls}.{name} 은 NotScriptable"
    write = (prop.get("Security") or {}).get("Write", "None")
    if write != "None":
        return f"{cls}.{name} 은 {write} 전용"
    return None


def enum_of_prop(cls, name):
    prop, _ = find_prop(cls, name)
    if prop and prop["ValueType"]["Category"] == "Enum":
        return prop["ValueType"]["Name"]
    return None


def strip_comments(text):
    """주석을 공백으로 바꾼다(줄 번호 유지). 문자열 안의 -- 는 건드리지 않는다."""
    out = []
    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        if ch == "-" and text.startswith("--", i):
            m = re.match(r"--\[(=*)\[", text[i:])
            if m:
                end = text.find("]" + m.group(1) + "]", i)
                end = n if end < 0 else end + len(m.group(1)) + 2
            else:
                end = text.find("\n", i)
                end = n if end < 0 else end
            out.append(re.sub(r"[^\n]", " ", text[i:end]))
            i = end
        elif ch in "\"'":
            j = i + 1
            while j < n and text[j] != ch and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            out.append(text[i : j + 1])
            i = j + 1
        elif ch == "[" and re.match(r"\[=*\[", text[i:]):
            m = re.match(r"\[(=*)\[", text[i:])
            end = text.find("]" + m.group(1) + "]", i)
            end = n if end < 0 else end + len(m.group(1)) + 2
            out.append(text[i:end])
            i = end
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def line_of(text, pos):
    return text.count("\n", 0, pos) + 1


def table_keys(text, start):
    """text[start] == '{' 인 표 리터럴의 맨 바깥 `Key = 값` 키들을 (키, 위치, 값 앞부분) 으로. 못 닫으면 None."""
    depth, i, n = 0, start, len(text)
    keys = []
    expect_key = True
    while i < n:
        ch = text[i]
        if ch in "\"'":
            j = i + 1
            while j < n and text[j] != ch and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            i = j + 1
            expect_key = False
            continue
        if ch in "{([":
            depth += 1
            if depth > 1:
                expect_key = False
            i += 1
            if depth == 1:
                expect_key = True
            continue
        if ch in "})]":
            depth -= 1
            i += 1
            if depth == 0:
                return keys
            continue
        if depth == 1:
            if ch in ",;":
                expect_key = True
                i += 1
                continue
            if expect_key:
                m = re.compile(r"([A-Za-z_]\w*)\s*=(?!=)").match(text, i)
                if m:
                    keys.append((m.group(1), i, text[m.end() : m.end() + 80]))
                    i = m.end()
                    expect_key = False
                    continue
                if not ch.isspace():
                    expect_key = False
        i += 1
    return None


INSTANCE_NEW = re.compile(r"Instance\.new\(\s*\"([^\"]+)\"")
LOCAL_NEW = re.compile(r"^\s*(?:local\s+)?([A-Za-z_]\w*)(?:\s*:\s*[\w.?]+)?\s*=\s*Instance\.new\(\s*\"([^\"]+)\"", re.M)
LOCAL_ANY = re.compile(r"^\s*local\s+([A-Za-z_]\w*)\b(?:\s*:\s*[^=\n]+)?\s*=\s*(?=\S)(?!Instance\.new\()", re.M)
ASSIGN = re.compile(r"^\s*([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s*=(?!=)\s*(.*)$", re.M)
CALL_CLASS = re.compile(r"[\w:.]+\(\s*\"([A-Za-z0-9]+)\"\s*,\s*\{")
ENUM_USE = re.compile(r"\bEnum\.([A-Za-z_]\w*)(?:\.([A-Za-z_]\w*))?")
NUMRANGE = re.compile(r"NumberRange\.new\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)")
KEYPOINT = re.compile(r"(?:Number|Color)SequenceKeypoint\.new\(\s*(-?[\d.]+)")


def check_file(path, problems):
    raw = path.read_text(encoding="utf8")
    text = strip_comments(raw)
    rel = path.relative_to(ROOT).as_posix() if ROOT in path.parents else path.as_posix()

    def add(pos, msg):
        problems.append(f"{rel}:{line_of(text, pos)}: {msg}")

    for m in INSTANCE_NEW.finditer(text):
        cls = m.group(1)
        if cls not in CLASSES:
            add(m.start(), f"Instance.new: 없는 클래스 '{cls}'")
        elif "NotCreatable" in CLASSES[cls]["tags"]:
            add(m.start(), f"Instance.new: '{cls}' 는 NotCreatable")

    # 변수 → 클래스 추적(대입 순서대로)
    events = []  # (pos, kind, name, cls)
    for m in LOCAL_NEW.finditer(text):
        events.append((m.start(), "set", m.group(1), m.group(2)))
    for m in LOCAL_ANY.finditer(text):
        events.append((m.start(), "clear", m.group(1), None))
    for m in ASSIGN.finditer(text):
        events.append((m.start(), "assign", m.group(1), (m.group(2), m.group(3))))
    events.sort(key=lambda e: e[0])
    current = {}
    for pos, kind, name, extra in events:
        if kind == "set":
            current[name] = extra if extra in CLASSES else None
        elif kind == "clear":
            current.pop(name, None)
        else:
            cls = current.get(name)
            if not cls:
                continue
            prop, value = extra
            problem = prop_problem(cls, prop)
            if problem:
                add(pos, problem)
                continue
            em = re.match(r"Enum\.([A-Za-z_]\w*)\.", value)
            want = enum_of_prop(cls, prop)
            if em and want and em.group(1) != want:
                add(pos, f"{cls}.{prop} 은 Enum.{want} 인데 Enum.{em.group(1)} 항목을 넣음")

    # make("Class", { ... }) 류
    for m in CALL_CLASS.finditer(text):
        cls = m.group(1)
        if cls not in CLASSES or "NotCreatable" in CLASSES[cls]["tags"]:
            continue
        keys = table_keys(text, m.end() - 1)
        if keys is None:
            continue
        for key, kpos, value in keys:
            problem = prop_problem(cls, key)
            if problem:
                add(kpos, f'("{cls}", {{...}}) ' + problem)
                continue
            em = re.match(r"\s*Enum\.([A-Za-z_]\w*)\.", value)
            want = enum_of_prop(cls, key)
            if em and want and em.group(1) != want:
                add(kpos, f'("{cls}", {{...}}) {cls}.{key} 은 Enum.{want} 인데 Enum.{em.group(1)} 항목을 넣음')

    for m in ENUM_USE.finditer(text):
        name, item = m.group(1), m.group(2)
        if name not in ENUMS:
            # Enum:GetEnums() 같은 메서드 호출은 제외
            if not text.startswith(":", m.start() + 4) and name not in ("GetEnums",):
                add(m.start(), f"Enum.{name}: 없는 Enum")
        elif item and item not in ENUMS[name] and item not in ("GetEnumItems", "Name", "Value", "EnumType", "FromName", "FromValue"):
            add(m.start(), f"Enum.{name}.{item}: 없는 항목")

    for m in NUMRANGE.finditer(text):
        try:
            if float(m.group(1)) > float(m.group(2)):
                add(m.start(), f"NumberRange.new({m.group(1)}, {m.group(2)}): min > max")
        except ValueError:
            pass
    for m in KEYPOINT.finditer(text):
        try:
            if not 0 <= float(m.group(1)) <= 1:
                add(m.start(), f"키포인트 시간 {m.group(1)} 이 0~1 밖")
        except ValueError:
            pass


def main():
    targets = [Path(a) for a in sys.argv[1:]] or [ROOT / "src"]
    files = []
    for t in targets:
        t = t if t.is_absolute() else Path.cwd() / t
        files += [t] if t.is_file() else sorted(t.rglob("*.luau"))
    problems = []
    for f in files:
        check_file(f.resolve(), problems)
    for p in problems:
        print(p)
    print(f"{len(files)} 파일 검사, 문제 {len(problems)}건")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
