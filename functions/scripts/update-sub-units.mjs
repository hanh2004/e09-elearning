// Cập nhật danh sách trực thuộc theo mã đơn vị.
// Mặc định chỉ xem trước; dùng --apply cùng ACCOUNT_SUBUNIT_UPDATE_APPROVED
// sau khi đã kiểm tra kế hoạch để ghi dữ liệu thật.
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

export const DEFAULT_SUB_UNITS = Object.freeze({
  d: Object.freeze(['C1', 'C2']),
  e09: Object.freeze(['Hậu cần', 'Tham mưu']),
});

export function unitKey(value) {
  return typeof value === 'string' ? value.trim().normalize('NFC').toLowerCase() : '';
}

export function managerUnit(user) {
  if (user?.role === 'super_admin') return 'E09';
  return typeof user?.unit === 'string' ? user.unit.trim().normalize('NFC') : '';
}

export function subUnitsForUnit(unit) {
  const values = DEFAULT_SUB_UNITS[unitKey(unit)];
  return values ? [...values] : null;
}

export function planSubUnitUpdates(users) {
  return users
    .map(({ id, data }) => ({ id, data, unit: managerUnit(data) }))
    .filter(({ data, unit }) =>
      ['super_admin', 'admin'].includes(data?.role) &&
      ['active', 'pending'].includes(data?.status) &&
      subUnitsForUnit(unit) !== null,
    )
    .map(({ id, data, unit }) => ({
      id,
      unit,
      previous: Array.isArray(data.subUnits) ? data.subUnits : [],
      subUnits: subUnitsForUnit(unit),
    }));
}

function authorizeApply(project) {
  if (process.env.ACCOUNT_SUBUNIT_UPDATE_APPROVED !== project) {
    throw new Error(
      `Live writes require ACCOUNT_SUBUNIT_UPDATE_APPROVED=${project} after reviewing the dry run.`,
    );
  }
}

const fields = (value) => Object.fromEntries(
  Object.entries(value).map(([key, item]) => [key, encode(item)]),
);

function encode(value) {
  if (value === null) return {nullValue: null};
  if (typeof value === 'string') return {stringValue: value};
  if (typeof value === 'boolean') return {booleanValue: value};
  if (Array.isArray(value)) return {arrayValue: {values: value.map(encode)}};
  return {mapValue: {fields: fields(value)}};
}

function decode(value) {
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('arrayValue' in value) return (value.arrayValue.values || []).map(decode);
  if ('mapValue' in value) {
    return Object.fromEntries(
      Object.entries(value.mapValue.fields || {}).map(([key, item]) => [key, decode(item)]),
    );
  }
  return null;
}

function documentData(document) {
  return Object.fromEntries(
    Object.entries(document.fields || {}).map(([key, value]) => [key, decode(value)]),
  );
}

async function updateSubUnits(client, project, apply) {
  const base = `projects/${project}/databases/(default)/documents`;
  const rows = (await client.post(`/${base}:runQuery`, {
    structuredQuery: {from: [{collectionId: 'users'}]},
  })).body.filter((row) => row.document).map((row) => row.document);
  const users = rows.map((document) => ({
    id: document.name.split('/').pop(),
    data: documentData(document),
  }));
  const plan = planSubUnitUpdates(users);
  if (apply && plan.length) {
    await client.post(`/${base}:commit`, {
      writes: plan.map((item) => ({
        update: {
          name: `${base}/users/${item.id}`,
          fields: fields({subUnits: item.subUnits}),
        },
        updateMask: {fieldPaths: ['subUnits', 'updatedAt']},
        updateTransforms: [{fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME'}],
      })),
    });
  }
  return {
    mode: apply ? 'applied' : 'dry-run',
    updated: plan.map(({ id, unit, previous, subUnits }) => ({
      id, unit, previous, subUnits,
    })),
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const apply = process.argv.includes('--apply');
  const project = 'e09-elearning';
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('Do not run the live-data migration against a Firestore emulator.');
  }
  if (apply) authorizeApply(project);
  const require = createRequire(import.meta.url);
  const {getGlobalDefaultAccount} = require('../node_modules/firebase-tools/lib/auth.js');
  const {requireAuth} = require('../node_modules/firebase-tools/lib/requireAuth.js');
  const {Client} = require('../node_modules/firebase-tools/lib/apiv2.js');
  await requireAuth({project, ...getGlobalDefaultAccount()});
  const client = new Client({urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1', auth: true});
  const result = await updateSubUnits(client, project, apply);
  console.log(JSON.stringify(result, null, 2));
}
