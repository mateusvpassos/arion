// Atende os pedidos de exclusão de conta (exclusoes/{email}, feitos pelo app).
// Apaga os dados da pessoa no Firestore e a conta no Authentication.
//
// Rodar (credencial de admin: `gcloud auth application-default login` ou
// GOOGLE_APPLICATION_CREDENTIALS apontando p/ a chave de uma conta de serviço):
//   node excluir-contas.mjs                 mostra os pedidos e o que seria feito
//   node excluir-contas.mjs --aplicar       apaga de verdade
//   node excluir-contas.mjs fulano@x.com    só esse e-mail (com ou sem pedido)
//
// O que acontece com quem pediu:
// - músicas, repertórios e músicas do acervo dele viram lápide (sem conteúdo nem
//   e-mail; os aparelhos dos outros tiram da lista) e perdem o histórico;
// - sugestões dele somem; onde ele só aparece como autor de uma versão,
//   decisão ou última edição, o e-mail e o nome são apagados;
// - sai dos grupos e das listas de editores; grupo pessoal (ou sem mais
//   ninguém) é apagado; grupo com gente passa para o próximo membro;
// - nome, liberação, sessão ao vivo, a conta Google no Firebase e o pedido somem.
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { pathToFileURL } from 'node:url';

const LAPIDE = (id) => ({
  id, apagada: true, apagadaPor: '', apagadaPorNome: 'conta excluída',
  updatedAt: new Date().toISOString(),
});

/** Apaga os dados de [email]. aplicar=false só conta o que mudaria. */
export async function excluirConta(db, auth, email, { aplicar = false, log = console.log } = {}) {
  const e = email.toLowerCase();
  const feito = [];
  const fazer = async (o, f) => { feito.push(o); if (aplicar) await f(); };
  const semMim = FieldValue.arrayRemove(e);

  // tira o e-mail de quem gravou/decidiu (o registro continua, sem autor)
  const anonimizar = async (col) => {
    for (const [campo, nome] of [['por', 'porNome'], ['decididoPor', 'decididoPorNome'],
      ['apagadaPor', 'apagadaPorNome']]) {
      const q = await col.where(campo, '==', e).get();
      for (const d of q.docs) {
        await fazer(`anonimiza ${d.ref.path} (${campo})`, () =>
          d.ref.update({ [campo]: '', [nome]: '' }));
      }
    }
  };

  // músicas / repertórios: os dele viram lápide; nos dos outros sai das listas e da autoria
  const conteudo = async (col, comVersoes) => {
    for (const d of (await col.where('dono', '==', e).get()).docs) {
      await fazer(`lápide ${d.ref.path}`, async () => {
        if (comVersoes) await db.recursiveDelete(d.ref.collection('versoes'));
        await d.ref.set(LAPIDE(d.id));
      });
    }
    for (const d of (await col.where('editores', 'array-contains', e).get()).docs) {
      await fazer(`tira editor ${d.ref.path}`, () => d.ref.update({ editores: semMim }));
    }
    await anonimizar(col);
    if (!comVersoes) return;
    for (const m of (await col.get()).docs) {
      if (m.data().dono === e) continue;
      for (const v of (await m.ref.collection('versoes').where('por', '==', e).get()).docs) {
        const s = v.data().song ?? {};
        await fazer(`anonimiza ${v.ref.path}`, () => v.ref.update({
          por: '', porNome: '',
          ...(s.por === e ? { 'song.por': '', 'song.porNome': '' } : {}),
        }));
      }
    }
  };

  const sugestoes = async (col) => {
    for (const d of (await col.where('por', '==', e).get()).docs) {
      await fazer(`apaga ${d.ref.path}`, () => d.ref.delete());
    }
    await anonimizar(col);
  };

  const pessoaEConfianca = async (base) => {
    const p = base.collection('pessoas').doc(e);
    if ((await p.get()).exists) await fazer(`apaga ${p.path}`, () => p.delete());
    const c = base.collection('confianca').doc(e);
    if ((await c.get()).exists) await fazer(`apaga ${c.path}`, () => c.delete());
    for (const d of (await base.collection('confianca').where('editores', 'array-contains', e).get()).docs) {
      await fazer(`tira editor ${d.ref.path}`, () => d.ref.update({ editores: semMim }));
    }
  };

  // ---- grupos ----
  for (const g of (await db.collection('grupos').where('membros', 'array-contains', e).get()).docs) {
    const j = g.data();
    const outros = (j.membros ?? []).filter((m) => m !== e);
    if (j.dono === e && (j.pessoal || !outros.length)) {
      await fazer(`apaga grupo ${g.ref.path} (${j.nome})`, () => db.recursiveDelete(g.ref));
      continue;
    }
    if (j.dono === e) {
      await fazer(`passa ${g.ref.path} (${j.nome}) p/ ${outros[0]}`, () =>
        g.ref.update({ dono: outros[0], membros: outros }));
    } else {
      await fazer(`sai de ${g.ref.path} (${j.nome})`, () => g.ref.update({ membros: semMim }));
    }
    await conteudo(g.ref.collection('musicas'), true);
    await conteudo(g.ref.collection('repertorios'), false);
    await sugestoes(g.ref.collection('sugestoes'));
    await pessoaEConfianca(g.ref);
  }

  // ---- acervo e coisas soltas ----
  await conteudo(db.collection('acervo'), true);
  await sugestoes(db.collection('acervoSugestoes'));
  await pessoaEConfianca(db);
  const lib = db.collection('liberados').doc(e);
  if ((await lib.get()).exists) await fazer(`apaga ${lib.path}`, () => lib.delete());
  for (const d of (await db.collection('liberados').where('por', '==', e).get()).docs) {
    await fazer(`anonimiza ${d.ref.path} (por)`, () => d.ref.update({ por: '' }));
  }
  for (const d of (await db.collection('sessoes').where('dono', '==', e).get()).docs) {
    await fazer(`apaga ${d.ref.path}`, () => d.ref.delete());
  }

  // ---- conta ----
  try {
    const u = await auth.getUserByEmail(e);
    await fazer(`apaga conta ${u.uid}`, () => auth.deleteUser(u.uid));
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
  }
  const pedido = db.collection('exclusoes').doc(e);
  if ((await pedido.get()).exists) await fazer(`apaga ${pedido.path}`, () => pedido.delete());

  for (const o of feito) log(`  ${aplicar ? '✔' : '·'} ${o}`);
  return feito;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  const aplicar = args.includes('--aplicar');
  initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? 'arion-cifras' });
  const db = getFirestore(), auth = getAuth();
  let emails = args.filter((a) => !a.startsWith('--'));
  if (!emails.length) {
    const q = await db.collection('exclusoes').get();
    emails = q.docs.map((d) => d.id);
    for (const d of q.docs) console.log(`pedido: ${d.id} em ${d.data().em?.toDate().toLocaleString('pt-BR')}`);
  }
  if (!emails.length) console.log('Nenhum pedido de exclusão.');
  for (const e of emails) {
    console.log(`\n${e}`);
    await excluirConta(db, auth, e, { aplicar });
  }
  if (emails.length && !aplicar) console.log('\nNada foi apagado. Rode de novo com --aplicar.');
}
