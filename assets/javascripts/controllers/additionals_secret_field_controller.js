import { Controller } from '@hotwired/stimulus';

// Field of a secret setting: the stored value never reaches the browser. The
// field stays disabled, so it is not sent and the stored value is kept, until
// the edit icon shows it.
class AdditionalsSecretFieldController extends Controller {
  static targets = ['stored', 'field', 'input'];

  edit(event) {
    event.preventDefault();
    this.storedTarget.classList.add('hidden');
    this.fieldTarget.classList.remove('hidden');
    this.inputTarget.disabled = false;
    this.inputTarget.focus();
  }
}

if (typeof window !== 'undefined' && window.Stimulus) {
  window.Stimulus.register('additionals-secret-field', AdditionalsSecretFieldController);
}

export default AdditionalsSecretFieldController;
