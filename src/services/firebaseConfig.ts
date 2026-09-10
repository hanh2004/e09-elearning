import { initializeApp, getApps, getApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

// Web Firebase config matching original Flutter project options
export const firebaseConfig = {
  apiKey: 'AIzaSyCpde74WXCCK6eZYvzeYpMNS5zi1HMa2kU',
  authDomain: 'e09-elearning.firebaseapp.com',
  projectId: 'e09-elearning',
  storageBucket: 'e09-elearning.firebasestorage.app',
  messagingSenderId: '722108374060',
  appId: '1:722108374060:web:3e518c94015ef130eec589',
  measurementId: 'G-227M17KM4Y',
};

// Initialize Firebase safely
export const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);

// Simple SHA-256 implementation using browser Web Crypto API
export async function sha256Hex(message: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(message.trim().toLowerCase());
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
}

// Convert username to SHA256 email used by the Flutter backend auth
export async function accountLoginEmail(username: string): Promise<string> {
  const hash = await sha256Hex(username);
  return `${hash}@accounts.invalid`;
}
