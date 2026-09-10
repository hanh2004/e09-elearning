import React, { useState } from 'react';
import { AuthProvider, useAuth } from './context/AuthContext';
import { LoginScreen } from './components/auth/LoginScreen';
import { UserNavbar } from './components/common/UserNavbar';
import { UserHomeScreen } from './components/user/UserHomeScreen';
import { UserExamScreen } from './components/user/UserExamScreen';
import { UserResultScreen } from './components/user/UserResultScreen';
import { UserExamHistoryScreen } from './components/user/UserExamHistoryScreen';
import { UserProfileScreen } from './components/user/UserProfileScreen';

// Admin Components
import { AdminSidebar } from './components/admin/AdminSidebar';
import { AdminHomeScreen } from './components/admin/AdminHomeScreen';
import { AdminExamScreen } from './components/admin/AdminExamScreen';
import { AdminQuestionBankScreen } from './components/admin/AdminQuestionBankScreen';
import { AdminAccountScreen } from './components/admin/AdminAccountScreen';
import { AdminRequestsScreen } from './components/admin/AdminRequestsScreen';
import { AdminProgressScreen } from './components/admin/AdminProgressScreen';
import { AdminReportScreen } from './components/admin/AdminReportScreen';
import { AdminSettingsScreen } from './components/admin/AdminSettingsScreen';

import { storage } from './services/storageService';
import { AdminTab, UserTab, Exam, Question, ExamAttempt } from './types';
import { Menu } from 'lucide-react';

const MainApp: React.FC = () => {
  const { currentUser, activePortal, setActivePortal, isAdmin } = useAuth();

  // User Portal Navigation State
  const [userTab, setUserTab] = useState<UserTab>('home');
  const [activeExam, setActiveExam] = useState<Exam | null>(null);
  const [examResult, setExamResult] = useState<{
    attempt: ExamAttempt;
    questions: Question[];
    exam: Exam;
  } | null>(null);

  // Admin Portal Navigation State
  const [adminTab, setAdminTab] = useState<AdminTab>('dashboard');
  const [adminExamQuestionsId, setAdminExamQuestionsId] = useState<string | null>(null);
  const [mobileAdminSidebarOpen, setMobileAdminSidebarOpen] = useState(false);

  // Pending Requests count for Root badge
  const pendingRequests = storage.getRequests().filter((r) => r.status === 'pending');

  if (!currentUser) {
    return <LoginScreen />;
  }

  // --- ADMIN PORTAL VIEW ---
  if (activePortal === 'admin' && isAdmin) {
    return (
      <div className="min-h-screen bg-slate-50 flex">
        {/* Responsive Admin Sidebar */}
        <AdminSidebar
          currentTab={adminTab}
          onSelectTab={(tab) => {
            setAdminTab(tab);
            setAdminExamQuestionsId(null);
          }}
          pendingRequestsCount={pendingRequests.length}
          mobileOpen={mobileAdminSidebarOpen}
          setMobileOpen={setMobileAdminSidebarOpen}
        />

        {/* Main Content Area */}
        <div className="flex-1 lg:pl-72 flex flex-col min-w-0">
          {/* Top Mobile Bar */}
          <div className="lg:hidden h-14 bg-slate-900 px-4 flex items-center justify-between text-white sticky top-0 z-30 shadow-sm">
            <button
              onClick={() => setMobileAdminSidebarOpen(true)}
              className="p-1.5 rounded-lg text-slate-300 hover:text-white hover:bg-slate-800 cursor-pointer"
            >
              <Menu className="w-5 h-5" />
            </button>
            <span className="font-bold text-sm">E-09 Quản Trị</span>
            <div className="w-5" />
          </div>

          <main className="flex-1 p-4 sm:p-6 lg:p-8 max-w-7xl w-full mx-auto">
            {adminExamQuestionsId ? (
              <AdminQuestionBankScreen
                examId={adminExamQuestionsId}
                onBack={() => setAdminExamQuestionsId(null)}
              />
            ) : adminTab === 'dashboard' ? (
              <AdminHomeScreen
                onNavigateTab={(tab) => {
                  setAdminTab(tab);
                  setAdminExamQuestionsId(null);
                }}
                onOpenQuestions={(id) => setAdminExamQuestionsId(id)}
              />
            ) : adminTab === 'exams' ? (
              <AdminExamScreen onOpenQuestions={(id) => setAdminExamQuestionsId(id)} />
            ) : adminTab === 'accounts' ? (
              <AdminAccountScreen />
            ) : adminTab === 'requests' ? (
              <AdminRequestsScreen />
            ) : adminTab === 'progress' ? (
              <AdminProgressScreen />
            ) : adminTab === 'reports' ? (
              <AdminReportScreen />
            ) : (
              <AdminSettingsScreen />
            )}
          </main>
        </div>
      </div>
    );
  }

  // --- USER PORTAL VIEW ---
  // Active exam taking mode (Full Screen)
  if (activeExam) {
    return (
      <UserExamScreen
        exam={activeExam}
        onExit={() => setActiveExam(null)}
        onFinish={(attempt, questions) => {
          setExamResult({ attempt, questions, exam: activeExam });
          setActiveExam(null);
        }}
      />
    );
  }

  // Exam Result mode
  if (examResult) {
    return (
      <div className="min-h-screen bg-slate-50">
        <UserNavbar currentTab={userTab} onSelectTab={(tab) => {
          setExamResult(null);
          setUserTab(tab);
        }} />
        <UserResultScreen
          attempt={examResult.attempt}
          questions={examResult.questions}
          exam={examResult.exam}
          onRetake={() => {
            const reExam = examResult.exam;
            setExamResult(null);
            setActiveExam(reExam);
          }}
          onGoHome={() => {
            setExamResult(null);
            setUserTab('home');
          }}
          onGoHistory={() => {
            setExamResult(null);
            setUserTab('history');
          }}
        />
      </div>
    );
  }

  // Standard User Dashboard
  return (
    <div className="min-h-screen bg-slate-50 flex flex-col">
      <UserNavbar currentTab={userTab} onSelectTab={setUserTab} />

      <main className="flex-1">
        {userTab === 'home' && (
          <UserHomeScreen
            onStartExam={(exam) => {
              setActiveExam(exam);
            }}
          />
        )}
        {userTab === 'history' && <UserExamHistoryScreen />}
        {userTab === 'profile' && <UserProfileScreen />}
      </main>

      <footer className="py-6 text-center text-xs text-slate-400 border-t border-slate-200/60 mt-8">
        Hệ thống thi trực tuyến E-09 E-Learning • Bản quyền © 2025
      </footer>
    </div>
  );
};

export function App() {
  return (
    <AuthProvider>
      <MainApp />
    </AuthProvider>
  );
}

export default App;
