import { Exam, Question, ExamAttempt, UserProfile, AdminRequest, AppStatus } from '../types';

// Key for local persistence fallback
const STORAGE_KEYS = {
  USERS: 'e09_users_v1',
  EXAMS: 'e09_exams_v1',
  QUESTIONS: 'e09_questions_v1',
  ATTEMPTS: 'e09_attempts_v1',
  REQUESTS: 'e09_requests_v1',
  STATUS: 'e09_status_v1',
};

// Initial Seed Users
const SEED_USERS: UserProfile[] = [
  {
    id: 'user_root_1',
    username: 'admintong1',
    name: 'Nguyễn Đình Hùng (Admin Tổng 1)',
    role: 'super_admin',
    status: 'active',
    createdBy: null,
    approvedBy: null,
    phoneNumber: '0901234567',
    school: 'Sở GD&ĐT',
    createdAt: new Date(Date.now() - 30 * 86400000).toISOString(),
  },
  {
    id: 'user_root_2',
    username: 'admintong2',
    name: 'Trần Văn Mạnh (Admin Tổng 2)',
    role: 'super_admin',
    status: 'active',
    createdBy: null,
    approvedBy: null,
    phoneNumber: '0907654321',
    school: 'Sở GD&ĐT',
    createdAt: new Date(Date.now() - 30 * 86400000).toISOString(),
  },
  {
    id: 'user_admin_1',
    username: 'gv_toan',
    name: 'Thầy Nguyễn Văn Toàn (GV Toán)',
    role: 'admin',
    status: 'active',
    createdBy: 'user_root_1',
    approvedBy: 'user_root_2',
    phoneNumber: '0912345678',
    school: 'THPT Chuyên Lê Hồng Phong',
    createdAt: new Date(Date.now() - 15 * 86400000).toISOString(),
  },
  {
    id: 'user_student_1',
    username: 'hocsinh1',
    name: 'Trần Minh Quân',
    role: 'user',
    status: 'active',
    createdBy: 'user_admin_1',
    className: '12A1',
    school: 'THPT Chuyên Lê Hồng Phong',
    phoneNumber: '0981112233',
    createdAt: new Date(Date.now() - 10 * 86400000).toISOString(),
  },
  {
    id: 'user_student_2',
    username: 'hocsinh2',
    name: 'Lê Thu Hà',
    role: 'user',
    status: 'active',
    createdBy: 'user_admin_1',
    className: '12A1',
    school: 'THPT Chuyên Lê Hồng Phong',
    phoneNumber: '0982223344',
    createdAt: new Date(Date.now() - 9 * 86400000).toISOString(),
  },
  {
    id: 'user_student_3',
    username: 'hocsinh3',
    name: 'Phạm Quốc Dũng',
    role: 'user',
    status: 'active',
    createdBy: 'user_admin_1',
    className: '12A2',
    school: 'THPT Chuyên Lê Hồng Phong',
    phoneNumber: '0983334455',
    createdAt: new Date(Date.now() - 8 * 86400000).toISOString(),
  },
];

// Initial Seed Exams
const SEED_EXAMS: Exam[] = [
  {
    id: 'exam_toan_12',
    title: 'Kiểm tra Toán 12 - Khảo sát hàm số & Tích phân',
    duration: '45 phút',
    durationMinutes: 45,
    isOpen: true,
    maxAttempts: 3,
    closesAt: null,
    createdAt: new Date(Date.now() - 7 * 86400000).toISOString(),
    description: 'Đề kiểm tra trọng tâm chương trình Giải tích lớp 12 bao gồm cực trị hàm số, tiệm cận và ứng dụng tích phân tính diện tích hình phẳng.',
  },
  {
    id: 'exam_anh_thpt',
    title: 'Đề thi Tiếng Anh THPT Quốc Gia - Đề số 01',
    duration: '50 phút',
    durationMinutes: 50,
    isOpen: true,
    maxAttempts: null, // unlimited
    closesAt: null,
    createdAt: new Date(Date.now() - 5 * 86400000).toISOString(),
    description: 'Đề luyện thi trắc nghiệm Tiếng Anh chuẩn format Bộ GD&ĐT gồm ngữ âm, ngữ pháp, từ đồng nghĩa và điền từ vào đoạn văn.',
  },
  {
    id: 'exam_ly_12',
    title: 'Kiểm tra Vật lý 12 - Dao động cơ & Sóng cơ học',
    duration: '45 phút',
    durationMinutes: 45,
    isOpen: true,
    maxAttempts: 2,
    closesAt: null,
    createdAt: new Date(Date.now() - 3 * 86400000).toISOString(),
    description: 'Chuyên đề dao động điều hòa của con lắc lò xo, con lắc đơn, giao thoa sóng cơ và sóng dừng trên dây.',
  },
  {
    id: 'exam_su_12',
    title: 'Lịch sử Việt Nam - Giai đoạn 1945 - 1975',
    duration: '30 phút',
    durationMinutes: 30,
    isOpen: false,
    maxAttempts: 1,
    closesAt: null,
    createdAt: new Date(Date.now() - 14 * 86400000).toISOString(),
    description: 'Tổng hợp kiến thức hai cuộc kháng chiến chống thực dân Pháp và đế quốc Mỹ cứu nước.',
  },
];

// Initial Seed Questions
const SEED_QUESTIONS: Question[] = [
  // Toan 12
  {
    id: 'q_toan_1',
    examId: 'exam_toan_12',
    questionText: 'Hàm số y = x³ - 3x² + 2 đạt cực đại tại điểm nào?',
    options: ['x = 0', 'x = 2', 'x = 1', 'x = -1'],
    correctAnswerIndex: 0,
    explanation: 'Ta có y\' = 3x² - 6x = 3x(x - 2). y\' = 0 <=> x = 0 hoặc x = 2. Qua x = 0, y\' đổi dấu từ dương sang âm nên x = 0 là điểm cực đại.',
  },
  {
    id: 'q_toan_2',
    examId: 'exam_toan_12',
    questionText: 'Đồ thị hàm số y = (2x + 1)/(x - 1) có đường tiệm cận đứng là đường thẳng nào sau đây?',
    options: ['x = 1', 'x = 2', 'y = 2', 'y = 1'],
    correctAnswerIndex: 0,
    explanation: 'Tiệm cận đứng của hàm phân thức bậc nhất trên bậc nhất là nghiệm của mẫu số: x - 1 = 0 <=> x = 1.',
  },
  {
    id: 'q_toan_3',
    examId: 'exam_toan_12',
    questionText: 'Cho hàm số f(x) có đạo hàm f\'(x) = x(x - 1)²(x + 2)³. Số điểm cực trị của hàm số f(x) là:',
    options: ['2', '3', '1', '4'],
    correctAnswerIndex: 0,
    explanation: 'Điểm cực trị chỉ xuất hiện khi đạo hàm đổi dấu qua nghiệm bội lẻ. Các nghiệm x = 0 (bội 1) và x = -2 (bội 3) là các nghiệm bội lẻ, còn x = 1 là nghiệm bội chẵn. Vậy có 2 điểm cực trị.',
  },
  {
    id: 'q_toan_4',
    examId: 'exam_toan_12',
    questionText: 'Tính tích phân I = ∫ (từ 0 đến 1) e^(2x) dx.',
    options: ['(e² - 1)/2', 'e² - 1', '(e² + 1)/2', '2(e² - 1)'],
    correctAnswerIndex: 0,
    explanation: 'Nguyên hàm của e^(2x) là (1/2)e^(2x). Thay cận từ 0 đến 1: (1/2)(e² - e⁰) = (e² - 1)/2.',
  },
  {
    id: 'q_toan_5',
    examId: 'exam_toan_12',
    questionText: 'Trong không gian Oxyz, cho mặt phẳng (P): 2x - y + 3z - 5 = 0. Vectơ nào dưới đây là một vectơ pháp tuyến của (P)?',
    options: ['n = (2; -1; 3)', 'n = (2; 1; 3)', 'n = (2; -1; -5)', 'n = (-2; -1; 3)'],
    correctAnswerIndex: 0,
    explanation: 'Mặt phẳng Ax + By + Cz + D = 0 có vectơ pháp tuyến là n = (A; B; C) = (2; -1; 3).',
  },
  {
    id: 'q_toan_6',
    examId: 'exam_toan_12',
    questionText: 'Giá trị nhỏ nhất của hàm số f(x) = x + 4/x trên đoạn [1; 3] là:',
    options: ['4', '5', '13/3', '3'],
    correctAnswerIndex: 0,
    explanation: 'Theo BĐT Cô-si với x > 0: x + 4/x >= 2√(x * 4/x) = 4. Dấu bằng xảy ra khi x = 4/x <=> x = 2 ∈ [1; 3]. Vậy min = 4.',
  },
  {
    id: 'q_toan_7',
    examId: 'exam_toan_12',
    questionText: 'Tập xác định của hàm số y = log₂(2x - 4) là:',
    options: ['(2; +∞)', '[2; +∞)', '(4; +∞)', '(-∞; 2)'],
    correctAnswerIndex: 0,
    explanation: 'Điều kiện xác định của biểu thức dưới dấu logarit: 2x - 4 > 0 <=> 2x > 4 <=> x > 2.',
  },
  {
    id: 'q_toan_8',
    examId: 'exam_toan_12',
    questionText: 'Thể tích của khối chóp có diện tích đáy B = 6 cm² và chiều cao h = 4 cm là:',
    options: ['8 cm³', '24 cm³', '12 cm³', '16 cm³'],
    correctAnswerIndex: 0,
    explanation: 'Công thức thể tích khối chóp là V = (1/3) * B * h = (1/3) * 6 * 4 = 8 cm³.',
  },

  // Tieng Anh
  {
    id: 'q_anh_1',
    examId: 'exam_anh_thpt',
    questionText: 'Choose the word whose underlined part is pronounced differently from that of the others: "laughed", "watched", "stopped", "cleaned"',
    options: ['cleaned', 'laughed', 'watched', 'stopped'],
    correctAnswerIndex: 0,
    explanation: '"cleaned" kết thúc bằng âm hữu thanh nên đuôi -ed phát âm là /d/. Các từ còn lại đuôi -ed phát âm là /t/.',
  },
  {
    id: 'q_anh_2',
    examId: 'exam_anh_thpt',
    questionText: 'If Mary had studied harder, she _______ the entrance exam last summer.',
    options: ['would have passed', 'would pass', 'will pass', 'had passed'],
    correctAnswerIndex: 0,
    explanation: 'Câu điều kiện loại 3 diễn tả giả định trái với quá khứ: If + S + had + P2, S + would/could + have + P2.',
  },
  {
    id: 'q_anh_3',
    examId: 'exam_anh_thpt',
    questionText: 'Neither John nor his friends _______ going to the concert tonight.',
    options: ['are', 'is', 'was', 'were'],
    correctAnswerIndex: 0,
    explanation: 'Cấu trúc "Neither A nor B + V": động từ chia theo chủ ngữ gần nhất là "his friends" (số nhiều) ở thì hiện tại => "are".',
  },
  {
    id: 'q_anh_4',
    examId: 'exam_anh_thpt',
    questionText: 'Choose the word OPPOSITE in meaning to the underlined word: "The teacher gave us a very **lenient** punishment."',
    options: ['strict', 'gentle', 'pleasant', 'easy'],
    correctAnswerIndex: 0,
    explanation: '"lenient" nghĩa là khoan dung, nhẹ nhàng. Từ trái nghĩa là "strict" (nghiêm khắc).',
  },
  {
    id: 'q_anh_5',
    examId: 'exam_anh_thpt',
    questionText: 'She is interested _______ learning foreign languages, especially Japanese and Korean.',
    options: ['in', 'on', 'at', 'about'],
    correctAnswerIndex: 0,
    explanation: 'Cụm từ cố định: "be interested in something / doing something" nghĩa là quan tâm, thích thú cái gì.',
  },
  {
    id: 'q_anh_6',
    examId: 'exam_anh_thpt',
    questionText: 'The doctor advised him to give _______ smoking to protect his health.',
    options: ['up', 'in', 'out', 'off'],
    correctAnswerIndex: 0,
    explanation: 'Phrasal verb "give up" có nghĩa là từ bỏ một thói quen xấu như hút thuốc.',
  },

  // Vat ly
  {
    id: 'q_ly_1',
    examId: 'exam_ly_12',
    questionText: 'Một vật dao động điều hòa theo phương trình x = 5cos(4πt + π/3) (cm). Tần số góc của dao động là:',
    options: ['4π rad/s', '2π rad/s', '4 rad/s', '2 Hz'],
    correctAnswerIndex: 0,
    explanation: 'Trong phương trình x = A*cos(ωt + φ), hệ số trước t chính là tần số góc ω = 4π rad/s.',
  },
  {
    id: 'q_ly_2',
    examId: 'exam_ly_12',
    questionText: 'Con lắc lò xo có độ cứng k = 100 N/m gắn với vật có khối lượng m = 1 kg. Chu kì dao động riêng của con lắc là:',
    options: ['0,2π (s)', '2π (s)', '0,1π (s)', '10π (s)'],
    correctAnswerIndex: 0,
    explanation: 'Chu kì dao động của con lắc lò xo: T = 2π√(m/k) = 2π√(1/100) = 2π * 0.1 = 0,2π (s).',
  },
  {
    id: 'q_ly_3',
    examId: 'exam_ly_12',
    questionText: 'Sóng cơ không truyền được trong môi trường nào sau đây?',
    options: ['Chân không', 'Chất rắn', 'Chất lỏng', 'Chất khí'],
    correctAnswerIndex: 0,
    explanation: 'Sóng cơ là sự lan truyền dao động cơ học trong môi trường vật chất đàn hồi, nên không thể truyền trong chân không.',
  },
  {
    id: 'q_ly_4',
    examId: 'exam_ly_12',
    questionText: 'Khi xảy ra hiện tượng cộng hưởng cơ, đại lượng nào sau đây đạt giá trị cực đại?',
    options: ['Biên độ dao động', 'Chu kì dao động', 'Tần số dao động', 'Pha ban đầu'],
    correctAnswerIndex: 0,
    explanation: 'Hiện tượng cộng hưởng xảy ra khi tần số của lực cưỡng bức bằng tần số riêng của hệ, làm cho biên độ dao động cưỡng bức đạt giá trị cực đại.',
  },
];

// Initial Seed Attempts for realistic Leaderboard and Progress
const SEED_ATTEMPTS: ExamAttempt[] = [
  {
    id: 'att_1',
    examId: 'exam_toan_12',
    examTitle: 'Kiểm tra Toán 12 - Khảo sát hàm số & Tích phân',
    userId: 'user_student_1',
    userName: 'Trần Minh Quân',
    startedAt: new Date(Date.now() - 48 * 3600000).toISOString(),
    endsAt: new Date(Date.now() - 48 * 3600000 + 45 * 60000).toISOString(),
    completedAt: new Date(Date.now() - 48 * 3600000 + 35 * 60000).toISOString(),
    bestCompletedAt: new Date(Date.now() - 48 * 3600000 + 35 * 60000).toISOString(),
    lastAttemptAt: new Date(Date.now() - 48 * 3600000 + 35 * 60000).toISOString(),
    status: 'completed',
    attemptCount: 1,
    diemSo: 8.75,
    bestScore: 8.75,
    correctAnswers: 7,
    totalQuestions: 8,
    selectedAnswers: { 0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 1 },
  },
  {
    id: 'att_2',
    examId: 'exam_anh_thpt',
    examTitle: 'Đề thi Tiếng Anh THPT Quốc Gia - Đề số 01',
    userId: 'user_student_1',
    userName: 'Trần Minh Quân',
    startedAt: new Date(Date.now() - 24 * 3600000).toISOString(),
    endsAt: new Date(Date.now() - 24 * 3600000 + 50 * 60000).toISOString(),
    completedAt: new Date(Date.now() - 24 * 3600000 + 40 * 60000).toISOString(),
    bestCompletedAt: new Date(Date.now() - 24 * 3600000 + 40 * 60000).toISOString(),
    lastAttemptAt: new Date(Date.now() - 24 * 3600000 + 40 * 60000).toISOString(),
    status: 'completed',
    attemptCount: 1,
    diemSo: 10.0,
    bestScore: 10.0,
    correctAnswers: 6,
    totalQuestions: 6,
    selectedAnswers: { 0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 },
  },
  {
    id: 'att_3',
    examId: 'exam_toan_12',
    examTitle: 'Kiểm tra Toán 12 - Khảo sát hàm số & Tích phân',
    userId: 'user_student_2',
    userName: 'Lê Thu Hà',
    startedAt: new Date(Date.now() - 12 * 3600000).toISOString(),
    endsAt: new Date(Date.now() - 12 * 3600000 + 45 * 60000).toISOString(),
    completedAt: new Date(Date.now() - 12 * 3600000 + 38 * 60000).toISOString(),
    bestCompletedAt: new Date(Date.now() - 12 * 3600000 + 38 * 60000).toISOString(),
    lastAttemptAt: new Date(Date.now() - 12 * 3600000 + 38 * 60000).toISOString(),
    status: 'completed',
    attemptCount: 2,
    diemSo: 9.5,
    bestScore: 9.5,
    correctAnswers: 8,
    totalQuestions: 8,
    selectedAnswers: { 0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0 },
  },
  {
    id: 'att_4',
    examId: 'exam_ly_12',
    examTitle: 'Kiểm tra Vật lý 12 - Dao động cơ & Sóng cơ học',
    userId: 'user_student_3',
    userName: 'Phạm Quốc Dũng',
    startedAt: new Date(Date.now() - 6 * 3600000).toISOString(),
    endsAt: new Date(Date.now() - 6 * 3600000 + 45 * 60000).toISOString(),
    completedAt: new Date(Date.now() - 6 * 3600000 + 30 * 60000).toISOString(),
    bestCompletedAt: new Date(Date.now() - 6 * 3600000 + 30 * 60000).toISOString(),
    lastAttemptAt: new Date(Date.now() - 6 * 3600000 + 30 * 60000).toISOString(),
    status: 'completed',
    attemptCount: 1,
    diemSo: 7.5,
    bestScore: 7.5,
    correctAnswers: 3,
    totalQuestions: 4,
    selectedAnswers: { 0: 0, 1: 0, 2: 0, 3: 1 },
  },
];

// Initial Seed Admin Request
const SEED_REQUESTS: AdminRequest[] = [
  {
    id: 'req_1',
    name: 'Cô Hoàng Thị Mai (GV Tiếng Anh)',
    username: 'gv_mai',
    status: 'pending',
    createdBy: 'user_root_1',
    createdByName: 'Admin Tổng 1',
    createdAt: new Date(Date.now() - 2 * 86400000).toISOString(),
  },
];

// Initial Seed Status
const SEED_STATUS: AppStatus = {
  maintenance: false,
  updatedAt: new Date().toISOString(),
  updatedBy: 'user_root_1',
};

// Storage Service class with listener subscription pattern
type Listener = () => void;

class StorageService {
  private listeners: Set<Listener> = new Set();

  constructor() {
    this.initIfEmpty();
  }

  private initIfEmpty() {
    if (!localStorage.getItem(STORAGE_KEYS.USERS)) {
      localStorage.setItem(STORAGE_KEYS.USERS, JSON.stringify(SEED_USERS));
    }
    if (!localStorage.getItem(STORAGE_KEYS.EXAMS)) {
      localStorage.setItem(STORAGE_KEYS.EXAMS, JSON.stringify(SEED_EXAMS));
    }
    if (!localStorage.getItem(STORAGE_KEYS.QUESTIONS)) {
      localStorage.setItem(STORAGE_KEYS.QUESTIONS, JSON.stringify(SEED_QUESTIONS));
    }
    if (!localStorage.getItem(STORAGE_KEYS.ATTEMPTS)) {
      localStorage.setItem(STORAGE_KEYS.ATTEMPTS, JSON.stringify(SEED_ATTEMPTS));
    }
    if (!localStorage.getItem(STORAGE_KEYS.REQUESTS)) {
      localStorage.setItem(STORAGE_KEYS.REQUESTS, JSON.stringify(SEED_REQUESTS));
    }
    if (!localStorage.getItem(STORAGE_KEYS.STATUS)) {
      localStorage.setItem(STORAGE_KEYS.STATUS, JSON.stringify(SEED_STATUS));
    }
  }

  subscribe(listener: Listener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private notify() {
    this.listeners.forEach((l) => l());
  }

  // --- USERS ---
  getUsers(): UserProfile[] {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.USERS);
      return data ? JSON.parse(data) : SEED_USERS;
    } catch {
      return SEED_USERS;
    }
  }

  getUserById(id: string): UserProfile | undefined {
    return this.getUsers().find((u) => u.id === id);
  }

  getUserByUsername(username: string): UserProfile | undefined {
    return this.getUsers().find((u) => u.username.toLowerCase() === username.trim().toLowerCase());
  }

  saveUser(user: UserProfile) {
    const users = this.getUsers();
    const idx = users.findIndex((u) => u.id === user.id);
    if (idx >= 0) {
      users[idx] = user;
    } else {
      users.push(user);
    }
    localStorage.setItem(STORAGE_KEYS.USERS, JSON.stringify(users));
    this.notify();
  }

  deleteUser(id: string) {
    let users = this.getUsers();
    users = users.filter((u) => u.id !== id);
    localStorage.setItem(STORAGE_KEYS.USERS, JSON.stringify(users));
    this.notify();
  }

  // --- EXAMS ---
  getExams(): Exam[] {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.EXAMS);
      return data ? JSON.parse(data) : SEED_EXAMS;
    } catch {
      return SEED_EXAMS;
    }
  }

  getExamById(id: string): Exam | undefined {
    return this.getExams().find((e) => e.id === id);
  }

  saveExam(exam: Exam) {
    const exams = this.getExams();
    const idx = exams.findIndex((e) => e.id === exam.id);
    if (idx >= 0) {
      exams[idx] = exam;
    } else {
      exams.unshift(exam);
    }
    localStorage.setItem(STORAGE_KEYS.EXAMS, JSON.stringify(exams));
    this.notify();
  }

  deleteExam(id: string) {
    let exams = this.getExams();
    exams = exams.filter((e) => e.id !== id);
    localStorage.setItem(STORAGE_KEYS.EXAMS, JSON.stringify(exams));

    // Also delete associated questions and attempts
    let questions = this.getQuestions();
    questions = questions.filter((q) => q.examId !== id);
    localStorage.setItem(STORAGE_KEYS.QUESTIONS, JSON.stringify(questions));

    let attempts = this.getAttempts();
    attempts = attempts.filter((a) => a.examId !== id);
    localStorage.setItem(STORAGE_KEYS.ATTEMPTS, JSON.stringify(attempts));

    this.notify();
  }

  toggleExamStatus(id: string) {
    const exams = this.getExams();
    const exam = exams.find((e) => e.id === id);
    if (exam) {
      exam.isOpen = !exam.isOpen;
      localStorage.setItem(STORAGE_KEYS.EXAMS, JSON.stringify(exams));
      this.notify();
    }
  }

  // --- QUESTIONS ---
  getQuestions(examId?: string): Question[] {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.QUESTIONS);
      const all = data ? JSON.parse(data) : SEED_QUESTIONS;
      return examId ? all.filter((q: Question) => q.examId === examId) : all;
    } catch {
      return SEED_QUESTIONS;
    }
  }

  saveQuestion(question: Question) {
    const questions = this.getQuestions();
    const idx = questions.findIndex((q) => q.id === question.id);
    if (idx >= 0) {
      questions[idx] = question;
    } else {
      questions.push(question);
    }
    localStorage.setItem(STORAGE_KEYS.QUESTIONS, JSON.stringify(questions));
    this.notify();
  }

  deleteQuestion(id: string) {
    let questions = this.getQuestions();
    questions = questions.filter((q) => q.id !== id);
    localStorage.setItem(STORAGE_KEYS.QUESTIONS, JSON.stringify(questions));
    this.notify();
  }

  // --- EXAM ATTEMPTS ---
  getAttempts(userId?: string): ExamAttempt[] {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.ATTEMPTS);
      const all = data ? JSON.parse(data) : SEED_ATTEMPTS;
      return userId ? all.filter((a: ExamAttempt) => a.userId === userId) : all;
    } catch {
      return SEED_ATTEMPTS;
    }
  }

  getAttemptById(id: string): ExamAttempt | undefined {
    return this.getAttempts().find((a) => a.id === id);
  }

  saveAttempt(attempt: ExamAttempt) {
    const attempts = this.getAttempts();
    const idx = attempts.findIndex((a) => a.id === attempt.id);
    if (idx >= 0) {
      attempts[idx] = attempt;
    } else {
      attempts.unshift(attempt);
    }
    localStorage.setItem(STORAGE_KEYS.ATTEMPTS, JSON.stringify(attempts));
    this.notify();
  }

  // --- ADMIN REQUESTS ---
  getRequests(): AdminRequest[] {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.REQUESTS);
      return data ? JSON.parse(data) : SEED_REQUESTS;
    } catch {
      return SEED_REQUESTS;
    }
  }

  saveRequest(req: AdminRequest) {
    const requests = this.getRequests();
    const idx = requests.findIndex((r) => r.id === req.id);
    if (idx >= 0) {
      requests[idx] = req;
    } else {
      requests.unshift(req);
    }
    localStorage.setItem(STORAGE_KEYS.REQUESTS, JSON.stringify(requests));
    this.notify();
  }

  decideAdminRequest(requestId: string, approve: boolean, approvedByUid: string) {
    const requests = this.getRequests();
    const req = requests.find((r) => r.id === requestId);
    if (req) {
      req.status = approve ? 'approved' : 'rejected';
      this.saveRequest(req);

      // If approved, create active sub-admin user!
      if (approve) {
        const newUser: UserProfile = {
          id: req.targetUid || `user_admin_${Date.now()}`,
          username: req.username,
          name: req.name,
          role: 'admin',
          status: 'active',
          createdBy: req.createdBy,
          approvedBy: approvedByUid,
          createdAt: new Date().toISOString(),
        };
        this.saveUser(newUser);
      }
    }
  }

  // --- APP STATUS (Maintenance) ---
  getStatus(): AppStatus {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.STATUS);
      return data ? JSON.parse(data) : SEED_STATUS;
    } catch {
      return SEED_STATUS;
    }
  }

  setMaintenanceMode(enabled: boolean, updatedBy: string) {
    const current = this.getStatus();
    const updated: AppStatus = {
      ...current,
      maintenance: enabled,
      updatedAt: new Date().toISOString(),
      updatedBy,
    };
    localStorage.setItem(STORAGE_KEYS.STATUS, JSON.stringify(updated));
    this.notify();
  }

  // Reset demo database to initial state
  resetToDefaults() {
    localStorage.setItem(STORAGE_KEYS.USERS, JSON.stringify(SEED_USERS));
    localStorage.setItem(STORAGE_KEYS.EXAMS, JSON.stringify(SEED_EXAMS));
    localStorage.setItem(STORAGE_KEYS.QUESTIONS, JSON.stringify(SEED_QUESTIONS));
    localStorage.setItem(STORAGE_KEYS.ATTEMPTS, JSON.stringify(SEED_ATTEMPTS));
    localStorage.setItem(STORAGE_KEYS.REQUESTS, JSON.stringify(SEED_REQUESTS));
    localStorage.setItem(STORAGE_KEYS.STATUS, JSON.stringify(SEED_STATUS));
    this.notify();
  }
}

export const storage = new StorageService();
