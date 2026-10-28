// Testa o excluir-contas.mjs no emulador (Firestore + Auth).
// Rodar: npm test
import { test, before, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { excluirConta } from './excluir-contas.mjs';

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8188';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
const ZE = 'ze@x.com', ANA = 'ana@x.com', BIA = 'bia@x.com';
let db, auth;

before(() => {
  initializeApp({ projectId: 'demo-arion' });
  db = getFirestore();
  auth = getAuth();
});

beforeEach(async () => {
  await db.recursiveDelete(db.collection('grupos'));
  for (const c of ['acervo', 'acervoSugestoes', 'pessoas', 'confianca', 'liberados', 'sessoes', 'exclusoes']) {
    await db.recursiveDelete(db.collection(c));
  }
  for (const u of (await auth.listUsers()).users) await auth.deleteUser(u.uid);
  await auth.createUser({ email: ZE });
  const set = (p, d) => db.doc(p).set(d);
  await set('grupos/pess', { nome: 'Biblioteca de Zé', dono: ZE, membros: [ZE], pessoal: true });
  await set('grupos/pess/musicas/p1', { id: 'p1', title: 'x', dono: ZE });
  await set('grupos/banda', { nome: 'Banda', dono: ZE, membros: [ZE, ANA, BIA] });
  await set('grupos/banda/musicas/m1', { id: 'm1', title: 'Do Zé', dono: ZE, donoNome: 'Zé' });
  await set('grupos/banda/musicas/m1/versoes/1', { n: 1, por: ZE, song: {} });
  await set('grupos/banda/musicas/m2', { id: 'm2', title: 'Da Ana', dono: ANA, editores: [ZE, BIA], por: ZE, porNome: 'Zé' });
  await set('grupos/banda/musicas/m2/versoes/2', { n: 2, por: ZE, porNome: 'Zé', song: { por: ZE, porNome: 'Zé', title: 'Da Ana' } });
  await set('grupos/banda/sugestoes/s1', { por: ZE, status: 'pendente' });
  await set('grupos/banda/sugestoes/s2', { por: ANA, decididoPor: ZE, decididoPorNome: 'Zé', status: 'aceita' });
  await set('grupos/banda/pessoas/' + ZE, { nome: 'Zé' });
  await set('grupos/banda/confianca/' + ANA, { editores: [ZE] });
  await set('grupos/coral', { nome: 'Coral', dono: ANA, membros: [ANA, ZE] });
  await set('acervo/a1', { id: 'a1', dono: ZE });
  await set('pessoas/' + ZE, { nome: 'Zé' });
  await set('liberados/' + ZE, { por: ANA });
  await set('liberados/' + BIA, { por: ZE });
  await set('sessoes/1234', { dono: ZE, ips: ['192.168.0.2'] });
  await set('exclusoes/' + ZE, { em: new Date(), nome: 'Zé' });
});

const get = async (p) => (await db.doc(p).get()).data();

test('sem --aplicar não muda nada', async () => {
  const feito = await excluirConta(db, auth, ZE, { log: () => {} });
  assert.ok(feito.length > 10);
  assert.equal((await get('pessoas/' + ZE)).nome, 'Zé');
  await auth.getUserByEmail(ZE);
});

test('apaga e anonimiza tudo do Zé, sem mexer no dos outros', async () => {
  await excluirConta(db, auth, ZE, { aplicar: true, log: () => {} });
  assert.equal(await get('grupos/pess'), undefined);
  assert.equal(await get('grupos/pess/musicas/p1'), undefined);
  const banda = await get('grupos/banda');
  assert.equal(banda.dono, ANA);
  assert.deepEqual(banda.membros, [ANA, BIA]);
  const m1 = await get('grupos/banda/musicas/m1');
  assert.equal(m1.apagada, true);
  assert.equal(m1.dono, undefined);
  assert.equal(m1.title, undefined);
  assert.equal(await get('grupos/banda/musicas/m1/versoes/1'), undefined);
  const m2 = await get('grupos/banda/musicas/m2');
  assert.deepEqual(m2.editores, [BIA]);
  assert.equal(m2.por, '');
  assert.equal(m2.title, 'Da Ana');
  const v2 = await get('grupos/banda/musicas/m2/versoes/2');
  assert.equal(v2.por, '');
  assert.equal(v2.song.por, '');
  assert.equal(v2.song.title, 'Da Ana');
  assert.equal(await get('grupos/banda/sugestoes/s1'), undefined);
  assert.equal((await get('grupos/banda/sugestoes/s2')).decididoPor, '');
  assert.equal(await get('grupos/banda/pessoas/' + ZE), undefined);
  assert.deepEqual((await get('grupos/banda/confianca/' + ANA)).editores, []);
  assert.deepEqual((await get('grupos/coral')).membros, [ANA]);
  assert.equal((await get('acervo/a1')).apagada, true);
  assert.equal(await get('pessoas/' + ZE), undefined);
  assert.equal(await get('liberados/' + ZE), undefined);
  assert.equal((await get('liberados/' + BIA)).por, '');
  assert.equal(await get('sessoes/1234'), undefined);
  assert.equal(await get('exclusoes/' + ZE), undefined);
  await assert.rejects(auth.getUserByEmail(ZE), { code: 'auth/user-not-found' });
});
