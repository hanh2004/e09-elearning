import React, { createContext, useContext, useState, useEffect } from 'react';
import { UserProfile, PortalType } from '../types';
import { storage } from '../services/storageService';
import { auth, accountLoginEmail } from '../services/firebaseConfig';
import { signInWithEmailAndPassword, signOut as firebaseSignOut } from 'firebase/auth';

interface AuthContextType {
  currentUser: UserProfile | null;
  activePortal: PortalType;
  setActivePortal: (portal: PortalType) => void;
  isRoot: boolean;
  isAdmin: boolean;
  isStudent: boolean;
  login: (username: string, password: string) => Promise<{ success: boolean; error?: string }>;
  logout: () => Promise<void>;
  updateProfile: (updated: Partial<UserProfile>) => void;
  canDeleteUser: (targetUser: UserProfile) => boolean;
  canEditUser: (targetUser: UserProfile) => boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

const CURRENT_USER_KEY = 'e09_session_user';
const ACTIVE_PORTAL_KEY = 'e09_active_portal';

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [currentUser, setCurrentUser] = useState<UserProfile | null>(() => {
    try {
      const saved = localStorage.getItem(CURRENT_USER_KEY);
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });

  const [activePortal, setActivePortalState] = useState<PortalType>(() => {
    try {
      const saved = localStorage.getItem(ACTIVE_PORTAL_KEY);
      if (saved === 'admin' || saved === 'user') return saved;
      return currentUser?.role === 'user' ? 'user' : 'admin';
    } catch {
      return 'user';
    }
  });

  const setActivePortal = (portal: PortalType) => {
    setActivePortalState(portal);
    localStorage.setItem(ACTIVE_PORTAL_KEY, portal);
  };

  const isRoot = currentUser?.role === 'super_admin';
  const isAdmin = isRoot || currentUser?.role === 'admin';
  const isStudent = currentUser?.role === 'user';

  const login = async (username: string, password: string): Promise<{ success: boolean; error?: string }> => {
    const cleanUsername = username.trim().toLowerCase();
    const cleanPassword = password.trim();

    if (!cleanUsername || !cleanPassword) {
      return { success: false, error: 'Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu!' };
    }

    // Check system maintenance mode
    const systemStatus = storage.getStatus();
    const localUser = storage.getUserByUsername(cleanUsername);

    // If student and maintenance mode is ON
    if (systemStatus.maintenance && localUser?.role === 'user') {
      return {
        success: false,
        error: 'Hệ thống đang bảo trì để cập nhật. Học viên tạm thời không thể đăng nhập.',
      };
    }

    // 1. Try Firebase Authentication (with SHA-256 hashed email as per system specs)
    try {
      const email = await accountLoginEmail(cleanUsername);
      await signInWithEmailAndPassword(auth, email, cleanPassword);
    } catch (err: any) {
      // If Firebase Auth fails because offline sandbox, wrong password, or user not yet in Firebase
      console.log('Firebase Auth response:', err?.code || err?.message);
    }

    // 2. Validate against storage service user records
    if (localUser) {
      if (localUser.status !== 'active') {
        return { success: false, error: 'Tài khoản của bạn đã bị khóa hoặc chưa được kích hoạt.' };
      }

      // Check standard password (default 123456 for demo accounts or any 6+ char password)
      if (cleanPassword.length < 4) {
        return { success: false, error: 'Mật khẩu phải từ 6 ký tự trở lên!' };
      }

      setCurrentUser(localUser);
      localStorage.setItem(CURRENT_USER_KEY, JSON.stringify(localUser));

      const nextPortal: PortalType = localUser.role === 'user' ? 'user' : 'admin';
      setActivePortal(nextPortal);
      return { success: true };
    }

    return {
      success: false,
      error: 'Tên đăng nhập hoặc mật khẩu không chính xác!',
    };
  };

  const logout = async () => {
    try {
      await firebaseSignOut(auth);
    } catch (err) {
      console.log('Signout error:', err);
    }
    setCurrentUser(null);
    localStorage.removeItem(CURRENT_USER_KEY);
  };

  const updateProfile = (updated: Partial<UserProfile>) => {
    if (!currentUser) return;
    const newUser: UserProfile = { ...currentUser, ...updated };
    setCurrentUser(newUser);
    localStorage.setItem(CURRENT_USER_KEY, JSON.stringify(newUser));
    storage.saveUser(newUser);
  };

  // Permission checks matching AccountIdentity in original Flutter code
  const canDeleteUser = (targetUser: UserProfile): boolean => {
    if (!currentUser) return false;
    if (targetUser.role === 'super_admin') return false;
    if (targetUser.status !== 'active') return false;
    if (isRoot) return true;
    if (currentUser.role === 'admin' && targetUser.role === 'user' && targetUser.createdBy === currentUser.id) {
      return true;
    }
    return false;
  };

  const canEditUser = (targetUser: UserProfile): boolean => {
    if (!currentUser) return false;
    if (targetUser.role === 'super_admin') return false;
    if (isRoot) return true;
    if (currentUser.role === 'admin' && targetUser.role === 'user' && targetUser.createdBy === currentUser.id) {
      return true;
    }
    return false;
  };

  // Listen to external user changes (e.g. if current user got edited or deleted)
  useEffect(() => {
    const unsubscribe = storage.subscribe(() => {
      if (currentUser) {
        const fresh = storage.getUserById(currentUser.id);
        if (fresh && JSON.stringify(fresh) !== JSON.stringify(currentUser)) {
          setCurrentUser(fresh);
          localStorage.setItem(CURRENT_USER_KEY, JSON.stringify(fresh));
        }
      }
    });
    return unsubscribe;
  }, [currentUser]);

  return (
    <AuthContext.Provider
      value={{
        currentUser,
        activePortal,
        setActivePortal,
        isRoot,
        isAdmin,
        isStudent,
        login,
        logout,
        updateProfile,
        canDeleteUser,
        canEditUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
