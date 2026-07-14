'use strict';

const state = {
  playerName:        'PLAYER',
  playerId:          0,
  reputation:        0,
  redXP:             0,
  greenXP:           0,
  redTier:           { id: 'D', label: 'D Tier', minXP: 0, nextMinXP: 100 },
  greenAccessible:   [],
  contracts:         [],
  unlockedContracts: [],
  contractFilter:    [],
  allContractTypes:  [],
  leaderboard:       [],
  activeContract:    null,
  selectedContract:  null,
  filterDraft:       [],

  crewMembers:       [],
  crewSize:          1,
  maxSize:           4,
  isCrewLeader:      false,
  leaderName:        '',
  pendingInvite:     null,

  vehicleInfo:       null,
};

function post(ep, data) {
  return fetch(`https://${getResource()}/${ep}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {}),
  }).catch(() => {});
}
function getResource() {
  return (typeof GetParentResourceName !== 'undefined')
    ? GetParentResourceName()
    : 'm3_illegaltablet';
}

const IMG_PATHS = {
  fleeca:      'images/fleeca.png',
  shop:        'images/shop.png',
  allcars:     'images/allcars.png',
  smallhouse:  'images/smallhouse.png',
  mediumhouse: 'images/mediumhouse.png',
  luxuryhouse: 'images/luxuryhouse.png',
  bobcat:      'images/bobcat.png',
  atm:         'images/atm.png',
  warehouse:   'images/warehouse.png',
  group6:      'images/group6.png',
  humanlabs:   'images/humanlabs.png',
  jewelrystore:'images/jewelrystore.png',
};

function nuiImg(key) {
  return IMG_PATHS[key] || null;
}

(() => {
  for (const k in IMG_PATHS) {
    const im = new Image();
    im.src = IMG_PATHS[k];
  }
})();

window.addEventListener('message', (e) => {
  const { action, data } = e.data;
  if (!action) return;
  if (action === 'lockpick_start') {
    lpStart(data || {});
    return;
  }
  if (action === 'vehicleInfo') {

    state.vehicleInfo = data || null;
    applyVehicleInfo(data);
    return;
  }
  if (action === 'leaderboardData') {
    state.leaderboard = data || [];
    renderLeaderboard();
    return;
  }
  if (action === 'open') {
    applyData(data);
    const scene = document.getElementById('scene');
    if (!scene || scene.style.display === 'none') {
      showTablet();
    } else {
      scheduleRerender();
    }
  }
  if (action === 'update') { applyData(data); scheduleRerender(); }
  if (action === 'hide')   { hideTablet(); }
  if (action === 'crewInvite')    { receivedCrewInvite(data); }
  if (action === 'fearBar') {
    const bar  = document.getElementById('fear-bar');
    const fill = document.getElementById('fear-fill');
    if (!bar || !fill) return;
    const pct = data.pct || 0;
    if (pct <= 0) {
      bar.classList.add('fear-hidden');
    } else {
      bar.classList.remove('fear-hidden');
      fill.style.width = (pct * 100).toFixed(1) + '%';
    }
  }
});

function applyData(d) {
  if (!d) return;
  if (d.playerName        !== undefined) state.playerName        = d.playerName;
  if (d.playerId          !== undefined) state.playerId          = d.playerId;
  if (d.reputation        !== undefined) state.reputation        = d.reputation;
  if (d.redXP             !== undefined) state.redXP             = d.redXP;
  if (d.greenXP           !== undefined) state.greenXP           = d.greenXP;
  if (d.redTier           !== undefined) state.redTier           = d.redTier;
  if (d.greenAccessible   !== undefined) state.greenAccessible   = d.greenAccessible;
  if (d.contracts         !== undefined) state.contracts         = d.contracts;
  if (d.unlockedContracts !== undefined) state.unlockedContracts = d.unlockedContracts;
  if (d.contractFilter    !== undefined) state.contractFilter    = d.contractFilter;
  if (d.allContractTypes  !== undefined) state.allContractTypes  = d.allContractTypes;
  if (d.activeContract    !== undefined) {
    state.activeContract = d.activeContract;
    if (!d.activeContract) {

      state.vehicleInfo  = null;
      state.crewMembers  = [];
      state.crewSize     = 1;
      state.isCrewLeader = false;
      state.leaderName   = null;
    }
  }
  if (d.leaderboard            !== undefined) state.leaderboard            = d.leaderboard;
  if (d.crewMembers       !== undefined) state.crewMembers       = d.crewMembers;
  if (d.crewSize          !== undefined) state.crewSize          = d.crewSize;
  if (d.maxSize           !== undefined) state.maxSize           = d.maxSize;
  if (d.isCrewLeader      !== undefined) state.isCrewLeader      = d.isCrewLeader;
  if (d.leaderName        !== undefined) state.leaderName        = d.leaderName;
  if (d.receivingEnabled  !== undefined) setReceivingUI(d.receivingEnabled === true);
  if (d.initAsLeader) {

    const myName = state.playerName || 'player';
    state.crewMembers  = [{ name: myName, isLeader: true }];
    state.crewSize     = 1;
    state.maxSize      = state.maxSize || 4;
    state.isCrewLeader = true;
    state.leaderName   = myName;
  }
}

let timerInterval  = null;
let timerRemaining = 0;

function startTimer(seconds) {
  stopTimer();
  timerRemaining = seconds;
  updateTimerDisplay();
  timerInterval = setInterval(() => {
    timerRemaining = Math.max(0, timerRemaining - 1);
    updateTimerDisplay();
    if (timerRemaining === 0) stopTimer();
  }, 1000);
}
function stopTimer() {
  if (timerInterval) { clearInterval(timerInterval); timerInterval = null; }
}
function updateTimerDisplay() {
  const h  = Math.floor(timerRemaining / 3600);
  const m  = Math.floor((timerRemaining % 3600) / 60);
  const s  = timerRemaining % 60;
  const str = [h, m, s].map(n => String(n).padStart(2, '0')).join(':');
  if (el('ac-timer-display')) el('ac-timer-display').textContent = str;
}

let _hideTimer       = null;
let _openAnimHandler = null;
let _closeAnimHandler = null;

function _clearTabletAnimListeners(wrap) {
  if (_openAnimHandler)  { wrap.removeEventListener('animationend', _openAnimHandler);  _openAnimHandler  = null; }
  if (_closeAnimHandler) { wrap.removeEventListener('animationend', _closeAnimHandler); _closeAnimHandler = null; }
  if (_hideTimer) { clearTimeout(_hideTimer); _hideTimer = null; }
}

let _rerenderQueued = false;
function scheduleRerender() {
  const wrap = document.querySelector('.tablet-wrap');
  if (wrap && wrap.classList.contains('is-opening')) {
    _rerenderQueued = true;
    return;
  }
  refreshHeader(); rerenderActive();
}
function flushQueuedRerender() {
  if (!_rerenderQueued) return;
  _rerenderQueued = false;
  refreshHeader(); rerenderActive();
}

function showTablet() {
  const scene = document.getElementById('scene');
  const wrap  = document.querySelector('.tablet-wrap');

  _clearTabletAnimListeners(wrap);

  refreshHeader();

  if (state.activeContract && !timerInterval && state.activeContract.timeLimit)
    startTimer(state.activeContract.timeLimit);

  let page = lastPage || 'contracts';
  if (page === 'active-contract' && !state.activeContract) page = 'contracts';
  switchPage(page);

  wrap.classList.remove('is-closing', 'is-opening');
  void wrap.offsetWidth;
  wrap.classList.add('is-opening');

  _openAnimHandler = function(e) {
    if (e.animationName !== 'tablet-in') return;
    wrap.classList.remove('is-opening');
    wrap.removeEventListener('animationend', _openAnimHandler);
    _openAnimHandler = null;
    flushQueuedRerender();
  };
  wrap.addEventListener('animationend', _openAnimHandler);

  setTimeout(flushQueuedRerender, 700);

  scene.style.display = '';
}
function hideTablet() {
  const scene = document.getElementById('scene');
  const wrap  = document.querySelector('.tablet-wrap');

  closeFilter();
  closeDetail();

  _clearTabletAnimListeners(wrap);

  wrap.classList.remove('is-opening', 'is-closing');
  void wrap.offsetWidth;
  wrap.classList.add('is-closing');

  const finish = () => {
    if (_hideTimer) { clearTimeout(_hideTimer); _hideTimer = null; }
    if (_closeAnimHandler) { wrap.removeEventListener('animationend', _closeAnimHandler); _closeAnimHandler = null; }
    wrap.classList.remove('is-closing');
    scene.style.display = 'none';
  };

  _closeAnimHandler = function(e) {
    if (e.animationName !== 'tablet-out') return;
    finish();
  };
  wrap.addEventListener('animationend', _closeAnimHandler);
  _hideTimer = setTimeout(finish, 350);
}
function closeSelf() {
  post('close');
  hideTablet();
}

function refreshHeader() {
  const name = (state.playerName || 'PLAYER').toUpperCase();
  const initial = name[0] || 'U';

  el('player-name-top').textContent = name;
  el('profile-name').textContent    = state.playerName;
  el('profile-letter').textContent  = initial;

  if (el('profile-avatar-big'))  el('profile-avatar-big').textContent  = initial;
  if (el('profile-fullname-big')) el('profile-fullname-big').textContent = state.playerName;

  const bar = el('active-contract-bar');
  if (bar) {
    if (state.activeContract) {
      bar.style.display = 'flex';
      if (el('active-contract-name'))
        el('active-contract-name').textContent = state.activeContract.label || '–';
    } else {
      bar.style.display = 'none';
      stopTimer();
    }
  }
}

function rerenderActive() {
  const activePage = document.querySelector('.page.active')?.id?.replace('page-', '');
  if (activePage) renderPage(activePage);
}

let lastPage = 'contracts';

function switchPage(page) {
  lastPage = page;
  closeNameModal();
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  const pg = document.getElementById('page-' + page);
  if (pg) pg.classList.add('active');

  const nv = document.querySelector(`.nav-item[data-page="${page}"]`);
  if (nv) nv.classList.add('active');
  renderPage(page);
}

function renderPage(page) {
  if (page === 'contracts')        renderContracts();
  if (page === 'leaderboard')      requestLeaderboard();
  if (page === 'profile')          renderProfile();
  if (page === 'active-contract')  renderActiveContract();
}

let isReceiving = false;

function setReceivingUI(enabled) {
  isReceiving = enabled;
  const btn = el('btn-toggle-contracts');
  if (!btn) return;
  if (isReceiving) {
    btn.className = 'btn btn-danger';
    btn.innerHTML = svgX(12) + ' Stop Receiving';
  } else {
    btn.className = 'btn btn-good';
    btn.innerHTML = `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12l5 5 11-12"/></svg> Start Receiving`;
  }
}

function toggleReceiving() {
  setReceivingUI(!isReceiving);
  post('setReceiving', { enabled: isReceiving });
}

function openNameModal() {
  const inp = el('name-modal-input');
  if (inp) { inp.value = state.playerName || ''; }
  el('modal-name').style.display = '';
  setTimeout(() => { if (inp) { inp.focus(); inp.select(); } }, 80);
}

function closeNameModal() {
  const m = el('modal-name');
  if (m) m.style.display = 'none';
}

function confirmNameModal() {
  const inp = el('name-modal-input');
  if (!inp) return;
  const newName = inp.value.trim();
  if (newName.length >= 2 && newName.length <= 30) {
    state.playerName = newName;
    post('setPlayerName', { name: newName });
    refreshHeader();
    if (el('profile-fullname-big')) el('profile-fullname-big').textContent = newName;
  }
  closeNameModal();
}

function onNameModalKey(e) {
  if (e.key === 'Enter')  { e.preventDefault(); confirmNameModal(); }
  if (e.key === 'Escape') { e.preventDefault(); closeNameModal();   }
}

function renderProfile() {
  const name    = state.playerName || 'PLAYER';
  const initial = name[0].toUpperCase();

  if (el('profile-avatar-big'))   el('profile-avatar-big').textContent   = initial;
  if (el('profile-fullname-big')) el('profile-fullname-big').textContent = name;

  if (el('profile-id-val')) {
    const pid = state.playerId || 0;
    el('profile-id-val').textContent = pid > 0 ? String(pid).padStart(4, '0') : '----';
  }

  if (el('profile-green-xp')) el('profile-green-xp').textContent = fmt(state.greenXP || 0);
  if (el('profile-red-xp'))   el('profile-red-xp').textContent   = fmt(state.redXP   || 0);

  const grid = el('unlock-grid');
  if (!grid) return;
  grid.innerHTML = '<div style="grid-column:1/-1;display:flex;justify-content:center;padding:32px 0"><div class="lb-spinner"></div></div>';

  requestAnimationFrame(() => {
    const types = state.allContractTypes || [];
    if (!types.length) {
      grid.innerHTML = '<p style="color:var(--text-2);font-size:12px">No contract data available.</p>';
      return;
    }

    grid.innerHTML = '';
    types.forEach(t => {
      const unlocked = !t.blocked;
      const card = document.createElement('div');
      card.className = 'ucn ' + (unlocked ? 'ucn-unlocked' : 'ucn-locked');

      let xpLine = '';
      if (!unlocked && t.minXP) {
        const curXP = t.xpType === 'red' ? (state.redXP || 0) : (state.greenXP || 0);
        xpLine = `<div class="ucn-xp">${fmt(curXP)} / ${fmt(t.minXP)} XP</div>`;
      }

      card.innerHTML = `
        <div class="ucn-img"></div>
        <div class="ucn-body">
          <div class="ucn-name">${escHtml(t.label)}</div>
          <div class="ucn-status">${unlocked ? '✓ UNLOCKED' : '⊘ LOCKED'}</div>
          ${xpLine}
        </div>`;

      const imgDiv = card.querySelector('.ucn-img');
      const imgSrc = unlockImage(t.id);
      if (imgSrc) {
        imgDiv.style.backgroundImage    = 'url(' + imgSrc + ')';
        imgDiv.style.backgroundSize     = 'cover';
        imgDiv.style.backgroundPosition = 'center';
      } else {
        imgDiv.style.background = unlockBg(t.id);
      }

      grid.appendChild(card);
    });
  });
}

function renderContracts() {
  const list = el('contracts-list');
  const noC  = el('no-contracts');
  list.innerHTML = '';

  if (!state.contracts.length) {
    noC.style.display = '';
    return;
  }
  noC.style.display = 'none';

  state.contracts.forEach(c => {
    const card = document.createElement('div');
    card.className = 'contract-card';
    card.onclick = () => openDetail(c);

    const timeStr = fmtTime(c.timeLimit || 0);
    const imgSrc  = contractImage(c);

    const items = c.requiredItems || [];
    const gearStr = items.map(i => (typeof i === 'object' ? (i.label || i.item) : i)).join(', ');
    const bottomHtml = gearStr
      ? `<div class="cc-gear-lbl">Required equipment</div>
         <div class="cc-gear-val">${escHtml(gearStr)}</div>`
      : '';

    if (imgSrc) {
      card.style.backgroundImage    = `url("${imgSrc}")`;
      card.style.backgroundSize     = 'cover';
      card.style.backgroundPosition = 'center';
      card.style.backgroundRepeat   = 'no-repeat';
    } else {
      card.style.background = contractFallbackBg(c);
    }

    card.innerHTML = `
      <div class="cc-overlay"></div>
      <div class="cc-top">
        <div class="cc-title">${escHtml(c.label)}</div>
        <div class="cc-timer">${svgClock(10)} ${timeStr}</div>
      </div>
      <div class="cc-bottom">${bottomHtml}</div>`;
    list.appendChild(card);
  });
}

function boostingDesc(c) {
  if (!c) return '';
  const parts = ['Find the vehicle inside the marked zone on your map and break in with a lockpick.'];

  if (c.needsHack) {
    const n = c.hackCount ? `${c.hackCount}x` : 'a few times';
    parts.push(`This one runs a tracker - get in and hack it ${n} with a hacking laptop, otherwise the police keep seeing roughly where you are.`);
  }

  const where = (c.deliveryPoint && c.deliveryPoint.label) ? ` at ${c.deliveryPoint.label}` : '';
  parts.push(`Then drive it to the buyer${where} and hand it over. Bring it in one piece - a wrecked car will not be accepted.`);

  if (c.isSpecial) {
    parts.push('The buyer wants this one tuned, so it pays extra.');
  }
  return parts.join(' ');
}

function renderVehicleQuote(info) {
  const q = el('ac-quote');
  if (!q) return;
  const c = state.activeContract;

  const raw = (c && c.vehicleModel) || '';
  const mdl = raw ? raw.charAt(0).toUpperCase() + raw.slice(1) : 'Vehicle';

  const details = info
    ? `${info.color} ${info.model}  ·  Plate: ${info.plate}`
    : `${mdl}  ·  loading details…`;

  const desc = boostingDesc(c);
  q.innerHTML =
    `<div class="ac-veh-line">${escHtml(details)}</div>` +
    (desc ? `<div class="ac-task-line">${escHtml(desc)}</div>` : '');
  q.style.display = '';
}

function applyVehicleInfo(info) {
  renderVehicleQuote(info);
  const tag = el('ac-special-tag');
  if (tag) tag.style.display = info && info.isSpecial ? '' : 'none';
}

function renderActiveContract() {
  const c = state.activeContract;
  if (!c) { switchPage('contracts'); return; }

  const artBg = contractArtBg(c);
  const typeLabel = contractTypeTxt(c);

  if (el('ac-title'))     el('ac-title').textContent     = (c.label || 'CONTRACT').toUpperCase();
  if (el('ac-art-label')) el('ac-art-label').textContent = (c.label || 'CONTRACT').toUpperCase();
  const art = el('ac-art');
  if (art) {
    const imgSrc = contractImage(c);
    if (imgSrc) {
      art.style.backgroundImage    = `url("${imgSrc}")`;
      art.style.backgroundSize     = 'cover';
      art.style.backgroundPosition = 'center';
      art.style.backgroundRepeat   = 'no-repeat';
    } else {
      art.style.background = artBg;
    }
  }

  const crewSz = state.crewSize || 1;

  if (el('ac-crew-count')) el('ac-crew-count').textContent = String(crewSz);
  if (el('ac-crew-max'))   el('ac-crew-max').textContent   = String(state.maxSize || 4);

  const crewList = el('ac-crew-list');
  if (crewList) {
    crewList.innerHTML = '';
    (state.crewMembers || []).forEach((member, idx) => {

      const name     = (typeof member === 'object') ? member.name     : member;
      const isLeader = (typeof member === 'object') ? member.isLeader : false;
      const row = document.createElement('div');
      row.className = 'ac-crew-member' + (isLeader ? ' ac-crew-leader-row' : '');

      const showKick = state.isCrewLeader && !isLeader;
      row.innerHTML = `
        <div class="ac-crew-avatar">${(name[0] || '?').toUpperCase()}</div>
        <span class="ac-crew-name">${escHtml(name)}</span>
        ${showKick ? `<button class="ac-crew-kick-btn" onclick="kickMember(${idx})" title="Kick from crew">${svgX(11)}</button>` : '<span class="ac-crew-kick-btn" style="visibility:hidden"></span>'}`;
      crewList.appendChild(row);
    });
  }

  if (el('ac-type'))       el('ac-type').textContent      = typeLabel;
  if (el('ac-time-limit')) el('ac-time-limit').textContent = fmtTime(c.timeLimit || 0);

  const rewardPill = el('ac-reward-pill');
  if (rewardPill) rewardPill.style.display = 'none';

  let displayLeader = String(state.leaderName || state.playerName || 'player').replace(/^@+/, '');
  if (el('ac-username')) el('ac-username').textContent = ('@' + displayLeader).toLowerCase();

  if (c.type === 'vehicle_theft') {
    if (state.vehicleInfo) {

      applyVehicleInfo(state.vehicleInfo);
    } else {

      renderVehicleQuote(null);
      const tag = el('ac-special-tag');
      if (tag) tag.style.display = c.isSpecial ? '' : 'none';
    }
  } else {
    const tag = el('ac-special-tag');
    if (tag) tag.style.display = 'none';
    const q = el('ac-quote');
    if (q) {
      const desc = contractDesc(c);
      q.textContent = desc ? `"${desc}"` : '';
      q.style.display = desc ? '' : 'none';
    }
  }

  if (!timerInterval && c.timeLimit && timerRemaining <= 0) {
    startTimer(c.timeLimit);
  }
}

function contractDesc(c) {
  if (c.type === 'vehicle_theft') {

    return null;
  }
  if (c.type === 'robbery') {
    const m = {
      fleeca:      'Hack the panel by the vault door, then get past the bars with a second hack. Inside you will find cash trolleys - take what you can from each and leave. The police respond fast, so do not dawdle.',
      bobcat:      'Hack the entry panel to get inside. Armed guards are waiting - deal with them. Plant C4 on the vault door, wait for the blast and grab the weapons from the crates. What you take is yours.',
      atm:         'You will find several ATMs at the marked spots. Hack each one with a device, take the contents and move to the next. Speed matters - once you are spotted, the police catch up sooner than you think.',
      supermarket: 'Enter the store and intimidate the cashier - the longer you hold out, the more they fill the bag. Once the bag is full, grab it and vanish. Do not drag it out, the neighbors love to call.',
      truck:       'A Gruppe 6 truck is delivering cash across the city right now. Watch the circle on the map, catch up to it and take out the crew. Then plant C4 on the rear doors, blow them and grab the money bags. The police arrive fast - have a getaway car.',
      jewelry:     'Vangelico has full display cases, but the doors hold. Drill the lock - the moment it gives, an alert goes to the police. Then smash the cases, grab jewelry, diamonds and watches, and vanish before they arrive.',
      humanelabs:  'Humane Labs hides chemicals that sell for gold on the street. Hack the entry panel - from that moment the police and the armed security inside know about you. Search the chemical crates, break open the cooling box and take the research sample.',
    };
    return m[c.robberyKey] || 'Pull off the robbery and vanish before backup arrives.';
  }
  if (c.type === 'burglary') {
    const m = {
      small_house:  'Break into the house with a lockpick. Inside, search the marked spots - one of them holds my item, which you then hand to my guy. Keep whatever else you find, it is yours.',
      house:        'A lockpick gets you inside. Search several rooms - somewhere in there is the item I need. Once you find it, hand it over at the agreed spot. The rest of the loot - jewelry, laptop, whatever - is yours.',
      luxury_house: 'The owners have money, so the lock is tougher. A lockpick still gets you in. Inside there are more spots to search - look for my item among them. Keep the rest - diamonds, jewelry, watches.',
      warehouse:    'The warehouse is bigger, so there are more crates. Break in with a lockpick, search as many crates as you can and find the item I need. The rest - ammo, goods, C4 - is yours. Watch the clock.',
    };
    return m[c.burglaryKey] || 'Break in with a lockpick, search the place, find my item and hand it over. Keep the rest of the loot.';
  }
  return '';
}

function contractFallbackBg(c) {
  if (c.type === 'vehicle_theft') {
    const m = {
      S: 'linear-gradient(135deg,#2a0a1a,#130620)',
      A: 'linear-gradient(135deg,#1a0a2a,#0e0615)',
      B: 'linear-gradient(135deg,#0a1a2a,#060e15)',
      C: 'linear-gradient(135deg,#0a2a1a,#06150e)',
      D: 'linear-gradient(135deg,#1a1a2a,#0e0e15)',
    };
    return m[c.category] || m.D;
  }
  if (c.type === 'robbery') {
    const m = {
      bobcat: 'linear-gradient(135deg,#2a0a0a,#150606)',
      atm:    'linear-gradient(135deg,#1a2a0a,#0e1506)',
      fleeca: 'linear-gradient(135deg,#0a1a2a,#060e15)',
      supermarket: 'linear-gradient(135deg,#1a1020,#0e0812)',
      truck:   'linear-gradient(135deg,#0a2a2a,#061515)',
      jewelry: 'linear-gradient(135deg,#241a05,#120d03)',
      humanelabs: 'linear-gradient(135deg,#052416,#03120b)',
    };
    return m[c.robberyKey] || 'linear-gradient(135deg,#1a1020,#0e0812)';
  }
  if (c.type === 'burglary') {
    const m = {
      warehouse:       'linear-gradient(135deg,#1a0a20,#0e0612)',
    };
    return m[c.burglaryKey] || 'linear-gradient(135deg,#1a1a10,#0e0e08)';
  }
  return 'linear-gradient(135deg,#1a1a2e,#0e0e1f)';
}

function contractImage(c) {
  if (c.type === 'vehicle_theft') return nuiImg('allcars');
  if (c.type === 'robbery') {
    const m = { fleeca: 'fleeca', supermarket: 'shop', bobcat: 'bobcat', atm: 'atm', jewelry: 'jewelrystore', humanelabs: 'humanlabs', truck: 'group6' };
    return m[c.robberyKey] ? nuiImg(m[c.robberyKey]) : null;
  }
  if (c.type === 'burglary') {
    const m = {
      small_house:  'smallhouse',
      house:        'mediumhouse',
      better_house: 'mediumhouse',
      luxury_house: 'luxuryhouse',
      warehouse:    'warehouse',
    };
    return m[c.burglaryKey] ? nuiImg(m[c.burglaryKey]) : null;
  }
  return null;
}

function contractArtBg(c) {
  return contractFallbackBg(c);
}

function unlockImage(typeId) {
  const m = {
    vehicle_D:              'allcars',
    vehicle_C:              'allcars',
    vehicle_B:              'allcars',
    vehicle_A:              'allcars',
    vehicle_S:              'allcars',
    robbery_jewelry:        'jewelrystore',
    robbery_fleeca:         'fleeca',
    robbery_bobcat:         'bobcat',
    robbery_supermarket:    'shop',
    robbery_atm:            'atm',
    robbery_truck:          'group6',
    robbery_humanelabs:     'humanlabs',
    burglary_small_house:   'smallhouse',
    burglary_house:         'mediumhouse',
    burglary_better_house:  'mediumhouse',
    burglary_luxury_house:  'luxuryhouse',
    burglary_warehouse:     'warehouse',
  };
  return m[typeId] ? nuiImg(m[typeId]) : null;
}

function unlockBg(typeId) {
  if (typeId.startsWith('vehicle_'))         return 'linear-gradient(135deg,#1a1a2a,#0e0e15)';
  if (typeId === 'robbery_bobcat')            return 'linear-gradient(135deg,#2a0a0a,#150606)';
  if (typeId === 'robbery_fleeca')            return 'linear-gradient(135deg,#0a1a2a,#060e15)';
  if (typeId === 'robbery_atm')              return 'linear-gradient(135deg,#1a2a0a,#0e1506)';
  if (typeId === 'robbery_truck')            return 'linear-gradient(135deg,#0a2a2a,#061515)';
  if (typeId === 'robbery_jewelry')          return 'linear-gradient(135deg,#241a05,#120d03)';
  if (typeId === 'robbery_humanelabs')       return 'linear-gradient(135deg,#052416,#03120b)';
  if (typeId.startsWith('robbery_'))         return 'linear-gradient(135deg,#1a1020,#0e0812)';
  if (typeId === 'burglary_warehouse')        return 'linear-gradient(135deg,#1a0a20,#0e0612)';
if (typeId.startsWith('burglary_'))        return 'linear-gradient(135deg,#1a1a10,#0e0e08)';
  return 'linear-gradient(135deg,#1a1a2e,#0e0e1f)';
}

function contractTypeTxt(c) {
  if (c.type === 'vehicle_theft') return 'Boosting';
  if (c.type === 'robbery')       return 'Robbery';
  if (c.type === 'burglary')      return 'Burglary';
  return 'Contract';
}

function openDetail(c, isActive) {
  state.selectedContract = c;

  const art = el('cm-art');
  if (art) {
    const imgSrc = contractImage(c);
    if (imgSrc) {
      art.style.backgroundImage    = `url("${imgSrc}")`;
      art.style.backgroundSize     = 'cover';
      art.style.backgroundPosition = 'center';
      art.style.backgroundRepeat   = 'no-repeat';
    } else {
      art.style.background = contractFallbackBg(c);
    }
  }

  el('detail-title').textContent = c.label;

  const sub = el('detail-sub');
  if (sub) {
    const parts = [contractTypeTxt(c)];
    if (c.category)  parts.push('Tier ' + c.category);
    if (c.timeLimit) parts.push(fmtTime(c.timeLimit));
    sub.textContent = parts.join('  ·  ');
    sub.style.display = '';
  }

  const q = el('detail-question');
  if (q) q.textContent = `Do you really want to accept "${c.label}"?`;

  const btnAccept = el('btn-accept-contract');
  const lblAccept = el('detail-accept-label');

  if (isActive) {
    btnAccept.style.display = 'none';
  } else if (state.activeContract) {

    btnAccept.style.display = '';
    btnAccept.disabled = true;
    btnAccept.className = 'cm-btn cm-btn-accept is-disabled';
    if (lblAccept) lblAccept.innerHTML =
      `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M8 12h8"/></svg>
       You have an active contract`;
  } else {
    btnAccept.style.display = '';
    btnAccept.disabled = false;
    btnAccept.className = 'cm-btn cm-btn-accept';
    if (lblAccept) lblAccept.innerHTML =
      `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12l5 5 11-12"/></svg>
       Accept`;
  }

  el('modal-detail').style.display = '';
}

function flashAcceptError(msg) {
  const btn = el('btn-accept-contract');
  const lbl = el('detail-accept-label');
  if (!btn || !lbl) return;
  const oc = btn.className, oh = lbl.innerHTML;
  btn.className = 'cm-btn cm-btn-accept is-error';
  lbl.innerHTML = `${svgX(12)} ${msg}`;
  btn.disabled = true;
  setTimeout(() => { btn.className = oc; lbl.innerHTML = oh; btn.disabled = false; }, 1600);
}
function closeDetail() {
  el('modal-detail').style.display = 'none';
  state.selectedContract = null;
}
function acceptFromDetail() {
  if (!state.selectedContract) return;

  if (state.activeContract) {
    flashAcceptError('You already have an active contract');
    return;
  }

  post('acceptContract', { id: state.selectedContract.id });
  state.activeContract = state.selectedContract;

  state.crewMembers  = [{ name: state.playerName || 'player', isLeader: true }];
  state.crewSize     = 1;
  state.isCrewLeader = true;
  state.leaderName   = state.playerName || 'player';
  closeDetail();
  refreshHeader();

  if (state.activeContract.timeLimit)
    startTimer(state.activeContract.timeLimit);
  switchPage('active-contract');
}
function kickMember(idx) {
  const member = (state.crewMembers || [])[idx];
  if (!member) return;
  const name = (typeof member === 'object') ? member.name : member;
  if (!name) return;
  post('kickCrewMember', { name });
  state.crewMembers.splice(idx, 1);
  state.crewSize = Math.max(1, (state.crewSize || 1) - 1);
  refreshHeader();
  renderActiveContract();
}

function cancelContract() {
  post('cancelContract');
  state.activeContract = null;
  state.vehicleInfo    = null;
  state.crewMembers    = [];
  state.crewSize       = 1;
  stopTimer();
  refreshHeader();
  switchPage('contracts');
}

function openInviteModal() {

  if (state.pendingInvite) { openReceiveInviteModal(); return; }
  const inp = el('invite-id-input');
  if (inp) inp.value = '';
  el('modal-invite').style.display = '';
  setTimeout(() => { if (inp) inp.focus(); }, 80);
}
function closeInviteModal() {
  el('modal-invite').style.display = 'none';
}
function sendInvite() {
  const inp = el('invite-id-input');
  if (!inp) return;
  const raw = inp.value.replace(/\D/g, '');
  if (raw.length !== 4) {
    inp.style.borderColor = 'var(--bad)';
    setTimeout(() => { inp.style.borderColor = ''; }, 1200);
    return;
  }
  post('inviteToCrew', { playerId: parseInt(raw, 10) });
  closeInviteModal();
}

function receivedCrewInvite(data) {
  state.pendingInvite = data;

  const bell = el('topbar-bell');
  if (bell) bell.style.display = '';

  if (bell) { bell.classList.remove('bell-ring'); void bell.offsetWidth; bell.classList.add('bell-ring'); }
}

function openReceiveInviteModal() {
  const inv = state.pendingInvite;
  if (!inv) return;

  const leaderName    = inv.leaderName    || '?';
  const contractLabel = inv.contractLabel || '–';
  const contractType  = inv.contractType  || '';
  if (el('ci-avatar'))          el('ci-avatar').textContent          = (leaderName[0] || '?').toUpperCase();
  if (el('ci-leader-name'))     el('ci-leader-name').textContent     = leaderName;
  if (el('ci-contract-label'))  el('ci-contract-label').textContent  = contractLabel;
  if (el('ci-contract-type'))   el('ci-contract-type').textContent   = contractType;
  if (el('ci-subtitle'))        el('ci-subtitle').textContent        = leaderName + ' is inviting you to a crew';
  el('modal-crew-invite').style.display = '';
}

function closeReceiveInviteModal() {
  el('modal-crew-invite').style.display = 'none';
}

function respondInvite(accepted) {
  const inv = state.pendingInvite;
  if (!inv) return;
  state.pendingInvite = null;

  const bell = el('topbar-bell');
  if (bell) bell.style.display = 'none';
  if (bell) bell.classList.remove('bell-ring');
  closeReceiveInviteModal();
  post('respondToCrewInvite', { leaderSrc: inv.leaderSrc, accepted });
}

function openFilter() {

  if (state.contractFilter == null) {
    state.filterDraft = getFilterTypes().filter(t => !t.blocked).map(t => t.id);
  } else {
    state.filterDraft = [...state.contractFilter];
  }
  renderFilterGrid();
  el('modal-filter').style.display = '';
}
function closeFilter() {
  el('modal-filter').style.display = 'none';
}

let sharesData  = {};
let sharesOrder = [];

function openShares() {

  const members = state.crewMembers || [];
  if (members.length > 0 && typeof members[0] === 'object') {
    sharesOrder = members.map(m => m.name);
  } else {

    const leader = state.playerName || 'Ja';
    sharesOrder = [leader, ...members];
  }
  _equalShares();
  _renderShares();
  el('modal-shares').style.display = '';
}
function closeShares() {
  el('modal-shares').style.display = 'none';
}

function _equalShares() {
  const n    = sharesOrder.length;
  const base = Math.floor(100 / n);
  const rem  = 100 - base * n;
  sharesOrder.forEach((name, i) => { sharesData[name] = base + (i === 0 ? rem : 0); });
}
function resetSharesEqual() { _equalShares(); _renderShares(); }

function _renderShares() {
  const list = el('shares-list');
  if (!list) return;
  list.innerHTML = '';
  const solo = sharesOrder.length === 1;
  sharesOrder.forEach((name, idx) => {
    const pct      = sharesData[name] ?? 0;
    const isLeader = idx === 0;
    const row = document.createElement('div');
    row.className = 'shares-row' + (isLeader ? ' is-leader' : '');
    row.innerHTML = `
      <div class="shares-avatar">${(name[0] || '?').toUpperCase()}</div>
      <div class="shares-name">
        ${escHtml(name)}

      </div>
      <div class="shares-input-wrap">
        <input type="number" class="shares-input" min="0" max="100" value="${pct}"
               data-idx="${idx}" ${solo ? 'disabled' : ''}
               oninput="onShareInput(this)">
        <span class="shares-pct-sym">%</span>
      </div>`;
    list.appendChild(row);
  });
}

function onShareInput(input) {
  const idx    = +input.dataset.idx;
  const name   = sharesOrder[idx];
  const newVal = Math.min(100, Math.max(0, parseInt(input.value, 10) || 0));
  input.value  = newVal;
  const others = sharesOrder.filter((_, i) => i !== idx);

  sharesData[name] = newVal;
  const remaining  = 100 - newVal;
  const othersSum  = others.reduce((s, n) => s + (sharesData[n] ?? 0), 0);

  if (others.length === 0) {
    sharesData[name] = 100;
  } else if (othersSum === 0) {
    const base = Math.floor(remaining / others.length);
    const rem  = remaining - base * others.length;
    others.forEach((n, i) => { sharesData[n] = base + (i === 0 ? rem : 0); });
  } else {
    let spent = 0;
    others.forEach((n, i) => {
      if (i === others.length - 1) {
        sharesData[n] = Math.max(0, remaining - spent);
      } else {
        const share = Math.round((sharesData[n] / othersSum) * remaining);
        sharesData[n] = Math.max(0, share);
        spent += sharesData[n];
      }
    });
  }

  const rows = el('shares-list').querySelectorAll('.shares-row');
  rows.forEach((row, i) => {
    if (i === idx) return;
    const inp = row.querySelector('.shares-input');
    if (inp) inp.value = sharesData[sharesOrder[i]] ?? 0;
  });
}

function confirmShares() {
  const total = sharesOrder.reduce((s, n) => s + (sharesData[n] ?? 0), 0);
  if (total !== 100) return;
  post('setXpShares', sharesData);
  closeShares();
}
function saveFilter() {
  const allAccessible = getFilterTypes().filter(t => !t.blocked).map(t => t.id);

  const allOn = allAccessible.length > 0 && allAccessible.every(id => state.filterDraft.includes(id));
  state.contractFilter = allOn ? null : [...state.filterDraft];
  post('updateFilter', { filter: state.contractFilter });
  closeFilter();
}
function filterDisableAll() {
  state.filterDraft = [];
  renderFilterGrid();
}
function filterEnableAll() {
  const types = getFilterTypes();
  state.filterDraft = types.filter(t => !t.blocked).map(t => t.id);
  renderFilterGrid();
}

function renderFilterGrid() {
  const grid = el('filter-grid');
  grid.innerHTML = '';
  const types = getFilterTypes();
  const active = types.filter(t => state.filterDraft.includes(t.id) && !t.blocked).length;

  if (el('filter-active-count')) el('filter-active-count').textContent = active;
  if (el('filter-total-count'))  el('filter-total-count').textContent  = types.length;

  types.forEach(t => {
    const blocked  = !!t.blocked;
    const selected = !blocked && state.filterDraft.includes(t.id);
    const tile = document.createElement('button');
    tile.className = 'filter-tile ' + (blocked ? 'off' : (selected ? 'on' : 'off'));

    const iconSvg = selected
      ? svgBriefcase(14)
      : (blocked ? svgLock(14) : svgLock(14));

    tile.innerHTML = `
      <div class="filter-tile-icon">${iconSvg}</div>
      <div style="min-width:0">
        <div class="filter-tile-name">${escHtml(t.label)}</div>
        <div class="filter-tile-state">${blocked ? 'LOCKED' : (selected ? 'ACTIVE' : 'DISABLED')}</div>
      </div>`;

    if (!blocked) {
      tile.onclick = () => {
        const idx = state.filterDraft.indexOf(t.id);
        if (idx === -1) state.filterDraft.push(t.id);
        else            state.filterDraft.splice(idx, 1);
        renderFilterGrid();
      };
    } else {
      tile.style.cursor = 'not-allowed';
    }
    grid.appendChild(tile);
  });
}

function getFilterTypes() {
  if (state.allContractTypes?.length) return state.allContractTypes;
  const seen = {}, out = [];
  state.contracts.forEach(c => {
    const id = c.contractKey || c.id.replace(/_\d+$/, '');
    if (!seen[id]) { seen[id] = true; out.push({ id, label: c.label, blocked: false }); }
  });
  return out;
}

let lbActiveTab = 'burglaries';

function switchLbTab(tab) {
  lbActiveTab = tab;
  const tabB = el('lb-tab-burglaries');
  const tabC = el('lb-tab-cartheft');
  if (tabB) { tabB.classList.remove('active-green', 'active-red'); tabB.classList.toggle('active-green', tab === 'burglaries'); }
  if (tabC) { tabC.classList.remove('active-green', 'active-red'); tabC.classList.toggle('active-red',   tab === 'cartheft');   }
  if (state.leaderboard?.length) renderLeaderboard();
}

function requestLeaderboard() {
  const loading = el('lb-loading');
  const content = el('lb-content');
  if (loading) loading.style.display = 'block';
  if (content) content.style.display = 'none';
  post('fetchLeaderboard', {});
}

function renderLeaderboard() {
  const loading = el('lb-loading');
  const content = el('lb-content');
  if (loading) loading.style.display = 'none';
  if (content) content.style.display = 'block';

  const isCarTheft = lbActiveTab === 'cartheft';
  const xpKey   = isCarTheft ? 'redXP'   : 'greenXP';
  const xpLabel = isCarTheft ? 'Boosting XP'  : 'Burglary XP';

  const xpLabelEl = el('lb-xp-label');
  if (xpLabelEl) xpLabelEl.textContent = xpLabel;

  const body = el('lb-body');
  if (!body) return;
  body.innerHTML = '';

  const entries = state.leaderboard || [];
  if (!entries.length) {
    body.innerHTML = '<div style="color:var(--text-2);text-align:center;padding:20px;font-size:13px">No records yet.</div>';
    return;
  }

  const sorted = [...entries].sort((a, b) => (b[xpKey] || 0) - (a[xpKey] || 0));
  sorted.forEach((e, i) => {
    const rank    = i + 1;
    const name    = (e.playerName || '???').substring(0, 24);
    const xp      = e[xpKey] || 0;
    const rankStr = String(rank).padStart(2, '0');
    const rankCls = rank <= 3 ? ` r${rank}` : '';

    const row = document.createElement('div');
    row.className = 'lb-row' + (rank <= 3 ? ' podium' : '');
    row.innerHTML = `
      <div class="lb-rank${rankCls}">${rankStr}</div>
      <div><div class="lb-name">${escHtml(name)}</div></div>
      <div><div class="lb-stat-label">${xpLabel}</div><div class="lb-stat">${fmt(xp)}</div></div>`;
    body.appendChild(row);
  });
}

function el(id) { return document.getElementById(id); }
function fmt(n) { return Number(n || 0).toLocaleString('en-EN'); }
function fmtTime(s) {
  const m = Math.floor(s / 60), ss = s % 60;
  return m > 0 ? `${m}m ${ss}s` : `${ss}s`;
}
function escHtml(s) {
  return String(s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}


function svgCoin(s)     { return `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="#ffd060" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8v8"/><path d="M9.5 10.5h3.5a1.5 1.5 0 0 1 0 3H9.5"/></svg>`; }
function svgX(s)        { return `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>`; }
function svgPlay(s)     { return `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="currentColor"><path d="M7 5l12 7-12 7V5Z"/></svg>`; }
function svgClock(s)    { return `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>`; }
function svgUsers(s)    { return `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.5"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6"/><circle cx="17" cy="9" r="2.5"/><path d="M15.5 14.5c2.6.5 5.5 2 5.5 5.5"/></svg>`; }
function svgBriefcase(s){ return `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2"/><path d="M3 13h18"/></svg>`; }
function svgLock(s)     { return `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>`; }


document.addEventListener('keydown', e => {
  if (e.key !== 'Escape') return;
  const filterOpen = el('modal-filter')?.style.display !== 'none';
  const detailOpen = el('modal-detail')?.style.display !== 'none';
  const inviteOpen = el('modal-invite')?.style.display !== 'none';
  const nameOpen   = el('modal-name')?.style.display   !== 'none';
  if (filterOpen) { closeFilter();      return; }
  if (detailOpen) { closeDetail();      return; }
  if (inviteOpen) { closeInviteModal(); return; }
  if (nameOpen)   { closeNameModal();   return; }
  closeSelf();
});




const lp = {
  minRot: -90, maxRot: 90,
  solveDeg: 0, solvePadding: 4, maxDistFromSolve: 45,
  pinRot: 0, cylRot: 0,
  lastMouseX: 0, mouseSmoothing: 2,
  keyRepeatRate: 25, cylRotSpeed: 3,
  pinDamage: 20, pinHealth: 100, pinDamageInterval: 150,
  userPushingCyl: false, gameOver: false, gamePaused: false,
  cylInterval: null, pinLastDamaged: null,
  active: false,
};

function lpClamp(v, mn, mx) { return Math.min(Math.max(v, mn), mx); }
function lpRange(v, oMin, oMax, nMin, nMax) {
  return ((v - oMin) * (nMax - nMin)) / (oMax - oMin) + nMin;
}

function lpEl(id) { return document.getElementById(id); }

function lpStart(cfg) {
  cfg = cfg || {};
  lp.solveDeg         = Math.random() * 180 - 90;
  lp.maxDistFromSolve = cfg.maxDistFromSolve ?? 45;
  lp.pinDamage        = cfg.pinDamage        ?? 20;
  lp.pinRot = 0; lp.cylRot = 0; lp.lastMouseX = 0;
  lp.pinHealth = 100; lp.pinLastDamaged = null;
  lp.userPushingCyl = false; lp.gameOver = false; lp.gamePaused = false;
  clearInterval(lp.cylInterval); lp.cylInterval = null;
  lp.active = true;

  lpEl('lp-wrap').style.display = 'flex';
  lpResetVisual();
}

function lpHide() {
  lp.active = false;
  clearInterval(lp.cylInterval);
  lpEl('lp-wrap').style.display = 'none';
}

function lpResetVisual() {
  const pin = lpEl('lp-pin');
  if (!pin) return;
  pin.querySelector('.lp-pin-top').classList.remove('lp-breaking-top');
  pin.querySelector('.lp-pin-bott').classList.remove('lp-breaking-bott');
  lpEl('lp-pin').style.transform      = 'rotateZ(0deg)';
  lpEl('lp-cylinder').style.transform = 'rotateZ(0deg)';
  lpEl('lp-driver').style.transform   = 'rotateZ(0deg)';
}

function lpApplyPin() {
  const pin = lpEl('lp-pin');
  if (pin) pin.style.transform = `rotateZ(${lp.pinRot}deg)`;
}

function lpApplyCyl() {
  const r = lp.cylRot;
  const cyl = lpEl('lp-cylinder'); if (cyl) cyl.style.transform = `rotateZ(${r}deg)`;
  const drv = lpEl('lp-driver');   if (drv) drv.style.transform = `rotateZ(${r}deg)`;
}

function lpPush() {
  clearInterval(lp.cylInterval);
  lp.userPushingCyl = true;

  const dist      = lpClamp(Math.abs(lp.pinRot - lp.solveDeg) - lp.solvePadding, 0, lp.maxDistFromSolve);
  const allowance = lpRange(dist, 0, lp.maxDistFromSolve, 1, 0.02) * lp.maxRot;

  lp.cylInterval = setInterval(() => {
    lp.cylRot += lp.cylRotSpeed;
    if (lp.cylRot >= lp.maxRot) {
      lp.cylRot = lp.maxRot;
      clearInterval(lp.cylInterval);
      lpUnlock();
    } else if (lp.cylRot >= allowance) {
      lp.cylRot = allowance;
      lpDamagePin();
    }
    lpApplyCyl();
  }, lp.keyRepeatRate);
}

function lpRelease() {
  lp.userPushingCyl = false;
  clearInterval(lp.cylInterval);
  lp.cylInterval = setInterval(() => {
    lp.cylRot = Math.max(lp.cylRot - lp.cylRotSpeed, 0);
    lpApplyCyl();
    if (lp.cylRot <= 0) { lp.cylRot = 0; clearInterval(lp.cylInterval); }
  }, lp.keyRepeatRate);
}

function lpDamagePin() {
  const now = Date.now();
  if (lp.pinLastDamaged && now - lp.pinLastDamaged < lp.pinDamageInterval) return;
  lp.pinLastDamaged = now;
  lp.pinHealth -= lp.pinDamage;


  const pin = lpEl('lp-pin');
  if (pin) {
    pin.style.transform = `rotateZ(${lp.pinRot - 2}deg)`;
    setTimeout(() => { if (pin) pin.style.transform = `rotateZ(${lp.pinRot}deg)`; },
      lp.pinDamageInterval / 4);
  }
  if (lp.pinHealth <= 0) lpBreakPin();
}

function lpBreakPin() {
  lp.gamePaused = true;
  clearInterval(lp.cylInterval);
  const pin = lpEl('lp-pin');
  if (pin) {
    pin.querySelector('.lp-pin-top').classList.add('lp-breaking-top');
    pin.querySelector('.lp-pin-bott').classList.add('lp-breaking-bott');
  }

  setTimeout(() => {
    lpHide();
    post('lockpickFailed', {});
  }, 700);
}

function lpUnlock() {
  lp.gameOver = true;
  lpHide();
  post('lockpickSucceed', {});
}


const LP_KEYS = new Set([87, 65, 83, 68, 37, 39]); // WASD + ←→

document.addEventListener('mousemove', (e) => {
  if (!lp.active || lp.gameOver || lp.gamePaused) { lp.lastMouseX = e.clientX; return; }
  if (lp.lastMouseX !== 0) {
    lp.pinRot += (e.clientX - lp.lastMouseX) / lp.mouseSmoothing;
    lp.pinRot = lpClamp(lp.pinRot, lp.minRot, lp.maxRot);
    lpApplyPin();
  }
  lp.lastMouseX = e.clientX;
});

document.addEventListener('keydown', (e) => {
  if (!lp.active || lp.userPushingCyl || lp.gameOver || lp.gamePaused) return;
  if (LP_KEYS.has(e.keyCode)) { e.preventDefault(); lpPush(); }
});

document.addEventListener('keyup', (e) => {
  if (!lp.active || lp.gameOver) return;
  if (LP_KEYS.has(e.keyCode)) lpRelease();
});




if (window.location.protocol === 'file:' || window.location.hostname === 'localhost') {
  setTimeout(() => {
    applyData({
      playerName:  'Player',
      playerId:    123,
      reputation:  42,
      redXP:       350,
      greenXP:     280,
      redTier:     { id: 'C', label: 'C Tier', minXP: 300, nextMinXP: 700 },
      contracts: [
        { id:'vehicle_D_1', type:'vehicle_theft', category:'D', contractKey:'vehicle_D', label:'Boosting (D)', reward:5500, timeLimit:900,
          requiredItems:['Lockpick'] },
        { id:'vehicle_C_2', type:'vehicle_theft', category:'C', contractKey:'vehicle_C', label:'Boosting (C)', reward:11000, timeLimit:900,
          requiredItems:['Lockpick'] },
        { id:'burglary_small_house_4', type:'burglary', burglaryKey:'small_house', contractKey:'burglary_small_house', label:'Vykradenie domu', reward:3500, timeLimit:300,
          requiredItems:['Lockpick','Screwdriver'] },
        { id:'burglary_luxury_house_5', type:'burglary', burglaryKey:'luxury_house', contractKey:'burglary_luxury_house', label:'Luxury house burglary', reward:18000, timeLimit:480,
          requiredItems:['Lockpick','Screwdriver','EMP device'] },
        { id:'robbery_supermarket_6', type:'robbery', robberyKey:'supermarket', contractKey:'robbery_supermarket', label:'Shop robbery', reward:6000, timeLimit:300,
          requiredItems:['Weapon'] },
        { id:'robbery_fleeca_7', type:'robbery', robberyKey:'fleeca', contractKey:'robbery_fleeca', label:'Fleeca bank robbery', reward:30000, timeLimit:600,
          requiredItems:['Hacking Device'] },
      ],
      allContractTypes: [
        { id:'vehicle_D',  label:'Boosting (D)',   blocked:false, xpType:'red',   minXP:0   },
        { id:'vehicle_C',  label:'Boosting (C)',   blocked:false, xpType:'red',   minXP:100 },
        { id:'vehicle_B',  label:'Boosting (B)',   blocked:true,  xpType:'red',   minXP:300 },
        { id:'vehicle_A',  label:'Boosting (A)',   blocked:true,  xpType:'red',   minXP:700 },
        { id:'vehicle_S',  label:'Boosting (S)',   blocked:true,  xpType:'red',   minXP:1500 },
        { id:'robbery_jewelry',      label:'Jewelry Store Robbery',  blocked:false, xpType:'green', minXP:0   },
        { id:'robbery_fleeca',       label:'Fleeca Bank Robbery',    blocked:true,  xpType:'green', minXP:500 },
        { id:'robbery_bobcat',       label:'BobCat Security Heist',  blocked:true,  xpType:'green', minXP:800 },
        { id:'robbery_supermarket',  label:'Supermarket Robbery',    blocked:false, xpType:'green', minXP:0   },
        { id:'robbery_atm',          label:'ATM Run',                blocked:true,  xpType:'green', minXP:300 },
        { id:'burglary_small_house', label:'Small House Burglary',   blocked:false, xpType:'green', minXP:0   },
        { id:'burglary_house',       label:'House Burglary',         blocked:false, xpType:'green', minXP:100 },
        { id:'burglary_better_house',label:'Better House Burglary',  blocked:true,  xpType:'green', minXP:400 },
        { id:'burglary_luxury_house',label:'Luxury House Burglary',  blocked:true,  xpType:'green', minXP:700 },
{ id:'burglary_warehouse',   label:'Warehouse Burglary',     blocked:false, xpType:'green', minXP:150 },
      ],
      contractFilter: ['vehicle_D','vehicle_C','burglary_small_house','burglary_warehouse'],
      leaderboard: [
        { rank:1, playerName:'Esmeralda Cruz',  identifier:'esme',    redXP:310, greenXP:202 },
        { rank:2, playerName:'Pablo Serrano',   identifier:'pablo',   redXP:220, greenXP:160 },
        { rank:3, playerName:'Ryan O\'Connor',  identifier:'ryan',    redXP:130, greenXP:90  },
        { rank:4, playerName:'Player',        identifier:'player',redXP:70,  greenXP:50  },
      ],
      activeContract: { id:'robbery_jewelry_3', type:'robbery', robberyKey:'jewelry', contractKey:'robbery_jewelry', label:'Jewelry Store Robbery', timeLimit:586 },
      crewMembers: ['Pablo Serrano', 'Ryan O\'Connor'],
      crewSize:    3,
      maxSize:     4,
    });
    showTablet();
  }, 200);
}
