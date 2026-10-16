const {chromium}=require('playwright');
const assert=require('assert');
const path=require('path');
const fs=require('fs');
const browserPath=process.env.CHROMIUM_PATH || (fs.existsSync('/usr/bin/chromium')?'/usr/bin/chromium':chromium.executablePath());
const previewUrl=process.env.DIARY_PREVIEW_URL || 'http://127.0.0.1:8770/docs/design-preview.html';
const output=name=>path.resolve(__dirname,'../docs',name);
(async()=>{const b=await chromium.launch({executablePath:browserPath,headless:true,args:['--no-sandbox']});try{
 const p=await b.newPage({viewport:{width:1100,height:1000},deviceScaleFactor:2});const errors=[];p.on('pageerror',e=>errors.push(e.message));
 await p.goto(previewUrl);await p.locator('.sport-icons img').first().waitFor();await p.waitForFunction(()=>[...document.images].every(i=>i.complete&&i.naturalWidth>0));
 assert.equal(await p.locator('.day').count(),16);
 assert(await p.locator('.vertical span').evaluateAll(es=>es.every(e=>e.scrollWidth<=e.clientWidth)));
 const header=await p.locator('header').boundingBox(),nav=await p.locator('.nav').boundingBox(),footer=await p.locator('footer').boundingBox(),halves=await p.locator('.halves').boundingBox();assert(nav.y>=header.y&&nav.y+nav.height<=header.y+header.height);assert(halves.y>=footer.y);assert(halves.x>footer.x+footer.width/2);
 for(const tile of await p.locator('.tile').all()){const r=await tile.boundingBox();assert.equal(r.width,r.height);}
 assert(await p.locator('.day span').evaluateAll(es=>es.every(e=>e.scrollWidth<=e.clientWidth)));
 await p.locator('#device').screenshot({path:output('design-preview.png')});
 await p.locator('[data-date="2026-10-16"][data-column="sleep"]').click();
 await p.locator('#sleepSlider').fill('0');assert.equal(await p.locator('#scoreOutput').innerText(),'0');await p.getByRole('button',{name:'Speichern',exact:true}).click();assert.equal(await p.locator('[data-date="2026-10-16"][data-column="sleep"]').innerText(),'0');
 await p.locator('[data-date="2026-10-16"][data-column="sleep"]').click();await p.locator('#sleepSlider').fill('100');await p.getByRole('button',{name:'Sleep Score erhöhen',exact:true}).click();assert.equal(await p.locator('#scoreOutput').innerText(),'100');await p.getByRole('button',{name:'Schlafwert entfernen'}).click();assert.equal(await p.locator('#scoreOutput').innerText(),'—');await p.getByRole('button',{name:'Speichern',exact:true}).click();assert.equal(await p.locator('[data-date="2026-10-16"][data-column="sleep"]').innerText(),'—');
 await p.locator('[data-date="2026-10-16"][data-column="sleep"]').click();await p.locator('#sleepSlider').fill('87');await p.getByRole('button',{name:'Sleep Score verringern',exact:true}).click();assert.equal(await p.locator('#scoreOutput').innerText(),'86');await p.getByRole('button',{name:'Sleep Score erhöhen',exact:true}).click();await p.locator('#device').screenshot({path:output('design-preview-slider.png')});
 await p.getByRole('button',{name:'Abbrechen',exact:true}).click();assert.equal(await p.locator('[data-date="2026-10-16"][data-column="sleep"]').innerText(),'—');
 await p.locator('#first').click();assert.equal(await p.locator('.day').count(),15);assert.equal(await p.locator('.day span').nth(9).innerText(),'10');assert.equal(await p.locator('.day span').last().innerText(),'15');
 await p.locator('#prev').click();assert.equal(await p.locator('#monthTitle').innerText(),'September 2026');await p.locator('#today').click();assert.equal(await p.locator('#monthTitle').innerText(),'Oktober 2026');
 await p.getByRole('button',{name:'Spalten',exact:true}).click();await p.getByRole('textbox',{name:'Name der neuen Spalte'}).fill('Yoga');await p.getByRole('button',{name:'Speichern',exact:true}).click();assert.equal(await p.locator('.heading.vertical').count(),6);
 await p.setViewportSize({width:600,height:800});assert.equal(await p.locator('#device').evaluate(e=>e.scrollWidth),600);
 assert.deepEqual(errors,[]);console.log('PASS: navigation placement, 16/15 days, two-digit dates, square tiles, all icon loads, slider 0/100/clear/cancel/+−, columns, 600px overflow and no JS errors.');
}finally{await b.close();}})().catch(e=>{console.error(e);process.exit(1)});
