import test from 'node:test';
import assert from 'node:assert/strict';
import { controlKey, usesNativeKeys } from '../controls.mjs';

test('movement uses physical keys when Korean input or another layout changes the letter', () => {
  for (const [code, key, expected] of [['KeyW', 'ㅈ', 'w'], ['KeyA', 'ㅁ', 'a'], ['KeyS', 'ㄴ', 's'], ['KeyD', 'ㅇ', 'd']]) {
    assert.equal(controlKey({ code, key }), expected);
  }
});

test('pause and upgrade shortcuts keep working during IME composition', () => {
  assert.equal(controlKey({ code: 'KeyP', key: 'Process' }), 'p');
  assert.equal(controlKey({ code: 'Digit2', key: '@' }), '2');
});

test('navigation keys and synthetic key-only events keep their existing meaning', () => {
  assert.equal(controlKey({ code: 'ArrowRight', key: 'ArrowRight' }), 'arrowright');
  assert.equal(controlKey({ code: 'Space', key: ' ' }), ' ');
  assert.equal(controlKey({ key: 'P' }), 'p');
});

test('focused form controls keep native arrows and Space; buttons and the game keep shortcuts', () => {
  for (const tagName of ['INPUT', 'SELECT', 'TEXTAREA']) assert.equal(usesNativeKeys({ tagName }), true);
  assert.equal(usesNativeKeys({ tagName: 'DIV', isContentEditable: true }), true);
  assert.equal(usesNativeKeys({ tagName: 'BUTTON' }), false);
  assert.equal(usesNativeKeys({ tagName: 'CANVAS' }), false);
});
