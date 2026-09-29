/*
  brace_json_numbers.js — 편집기용 JSON 파일의 카드 설명 속 **맨 숫자**를 전부
  `{ }`로 감싼다.

    node tools/brace_json_numbers.js <입력.json> <출력.json>

  규칙은 `tools/brace_numbers.luau`(소스 카드용)와 똑같이 맞췄다. 두 곳이
  다르게 감싸면 나중에 둘을 합칠 때 어긋난다.

    감싸지 않는 것
      1스킬 · 2스킬       스킬 번호지 값이 아니다
      16분음표 · 4분음표   음표 이름이지 값이 아니다
      레벨 2 / 레벨 2에서  레벨 번호를 가리킨다
      이미 [ ] · { } · ` ` 안에 있는 것
      한 글 안에서 백틱으로 한 번이라도 나온 말(스킬 이름)의 다른 자리
*/

const fs = require("fs");

const SKIP_SUFFIX = ["스킬", "분음표"];
const SKIP_PREFIX = ["레벨"];
const WORDISH = /[0-9A-Za-z가-힣]/;

function protectedMask(text) {
  const mask = new Array(text.length).fill(false);
  const backtickTerms = [];
  let i = 0;
  while (i < text.length) {
    const c = text[i];
    const close = c === "[" ? "]" : c === "{" ? "}" : c === "`" ? "`" : null;
    if (close) {
      const j = text.indexOf(close, i + 1);
      if (j >= 0) {
        for (let k = i; k <= j; k++) mask[k] = true;
        if (c === "`") backtickTerms.push(text.slice(i + 1, j));
        i = j + 1;
        continue;
      }
    }
    i++;
  }

  // 백틱으로 한 번이라도 나온 말은 그 글 안의 다른 자리도 보호한다.
  for (const term of backtickTerms) {
    if (!term) continue;
    let from = 0;
    for (;;) {
      const s = text.indexOf(term, from);
      if (s < 0) break;
      for (let k = s; k < s + term.length; k++) mask[k] = true;
      from = s + term.length;
    }
  }

  // "n분음표"는 음악 용어다. 앞에 붙은 숫자까지 통째로 보호한다.
  let from = 0;
  for (;;) {
    const s = text.indexOf("분음표", from);
    if (s < 0) break;
    let digitStart = s;
    while (digitStart > 0 && /[0-9]/.test(text[digitStart - 1])) digitStart--;
    for (let k = digitStart; k < s + 3; k++) mask[k] = true;
    from = s + 3;
  }

  return mask;
}

function wrapNumbers(input) {
  let text = input;
  let wrapped = 0;
  let i = 0;
  while (i < text.length) {
    const mask = protectedMask(text);
    const c = text[i];
    const signLen = c === "-" || c === "−" ? 1 : 0;
    const digitStart = i + signLen;
    if (!/[0-9]/.test(text[digitStart] || "")) { i++; continue; }
    if (mask[digitStart] || mask[i]) { i++; continue; }

    let j = digitStart;
    while (j < text.length && /[0-9]/.test(text[j])) j++;
    if (text[j] === "." && /[0-9]/.test(text[j + 1] || "")) {
      j++;
      while (j < text.length && /[0-9]/.test(text[j])) j++;
    }
    const numEnd = j - 1;
    const numStart = i;
    const prev = numStart > 0 ? text[numStart - 1] : "";

    /*
      앞이 글자면 낱말의 일부다(예: "16분음표"의 6) — 감싸지 않는다.
      다만 `x`·`×`는 **곱셈 기호**다("음표수x3만큼"). 뒤의 숫자는 값이므로 감싼다.
    */
    let skip = false;
    if (WORDISH.test(prev) && !/[xX×]/.test(prev)) skip = true;
    for (const w of SKIP_SUFFIX) if (text.startsWith(w, numEnd + 1)) skip = true;
    for (const w of SKIP_PREFIX) {
      if (text.slice(numStart - w.length, numStart) === w) skip = true;
      if (text.slice(numStart - w.length - 1, numStart) === w + " ") skip = true;
    }

    if (skip) { i = numEnd + 1; continue; }

    const raw = text.slice(numStart, numEnd + 1);
    text = text.slice(0, numStart) + "{" + raw + "}" + text.slice(numEnd + 1);
    wrapped++;
    i = numEnd + 3;
  }
  return [text, wrapped];
}

const [, , inPath, outPath] = process.argv;
if (!inPath || !outPath) {
  console.error("사용법: node tools/brace_json_numbers.js <입력.json> <출력.json>");
  process.exit(1);
}

const data = JSON.parse(fs.readFileSync(inPath, "utf8"));
let cardCount = 0;
let numberCount = 0;

for (const id of Object.keys(data.cards || {})) {
  const card = data.cards[id];
  if (!card || typeof card.Description !== "string") continue;
  const [next, n] = wrapNumbers(card.Description);
  if (n > 0) {
    card.Description = next;
    cardCount++;
    numberCount += n;
  }
}

fs.writeFileSync(outPath, JSON.stringify(data, null, 2) + "\n", "utf8");
console.log(`[brace_json_numbers] 카드 ${cardCount}장 · 숫자 ${numberCount}개 감쌈 → ${outPath}`);
