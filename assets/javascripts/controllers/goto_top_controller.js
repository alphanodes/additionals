import { Controller } from '@hotwired/stimulus';

class GotoTopController extends Controller {
  connect() {
    const stickyHeader = document.getElementById('sticky-issue-header');
    if (!stickyHeader) {
      return;
    }

    this.stickyHeader = stickyHeader;
    this.boundClick = this.scrollToTop.bind(this);

    stickyHeader.style.cursor = 'pointer';
    stickyHeader.setAttribute('title', this.element.dataset.label || 'Go to top');
    stickyHeader.addEventListener('click', this.boundClick);
  }

  disconnect() {
    if (this.stickyHeader) {
      this.stickyHeader.removeEventListener('click', this.boundClick);
      this.stickyHeader.style.cursor = '';
      this.stickyHeader.removeAttribute('title');
    }
  }

  scrollToTop(event) {
    event.preventDefault();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }
}

if (typeof window !== 'undefined' && window.Stimulus) {
  window.Stimulus.register('goto-top', GotoTopController);
}

export default GotoTopController;
