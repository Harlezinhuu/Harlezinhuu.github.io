// Base dos sites de exemplo para lojas (Harle): "aberto agora", entradas ao rolar e o botão do
// WhatsApp (no exemplo, ele explica o que faria; no site de verdade, abre a conversa com a loja).
(function () {
  var dados = document.body.dataset
  var calmo = window.matchMedia('(prefers-reduced-motion: reduce)').matches

  // Aberto agora? data-horario="1-5 07:00-20:00; 6 07:00-14:00" (0 = domingo)
  var el = document.querySelector('[data-aberto]')
  if (el && dados.horario) {
    var agora = new Date(), d = agora.getDay(), m = agora.getHours() * 60 + agora.getMinutes(), texto = 'Fechado agora'
    var aberto = false
    dados.horario.split(';').forEach(function (f) {
      var p = f.trim().split(' '), dias = p[0], h = (p[1] || '').split('-')
      var ab = dias.split('-').map(Number), ini = h[0], fim = h[1]
      var hoje = ab.length === 2 ? d >= ab[0] && d <= ab[1] : ab.indexOf(d) >= 0 || dias.split(',').map(Number).indexOf(d) >= 0
      if (!hoje || !ini || !fim) return
      var a = +ini.slice(0, 2) * 60 + +ini.slice(3), b = +fim.slice(0, 2) * 60 + +fim.slice(3)
      if (m >= a && m < b) { aberto = true; texto = 'Aberto agora · até ' + fim }
      else if (m < a && !aberto) texto = 'Fechado · abre às ' + ini
    })
    el.classList.toggle('sim', aberto)
    el.querySelector('span').textContent = texto
  }

  // Botões do WhatsApp
  var toast = document.createElement('div')
  toast.className = 'toast'
  toast.setAttribute('role', 'status')
  document.body.appendChild(toast)
  var t
  function avisar(msg) {
    toast.textContent = msg
    toast.classList.add('ver')
    clearTimeout(t)
    t = setTimeout(function () { toast.classList.remove('ver') }, 4200)
  }
  document.addEventListener('click', function (e) {
    var b = e.target.closest('[data-zap]')
    if (!b) return
    e.preventDefault()
    var item = b.getAttribute('data-zap')
    avisar('No site da sua loja, este botão abre o WhatsApp com a mensagem pronta' + (item ? ': "Oi! Quero ' + item + '."' : '.'))
  })

  // Entradas ao rolar
  var itens = document.querySelectorAll('.surge')
  if (calmo || !('IntersectionObserver' in window)) { itens.forEach(function (i) { i.classList.add('ok') }); return }
  var io = new IntersectionObserver(function (es) {
    es.forEach(function (x) { if (x.isIntersecting) { x.target.classList.add('ok'); io.unobserve(x.target) } })
  }, { rootMargin: '0px 0px -8% 0px' })
  itens.forEach(function (i) { io.observe(i) })
})()
