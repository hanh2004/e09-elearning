import test from 'node:test';
import assert from 'node:assert/strict';
import {
  managerUnit,
  planSubUnitUpdates,
  subUnitsForUnit,
} from '../scripts/update-sub-units.mjs';

test('maps D and E09 to the requested subordinate units', () => {
  assert.deepEqual(subUnitsForUnit(' D '), ['C1', 'C2']);
  assert.deepEqual(subUnitsForUnit('e09'), ['Hậu cần', 'Tham mưu']);
  assert.equal(subUnitsForUnit('D1'), null);
  assert.equal(managerUnit({role: 'super_admin'}), 'E09');
});

test('plans only active or pending managers in the mapped units', () => {
  assert.deepEqual(
    planSubUnitUpdates([
      {id: 'manager-d', data: {role: 'admin', status: 'active', unit: 'D', subUnits: ['old']}},
      {id: 'root-1', data: {role: 'super_admin', status: 'active', subUnits: []}},
      {id: 'root-2', data: {role: 'super_admin', status: 'active'}},
      {id: 'blocked-d', data: {role: 'admin', status: 'blocked', unit: 'D'}},
      {id: 'other', data: {role: 'admin', status: 'active', unit: 'X'}},
    ]),
    [
      {id: 'manager-d', unit: 'D', previous: ['old'], subUnits: ['C1', 'C2']},
      {id: 'root-1', unit: 'E09', previous: [], subUnits: ['Hậu cần', 'Tham mưu']},
      {id: 'root-2', unit: 'E09', previous: [], subUnits: ['Hậu cần', 'Tham mưu']},
    ],
  );
});
