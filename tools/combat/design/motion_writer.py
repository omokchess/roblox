"""모션 파일 생성기 공용 도구(quasar_motions.py · berserker_motions.py).
자세 표(…_out.txt 의 `local 이름 = { … }` 줄)를 읽고, 키를 Luau 줄로 적는다. 키마다 무기 W 회전을 앞 키에 가장 가까운
표기로 감아 적어(성분마다 ±360) 키 사이가 늘 쿼터니언 최단 호로 돈다 — 뜻하지 않은 오일러 돌기가 없다(check_wrap.py)."""
import re


def load_poses(path):
    poses = {}
    for name, body in re.findall(r"^local (\w+) = \{ (.*) \}$", open(path, encoding="utf-8").read(), re.M):
        poses[name] = {k: [float(x) for x in v.split(",")] for k, v in re.findall(r"(\w+) = \{ ([^}]*) \}", body)}
    return poses


def fmt(v):
    return "{ " + ", ".join(("%g" % round(x, 2)) for x in v) + " }"


def wrap_to(w, prev):
    return w[:3] + [w[i] + 360 * round((prev[i] - w[i]) / 360) for i in (3, 4, 5)]


def make(poses):
    """poses 로 keys(spec)·motion(...) 을 만든다. spec = [(t, 곡선, 자세 이름, {덮을 것})]"""

    def keys(spec):
        lines, prev = [], None
        for t, e, pose, over in spec:
            over = dict(over or {})
            w = list(over.get("W", poses[pose]["W"]))
            if prev is not None:
                w = wrap_to(w, prev)
            if w != poses[pose]["W"]:
                over["W"] = w
            prev = w
            es = "nil" if e is None else '"%s"' % e
            if over:
                body = ", ".join("%s = %s" % (k, fmt(v)) for k, v in over.items())
                lines.append("\t\t\t\tK(%s, %s, %s, { %s })," % (t, es, pose, body))
            else:
                lines.append("\t\t\t\tK(%s, %s, %s)," % (t, es, pose))
        return "\n".join(lines)

    def motion(name, comment, duration, spec, events, extra="", indent=2):
        tab = "\t" * indent
        ev = "\n".join(tab + "\t\t" + e + "," for e in events)
        body = keys(spec)
        if indent == 1:
            body = "\n".join(l[1:] for l in body.split("\n"))
        return (
            f"{tab}-- {comment}\n{tab}{name} = {{\n{tab}\tDuration = {duration},\n{extra}{tab}\tKeys = {{\n{body}\n{tab}\t}},\n"
            + (f"{tab}\tEvents = {{\n{ev}\n{tab}\t}},\n" if events else "")
            + f"{tab}}},\n"
        )

    return keys, motion


def pose_lines(poses, order, notes):
    out = []
    for name in order:
        body = ", ".join("%s = %s" % (k, fmt(v)) for k, v in poses[name].items())
        out.append("-- %s\nlocal %s = { %s }" % (notes[name], name, body))
    return "\n".join(out)
