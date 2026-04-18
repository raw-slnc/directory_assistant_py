#!/usr/bin/env python3

import sys
sys.dont_write_bytecode = True

import argparse
import json
import os
os.environ.setdefault("PYTHONDONTWRITEBYTECODE", "1")
import platform
import subprocess
import threading
import time
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse


DEFAULT_PORT = 8742
DEFAULT_BIND = "127.0.0.1"
DA_VERSION = "2026-04-18.2"
VERSION = "0.1.0"

EXCLUDE = {
    ".DS_Store",
    ".server.pid",
    "DirectoryAssistant.bat",
    "DirectoryAssistant.command",
    "DirectoryAssistant.desktop",
    "DirectoryAssistant.py",
    "DirectoryAssistantPy.sh",
    "DirectoryAssistantPy.command",
    "DirectoryAssistantPy.bat",
}

EXCLUDE_DIRS = {
    "__pycache__",
    "backup",
    ".directoryassistant",
}

PID_FILENAME = ".server.pid"
HEARTBEAT_TIMEOUT_SEC = 30

last_ping = None
server_inst = None
shutdown_lock = threading.Lock()
shutdown_timer = None
shutdown_requested_at = None

HTML = """<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Directory Assistant</title>
  <link rel="icon" type="image/png" href="/icon.png">
  <link rel="apple-touch-icon" href="/icon.png">
  <style>
    :root {
      --bg:#f5f5f0; --sidebar-bg:#2d3a2e; --sidebar-text:#d8e8d9;
      --sidebar-accent:#7ab87d; --card-bg:#ffffff; --border:#d6e0d6;
      --text:#2c2c2c; --muted:#6b7c6b; --folder-color:#5a8a5c;
      --file-pdf:#d94f3d; --file-word:#2b5cb8; --file-excel:#1e7e3c;
      --file-other:#7a7a7a; --accent:#4a7a4c;
    }
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:'Hiragino Sans','Meiryo','Yu Gothic',sans-serif;
         background:var(--bg);color:var(--text);display:flex;height:100vh;overflow:hidden}
    #sidebar{width:260px;background:var(--sidebar-bg);color:var(--sidebar-text);
             display:flex;flex-direction:column;flex-shrink:0}
    #sidebar-header{padding:18px 16px 12px;border-bottom:1px solid rgba(255,255,255,.08)}
    #sidebar-eyebrow{font-size:10px;font-weight:700;letter-spacing:.1em;
                     text-transform:uppercase;color:var(--sidebar-accent);margin-bottom:5px}
    #project-name{font-size:13px;line-height:1.5;word-break:break-all}
    #sidebar-actions{padding:10px 12px;border-bottom:1px solid rgba(255,255,255,.06);display:flex;gap:6px}
    .btn{flex:1;padding:7px 8px;border:none;border-radius:6px;font-size:12px;font-family:inherit;
         cursor:pointer;font-weight:600;transition:background .15s,opacity .15s;
         display:flex;align-items:center;justify-content:center;gap:4px}
    .btn:disabled{opacity:.4;cursor:default}
    .btn:active:not(:disabled){transform:scale(.96)}
    .btn-ghost{background:rgba(255,255,255,.08);color:var(--sidebar-text)}
    .btn-ghost:hover:not(:disabled){background:rgba(255,255,255,.14)}
    .btn-danger{background:rgba(220,60,60,.18);color:#f08080}
    .btn-danger:hover:not(:disabled){background:rgba(220,60,60,.32);color:#ffaaaa}
    #search-wrap{padding:9px 12px;border-bottom:1px solid rgba(255,255,255,.06);position:relative}
    #search-icon{position:absolute;left:21px;top:50%;transform:translateY(-50%);
                 font-size:12px;opacity:.4;pointer-events:none}
    #search{width:100%;background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.1);
            border-radius:6px;padding:6px 8px 6px 28px;font-size:12px;
            color:var(--sidebar-text);font-family:inherit;outline:none}
    #search::placeholder{color:rgba(216,232,217,.3)}
    #search:focus{border-color:var(--sidebar-accent)}
    #stats{padding:8px 14px;font-size:11px;color:rgba(216,232,217,.4);
           border-bottom:1px solid rgba(255,255,255,.04)}
    #tree-container{flex:1;overflow-y:auto;padding:6px 0}
    #tree-container::-webkit-scrollbar{width:4px}
    #tree-container::-webkit-scrollbar-thumb{background:rgba(255,255,255,.12);border-radius:2px}
    .tree-item{user-select:none}
    .tree-row{display:flex;align-items:center;gap:3px;padding:4px 8px;cursor:pointer;
              border-radius:5px;margin:0 5px 1px;font-size:12.5px;line-height:1.4;
              color:rgba(216,232,217,.8);transition:background .1s}
    .tree-row:hover{background:rgba(122,184,125,.15);color:#d8e8d9}
    .tree-row.active{background:rgba(122,184,125,.22);color:#b8f0bb}
    .tree-toggle{width:13px;height:13px;flex-shrink:0;display:flex;align-items:center;
                 justify-content:center;font-size:8px;opacity:.55;transition:transform .18s}
    .tree-toggle.open{transform:rotate(90deg)}
    .tree-toggle.leaf{opacity:0;pointer-events:none}
    .tree-icon{font-size:13px;flex-shrink:0}
    .tree-label{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
    .tree-children{overflow:hidden;transition:max-height .22s ease-out,opacity .18s}
    .tree-children.closed{max-height:0!important;opacity:0}
    #sidebar-footer{padding:8px 12px;border-top:1px solid rgba(255,255,255,.06);display:flex;flex-direction:column;gap:4px}
    #main{flex:1;display:flex;flex-direction:column;overflow:hidden}
    #main-header{background:var(--card-bg);border-bottom:1px solid var(--border);
                 padding:13px 22px;display:flex;align-items:center;
                 justify-content:space-between;gap:12px;flex-shrink:0}
    #breadcrumb{font-size:13px;color:var(--muted);display:flex;align-items:center;
                gap:5px;flex-wrap:wrap;min-width:0}
    .bc-item{cursor:pointer;color:var(--accent);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .bc-item:hover{text-decoration:underline}
    .bc-current{color:var(--text);cursor:default;font-weight:500}
    .bc-sep{color:var(--border);flex-shrink:0}
    #folder-meta{font-size:12px;color:var(--muted);white-space:nowrap;flex-shrink:0}
    #content-area{flex:1;overflow-y:auto;padding:18px 22px}
    #content-area::-webkit-scrollbar{width:6px}
    #content-area::-webkit-scrollbar-thumb{background:var(--border);border-radius:3px}
    .section-label{font-size:11px;font-weight:700;letter-spacing:.06em;
                   color:var(--muted);text-transform:uppercase;margin-bottom:9px}
    .file-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));
               gap:9px;margin-bottom:22px}
    .file-card{background:var(--card-bg);border:1px solid var(--border);border-radius:10px;
               padding:13px;cursor:pointer;
               transition:border-color .15s,box-shadow .15s,transform .1s;
               display:flex;flex-direction:column;gap:7px}
    .file-card:hover{border-color:var(--accent);box-shadow:0 2px 12px rgba(74,122,76,.12);
                     transform:translateY(-1px)}
    .file-card:active{transform:scale(.98)}
    .file-card-icon{font-size:26px;line-height:1}
    .file-card-name{font-size:12px;line-height:1.45;word-break:break-all;
                    color:var(--text);font-weight:500}
    .file-card-ext{display:inline-block;font-size:10px;font-weight:700;letter-spacing:.04em;
                   padding:2px 6px;border-radius:3px;text-transform:uppercase;align-self:flex-start}
    .ext-pdf {background:#fce8e6;color:var(--file-pdf)}
    .ext-docx{background:#e6ecf8;color:var(--file-word)}
    .ext-xlsx{background:#e6f4eb;color:var(--file-excel)}
    .ext-dir {background:#eef4ee;color:var(--folder-color)}
    .ext-misc{background:#f0f0f0;color:var(--file-other)}
    #toast{position:fixed;bottom:24px;left:50%;transform:translateX(-50%) translateY(80px);
           background:#2d3a2e;color:#d8e8d9;padding:9px 18px;border-radius:8px;font-size:13px;
           box-shadow:0 4px 20px rgba(0,0,0,.25);
           transition:transform .25s cubic-bezier(.34,1.56,.64,1),opacity .25s;
           opacity:0;z-index:999;white-space:nowrap}
    #toast.show{transform:translateX(-50%) translateY(0);opacity:1}
    #context-menu{position:fixed;display:none;min-width:220px;background:#fff;color:#2c2c2c;
      border:1px solid #d6e0d6;border-radius:8px;box-shadow:0 10px 30px rgba(0,0,0,.18);
      z-index:1200;padding:6px}
    #context-menu.show{display:block}
    .ctx-item{display:flex;align-items:center;gap:8px;width:100%;padding:8px 10px;border:none;
      background:transparent;border-radius:6px;cursor:pointer;font-size:13px;color:inherit;text-align:left}
    .ctx-item:hover{background:#eef4ee}
    .center-msg{display:flex;flex-direction:column;align-items:center;justify-content:center;
                height:100%;gap:12px;color:var(--muted);text-align:center}
    .center-msg .big{font-size:52px}
    .center-msg h2{font-size:16px;color:var(--text)}
    .spin{display:inline-block;animation:spin 1s linear infinite}
    @keyframes spin{to{transform:rotate(360deg)}}
    .hl{background:rgba(122,184,125,.38);border-radius:2px}
    #shutdown-screen{display:none;position:fixed;inset:0;background:#1a2e1b;color:#d8e8d9;
      flex-direction:column;align-items:center;justify-content:center;
      gap:14px;z-index:9999;font-family:inherit}
    #shutdown-screen.show{display:flex}
    #shutdown-screen .big{font-size:56px}
    #shutdown-screen h2{font-size:20px}
    #shutdown-screen p{font-size:13px;opacity:.6}
    .tree-row.kb-focus{outline:2px solid rgba(122,184,125,.6);outline-offset:-2px}
    .file-card.kb-focus{border-color:var(--accent);box-shadow:0 0 0 3px rgba(74,122,76,.3)}
    #update-banner{display:none;position:fixed;top:0;left:0;right:0;z-index:200;
      background:#2d6b30;color:#d8e8d9;
      font-size:13px;padding:9px 16px;
      align-items:center;justify-content:space-between;gap:12px;
      border-bottom:1px solid rgba(122,184,125,.4);}
    #update-banner.show{display:flex;}
    #update-banner a{color:var(--green-accent,#b8f0bb);font-weight:700;text-decoration:underline;}
    #update-banner-close{background:none;border:none;color:rgba(216,232,217,.6);
      font-size:18px;cursor:pointer;padding:0 4px;line-height:1;}
    #update-banner-close:hover{color:#d8e8d9;}
  </style>
</head>
<body>
<div id="sidebar">
  <div id="sidebar-header">
    <div id="sidebar-eyebrow">Directory Assistant</div>
    <div id="project-name">読み込み中...</div>
  </div>
  <div id="sidebar-actions">
    <button class="btn btn-ghost" id="btn-refresh">⟳ 更新</button>
    <button class="btn btn-ghost" id="btn-expand">全展開</button>
    <button class="btn btn-ghost" id="btn-collapse">全閉</button>
  </div>
  <div id="search-wrap">
    <span id="search-icon">🔍</span>
    <input id="search" type="text" placeholder="ファイル・フォルダを検索...">
  </div>
  <div id="stats">読み込み中...</div>
  <div id="tree-container">
    <div style="padding:20px;text-align:center;font-size:12px;opacity:.4">
      <span class="spin">⟳</span> スキャン中...
    </div>
  </div>
  <div id="sidebar-footer">
    <a href="https://github.com/raw-slnc/directory_assistant_py" target="_blank"
       style="display:block;text-align:center;font-size:11px;color:rgba(216,232,217,.45);
              text-decoration:none;padding:6px 0 4px;letter-spacing:.01em;
              transition:color .15s;"
       onmouseover="this.style.color='rgba(216,232,217,.8)'"
       onmouseout="this.style.color='rgba(216,232,217,.45)'">GitHub Link</a>
    <button class="btn btn-danger" id="btn-shutdown" style="font-size:11px">⏻ 終了</button>
  </div>
</div>
<div id="main">
  <div id="main-header">
    <div id="breadcrumb"></div>
    <div id="folder-meta"></div>
  </div>
  <div id="content-area">
    <div class="center-msg"><div class="big"><span class="spin">⟳</span></div><h2>読み込み中...</h2></div>
  </div>
</div>
<div id="update-banner">
  <span id="update-banner-msg"></span>
  <button id="update-banner-close" title="閉じる">✕</button>
</div>
<div id="toast"></div>
<div id="context-menu">
  <button type="button" class="ctx-item" id="ctx-reveal">📂 ファイルマネージャーで表示</button>
</div>
<div id="shutdown-screen">
  <div class="big">🌲</div>
  <h2>Directory Assistant を終了しました</h2>
  <p>このタブは閉じてください</p>
</div>
<script>
let treeData=null,currentNode=null;
let pathToRow=new Map();
let activePanel='none',focusedTreeIdx=-1,focusedCardIdx=-1;
let navHistory=[],historyIdx=-1;
let appPlatform='',ctxTargetNode=null;
const api={
  tree:()=>fetch('/api/tree').then(r=>r.json()),
  info:()=>fetch('/api/info').then(r=>r.json()),
  ping:()=>fetch('/api/ping').catch(()=>{}),
  open:p=>fetch('/api/open',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({path:p})}).then(r=>r.json()),
  reveal:p=>fetch('/api/reveal',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({path:p})}).then(r=>r.json()),
  shutdown:()=>fetch('/api/shutdown',{method:'POST'}).catch(()=>{}),
};
setInterval(()=>api.ping(),10000);api.ping();
// Make panels focusable so Tab/focus behavior is consistent across browsers.
const treeContainer=document.getElementById('tree-container');
const contentArea=document.getElementById('content-area');
treeContainer.tabIndex=0;
contentArea.tabIndex=0;
document.getElementById('btn-shutdown').addEventListener('click',async()=>{
  if(!confirm('サーバーを終了しますか？'))return;
  window.__daShuttingDown = true;
  await api.shutdown();
  document.getElementById('shutdown-screen').classList.add('show');
});
window.__daShuttingDown = false;
// Heuristic: treat Ctrl+R / F5 as reload, so we can skip shutdown + close-confirm.
// Note: browser UI reload button / address bar navigation can't be reliably detected.
window.__daReloading = false;
window.addEventListener('keydown', (e)=>{
  const key=(e.key||'').toLowerCase();
  const isReloadShortcut = (key==='f5') || ((e.ctrlKey||e.metaKey) && key==='r');
  if(!isReloadShortcut) return;
  window.__daReloading = true;
  setTimeout(()=>{ window.__daReloading = false; }, 3000);
}, {capture:true});
function requestShutdownOnClose(){
  if(window.__daShuttingDown) return;
  if(window.__daReloading) return;
  window.__daShuttingDown = true;
  try{
    const blob = new Blob([JSON.stringify({})], {type:'application/json'});
    if(navigator.sendBeacon){
      navigator.sendBeacon('/api/shutdown', blob);
      return;
    }
  }catch(e){}
  try{
    fetch('/api/shutdown',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}',keepalive:true}).catch(()=>{});
  }catch(e){}
}
// When the tab/window is closed, request server shutdown (best-effort).
// visibilitychange is intentionally NOT used — switching to another tab would trigger shutdown.
window.addEventListener('pagehide', ()=>{ requestShutdownOnClose(); });
// Close confirm: show only when it's not a reload shortcut.
window.addEventListener('beforeunload', (e)=>{
  if(window.__daShuttingDown) return;
  if(window.__daReloading) return;
  e.preventDefault();
  e.returnValue = '';
  return '';
});
function pushNav(node){
  if(historyIdx>=0)navHistory[historyIdx].cardIdx=focusedCardIdx;
  navHistory=navHistory.slice(0,historyIdx+1);
  navHistory.push({node,cardIdx:-1});
  historyIdx=navHistory.length-1;
}
function goBack(){
  if(historyIdx<=0)return;
  navHistory[historyIdx].cardIdx=focusedCardIdx;
  historyIdx--;
  const e=navHistory[historyIdx];showFolderRaw(e.node,e.cardIdx);
}
function goForward(){
  if(historyIdx>=navHistory.length-1)return;
  navHistory[historyIdx].cardIdx=focusedCardIdx;
  historyIdx++;
  const e=navHistory[historyIdx];showFolderRaw(e.node,e.cardIdx);
}
const ICONS={pdf:'📄',doc:'📝',docx:'📝',xls:'📊',xlsx:'📊',csv:'📊',
  jpg:'🖼️',jpeg:'🖼️',png:'🖼️',gif:'🖼️',svg:'🖼️',webp:'🖼️',
  mp4:'🎬',mov:'🎬',mp3:'🎵',wav:'🎵',zip:'🗜️',rar:'🗜️',lnk:'🔗',url:'🔗',txt:'📋',md:'📋'};
const ext=n=>{const p=n.split('.');return p.length>1?p.pop().toLowerCase():'';};
const icon=n=>ICONS[ext(n)]||'📄';
const ecls=n=>{const e=ext(n);return e==='pdf'?'ext-pdf':['doc','docx'].includes(e)?'ext-docx':['xls','xlsx'].includes(e)?'ext-xlsx':'ext-misc';};
const esc=s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
function getVisibleTreeRows(){
  return[...document.querySelectorAll('#tree-container .tree-row')].filter(row=>{
    let el=row.parentElement;
    while(el&&el.id!=='tree-container'){
      if(el.classList.contains('tree-children')&&el.classList.contains('closed'))return false;
      el=el.parentElement;
    }
    return true;
  });
}
function setTreeKbFocus(row){
  document.querySelectorAll('#tree-container .tree-row.kb-focus').forEach(r=>r.classList.remove('kb-focus'));
  if(row){row.classList.add('kb-focus');row.scrollIntoView({block:'nearest',behavior:'smooth'});}
}
function syncTreeToNode(node){
  const rows=getVisibleTreeRows();
  const idx=rows.findIndex(r=>r.closest('.tree-item')&&r.closest('.tree-item')._node===node);
  if(idx>=0){focusedTreeIdx=idx;if(activePanel==='tree')setTreeKbFocus(rows[idx]);}
}
function expandTreeToRow(row){
  let el=row&&row.parentElement;
  while(el&&el.id!=='tree-container'){
    if(el.classList.contains('tree-children')){
      const item=el.parentElement;
      const tog=item&&item.querySelector('.tree-row .tree-toggle');
      if(tog && !tog.classList.contains('leaf')){
        el.classList.remove('closed');
        el.style.maxHeight='9999px';
        tog.classList.add('open');
      }
    }
    el=el.parentElement;
  }
}
function syncTreeToPath(path){
  if(!treeData)return;
  const treeHasItems=!!document.querySelector('#tree-container .tree-item');
  if(!treeHasItems){
    const q=(document.getElementById('search').value||'').trim();
    if(q){
      document.getElementById('search').value='';
      renderTree();
    }
  }
  const key=String(path??'');
  const row=pathToRow.get(key);
  if(!row||!row.isConnected)return;
  expandTreeToRow(row);
  setActive(row);
  row.scrollIntoView({block:'nearest',behavior:'smooth'});
  const rows=getVisibleTreeRows();
  focusedTreeIdx=rows.indexOf(row);
  if(activePanel==='tree')setTreeKbFocus(row);
}
function getAllCards(){return[...document.querySelectorAll('#content-area .file-card')];}
function revealLabel(){
  if(appPlatform==='Darwin')return 'Finderで表示';
  if(appPlatform==='Windows')return 'エクスプローラーで表示';
  return 'ファイルマネージャーで表示';
}
function hideContextMenu(){
  const m=document.getElementById('context-menu');
  m.classList.remove('show');
  ctxTargetNode=null;
}
function showContextMenu(x,y,node){
  const m=document.getElementById('context-menu');
  const btn=document.getElementById('ctx-reveal');
  btn.textContent='📂 '+revealLabel();
  ctxTargetNode=node;
  m.style.left='0px';
  m.style.top='0px';
  m.classList.add('show');
  const w=m.offsetWidth||220,h=m.offsetHeight||40,pad=8;
  const nx=Math.max(pad,Math.min(x,window.innerWidth-w-pad));
  const ny=Math.max(pad,Math.min(y,window.innerHeight-h-pad));
  m.style.left=nx+'px';
  m.style.top=ny+'px';
}
function setCardKbFocus(idx){
  document.querySelectorAll('#content-area .file-card.kb-focus').forEach(c=>c.classList.remove('kb-focus'));
  const cards=getAllCards();
  if(idx>=0&&idx<cards.length){cards[idx].classList.add('kb-focus');cards[idx].scrollIntoView({block:'nearest',behavior:'smooth'});focusedCardIdx=idx;}
  else focusedCardIdx=-1;
}
function moveCardFocus(dir){
  const cards=getAllCards();if(!cards.length)return;
  if(focusedCardIdx<0||focusedCardIdx>=cards.length){setCardKbFocus(0);return;}
  const cur=cards[focusedCardIdx],cr=cur.getBoundingClientRect();
  if(dir==='left'){setCardKbFocus(Math.max(0,focusedCardIdx-1));return;}
  if(dir==='right'){setCardKbFocus(Math.min(cards.length-1,focusedCardIdx+1));return;}
  const cx=cr.left+cr.width/2;let best=-1,bestDist=Infinity;
  cards.forEach((c,i)=>{
    if(i===focusedCardIdx)return;
    const r=c.getBoundingClientRect();
    const inDir=dir==='down'?(r.top>cr.bottom-4):(r.bottom<cr.top+4);
    if(!inDir)return;
    const d=Math.abs((r.left+r.width/2)-cx);
    if(d<bestDist){bestDist=d;best=i;}
  });
  if(best>=0)setCardKbFocus(best);
}
async function loadTree(){
  spin(true);
  try{treeData=await api.tree();}catch{setContent('<div class="center-msg"><div class="big">❌</div><h2>サーバーエラー</h2></div>');spin(false);return;}
  try{
    const i=await api.info();
    appPlatform=(i&&i.platform)||'';
    document.getElementById('project-name').textContent=i.root_name;
    document.title=i.root_name;
  }catch{}
  document.getElementById('stats').textContent=`フォルダ ${treeData.folder_count}\u3000ファイル ${treeData.file_count}`;
  navHistory=[];historyIdx=-1;
  renderTree();showFolder(treeData);spin(false);
}
function spin(on){const b=document.getElementById('btn-refresh');b.disabled=on;b.textContent=on?'⟳ ...':'⟳ 更新';}
function renderTree(){const tc=document.getElementById('tree-container');tc.innerHTML='';pathToRow=new Map();if(treeData)renderNode(treeData,tc,0);}
function renderNode(node,parent,depth){
  const item=document.createElement('div');item.className='tree-item';item._node=node;
  const row=document.createElement('div');row.className='tree-row';row.style.paddingLeft=(8+depth*14)+'px';
  if(node===currentNode)row.classList.add('active');
  row.dataset.path=String(node&&node.path!=null?node.path:'');
  pathToRow.set(row.dataset.path,row);
  const tog=el('span','tree-toggle','▶'),ico=el('span','tree-icon','📁'),lbl=el('span','tree-label',node.name);
  row.append(tog,ico,lbl);item.appendChild(row);
  const sub=(node.children||[]).filter(c=>c.kind==='directory');
  const cw=document.createElement('div');cw.className='tree-children';
  if(sub.length===0){
    tog.classList.add('leaf');cw.classList.add('closed');cw.style.maxHeight='0';row._toggle=null;row._expand=null;row._collapse=null;row._isOpen=()=>false;
  } else {
    const open=depth===0;tog.classList.toggle('open',open);
    if(!open){cw.classList.add('closed');cw.style.maxHeight='0';}else cw.style.maxHeight='9999px';
    row._toggle=()=>{
      if(tog.classList.contains('open')){tog.classList.remove('open');cw.style.maxHeight=cw.scrollHeight+'px';requestAnimationFrame(()=>cw.classList.add('closed'));}
      else{cw.classList.remove('closed');cw.style.maxHeight='9999px';tog.classList.add('open');}
    };
    row._isOpen=()=>tog.classList.contains('open');
    row._expand=()=>{
      if(!tog.classList.contains('open'))row._toggle&&row._toggle();
    };
    row._collapse=()=>{
      if(tog.classList.contains('open'))row._toggle&&row._toggle();
    };
    // Toggle open/close only when clicking the triangle.
    tog.addEventListener('click',e=>{
      e.stopPropagation();
      // Select the row even when using the triangle (close/open) so behavior is consistent.
      setActive(row);activePanel='tree';treeContainer.focus({preventScroll:true});
      const rows=getVisibleTreeRows();focusedTreeIdx=rows.indexOf(row);
      setTreeKbFocus(row);
      row._toggle&&row._toggle();
      // Selecting a folder implies showing it in the right panel as well.
      row._open&&row._open();
    });
    sub.forEach(c=>renderNode(c,cw,depth+1));
  }
  row._open=()=>showFolder(node);
  row.addEventListener('click',()=>{
    // Click = expand + open
    setActive(row);activePanel='tree';treeContainer.focus({preventScroll:true});
    const rows=getVisibleTreeRows();focusedTreeIdx=rows.indexOf(row);
    setTreeKbFocus(row);
    if(row._toggle){
      // If already expanded, collapse and also show it in the right panel.
      if(tog.classList.contains('open')){ row._toggle(); row._open&&row._open(); return; }
      // Expand then open in right panel.
      row._toggle(); row._open&&row._open(); return;
    }
    // Leaf directory: open in right panel.
    row._open&&row._open();
  });
  row.addEventListener('dblclick',e=>{
    // Double click = open
    if(e.target.closest('.tree-toggle'))return;
    setActive(row);activePanel='tree';treeContainer.focus({preventScroll:true});
    const rows=getVisibleTreeRows();focusedTreeIdx=rows.indexOf(row);
    setTreeKbFocus(row);
    row._open&&row._open();
  });
  item.appendChild(cw);parent.appendChild(item);
}
function setActive(r){document.querySelectorAll('.tree-row.active').forEach(x=>x.classList.remove('active'));r.classList.add('active');}
function showFolder(node){
  if(historyIdx<0||navHistory[historyIdx].node!==node)pushNav(node);
  showFolderRaw(node,-1);
}
function showFolderRaw(node,restoreCardIdx=-1){
  currentNode=node;
  buildBC(node);
  syncTreeToPath(node&&node.path);
  const all=(node.children||[]);
  const dirs=all.filter(x=>x.kind==='directory'),files=all.filter(x=>x.kind==='file');
  const meta=document.getElementById('folder-meta');
  meta.textContent=`フォルダ ${dirs.length}　ファイル ${files.length}`;
  const area=document.createElement('div');
  if(dirs.length){area.appendChild(sec('フォルダ'));area.appendChild(cardGrid(dirs,folderCard));}
  if(files.length){area.appendChild(sec('ファイル'));area.appendChild(cardGrid(files,fileCard));}
  focusedCardIdx=-1;
  if(restoreCardIdx>=0){
    const cards=getAllCards();
    if(restoreCardIdx<cards.length){cards[restoreCardIdx].classList.add('kb-focus');cards[restoreCardIdx].scrollIntoView({block:'nearest'});}
    focusedCardIdx=restoreCardIdx<cards.length?restoreCardIdx:-1;
  }
  setContent('');document.getElementById('content-area').appendChild(area);
}
function sec(t){return el('div','section-label',t);}
function cardGrid(items,fn){const g=el('div','file-grid');items.forEach(i=>g.appendChild(fn(i)));return g;}
function folderCard(node){
  const c=el('div','file-card');
  c._node=node;
  const sub=(node.children||[]).filter(x=>x.kind==='directory').length;
  const fil=(node.children||[]).filter(x=>x.kind==='file').length;
  c.innerHTML=`<div class="file-card-icon">📁</div><div class="file-card-name">${esc(node.name)}</div><span class="file-card-ext ext-dir">${sub?sub+'フォルダ · ':''}${fil}ファイル</span>`;
  c._open=()=>showFolder(node);
  c.addEventListener('click',()=>{
    // Click = select only
    activePanel='cards';contentArea.focus({preventScroll:true});
    const cards=getAllCards();focusedCardIdx=cards.indexOf(c);
    setCardKbFocus(focusedCardIdx);
  });
  c.addEventListener('dblclick',()=>{
    // Double click = open
    activePanel='cards';contentArea.focus({preventScroll:true});
    c._open&&c._open();
  });
  c.addEventListener('contextmenu',e=>{
    e.preventDefault();
    activePanel='cards';contentArea.focus({preventScroll:true});
    const cards=getAllCards();focusedCardIdx=cards.indexOf(c);setCardKbFocus(focusedCardIdx);
    showContextMenu(e.clientX,e.clientY,node);
  });
  return c;
}
function fileCard(node){
  const c=el('div','file-card'),e=ext(node.name).toUpperCase();
  c._node=node;
  c.innerHTML=`<div class="file-card-icon">${icon(node.name)}</div><div class="file-card-name">${esc(node.name)}</div>${e?`<span class="file-card-ext ${ecls(node.name)}">${esc(e)}</span>`:''}`;
  c._open=async()=>{
    toast(`📂 開いています… ${node.name}`);const r=await api.open(node.path);if(!r.ok)toast(`❌ エラー: ${r.error}`);
  };
  c.addEventListener('click',()=>{
    // Click = select only
    activePanel='cards';contentArea.focus({preventScroll:true});
    const cards=getAllCards();focusedCardIdx=cards.indexOf(c);setCardKbFocus(focusedCardIdx);
  });
  c.addEventListener('dblclick',async()=>{
    // Double click = open
    activePanel='cards';contentArea.focus({preventScroll:true});
    const cards=getAllCards();focusedCardIdx=cards.indexOf(c);setCardKbFocus(focusedCardIdx);
    await (c._open&&c._open());
  });
  c.addEventListener('contextmenu',e=>{
    e.preventDefault();
    activePanel='cards';contentArea.focus({preventScroll:true});
    const cards=getAllCards();focusedCardIdx=cards.indexOf(c);setCardKbFocus(focusedCardIdx);
    showContextMenu(e.clientX,e.clientY,node);
  });
  return c;
}
function buildBC(target){
  const path=findPath(treeData,target),bc=document.getElementById('breadcrumb');bc.innerHTML='';
  (path||[target]).forEach((n,i,a)=>{
    const s=document.createElement('span');
    if(i<a.length-1){s.className='bc-item';s.textContent=n.name;s.addEventListener('click',()=>showFolder(n));}
    else{s.className='bc-current';s.textContent=n.name;}
    bc.appendChild(s);if(i<a.length-1)bc.appendChild(el('span','bc-sep',' / '));
  });
}
function findPath(root,target,acc=[]){
  acc.push(root);if(root===target)return acc;
  for(const c of(root.children||[])){if(c.kind!=='directory')continue;const f=findPath(c,target,[...acc]);if(f)return f;}return null;
}
document.getElementById('search').addEventListener('input',function(){
  clearTimeout(window.__da_st);window.__da_st=setTimeout(()=>{
    const q=this.value.trim();
    if(!q){renderTree();if(currentNode)showFolderRaw(currentNode,focusedCardIdx);return;}
    const lq=q.toLowerCase(),res=[];
    (function walk(n){
      if(n.kind==='directory' && n.name.toLowerCase().includes(lq))res.push(n);
      (n.children||[]).forEach(walk);
    })(treeData);
    const tc=document.getElementById('tree-container');tc.innerHTML='';
    if(!res.length){tc.innerHTML='<div style="padding:16px;text-align:center;font-size:12px;opacity:.4">見つかりません</div>';return;}
    res.forEach(node=>{
      const row=el('div','tree-row');row.style.paddingLeft='10px';
      const ico=el('span','tree-icon','📁');
      const lbl=el('span','tree-label');
      const i=node.name.toLowerCase().indexOf(lq);
      lbl.innerHTML=i>=0?esc(node.name.slice(0,i))+`<span class="hl">${esc(node.name.slice(i,i+lq.length))}</span>`+esc(node.name.slice(i+lq.length)):esc(node.name);
      row.append(ico,lbl);row.addEventListener('click',()=>showFolder(node));
      tc.appendChild(row);
    });
    const cnt=el('div');cnt.style='padding:6px 14px;font-size:11px;opacity:.35';cnt.textContent=res.length+' 件';tc.appendChild(cnt);
  },180);
});
document.getElementById('btn-expand').addEventListener('click',()=>document.querySelectorAll('.tree-toggle:not(.leaf)').forEach(t=>{const w=t.closest('.tree-item').querySelector('.tree-children');t.classList.add('open');w.classList.remove('closed');w.style.maxHeight='9999px';}));
document.getElementById('btn-collapse').addEventListener('click',()=>document.querySelectorAll('.tree-toggle:not(.leaf)').forEach(t=>{
  const item=t.closest('.tree-item');
  // Keep root open on "collapse all".
  if(item&&item._node===treeData)return;
  const w=item.querySelector('.tree-children');
  t.classList.remove('open');w.style.maxHeight=w.scrollHeight+'px';requestAnimationFrame(()=>w.classList.add('closed'));
}));
document.getElementById('btn-refresh').addEventListener('click',loadTree);
document.getElementById('ctx-reveal').addEventListener('click',async()=>{
  if(!ctxTargetNode||!ctxTargetNode.path){hideContextMenu();return;}
  const r=await api.reveal(ctxTargetNode.path);
  if(!r.ok)toast(`❌ エラー: ${r.error||'表示できませんでした'}`);
  hideContextMenu();
});
document.addEventListener('click',e=>{
  const m=document.getElementById('context-menu');
  if(!m.classList.contains('show'))return;
  if(e.target.closest('#context-menu'))return;
  hideContextMenu();
});
window.addEventListener('blur',hideContextMenu);
document.addEventListener('keydown',e=>{
  if(e.key==='Escape')hideContextMenu();
  if(e.target.tagName==='INPUT')return;
  if(e.altKey&&e.key==='ArrowLeft'){goBack();e.preventDefault();return;}
  if(e.altKey&&e.key==='ArrowRight'){goForward();e.preventDefault();return;}
  if(e.key==='Tab'){
    e.preventDefault();
    activePanel=(activePanel==='cards')?'tree':'cards';
    if(activePanel==='cards'){
      const cards=getAllCards();if(cards.length){if(focusedCardIdx<0||focusedCardIdx>=cards.length)setCardKbFocus(0);else setCardKbFocus(focusedCardIdx);contentArea.focus({preventScroll:true});}
    } else {
      const rows=getVisibleTreeRows();if(rows.length){if(focusedTreeIdx<0||focusedTreeIdx>=rows.length)focusedTreeIdx=0;const row=rows[focusedTreeIdx];setTreeKbFocus(row);treeContainer.focus({preventScroll:true});}
    }
    return;
  }
  if(activePanel==='cards'){
    const cards=getAllCards();if(!cards.length)return;
    if(e.key==='ArrowLeft'){e.preventDefault();moveCardFocus('left');}
    else if(e.key==='ArrowRight'){e.preventDefault();moveCardFocus('right');}
    else if(e.key==='ArrowUp'){e.preventDefault();moveCardFocus('up');}
    else if(e.key==='ArrowDown'){e.preventDefault();moveCardFocus('down');}
    else if(e.key==='Enter'){
      e.preventDefault();
      if(focusedCardIdx>=0){
        const c=getAllCards();if(focusedCardIdx<c.length){
          const el=c[focusedCardIdx];
          if(el&&el._open)el._open();
          else el&&el.dispatchEvent(new MouseEvent('dblclick',{bubbles:true}));
        }
      }
      else setCardKbFocus(0);
    }
  } else {
    const rows=getVisibleTreeRows();if(!rows.length)return;
    if(focusedTreeIdx<0)focusedTreeIdx=0;
    if(e.key==='ArrowUp'){
      e.preventDefault();focusedTreeIdx=Math.max(0,focusedTreeIdx-1);
      const row=rows[focusedTreeIdx];setActive(row);setTreeKbFocus(row);
      showFolder(row.closest('.tree-item')._node);
    } else if(e.key==='ArrowDown'){
      e.preventDefault();focusedTreeIdx=Math.min(rows.length-1,focusedTreeIdx+1);
      const row=rows[focusedTreeIdx];setActive(row);setTreeKbFocus(row);
      showFolder(row.closest('.tree-item')._node);
    } else if(e.key==='Enter'){
      e.preventDefault();
      if(focusedTreeIdx>=0&&focusedTreeIdx<rows.length){const row=rows[focusedTreeIdx];if(row._toggle)row._toggle();}
    } else if(e.key==='ArrowRight'){
      e.preventDefault();
      if(focusedTreeIdx>=0&&focusedTreeIdx<rows.length){const row=rows[focusedTreeIdx];if(row._expand)row._expand();}
    } else if(e.key==='ArrowLeft'){
      e.preventDefault();
      if(focusedTreeIdx>=0&&focusedTreeIdx<rows.length){
        const row=rows[focusedTreeIdx];
        const canCollapse=row._collapse&&row._isOpen&&row._isOpen();
        if(canCollapse){row._collapse();return;}
        const item=row.closest('.tree-item');
        const pitem=item&&item.parentElement&&item.parentElement.closest('.tree-item');
        if(pitem){
          const prow=pitem.firstElementChild;
          if(prow&&prow.classList.contains('tree-row')){
            setActive(prow);setTreeKbFocus(prow);
            const node=pitem._node;node&&showFolder(node);
            const vrows=getVisibleTreeRows();focusedTreeIdx=vrows.indexOf(prow);
          }
        }
      }
    }
  }
});
function el(tag,cls='',text=''){const e=document.createElement(tag);if(cls)e.className=cls;if(text)e.textContent=text;return e;}
function setContent(html){document.getElementById('content-area').innerHTML=html;}
let tt=null;
function toast(msg,ms=2500){const e=document.getElementById('toast');e.textContent=msg;e.classList.add('show');clearTimeout(tt);tt=setTimeout(()=>e.classList.remove('show'),ms);}
// Empty-area click switches which panel receives arrow key navigation.
treeContainer.addEventListener('click',e=>{
  if(e.target.closest('.tree-row'))return;
  activePanel='tree';treeContainer.focus({preventScroll:true});
  const rows=getVisibleTreeRows();if(!rows.length)return;
  let row=document.querySelector('.tree-row.active');
  if(!row)row=rows[Math.max(0,focusedTreeIdx)];
  if(!row)row=rows[0];
  focusedTreeIdx=Math.max(0,rows.indexOf(row));
  setTreeKbFocus(row);
});
contentArea.addEventListener('click',e=>{
  if(e.target.closest('.file-card'))return;
  activePanel='cards';contentArea.focus({preventScroll:true});
  const cards=getAllCards();if(!cards.length){focusedCardIdx=-1;return;}
  if(focusedCardIdx<0||focusedCardIdx>=cards.length)setCardKbFocus(0);
  else setCardKbFocus(focusedCardIdx);
});
loadTree();
(function(){
  const banner=document.getElementById('update-banner');
  const msg=document.getElementById('update-banner-msg');
  document.getElementById('update-banner-close').addEventListener('click',()=>banner.classList.remove('show'));
  function showBanner(latest,title){
    const label=title?'<strong>'+title+'</strong>':'バージョン <strong>'+latest+'</strong>';
    msg.innerHTML='🌿 更新があります：'+label
      +' — <a href="https://github.com/raw-slnc/directory_assistant_py/releases" target="_blank">リリースページへ</a>';
    banner.classList.add('show');
  }
  const params=new URLSearchParams(location.search);
  if(params.get('update_test')==='1'){showBanner('test-version','テスト表示');return;}
  Promise.all([
    fetch('/api/info').then(r=>r.json()),
    fetch('https://api.github.com/repos/raw-slnc/directory_assistant_py/releases/latest',
      {signal:AbortSignal.timeout(5000)}).then(r=>r.ok?r.json():null)
  ]).then(([info,data])=>{
    if(!data||!data.tag_name||!info)return;
    if(data.tag_name.replace(/^v/,'')!==info.version)showBanner(data.tag_name,data.name||null);
  }).catch(()=>{});
})();
</script>
</body>
</html>"""


def build_tree(root_path: Path, path: Path):
    node = {
        "name": path.name,
        "kind": "directory",
        "path": str(path.relative_to(root_path)),
        "children": [],
        "file_count": 0,
        "folder_count": 0,
    }
    try:
        entries = list(path.iterdir())
    except PermissionError:
        return node
    dirs = sorted(
        [e for e in entries if e.is_dir() and not e.name.startswith(".") and e.name not in EXCLUDE_DIRS],
        key=lambda x: x.name,
    )
    files = sorted(
        [e for e in entries if e.is_file() and not e.name.startswith(".") and e.name not in EXCLUDE],
        key=lambda x: x.name,
    )
    for directory in dirs:
        child = build_tree(root_path, directory)
        node["children"].append(child)
        node["folder_count"] += 1 + child["folder_count"]
        node["file_count"] += child["file_count"]
    for file in files:
        node["children"].append({"name": file.name, "kind": "file", "path": str(file.relative_to(root_path))})
        node["file_count"] += 1
    return node


def open_with_app(path_str: str):
    system = platform.system()
    if system == "Darwin":
        subprocess.Popen(["open", path_str])
    elif system == "Windows":
        os.startfile(path_str)  # type: ignore[attr-defined]
    else:
        subprocess.Popen(["xdg-open", path_str])


def reveal_in_file_manager(path_str: str):
    p = Path(path_str)
    system = platform.system()
    if system == "Darwin":
        if p.is_file():
            subprocess.Popen(["open", "-R", str(p)])
        else:
            subprocess.Popen(["open", str(p)])
    elif system == "Windows":
        if p.is_file():
            subprocess.Popen(["explorer", "/select,", str(p)])
        else:
            subprocess.Popen(["explorer", str(p)])
    else:
        target = p if p.is_dir() else p.parent
        subprocess.Popen(["xdg-open", str(target)])


def do_shutdown(pid_file: Path):
    pid_file.unlink(missing_ok=True)
    if server_inst:
        threading.Thread(target=server_inst.shutdown, daemon=True).start()


def request_shutdown(pid_file: Path, delay_sec: float = 2.0):
    global shutdown_timer, shutdown_requested_at
    now = time.time()
    with shutdown_lock:
        shutdown_requested_at = now
        if shutdown_timer:
            try:
                shutdown_timer.cancel()
            except Exception:
                pass
        shutdown_timer = threading.Timer(delay_sec, lambda: finalize_shutdown(pid_file, now))
        shutdown_timer.daemon = True
        shutdown_timer.start()


def finalize_shutdown(pid_file: Path, token: float):
    global shutdown_requested_at
    with shutdown_lock:
        if shutdown_requested_at != token:
            return
        shutdown_requested_at = None
    do_shutdown(pid_file)

def heartbeat_monitor(pid_file: Path):
    global last_ping
    while last_ping is None:
        time.sleep(1)
    while True:
        time.sleep(5)
        if last_ping and (time.time() - last_ping) > HEARTBEAT_TIMEOUT_SEC:
            print(f"\nブラウザ切断。{HEARTBEAT_TIMEOUT_SEC}秒経過のため終了します。")
            do_shutdown(pid_file)
            return


class Handler(BaseHTTPRequestHandler):
    root_path: Path = Path(".")
    bind_host: str = DEFAULT_BIND
    port: int = DEFAULT_PORT

    def log_message(self, *args):
        return

    def send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        global last_ping
        p = urlparse(self.path).path
        if p in ("/", "/index.html"):
            body = HTML.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            self.wfile.write(body)
        elif p in ("/icon.png", "/favicon.ico"):
            icon_path = self.root_path / "icon.png"
            if not icon_path.exists():
                self.send_response(404)
                self.end_headers()
                return
            try:
                data = icon_path.read_bytes()
            except OSError:
                self.send_response(500)
                self.end_headers()
                return
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            self.wfile.write(data)
        elif p == "/api/tree":
            self.send_json(build_tree(self.root_path, self.root_path))
        elif p == "/api/info":
            self.send_json(
                {
                    "root_name": self.root_path.name,
                    "root_path": str(self.root_path),
                    "platform": platform.system(),
                    "version": VERSION,
                }
            )
        elif p == "/api/ping":
            global shutdown_requested_at
            now = time.time()
            last_ping = now
            with shutdown_lock:
                # If the page reloaded, a new ping should cancel a pending shutdown.
                if shutdown_requested_at:
                    shutdown_requested_at = None
            self.send_json({"ok": True})
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        pid_file = self.root_path / PID_FILENAME
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length else {}
        p = urlparse(self.path).path
        if p == "/api/open":
            ap = str(self.root_path / body.get("path", ""))
            if not Path(ap).exists():
                self.send_json({"ok": False, "error": "ファイルが見つかりません"}, 404)
                return
            try:
                open_with_app(ap)
                self.send_json({"ok": True})
            except Exception as e:
                self.send_json({"ok": False, "error": str(e)}, 500)
        elif p == "/api/reveal":
            ap = str(self.root_path / body.get("path", ""))
            if not Path(ap).exists():
                self.send_json({"ok": False, "error": "ファイルが見つかりません"}, 404)
                return
            try:
                reveal_in_file_manager(ap)
                self.send_json({"ok": True})
            except Exception as e:
                self.send_json({"ok": False, "error": str(e)}, 500)
        elif p == "/api/shutdown":
            self.send_json({"ok": True})
            print("\n終了します。")
            request_shutdown(pid_file, delay_sec=2.0)
        else:
            self.send_response(404)
            self.end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()


def main():
    global server_inst

    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("--root", default=None, help="Root directory to browse")
    parser.add_argument("--bind", default=DEFAULT_BIND, help="Bind host (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Port (default: 8742)")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--open", dest="open_browser", action="store_true", help="Open in default browser")
    group.add_argument("--no-open", dest="open_browser", action="store_false", help="Do not open browser")
    parser.set_defaults(open_browser=True)
    args = parser.parse_args()

    root_path = Path(args.root).resolve() if args.root else Path(__file__).parent.resolve()
    pid_file = root_path / PID_FILENAME

    if pid_file.exists():
        try:
            pid = int(pid_file.read_text().strip())
            os.kill(pid, 0)
            print(f"既に起動中 (PID:{pid})")
            return
        except (OSError, ValueError):
            pid_file.unlink(missing_ok=True)

    Handler.root_path = root_path
    Handler.bind_host = str(args.bind)
    Handler.port = int(args.port)

    try:
        server_inst = HTTPServer((Handler.bind_host, Handler.port), Handler)
    except Exception as e:
        import traceback

        print(f"起動失敗: {e!r}")
        traceback.print_exc()
        pid_file.unlink(missing_ok=True)
        return

    pid_file.write_text(str(os.getpid()), encoding="utf-8")
    open_host = Handler.bind_host
    if open_host in ("0.0.0.0", "::", "127.0.0.1", "::1"):
        open_host = "localhost"
    url = f"http://{open_host}:{Handler.port}"
    print(f"起動 → {url}")
    if args.open_browser:
        threading.Timer(0.4, lambda: webbrowser.open(url, new=1, autoraise=True)).start()
    threading.Thread(target=lambda: heartbeat_monitor(pid_file), daemon=True).start()
    try:
        server_inst.serve_forever()
    except KeyboardInterrupt:
        print("\n停止")
    finally:
        pid_file.unlink(missing_ok=True)


if __name__ == "__main__":
    main()

