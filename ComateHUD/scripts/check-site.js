#!/usr/bin/env node
'use strict';
// 官网渲染自检。
//
// 为什么需要它：index.html 的版本记录行 / 下载区 / 更新日志都是 JS 从 versions.json
// 渲染出来的。纯静态站点没有构建产物可测，而下面三类问题在页面上不一定报错、肉眼也看不出来：
//   1. 改了元素 id 却漏改 JS（getElementById 拿到 null，静默不渲染）
//   2. 渲染值与 versions.json 脱节（数据源换了，页面还显示旧的）
//   3. 字段缺失时回落到硬编码（AGENTS.md 明令禁止写死版本号 / DMG 体积）
// 办法只有一个：把 index.html 里那段真实的脚本，放到最小 DOM 桩上跑一遍，断言渲染结果。
//
// 用法: node ComateHUD/scripts/check-site.js
// 退出码: 0 全部通过；1 有失败项（失败详情逐条打印）

const fs = require('fs');
const path = require('path');

const HUD_DIR = path.resolve(__dirname, '..');
const HTML_PATH = path.join(HUD_DIR, 'index.html');
const VERSIONS_PATH = path.join(HUD_DIR, 'versions.json');

let checks = 0;
let failures = 0;

function ok(cond, name, detail) {
  checks += 1;
  if (cond) {
    console.log('  \u2713 ' + name);
  } else {
    failures += 1;
    console.log('  \u2717 ' + name + (detail ? '  -> 实际: ' + detail : ''));
  }
}

// 版本渲染脚本是内联的；靠 rl-ver 这个只属于它的 id 定位，不依赖注释（注释可能被压缩掉）
function extractVersionScript(html) {
  const blocks = [...html.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g)].map(function (m) { return m[1]; });
  return blocks.find(function (b) { return b.includes('rl-ver'); }) || null;
}

function collectIds(html) {
  return new Set([...html.matchAll(/\bid="([^"]+)"/g)].map(function (m) { return m[1]; }));
}

function makeElement(id) {
  const el = Object.create(null);
  el.id = id;
  el.textContent = '';
  el.innerHTML = '';
  el.hidden = false;
  el.href = '';
  el.setAttribute = function () { return null; };
  el.removeAttribute = function () { return null; };
  el.addEventListener = function () { return null; };
  el.appendChild = function () { return null; };
  el.querySelector = function () { return null; };
  el.querySelectorAll = function () { return []; };
  el.style = Object.create(null);
  el.classList = Object.create(null);
  el.classList.add = function () { return null; };
  el.classList.remove = function () { return null; };
  return el;
}

// 元素缺失时给一个「隐藏且无文本」的替身：断言会给出干净的 ✗，而不是抛 TypeError
function hiddenStub(id) {
  const stub = makeElement('__missing_' + id + '__');
  stub.hidden = true;
  return stub;
}

class StubObserver {
  constructor(cb, opts) { this.cb = cb; this.opts = opts; }
  observe() { return null; }
  unobserve() { return null; }
  disconnect() { return null; }
}

// 把页面真实脚本放到 DOM 桩上执行，返回各元素最终状态。
// 脚本是异步渲染的（fetch().then()），所以等一个 tick 再取状态。
function runPage(html, versions) {
  const script = extractVersionScript(html);
  if (!script) return Promise.resolve({ error: '未找到含 rl-ver 的内联脚本' });

  const els = new Map();
  collectIds(html).forEach(function (id) { els.set(id, makeElement(id)); });

  const generic = makeElement('__generic__');
  generic.querySelector = function () { return generic; };
  els.forEach(function (el) { el.querySelector = function () { return generic; }; });

  const stubDocument = {
    getElementById: function (id) { return els.get(id) || generic; },
    querySelector: function () { return generic; },
    querySelectorAll: function () { return []; },
    addEventListener: function () { return null; },
    createElement: function () { return makeElement('__created__'); },
    readyState: 'complete',
    hidden: false,
    body: generic,
    documentElement: generic
  };
  const stubWindow = {
    addEventListener: function () { return null; },
    innerWidth: 1280,
    innerHeight: 900,
    matchMedia: function () { return { matches: false, addEventListener: function () { return null; } }; }
  };
  const warnings = [];
  const stubConsole = {
    warn: function () { warnings.push(Array.prototype.join.call(arguments, ' ')); },
    log: function () { return null; },
    error: function () { return null; }
  };
  const stubFetch = function () {
    return Promise.resolve({ json: function () { return Promise.resolve(versions); } });
  };

  try {
    new Function('document', 'window', 'fetch', 'console', 'IntersectionObserver', script)(
      stubDocument, stubWindow, stubFetch, stubConsole, StubObserver);
  } catch (e) {
    return Promise.resolve({ error: '页面脚本执行报错: ' + e.message });
  }
  return new Promise(function (resolve) {
    setTimeout(function () {
      resolve({
        els: { get: function (id) { return els.get(id) || hiddenStub(id); } },
        warnings: warnings
      });
    }, 60);
  });
}

function report() {
  console.log('');
  if (failures === 0) {
    console.log('全部通过 (' + checks + ' 项)');
    process.exit(0);
  }
  console.log(failures + ' / ' + checks + ' 项失败');
  process.exit(1);
}

async function main() {
  const html = fs.readFileSync(HTML_PATH, 'utf8');
  const versions = JSON.parse(fs.readFileSync(VERSIONS_PATH, 'utf8'));
  const first = versions.versions[0];

  console.log('官网渲染自检');
  console.log('  HTML:     ' + HTML_PATH);
  console.log('  数据源:   ' + VERSIONS_PATH + ' (v' + first.version + ' build ' + first.build + ')');
  console.log('');

  // 1) 脚本能定位到
  const script = extractVersionScript(html);
  ok(script !== null, 'index.html 里有负责渲染版本的脚本');
  if (!script) { report(); return; }

  // 2) 脚本引用的每个 id 都真实存在 —— 抓「改 id 漏改 JS」
  const staticIds = collectIds(html);
  const refs = [...script.matchAll(/getElementById\(\s*['"]([^'"]+)['"]\s*\)/g)].map(function (m) { return m[1]; });
  const uniqRefs = [...new Set(refs)];
  const missing = uniqRefs.filter(function (id) { return !staticIds.has(id); });
  ok(missing.length === 0, '脚本引用的 ' + uniqRefs.length + ' 个 id 在 HTML 中都存在', missing.join(', '));

  // 3) 版本号 / 体积不许硬编码进 HTML
  const verTag = /<span[^>]*id="rl-ver"[^>]*>([\s\S]*?)<\/span>/.exec(html);
  ok(verTag !== null && verTag[1].trim() === '',
    'rl-ver 标签静态内容为空（版本号只能由 versions.json 驱动）',
    verTag ? JSON.stringify(verTag[1]) : '没找到 rl-ver 标签');

  // 4) latest 不能回退（官网首屏版本取自 latest）
  ok(versions.latest === first.version, 'versions.json 的 latest 等于首项版本',
    versions.latest + ' vs ' + first.version);

  // 5) 真实数据渲染
  const run = await runPage(html, versions);
  if (run.error) { ok(false, '页面脚本可执行', run.error); report(); return; }
  const e = run.els;
  ok(e.get('rl-ver').textContent === 'v' + first.version,
    '版本号渲染为 v' + first.version, e.get('rl-ver').textContent);
  ok(e.get('rl-date').textContent === first.date,
    '更新日期渲染为 ' + first.date, e.get('rl-date').textContent);
  ok(e.get('rl-build').textContent === 'build ' + first.build,
    'build 渲染为 build ' + first.build, e.get('rl-build').textContent);
  ok(!e.get('rl-build').hidden && !e.get('rl-sep-build').hidden, '有 build 时 build 与分隔符可见');
  ok(!e.get('release-line').hidden, '版本记录行整行可见');
  ok(e.get('dl-size-text').textContent === first.size,
    '安装包体积渲染为 ' + first.size + '（取自 versions.json）', e.get('dl-size-text').textContent);
  ok(e.get('dl-btn').href === first.download,
    '下载按钮指向 ' + first.download, e.get('dl-btn').href);
  ok(String(e.get('version-list').innerHTML).includes('v' + first.version),
    '更新日志列表含当前版本条目');
  ok(run.warnings.length === 0, '渲染过程无 console.warn', run.warnings.join(' | '));

  // 6) 字段缺失时不回落硬编码：把 build / size 抽掉再跑一次
  const sparse = JSON.parse(JSON.stringify(versions));
  delete sparse.versions[0].build;
  sparse.versions[0].size = '-';
  const run2 = await runPage(html, sparse);
  if (run2.error) { ok(false, '字段缺失的副本可执行', run2.error); report(); return; }
  const e2 = run2.els;
  ok(e2.get('rl-build').hidden && e2.get('rl-sep-build').hidden,
    'versions.json 缺 build 时 build 与分隔符整段隐藏（不回落硬编码）');
  ok(e2.get('dl-size').hidden, "size 为 '-' 时体积整条隐藏（不回落硬编码）");
  ok(e2.get('rl-ver').textContent === 'v' + first.version,
    '缺字段时版本号仍正确渲染', e2.get('rl-ver').textContent);

  report();
}

main().catch(function (err) {
  console.log('\n\u2717 自检脚本自身报错: ' + err.message);
  process.exit(1);
});
