const MODULES = {
  0: 'Apertura',
  1: 'Capa 1 · Higiene de borde',
  2: 'Capa 2 · Visibilidad',
  3: 'Capa 3 · Detección',
  4: 'Capa 4 · Mitigación',
  5: 'Capa 5 · Intel + Automatización',
  6: 'LLM On-Prem',
  7: 'Resumen',
};

function updateBreadcrumb(event) {
  const slide = event && event.currentSlide ? event.currentSlide : Reveal.getCurrentSlide();
  if (!slide) return;
  let section = slide;
  let mod = section.getAttribute('data-module');
  if (!mod && section.parentElement && section.parentElement.tagName === 'SECTION') {
    mod = section.parentElement.getAttribute('data-module');
  }
  const crumb = document.querySelector('.course-footer .module-crumb');
  if (crumb) {
    crumb.textContent = MODULES[mod] || 'Apertura';
  }
}

document.addEventListener('DOMContentLoaded', () => {
  if (typeof Reveal !== 'undefined') {
    Reveal.on('ready', updateBreadcrumb);
    Reveal.on('slidechanged', updateBreadcrumb);
  }
});
