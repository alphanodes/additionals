import { Controller } from '@hotwired/stimulus';

// Fields of a settings form that depend on other fields, as the settings
// declare them: a field with data-shown-with shows only while that checkbox
// is on, its inputs are disabled while hidden so they are not sent. A field
// with data-reset-by is reset when that other field changes, e.g. own columns
// of a list when its query changes.
class AdditionalsSettingsDependencyController extends Controller {
  connect() {
    this.applyShownWith();
  }

  update(event) {
    const changedId = event.target.id;
    if (changedId) {
      this.element.querySelectorAll('[data-reset-by]').forEach((field) => {
        if (field.dataset.resetBy === changedId) {
          this.reset(field);
        }
      });
    }
    this.applyShownWith();
  }

  reset(field) {
    field.querySelectorAll('input[type=checkbox]').forEach((checkbox) => {
      checkbox.checked = false;
    });
  }

  applyShownWith() {
    this.element.querySelectorAll('[data-shown-with]').forEach((field) => {
      const checkbox = document.getElementById(field.dataset.shownWith);
      const shown = Boolean(checkbox?.checked);
      field.classList.toggle('hidden', !shown);
      // Only inputs disabled here are enabled again, e.g. a secret field
      // stays disabled until edited
      field.querySelectorAll('input, select, textarea').forEach((input) => {
        if (!shown && !input.disabled) {
          input.disabled = true;
          input.dataset.dependencyDisabled = 'true';
        } else if (shown && input.dataset.dependencyDisabled) {
          input.disabled = false;
          delete input.dataset.dependencyDisabled;
        }
      });
    });
  }
}

if (typeof window !== 'undefined' && window.Stimulus) {
  window.Stimulus.register('additionals-settings-dependency', AdditionalsSettingsDependencyController);
}

export default AdditionalsSettingsDependencyController;
