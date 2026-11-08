// Longest-common-subsequence text diff → { left, right, ops[] } where ops are
// {type:'equal'|'del'|'ins', text} in left/right order. Hand-rolled, no deps.
export function lcs(a, b) {
  const n = a.length, m = b.length;
  const dp = Array.from({length: n+1}, () => new Array(m+1).fill(0));
  for (let i = n-1; i >= 0; i--) for (let j = m-1; j >= 0; j--) {
    dp[i][j] = a[i] === b[j] ? dp[i+1][j+1] + 1 : Math.max(dp[i+1][j], dp[i][j+1]);
  }
  const ops = [];
  let i = 0, j = 0;
  while (i < n && j < m) {
    if (a[i] === b[j]) { ops.push({type:'equal', text:a[i]}); i++; j++; }
    else if (dp[i+1][j] >= dp[i][j+1]) { ops.push({type:'del', text:a[i]}); i++; }
    else { ops.push({type:'ins', text:b[j]}); j++; }
  }
  while (i < n) { ops.push({type:'del', text:a[i]}); i++; }
  while (j < m) { ops.push({type:'ins', text:b[j]}); j++; }
  return {left: a, right: b, ops};
}

export function diff(a, b) { return lcs(a, b); }

export function htmlDiff(a, b) {
  const {ops} = diff(a, b);
  const left = [], right = [];
  for (const op of ops) {
    if (op.type === 'equal') { left.push(op.text); right.push(op.text); }
    else if (op.type === 'del') left.push(op.text);
    else right.push(op.text);
  }
  const esc = s => s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  const spans = (arr) => {
    let out = '', last = 0;
    for (const op of ops) {
      if (op.type === 'equal') continue;
      if (op.type === 'del') { out += `<span class="bad">${esc(op.text)}</span>`; }
      if (op.type === 'ins') { out += `<span class="ok">${esc(op.text)}</span>`; }
    }
    return out;
  };
  const leftHtml = a.split('').map((c,i)=>ops[i]&&ops[i].type==='equal'?'':(ops[i]&&ops[i].type==='del'?`<span class="bad">${esc(c)}</span>`:esc(c))).join('');
  const rightHtml = b.split('').map((c,i)=>ops[i]&&ops[i].type==='equal'?'':(ops[i]&&ops[i].type==='ins'?`<span class="ok">${esc(c)}</span>`:esc(c))).join('');
  return {leftHtml, rightHtml};
}
