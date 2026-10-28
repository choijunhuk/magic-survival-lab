const physicalKeys = { KeyW: 'w', KeyA: 'a', KeyS: 's', KeyD: 'd', KeyP: 'p', Digit1: '1', Digit2: '2', Digit3: '3' };

export function controlKey(event) {
  return physicalKeys[event.code] ?? event.key.toLowerCase();
}
