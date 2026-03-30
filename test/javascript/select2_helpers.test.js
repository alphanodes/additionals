import { describe, it, expect, vi } from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Mock jQuery and Select2 (required by select2_helpers.js)
globalThis.$ = vi.fn(selector => {
  const el = { length: 0, hide: vi.fn(), attr: vi.fn(), select2: vi.fn(), append: vi.fn(), find: vi.fn(() => el), on: vi.fn(), val: vi.fn(), data: vi.fn() };
  return el;
});
$.inArray = (val, arr) => arr.indexOf(val);
$.Event = vi.fn();

// Mock Redmine Core globals
globalThis.window = globalThis;
globalThis.toggleFilter = vi.fn();
globalThis.buildFilterRow = vi.fn();
globalThis.availableFilters = {};
globalThis.operatorByType = {};
globalThis.formatNameWithIcon = vi.fn();

// Load the actual script
const scriptPath = resolve(__dirname, '../../assets/javascripts/select2_helpers.js');
const scriptContent = readFileSync(scriptPath, 'utf-8');
const globalEval = eval; // eslint-disable-line no-eval
globalEval(scriptContent);

describe('select2_helpers.js', () => {
  describe('sanitizeToId', () => {
    it('replaces dots with underscores', () => {
      expect(sanitizeToId('cf.123')).toBe('cf_123');
    });

    it('returns unchanged string without dots', () => {
      expect(sanitizeToId('status_id')).toBe('status_id');
    });

    it('handles empty string', () => {
      expect(sanitizeToId('')).toBe('');
    });
  });

  describe('buildTagGroupName', () => {
    it('returns group name for scoped tag', () => {
      expect(buildTagGroupName('Priority::High')).toBe('Priority');
    });

    it('returns nested group name for deeply scoped tag', () => {
      expect(buildTagGroupName('Category::Sub::Value')).toBe('Category::Sub');
    });

    it('returns empty string for unscoped tag', () => {
      expect(buildTagGroupName('simple')).toBe('');
    });
  });

  describe('createTag', () => {
    it('creates tag from trimmed term', () => {
      const result = createTag({ term: ' hello ' });

      expect(result).toEqual({ id: 'hello', text: 'hello' });
    });

    it('returns null for empty term', () => {
      expect(createTag({ term: '  ' })).toBeNull();
    });

    it('returns null for term with comma', () => {
      expect(createTag({ term: 'one,two' })).toBeNull();
    });
  });

  describe('buildSelect2Options', () => {
    it('builds basic options', () => {
      const result = buildSelect2Options({
        placeholder: 'Select...',
        allow_clear: true,
        min_input_length: 2,
        width: '100%'
      });

      expect(result.placeholder).toBe('Select...');
      expect(result.allowClear).toBe(true);
      expect(result.minimumInputLength).toBe(2);
      expect(result.width).toBe('100%');
    });

    it('uses defaults for missing options', () => {
      const result = buildSelect2Options({});

      expect(result.placeholder).toBe('');
      expect(result.allowClear).toBe(false);
      expect(result.minimumInputLength).toBe(0);
      expect(result.width).toBe('90%');
    });

    it('adds ajax config when url is provided', () => {
      const result = buildSelect2Options({ url: '/search' });

      expect(result.ajax).toBeDefined();
      expect(result.ajax.url).toBe('/search');
      expect(result.ajax.dataType).toBe('json');
      expect(result.ajax.cache).toBe(true);
    });

    it('uses static data when no url', () => {
      const data = [{ id: 1, text: 'One' }];
      const result = buildSelect2Options({ data });

      expect(result.data).toEqual(data);
      expect(result.ajax).toBeUndefined();
    });

    it('enables tags with separators', () => {
      const result = buildSelect2Options({ tags: true });

      expect(result.tags).toBe(true);
      expect(result.tokenSeparators).toEqual([',']);
      expect(result.createTag).toBeDefined();
    });

    it('disables tags by default', () => {
      const result = buildSelect2Options({});

      expect(result.tags).toBe(false);
    });

    it('resolves format_state from window', () => {
      window.myFormatter = vi.fn();
      const result = buildSelect2Options({ format_state: 'myFormatter' });

      expect(result.templateResult).toBe(window.myFormatter);
      delete window.myFormatter;
    });
  });

  describe('setSelect2Filter', () => {
    it('registers filter options', () => {
      setSelect2Filter('custom_type', { url: '/test', placeholder: 'Test' });

      expect(select2Filters.custom_type).toEqual({ url: '/test', placeholder: 'Test' }); // eslint-disable-line no-undef
    });

    it('sets operator type from list_optional', () => {
      globalThis.operatorByType = { list_optional: ['=', '!'] };

      setSelect2Filter('new_type', {});

      expect(operatorByType.new_type).toEqual(['=', '!']);
    });
  });
});
