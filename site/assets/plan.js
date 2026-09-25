(function(){
  var KEY='plan-1c-rabbitmq-checklist';
  var boxes=[].slice.call(document.querySelectorAll('.check input'));
  var out=document.getElementById('progress');
  var saved=[];
  try{saved=JSON.parse(localStorage.getItem(KEY)||'[]')||[];}catch(e){saved=[];}
  boxes.forEach(function(b,i){b.checked=!!saved[i];});
  function upd(){
    var n=boxes.filter(function(b){return b.checked;}).length;
    out.textContent='Отмечено '+n+' из '+boxes.length+'. Отметки сохраняются только в этом браузере.';
    try{localStorage.setItem(KEY,JSON.stringify(boxes.map(function(b){return b.checked;})));}catch(e){}
  }
  boxes.forEach(function(b){b.addEventListener('change',upd);});
  upd();
})();
