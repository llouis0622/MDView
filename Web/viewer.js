import MarkdownIt from 'markdown-it';
import DOMPurify from 'dompurify';
import mermaid from 'mermaid';

const content = document.querySelector('#content');
const scroller = document.querySelector('#scroller');
const toc = document.querySelector('#toc');
let generation = 0, imageSession = '', headings = [], marks = [], selected = -1, lastQuery = '';
const post = (type, data = {}) => window.webkit?.messageHandlers.bridge.postMessage({type, ...data});
const md = new MarkdownIt({html:false, linkify:true, typographer:false, breaks:false});
const escape = md.utils.escapeHtml;
md.renderer.rules.image = (tokens, idx) => {
  const token = tokens[idx], src = token.attrGet('src') || '', alt = token.content || '이미지';
  if (/^(?:[a-z][a-z\d+.-]*:|\/|\\)/i.test(src) || src.includes('\\') || !imageSession)
    return `<span class="image-blocked">${escape(alt)} · 외부 이미지 차단</span>`;
  return `<img loading="lazy" src="mdimage://${imageSession}/${encodeURIComponent(src)}" alt="${escape(alt)}">`;
};
md.renderer.rules.fence = (tokens, idx) => {
  const token = tokens[idx], language = token.info.trim().split(/\s+/)[0].toLowerCase();
  if (language === 'mermaid') return `<div class="diagram-pending"><pre data-language="mermaid"><code>${escape(token.content)}</code></pre></div>`;
  return `<pre${language ? ` data-language="${escape(language.slice(0,40))}"` : ''}><code>${escape(token.content)}</code></pre>`;
};
mermaid.initialize({startOnLoad:false, securityLevel:'strict', theme:'neutral', htmlLabels:false,
  flowchart:{htmlLabels:false}, maxTextSize:12000, maxEdges:200, suppressErrorRendering:true,
  secure:['securityLevel','startOnLoad','maxTextSize','maxEdges','htmlLabels','flowchart','theme','themeCSS','fontFamily','secure']});
function notice(text) { const n=document.querySelector('#notice');n.textContent=text;n.style.display='block';clearTimeout(notice.timer);notice.timer=setTimeout(()=>n.style.display='none',3500); }
function clearSearch() { for(const m of marks) m.replaceWith(document.createTextNode(m.textContent));content.normalize();marks=[];selected=-1;lastQuery=''; }
function reportSearch() { post('search',{count:marks.length,index:selected+1}); }
function selectMatch(delta) { if(!marks.length)return;marks[selected]?.classList.remove('current');selected=(selected+delta+marks.length)%marks.length;marks[selected].classList.add('current');marks[selected].scrollIntoView({block:'center'});reportSearch(); }
function search(query) {
  clearSearch();lastQuery=query;
  if(!query.trim()){reportSearch();return;}
  const needle=query.toLocaleLowerCase();const walker=document.createTreeWalker(content,NodeFilter.SHOW_TEXT,{acceptNode:n=>n.parentElement.closest('svg, .diagram, .diagram-pending')?NodeFilter.FILTER_REJECT:NodeFilter.FILTER_ACCEPT});
  const nodes=[];while(walker.nextNode())nodes.push(walker.currentNode);
  for(const node of nodes){const value=node.nodeValue, lower=value.toLocaleLowerCase();let start=0,at=lower.indexOf(needle);if(at<0)continue;const fragment=document.createDocumentFragment();
    while(at>=0&&marks.length<3000){fragment.append(value.slice(start,at));const mark=document.createElement('mark');mark.textContent=value.slice(at,at+query.length);fragment.append(mark);marks.push(mark);start=at+query.length;at=lower.indexOf(needle,start);}
    fragment.append(value.slice(start));node.replaceWith(fragment);if(marks.length>=3000)break;
  }
  if(marks.length)selectMatch(1);else reportSearch();
}
function slug(text){return text.trim().toLowerCase().replace(/[^\p{L}\p{N}\s_-]/gu,'').replace(/\s+/g,'-');}
function buildTOC(){
  headings=[...content.querySelectorAll('h1,h2,h3,h4,h5,h6')];toc.replaceChildren();const used=new Map();
  for(const [i,h] of headings.entries()){h.id=`md-heading-${i}`;const base=slug(h.textContent);const n=used.get(base)||0;used.set(base,n+1);h.dataset.anchor=base+(n?`-${n}`:'');
    const a=document.createElement('a');a.href=`#${h.id}`;a.textContent=h.textContent;a.style.paddingLeft=`${10+(Number(h.tagName[1])-1)*10}px`;a.title=h.textContent;toc.append(a);}
  if(!headings.length){const p=document.createElement('p');p.className='toc-empty';p.textContent='제목이 있는 문서는\n이곳에 목차가 표시됩니다.';toc.append(p);}
}
function activeHeading(){let current=0;for(let i=0;i<headings.length;i++)if(headings[i].getBoundingClientRect().top<100)current=i;[...toc.children].forEach((a,i)=>a.classList.toggle('active',i===current));}
scroller.addEventListener('scroll',activeHeading,{passive:true});
async function diagrams(epoch){
  const nodes=[...content.querySelectorAll('.diagram-pending')];
  for(const [i,node] of nodes.entries()){
    if(epoch!==generation)return;const source=node.textContent;
    if(i>=20||source.length>12000||/%%\s*\{|^\s*---/m.test(source)){node.className='diagram-fallback';node.insertAdjacentText('afterbegin','이 도식은 크기 또는 설정 제한으로 원문을 표시합니다.');continue;}
    try{const {svg}=await mermaid.render(`md-diagram-${epoch}-${i}`,source);if(epoch!==generation)return;
      const safe=DOMPurify.sanitize(svg,{USE_PROFILES:{svg:true,svgFilters:true},FORBID_TAGS:['foreignObject','image','a','script','iframe'],FORBID_ATTR:['href','xlink:href'],ADD_TAGS:['style']});
      node.innerHTML=safe;node.className='diagram';node.setAttribute('aria-label','Mermaid 도식');
    }catch{if(epoch!==generation)return;node.className='diagram-fallback';node.insertAdjacentText('afterbegin','도식을 그릴 수 없어 원문을 표시합니다.');}
  }
  if(epoch===generation)post('diagrams',{generation:epoch,count:nodes.length});
}
window.MDView={
 render(data){
  const epoch=++generation;imageSession=data.session;clearSearch();reportSearch();document.querySelector('#notice').style.display='none';
  document.querySelector('#filename').textContent=data.name;
  document.querySelector('.eyebrow').textContent='MARKDOWN DOCUMENT';
  const count=data.text.trim()?data.text.trim().split(/\s+/).length:0;
  document.querySelector('#metadata').textContent=`${new Intl.NumberFormat('ko-KR').format(data.bytes)} bytes · ${Math.max(1,Math.ceil(count/220))}분 읽기 · 읽기 전용`+(data.plain?' · 큰 문서: 원문 보기':'');
  if(!data.text.trim()){content.innerHTML='<div class="empty">비어 있는 문서입니다. 새로운 생각을 기다리고 있어요.</div>';}
  else if(data.plain){const pre=document.createElement('pre');pre.className='plain';pre.textContent=data.text;content.replaceChildren(pre);}
  else {
   const html=md.render(data.text);
   content.innerHTML=DOMPurify.sanitize(html,{ADD_ATTR:['data-language'],ADD_URI_SAFE_ATTR:[],ALLOWED_URI_REGEXP:/^(?:(?:https?|mailto|mdimage):|[^a-z]|[a-z+.-]+(?:[^a-z+.-:]|$))/i});
   for(const table of content.querySelectorAll('table')){const wrap=document.createElement('div');wrap.className='table-wrap';table.replaceWith(wrap);wrap.append(table);}
   for(const li of content.querySelectorAll('li')){const first=li.firstChild;if(first?.nodeType===3&&/^\[[ xX]\] /.test(first.textContent)){const checked=/^\[[xX]\]/.test(first.textContent);first.textContent=first.textContent.replace(/^\[[ xX]\] /,'');const box=document.createElement('span');box.textContent=checked?'☑ ':'☐ ';box.setAttribute('aria-label',checked?'완료':'미완료');li.prepend(box);}}
  }
  buildTOC();scroller.scrollTop=0;scroller.scrollLeft=0;activeHeading();post('rendered',{generation:epoch,headings:headings.length});
  void diagrams(epoch);
 },
 settings({font,theme,dark,sidebar}){document.documentElement.style.setProperty('--font',`${Math.max(12,Math.min(28,font))}px`);document.body.classList.toggle('dark',theme==='dark'||(theme==='system'&&dark));document.body.classList.toggle('no-sidebar',!sidebar);},
 search, next:()=>selectMatch(1), previous:()=>selectMatch(-1), notice,
 state:()=>({generation,query:lastQuery,count:marks.length,index:selected+1,scroll:scroller.scrollTop,headings:headings.length,text:content.textContent})
};
document.addEventListener('error',event=>{if(event.target.tagName==='IMG'){const img=event.target,span=document.createElement('span');span.className='image-blocked';span.textContent=`${img.alt||'이미지'} · 표시할 수 없음`;img.replaceWith(span);}},true);
document.addEventListener('click',event=>{
 const a=event.target.closest('a');if(!a)return;event.preventDefault();if(!event.isTrusted)return;
 const href=a.getAttribute('href')||'';if(href.startsWith('#')){let key;try{key=decodeURIComponent(href.slice(1));}catch{return;}const h=headings.find(h=>h.id===key||h.dataset.anchor===key);h?.scrollIntoView({block:'start'});return;}
 post('link',{href});
});
document.querySelector('#welcome-open').addEventListener('click',event=>{if(event.isTrusted)post('open');});
document.addEventListener('dragover',event=>event.preventDefault());
document.addEventListener('drop',event=>event.preventDefault());
buildTOC();post('ready');
