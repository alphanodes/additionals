import { describe, it, expect, beforeEach, vi } from 'vitest';
import AdditionalsSecretFieldController from '../../../assets/javascripts/controllers/additionals_secret_field_controller.js';

describe('AdditionalsSecretFieldController', () => {
  it('declares its targets', () => {
    expect(AdditionalsSecretFieldController.targets).toEqual(['stored', 'field', 'input']);
  });

  describe('edit', () => {
    let ctx;
    let event;

    beforeEach(() => {
      document.body.innerHTML = `
        <span id="stored"><label>Token</label><a href="#">edit</a></span>
        <span id="field" class="hidden"><input id="input" type="password" disabled></span>`;
      ctx = {
        storedTarget: document.getElementById('stored'),
        fieldTarget: document.getElementById('field'),
        inputTarget: document.getElementById('input'),
      };
      event = { preventDefault: vi.fn() };
      AdditionalsSecretFieldController.prototype.edit.call(ctx, event);
    });

    it('does not follow the link', () => {
      expect(event.preventDefault).toHaveBeenCalled();
    });

    it('hides the stored hint', () => {
      expect(ctx.storedTarget.classList.contains('hidden')).toBe(true);
    });

    it('shows the field', () => {
      expect(ctx.fieldTarget.classList.contains('hidden')).toBe(false);
    });

    // A disabled field is not sent, so the stored value would stay
    it('enables the field so it is sent', () => {
      expect(ctx.inputTarget.disabled).toBe(false);
    });

    it('focuses the field', () => {
      expect(document.activeElement).toBe(ctx.inputTarget);
    });
  });
});
