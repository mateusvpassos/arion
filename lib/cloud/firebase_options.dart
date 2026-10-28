import 'package:firebase_core/firebase_core.dart';

/// Configuração do projeto Firebase "arion-cifras" (console do Firebase →
/// Configurações do projeto → Seus apps → Android). Não é segredo: o acesso
/// é controlado pelas regras em firebase/firestore.rules.
///
/// null = nuvem não configurada (o app funciona só local).
// ignore: unnecessary_nullable_for_final_variable_declarations
const FirebaseOptions? firebaseAndroid = FirebaseOptions(
  apiKey: 'AIzaSyC--2c2wMRa4pNx9LWBc1UR1dUJtKnNZT0',
  appId: '1:911820467893:android:7f3ba5ca11ec762c8058fc',
  messagingSenderId: '911820467893',
  projectId: 'arion-cifras',
  storageBucket: 'arion-cifras.firebasestorage.app',
);

/// null até registrar o app iOS no mesmo projeto Firebase
/// (bundle `com.mvini.arion`) e colar aqui o bloco do console.
const FirebaseOptions? firebaseIos = null;
