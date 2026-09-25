(function(){
  var slides=[].slice.call(document.querySelectorAll('.slide'));
  var dots=[].slice.call(document.querySelectorAll('.dots a'));
  function current(){
    var mid=window.innerHeight/2,idx=0;
    slides.forEach(function(s,i){if(s.getBoundingClientRect().top<=mid)idx=i;});
    return idx;
  }
  function mark(){var i=current();dots.forEach(function(d,j){d.classList.toggle('on',i===j);});}
  window.addEventListener('scroll',mark,{passive:true});mark();
  dots.forEach(function(d,i){d.addEventListener('click',function(e){e.preventDefault();slides[i].scrollIntoView();});});
  document.addEventListener('keydown',function(e){
    if(e.target.closest&&e.target.closest('input,textarea'))return;
    var i=current();
    if(['ArrowDown','PageDown','ArrowRight'].indexOf(e.key)>-1&&i<slides.length-1){e.preventDefault();slides[i+1].scrollIntoView();}
    if(['ArrowUp','PageUp','ArrowLeft'].indexOf(e.key)>-1&&i>0){e.preventDefault();slides[i-1].scrollIntoView();}
  });
})();
