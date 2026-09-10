export type UserRole = 'super_admin' | 'admin' | 'user';

export type AccountStatus = 'active' | 'pending' | 'rejected' | 'disabled';

export interface UserProfile {
  id: string;
  username: string;
  name: string;
  role: UserRole;
  status: AccountStatus;
  createdBy?: string | null;
  approvedBy?: string | null;
  school?: string;
  className?: string;
  phoneNumber?: string;
  avatarUrl?: string;
  createdAt?: string;
}

export interface Exam {
  id: string;
  title: string;
  duration?: string; // e.g. "90 phút" for display
  durationMinutes: number;
  isOpen: boolean;
  maxAttempts?: number | null; // null = unlimited
  closesAt?: string | null; // ISO date string or null
  createdAt?: string;
  description?: string;
}

export interface Question {
  id: string;
  examId: string;
  questionText: string;
  options: string[]; // 4 options
  correctAnswerIndex: number; // 0..3
  explanation?: string;
}

export interface ExamAttempt {
  id: string;
  examId: string;
  examTitle: string;
  userId: string;
  userName?: string;
  startedAt: string;
  endsAt: string;
  completedAt?: string | null;
  bestCompletedAt?: string | null;
  lastAttemptAt?: string;
  status: 'in_progress' | 'completed';
  attemptCount: number;
  diemSo?: number; // Last score (0..10)
  bestScore?: number; // Best score (0..10)
  correctAnswers?: number;
  totalQuestions?: number;
  selectedAnswers?: Record<number, number>; // question index -> option index
  currentQuestionIndex?: number;
}

export interface AdminRequest {
  id: string;
  name: string;
  username: string;
  status: 'pending' | 'approved' | 'rejected';
  createdBy: string;
  createdByName?: string;
  targetUid?: string;
  createdAt: string;
}

export interface AppStatus {
  maintenance: boolean;
  updatedAt?: string;
  updatedBy?: string;
}

export type PortalType = 'user' | 'admin';

export type AdminTab = 'dashboard' | 'exams' | 'accounts' | 'requests' | 'progress' | 'reports' | 'settings';
export type UserTab = 'home' | 'history' | 'profile';
