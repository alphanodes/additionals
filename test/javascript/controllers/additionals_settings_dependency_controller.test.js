import { describe, it, expect, beforeEach } from 'vitest';
import AdditionalsSettingsDependencyController from '../../../assets/javascripts/controllers/additionals_settings_dependency_controller.js';

// A query select, the own columns checkbox reset by it and the columns shown
// with it, as the settings form of a query list renders them
function setupForm({ ownColumns }) {
  document.body.innerHTML = `
    <div id="settings">
      <p><select id="settings_q_query_id"><option value="1">A</option><option value="2">B</option></select></p>
      <p data-reset-by="settings_q_query_id">
        <input type="hidden" name="settings[q][own_columns]" value="0">
        <input type="checkbox" id="settings_q_own_columns" ${ownColumns ? 'checked' : ''}>
      </p>
      <div data-shown-with="settings_q_own_columns">
        <input type="hidden" id="blank_columns" name="settings[q][columns][]" value="">
        <input type="password" id="secret" disabled>
      </div>
    </div>`;
  const ctx = { element: document.getElementById('settings') };
  Object.setPrototypeOf(ctx, AdditionalsSettingsDependencyController.prototype);
  return ctx;
}

const columns = () => document.querySelector('[data-shown-with]');

describe('AdditionalsSettingsDependencyController', () => {
  describe('with the checkbox off', () => {
    beforeEach(() => setupForm({ ownColumns: false }).connect());

    it('hides the dependent field', () => {
      expect(columns().classList.contains('hidden')).toBe(true);
    });

    // A disabled input is not sent, the stored columns stay
    it('disables the inputs of the hidden field', () => {
      expect(document.getElementById('blank_columns').disabled).toBe(true);
    });
  });

  describe('turning the checkbox on', () => {
    beforeEach(() => {
      const ctx = setupForm({ ownColumns: false });
      ctx.connect();
      const checkbox = document.getElementById('settings_q_own_columns');
      checkbox.checked = true;
      ctx.update({ target: checkbox });
    });

    it('shows the dependent field', () => {
      expect(columns().classList.contains('hidden')).toBe(false);
    });

    it('enables the inputs it disabled', () => {
      expect(document.getElementById('blank_columns').disabled).toBe(false);
    });

    // Disabled by its own rule, e.g. a secret field until edited
    it('keeps an input disabled before', () => {
      expect(document.getElementById('secret').disabled).toBe(true);
    });
  });

  describe('changing the field a checkbox is reset by', () => {
    beforeEach(() => {
      const ctx = setupForm({ ownColumns: true });
      ctx.connect();
      const select = document.getElementById('settings_q_query_id');
      select.value = '2';
      ctx.update({ target: select });
    });

    it('turns the checkbox off', () => {
      expect(document.getElementById('settings_q_own_columns').checked).toBe(false);
    });

    it('hides the field shown with it', () => {
      expect(columns().classList.contains('hidden')).toBe(true);
    });
  });

  // A field shown with values of a select, e.g. the days of a fixed period
  describe('with a field shown with values of a select', () => {
    let ctx;
    beforeEach(() => {
      document.body.innerHTML = `
        <div id="settings">
          <p><select id="settings_s_period">
            <option value="">all</option><option value="from">from</option><option value="between">between</option>
          </select></p>
          <p data-shown-with="settings_s_period" data-shown-values='["between"]'><input type="date" id="period_to"></p>
        </div>`;
      ctx = { element: document.getElementById('settings') };
      Object.setPrototypeOf(ctx, AdditionalsSettingsDependencyController.prototype);
      ctx.connect();
    });

    const choose = (value) => {
      const select = document.getElementById('settings_s_period');
      select.value = value;
      ctx.update({ target: select });
    };
    const field = () => document.querySelector('[data-shown-values]');

    it('shows the field again after another value was chosen', () => {
      choose('between');
      choose('from');

      expect([field().classList.contains('hidden'), document.getElementById('period_to').disabled]).toEqual([true, true]);
      choose('between');

      expect([field().classList.contains('hidden'), document.getElementById('period_to').disabled]).toEqual([false, false]);
    });
  });
});
