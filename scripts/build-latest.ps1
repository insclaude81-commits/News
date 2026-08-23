<#
  brief-latest.html 생성기

  날짜별 brief-YYYY-MM-DD.html 들을 읽어 하나의 고정 주소 페이지로 합친다.
  최신 날짜가 기본으로 열리고, 상단 날짜 칩을 눌러 지난 날짜를 볼 수 있다.

  사용:
    powershell -ExecutionPolicy Bypass -File build-latest.ps1 -BriefDir "<보관 폴더>"

  역할 분담:
    날짜별 파일  내용만 담는다. <div class="wrap"> 안쪽이 그날의 브리핑이다.
    이 스크립트  상단 바(검색·헤드라인 모드·날짜 레일)와 조작 스크립트를 붙인다.
    색 토큰과 컴포넌트 CSS는 가장 최신 날짜 파일의 <style> 을 그대로 쓴다.
    그래서 템플릿 디자인을 바꾸면 다음 실행 때 자동으로 따라간다.

  파일이 많아지면 무거워지므로 -Keep 으로 포함할 날짜 수를 정한다(기본 14).
  잘려 나간 날짜도 폴더에는 그대로 남으므로 아카이브가 사라지지는 않는다.
#>

param(
  [Parameter(Mandatory = $true)][string]$BriefDir,
  [int]$Keep = 14
)

$ErrorActionPreference = 'Stop'

$files = Get-ChildItem -Path $BriefDir -Filter 'brief-????-??-??.html' |
         Sort-Object Name -Descending |
         Select-Object -First $Keep

if (-not $files) { throw "brief-YYYY-MM-DD.html 파일을 찾지 못했습니다: $BriefDir" }

$dayNames = @('일','월','화','수','목','금','토')

# 최신 파일에서 폰트 링크와 스타일을 가져온다
$newest = Get-Content $files[0].FullName -Raw -Encoding UTF8
$headMatch = [regex]::Match($newest, '(?s)^(.*?)<div class="wrap">')
if (-not $headMatch.Success) { throw "최신 파일에서 <div class=""wrap""> 를 찾지 못했습니다." }
$head = $headMatch.Groups[1].Value

# 제목은 고정 주소용으로 바꾼다
$head = [regex]::Replace($head, '<title>.*?</title>', '<title>모닝 브리프</title>')

$days  = New-Object System.Collections.Generic.List[string]
$chips = New-Object System.Collections.Generic.List[string]
$dates = New-Object System.Collections.Generic.List[string]
$i = 0

foreach ($f in $files) {
  $raw = Get-Content $f.FullName -Raw -Encoding UTF8

  $m = [regex]::Match($raw, '(?s)<div class="wrap">(.*)</div>')
  if (-not $m.Success) { Write-Warning "건너뜀(구조 불일치): $($f.Name)"; continue }
  $inner = $m.Groups[1].Value

  # 혹시 남아 있는 스크립트 조각 제거. 스크립트는 페이지에 하나만 둔다.
  $inner = [regex]::Replace($inner, '(?s)<script>.*?</script>', '')

  # id 중복 방지. 앵커는 data-sec 으로 바꾸고 JS가 처리한다.
  $inner = [regex]::Replace($inner, 'id="(tech|market|domestic|world|insight|desk)"', 'data-sec="$1"')
  $inner = [regex]::Replace($inner, 'href="#(tech|market|domestic|world|insight|desk)"', 'data-goto="$1"')

  $date  = $f.BaseName -replace '^brief-', ''
  $dt    = [datetime]::ParseExact($date, 'yyyy-MM-dd', $null)
  $label = "{0}.{1:00}" -f $dt.Month, $dt.Day
  $full  = "{0}월 {1}일 ({2})" -f $dt.Month, $dt.Day, $dayNames[[int]$dt.DayOfWeek]
  $act   = if ($i -eq 0) { ' active' } else { '' }

  $days.Add("<section class=""day$act"" data-date=""$date"" data-label=""$label"" data-full=""$full"">$inner</section>")
  $chips.Add("<button type=""button"" class=""dchip$act"" data-target=""$date"" title=""$full"">$label</button>")
  $dates.Add($date)
  $i++
}

$firstLabel = if ($chips.Count) { ([regex]::Match($chips[0], '>([^<]+)</button>')).Groups[1].Value } else { '' }

$shellCss = @'
<style>
  /* ══════ 상단 바와 날짜 전환. build-latest.ps1 이 붙인다 ══════ */
  .progress {
    position: fixed; top: 0; left: 0; height: 3px; width: 0;
    background: var(--accent); z-index: 60; transition: width .08s linear;
  }
  @media (prefers-reduced-motion: reduce) { .progress { transition: none; } }

  .topbar { position: sticky; top: 0; z-index: 50; background: var(--bg); border-bottom: 1px solid var(--rule); }
  @supports (backdrop-filter: blur(8px)) {
    .topbar { background: color-mix(in srgb, var(--bg) 88%, transparent); backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px); }
  }
  .tb-row { display: flex; align-items: center; gap: 8px; max-width: 860px; margin: 0 auto; padding: 9px 16px; }
  .tb-badge {
    font-family: 'IBM Plex Mono', ui-monospace, monospace;
    font-size: 11px; font-weight: 600; letter-spacing: .08em;
    color: var(--onsolid); background: var(--accent);
    border-radius: 4px; padding: 5px 8px; flex: none; font-variant-numeric: tabular-nums;
  }
  .tb-field { position: relative; flex: 1; min-width: 0; }
  .tb-field input {
    width: 100%; box-sizing: border-box; font-family: 'Noto Sans KR', sans-serif;
    font-size: 16px; color: var(--ink); background: var(--surface);
    border: 1px solid var(--rule); border-radius: 8px;
    padding: 9px 34px 9px 13px; -webkit-appearance: none; appearance: none;
  }
  .tb-field input::placeholder { color: var(--ink-3); }
  .tb-field input:focus { outline: 2px solid var(--accent); outline-offset: -1px; }
  .tb-field input::-webkit-search-cancel-button { display: none; }
  .tb-x {
    position: absolute; right: 4px; top: 50%; transform: translateY(-50%);
    width: 28px; height: 28px; border: none; background: none;
    color: var(--ink-3); font-size: 14px; cursor: pointer; border-radius: 50%;
  }
  .tb-btn {
    flex: none; font-family: 'IBM Plex Mono', ui-monospace, monospace;
    font-size: 11px; letter-spacing: .04em; color: var(--ink-2); background: var(--surface);
    border: 1px solid var(--rule); border-radius: 8px; padding: 10px 11px; cursor: pointer; min-height: 40px;
  }
  .tb-btn.on { color: var(--onsolid); background: var(--accent); border-color: var(--accent); }
  .tb-count {
    max-width: 860px; margin: 0 auto; padding: 0 16px 9px;
    font-family: 'IBM Plex Mono', ui-monospace, monospace; font-size: 11px; color: var(--ink-3);
  }

  .date-rail {
    display: flex; align-items: center; gap: 6px;
    max-width: 860px; margin: 0 auto; padding: 0 16px 9px;
    overflow-x: auto; scrollbar-width: none;
  }
  .date-rail::-webkit-scrollbar { display: none; }
  .rail-label {
    flex: none; font-family: 'IBM Plex Mono', ui-monospace, monospace;
    font-size: 10px; letter-spacing: .14em; text-transform: uppercase;
    color: var(--ink-3); margin-right: 4px;
  }
  .dchip {
    flex: none; font-family: 'IBM Plex Mono', ui-monospace, monospace;
    font-size: 11.5px; font-variant-numeric: tabular-nums; letter-spacing: .04em;
    color: var(--ink-2); background: var(--surface);
    border: 1px solid var(--rule); border-radius: 999px;
    padding: 6px 13px; cursor: pointer; min-height: 32px;
  }
  .dchip:hover { border-color: var(--accent); color: var(--accent); }
  .dchip.active { color: var(--onsolid); background: var(--accent); border-color: var(--accent); }
  .dchip:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }

  .day { display: none; }
  .day.active { display: block; }

  .s-hide { display: none !important; }
  mark { background: var(--neu-bg); color: var(--ink); border-radius: 2px; padding: 0 2px; }
  body.searching .masthead,
  body.searching .tape,
  body.searching .stat-row,
  body.searching .verdict,
  body.searching .notice,
  body.searching .round,
  body.searching .wrapup,
  body.searching .disclaimer,
  body.searching .empty,
  body.searching .zone-head p,
  body.searching footer { display: none; }
  body.searching .zone, body.searching .desk, body.searching .section { margin: 26px 0; }
  body.searching .desk { padding: 20px 17px; }

  body.headlines-only .story { padding: 12px 0; }
  body.headlines-only .story > p,
  body.headlines-only .story .why,
  body.headlines-only .story .src { display: none; }
  body.headlines-only .story.expanded > p,
  body.headlines-only .story.expanded .why,
  body.headlines-only .story.expanded .src { display: block; }
  body.headlines-only .story h3 { margin-bottom: 0; cursor: pointer; }
  body.headlines-only .story.lead h3 { font-size: 18px; font-weight: 700; }
  body.headlines-only .story h3::after { content: " ▾"; color: var(--ink-3); font-size: 12px; }
  body.headlines-only .story.expanded h3::after { content: " ▴"; }
  body.headlines-only .story.expanded > p { margin-top: 10px; }

  body.is-narrow .tile { cursor: pointer; }
  body.is-narrow .tile .s-thesis { display: none; }
  body.is-narrow .tile.open .s-thesis { display: block; }
  body.is-narrow .tile .s-name::after { content: " ▾"; color: var(--ink-3); font-size: 12px; font-weight: 500; }
  body.is-narrow .tile.open .s-name::after { content: " ▴"; }
  body.is-narrow .board { gap: 7px; }

  .fab {
    position: fixed; right: 16px; bottom: 18px; z-index: 55;
    width: 46px; height: 46px; border-radius: 50%; border: 1px solid var(--rule);
    background: var(--surface); color: var(--ink-2); box-shadow: var(--shadow-lg);
    font-size: 17px; cursor: pointer; display: none; place-items: center;
  }
  .fab.show { display: grid; }

  .jump { display: none; }
  .section, .zone, .desk { scroll-margin-top: 132px; }
  .wrap { padding-top: 22px; }
  @media (max-width: 640px) {
    .src a, .item a { padding: 3px 0; display: inline-block; }
    .watch li { padding: 14px 0; }
  }
</style>
'@

$shellTop = @"
<div class="progress" id="prog"></div>

<div class="topbar">
  <div class="tb-row">
    <span class="tb-badge" id="tbBadge">$firstLabel</span>
    <div class="tb-field">
      <input id="tbSearch" type="search" placeholder="브리핑 안에서 검색" autocomplete="off" aria-label="브리핑 내 검색">
      <button id="tbClear" class="tb-x" type="button" aria-label="검색어 지우기" hidden>✕</button>
    </div>
    <button id="tbMode" class="tb-btn" type="button" aria-pressed="false">헤드라인</button>
  </div>
  <nav class="date-rail" id="dateRail" aria-label="날짜 선택">
    <span class="rail-label">날짜</span>
    $($chips -join "`n    ")
  </nav>
  <div class="tb-count" id="tbCount" hidden></div>
</div>

<button class="fab" id="fab" type="button" aria-label="맨 위로">↑</button>
"@

$shellJs = @'
<script>
(function () {
  'use strict';
  var d = document, b = d.body;

  if (!d.querySelector('meta[name="viewport"]')) {
    var mv = d.createElement('meta');
    mv.name = 'viewport';
    mv.content = 'width=device-width, initial-scale=1, viewport-fit=cover';
    d.head.appendChild(mv);
  }

  var UNITS = ['.story', '.item', '.tile', '.tenor', '.curve-box', '.short-case',
               '.watch li', '.turn', '.accord ol li', '.accord-foot div'];
  var VISIBLE = UNITS.map(function (s) { return s + ':not(.s-hide)'; }).join(', ');
  var CONTAINERS = '.section, .block, .analyst, .zone, .desk, .accord';

  [].forEach.call(d.querySelectorAll(UNITS.join(', ')), function (u) { u._orig = u.innerHTML; });

  var input = d.getElementById('tbSearch'),
      clearBtn = d.getElementById('tbClear'),
      modeBtn = d.getElementById('tbMode'),
      countEl = d.getElementById('tbCount'),
      badge = d.getElementById('tbBadge'),
      rail = d.getElementById('dateRail'),
      prog = d.getElementById('prog'),
      fab = d.getElementById('fab');

  function activeDay() { return d.querySelector('.day.active'); }
  function unitsIn(root) { return [].slice.call(root.querySelectorAll(UNITS.join(', '))); }

  function highlight(root, q) {
    var walker = d.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode: function (n) {
        if (!n.nodeValue) return NodeFilter.FILTER_REJECT;
        var p = n.parentNode && n.parentNode.nodeName;
        if (p === 'SCRIPT' || p === 'STYLE' || p === 'MARK') return NodeFilter.FILTER_REJECT;
        return n.nodeValue.toLowerCase().indexOf(q) === -1
          ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
      }
    });
    var hits = [], n;
    while ((n = walker.nextNode())) hits.push(n);
    hits.forEach(function (node) {
      var txt = node.nodeValue, low = txt.toLowerCase();
      var frag = d.createDocumentFragment(), i = 0, at;
      while ((at = low.indexOf(q, i)) !== -1) {
        if (at > i) frag.appendChild(d.createTextNode(txt.slice(i, at)));
        var m = d.createElement('mark');
        m.textContent = txt.slice(at, at + q.length);
        frag.appendChild(m);
        i = at + q.length;
      }
      if (i < txt.length) frag.appendChild(d.createTextNode(txt.slice(i)));
      node.parentNode.replaceChild(frag, node);
    });
  }

  function search(raw) {
    var day = activeDay();
    if (!day) return;
    var q = (raw || '').trim().toLowerCase();
    clearBtn.hidden = !q;
    b.classList.toggle('searching', !!q);

    var hits = 0;
    unitsIn(day).forEach(function (u) {
      u.innerHTML = u._orig;
      if (!q) { u.classList.remove('s-hide', 'open', 'expanded'); return; }
      if (u.textContent.toLowerCase().indexOf(q) !== -1) {
        u.classList.remove('s-hide');
        u.classList.add('open', 'expanded');
        highlight(u, q);
        hits++;
      } else {
        u.classList.add('s-hide');
      }
    });

    [].forEach.call(day.querySelectorAll(CONTAINERS), function (c) {
      if (!q) { c.classList.remove('s-hide'); return; }
      c.classList.toggle('s-hide', !c.querySelector(VISIBLE));
    });

    if (q) {
      countEl.hidden = false;
      countEl.textContent = hits
        ? '"' + raw.trim() + '" · ' + hits + '건 일치 (' + (day.dataset.full || '') + ')'
        : '"' + raw.trim() + '" · 일치하는 내용 없음 (' + (day.dataset.full || '') + ')';
    } else {
      countEl.hidden = true;
    }
  }

  var timer;
  input.addEventListener('input', function () {
    clearTimeout(timer);
    var v = input.value;
    timer = setTimeout(function () { search(v); }, 140);
  });
  input.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { input.value = ''; search(''); input.blur(); }
  });
  clearBtn.addEventListener('click', function () { input.value = ''; search(''); input.focus(); });

  modeBtn.addEventListener('click', function () {
    var on = b.classList.toggle('headlines-only');
    modeBtn.classList.toggle('on', on);
    modeBtn.setAttribute('aria-pressed', on ? 'true' : 'false');
    if (!on) {
      [].forEach.call(d.querySelectorAll('.story.expanded'), function (s) { s.classList.remove('expanded'); });
    }
  });

  d.addEventListener('click', function (e) {
    var t = e.target;
    if (!t || !t.closest) return;

    var chip = t.closest('.dchip');
    if (chip) { showDay(chip.dataset.target); return; }

    var goto = t.closest('[data-goto]');
    if (goto) {
      e.preventDefault();
      var day = activeDay();
      var sec = day && day.querySelector('[data-sec="' + goto.dataset.goto + '"]');
      if (sec) sec.scrollIntoView({ block: 'start', behavior: 'auto' });
      return;
    }

    var h = t.closest('.story h3');
    if (h && b.classList.contains('headlines-only')) { h.parentNode.classList.toggle('expanded'); return; }

    var tile = t.closest('.tile');
    if (tile && b.classList.contains('is-narrow')) tile.classList.toggle('open');
  });

  function showDay(date) {
    [].forEach.call(d.querySelectorAll('.day'), function (s) {
      s.classList.toggle('active', s.dataset.date === date);
    });
    [].forEach.call(rail.querySelectorAll('.dchip'), function (c) {
      c.classList.toggle('active', c.dataset.target === date);
    });
    var day = activeDay();
    if (badge && day) badge.textContent = day.dataset.label;
    if (input && input.value) { input.value = ''; search(''); }
    window.scrollTo({ top: 0, behavior: 'auto' });
    if (history.replaceState) history.replaceState(null, '', '#' + date);
  }

  function sizeCheck() { b.classList.toggle('is-narrow', window.innerWidth <= 640); }
  sizeCheck();
  window.addEventListener('resize', sizeCheck);

  var ticking = false;
  function onScroll() {
    var h = d.documentElement.scrollHeight - window.innerHeight;
    prog.style.width = (h > 0 ? (window.pageYOffset / h) * 100 : 0) + '%';
    fab.classList.toggle('show', window.pageYOffset > 700);
    ticking = false;
  }
  window.addEventListener('scroll', function () {
    if (!ticking) { ticking = true; window.requestAnimationFrame(onScroll); }
  }, { passive: true });
  onScroll();

  fab.addEventListener('click', function () {
    var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    window.scrollTo({ top: 0, behavior: reduce ? 'auto' : 'smooth' });
  });

  var want = (location.hash || '').replace('#', '');
  if (want && d.querySelector('.day[data-date="' + want + '"]')) showDay(want);
})();
</script>
'@

$out = $head + $shellCss + "`n" + $shellTop + "`n" +
       '<div class="wrap">' + "`n" + ($days -join "`n") + "`n" + '</div>' + "`n" +
       $shellJs + "`n"

$outPath = Join-Path $BriefDir 'brief-latest.html'
Set-Content -Path $outPath -Value $out -Encoding UTF8 -NoNewline

$kb = [math]::Round((Get-Item $outPath).Length / 1KB)
Write-Host "brief-latest.html 생성 완료: $($days.Count)일치, ${kb}KB"
Write-Host "포함 날짜: $($dates -join ', ')"
