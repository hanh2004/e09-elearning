// Chỉ dữ liệu học tập mẫu; không tạo tài khoản, thông báo hoặc kết quả giả.
const lesson = (id,title,chapter,content) => ({id,title,chapter,content,
  minimumStudySeconds:90,importantNote:'Nội dung mẫu để học và chạy thử. Kết quả chỉ được ghi nhận khi bạn thực sự học hoặc làm bài.'});
const question = (questionText,options,correctAnswerIndex,explanation) =>
  ({questionText,options,correctAnswerIndex,explanation,loai_cau_hoi:'SINGLE_CHOICE'});

export const sampleCourses = [
  {id:'sample_math_20260914', title:'[Mẫu] Toán cơ bản trong công việc',subject:'Toán cơ bản',coverUrl:'icon:math',
    description:'Ôn phép tính, tỉ lệ phần trăm và trung bình cộng qua các ví dụ về tài liệu, kế hoạch và kết quả học tập. Bộ mẫu gồm 3 bài và 1 bài luyện tập 5 câu.',
    objectives:'Tính đúng các phép cộng, trừ, nhân, chia đơn giản\nTính tỉ lệ hoàn thành và số lượng tương ứng\nTính trung bình cộng và đọc kết quả theo đúng đơn vị',
    lessons:[
      lesson('operations','Bài 1: Phép tính và thứ tự thực hiện','Chương 1 • Nền tảng',
`# Phép tính trong công việc
## Bốn phép tính cơ bản
Cộng để gộp số lượng, trừ để tìm phần còn lại, nhân để tính các nhóm bằng nhau và chia để phân đều. Khi ghi kết quả, luôn kèm đơn vị như người, trang hoặc phút.

## Ví dụ
Một tổ có 12 tài liệu, nhận thêm 8 tài liệu rồi bàn giao 5 tài liệu. Số còn lại là 12 + 8 − 5 = 15 tài liệu.
Ba nhóm, mỗi nhóm có 4 người, có tổng cộng 3 × 4 = 12 người. Chia đều 24 trang cho 6 người thì mỗi người nhận 24 ÷ 6 = 4 trang.

## Thứ tự thực hiện
Thực hiện biểu thức trong ngoặc trước. Sau đó làm nhân, chia trước cộng, trừ. Các phép cùng mức ưu tiên được làm từ trái sang phải.
Ví dụ: 6 + 3 × 4 = 18, còn (6 + 3) × 4 = 36. Vị trí dấu ngoặc làm thay đổi kết quả.

## Tự thực hành
- Tính 20 − 4 × 3. Kết quả: 8.
- Tính (20 − 4) ÷ 4. Kết quả: 4.
- Tính số trang khi 5 tập có cùng 6 trang. Kết quả: 30 trang.
Đọc lại yêu cầu trước khi chọn phép tính và kiểm tra xem kết quả có hợp lý với số lượng ban đầu không.`),
      lesson('percent','Bài 2: Tỉ lệ phần trăm và mức hoàn thành','Chương 2 • Vận dụng',
`# Hiểu tỉ lệ phần trăm
Phần trăm mô tả một phần so với tổng thể được quy về 100 phần bằng nhau. Công thức: tỉ lệ (%) = phần đã có ÷ tổng số × 100.

## Tính tiến độ
Nếu hoàn thành 3 trong 4 bài học, tỉ lệ là 3 ÷ 4 × 100 = 75%. Còn lại 1 bài, tương ứng 25% tổng số bài.
Nếu một nhóm có 20 người và 15 người đã nộp bài, tỉ lệ nộp là 15 ÷ 20 × 100 = 75%.

## Tính số lượng từ tỉ lệ
Muốn tính 20% của 150 trang, lấy 150 × 20 ÷ 100 = 30 trang. Muốn hoàn thành 80% kế hoạch 50 đầu việc, cần hoàn thành 50 × 80 ÷ 100 = 40 đầu việc.

## Kiểm tra tổng số
Luôn xác định mẫu số trước khi tính. Ba bài đã học trên tổng bốn bài khác với ba bài trên tổng sáu bài. Không chia cho tổng bằng 0; trường hợp chưa có bài học thì chưa có cơ sở tính tỉ lệ bằng công thức này.

## Tự thực hành
- Hoàn thành 8/10 nhiệm vụ: 80%.
- 25% của 40 tài liệu: 10 tài liệu.
- Hoàn thành 60% của 10 bài: 6 bài.
Tỉ lệ hoàn thành bài học và điểm bài kiểm tra là hai chỉ số khác nhau.`),
      lesson('average','Bài 3: Trung bình cộng và cách đọc số liệu','Chương 2 • Vận dụng',
`# Trung bình cộng
Trung bình cộng bằng tổng các giá trị chia cho số giá trị. Chỉ dùng công thức này khi các giá trị có trọng số như nhau.

## Ví dụ điểm học tập
Ba lần luyện tập có điểm 6, 8 và 10. Trung bình cộng là (6 + 8 + 10) ÷ 3 = 8 điểm. Nếu quy định từng bài có trọng số khác nhau, phải tính theo trọng số đó.

## Ví dụ thời gian
Ba buổi học kéo dài 20, 30 và 40 phút. Tổng là 90 phút; trung bình mỗi buổi là 90 ÷ 3 = 30 phút. Cần đưa các giá trị về cùng đơn vị trước khi cộng.

## Đọc số liệu cẩn thận
Giá trị trung bình không có nghĩa mọi người đều có cùng kết quả. Hai nhóm cùng trung bình 8 điểm có thể có mức chênh lệch giữa các thành viên khác nhau.
Không coi ô chưa có dữ liệu là điểm 0 nếu chưa biết quy ước thống kê. Ví dụ, điểm 8 và một bài chưa làm không tự động có nghĩa trung bình là 4.

## Tự thực hành
- Trung bình của 4, 6, 8: 6.
- Trung bình của 10 và 20 phút: 15 phút.
- Tổng thời gian 4 buổi là 120 phút: trung bình 30 phút/buổi.
Khi ghi nhận số liệu, nêu rõ tổng số quan sát, đơn vị đo và cách tính.`),
    ],
    questions:[
      question('6 + 3 × 4 bằng bao nhiêu?',['36','18','24','15'],1,'Nhân trước: 3 × 4 = 12; sau đó 6 + 12 = 18.'),
      question('Chia đều 24 trang cho 6 người, mỗi người nhận bao nhiêu trang?',['6','3','4','8'],2,'24 ÷ 6 = 4 trang cho mỗi người.'),
      question('Hoàn thành 3 trên 4 bài tương ứng bao nhiêu phần trăm?',['25%','50%','60%','75%'],3,'3 ÷ 4 × 100 = 75%.'),
      question('20% của 150 là bao nhiêu?',['30','20','15','75'],0,'150 × 20 ÷ 100 = 30.'),
      question('Trung bình cộng của 6, 8 và 10 là bao nhiêu?',['6','8','9','10'],1,'(6 + 8 + 10) ÷ 3 = 8.'),
    ]},
  {id:'sample_study_20260914',title:'[Mẫu] Kỹ năng tự học và làm việc có kế hoạch',subject:'Kỹ năng học tập',coverUrl:'icon:book',
    description:'Thực hành đặt mục tiêu, ghi chép và tự đánh giá sau khi học. Bộ mẫu gồm 3 bài và 1 bài luyện tập 5 câu.',
    objectives:'Viết mục tiêu học tập cụ thể và có thời hạn\nGhi chép bằng ý chính, ví dụ và câu hỏi\nDùng kết quả luyện tập để lựa chọn nội dung cần ôn lại',
    lessons:[
      lesson('plan','Bài 1: Lập kế hoạch cho một buổi học','Chương 1 • Chuẩn bị',
`# Một mục tiêu đủ rõ
Trước khi mở tài liệu, viết điều bạn muốn làm được sau buổi học. “Học toán” còn quá rộng. “Giải đúng ba ví dụ tính phần trăm trong 20 phút” cho biết nội dung, sản phẩm và thời gian dự kiến.

## Chia nhỏ việc cần làm
Một buổi học có thể gồm ba việc: đọc khái niệm, làm ví dụ và tự kiểm tra. Phân bổ thời gian phù hợp với mức độ khó; dành một phần cuối buổi để ghi lại điều chưa hiểu.

## Ví dụ kế hoạch 30 phút
- 5 phút: xem mục tiêu và đọc lại kiến thức cần có.
- 15 phút: đọc bài, ghi ý chính và làm ví dụ.
- 10 phút: tự trả lời câu hỏi rồi kiểm tra đáp án.
Đây là kế hoạch gợi ý; bạn có thể điều chỉnh theo độ dài bài và thời gian học tối thiểu được đặt trong ứng dụng.

## Chuẩn bị trước khi bắt đầu
Kiểm tra pin, kết nối và tài khoản đang đăng nhập. Chuẩn bị chỗ ghi chép, giảm thông báo gây mất tập trung và mở đúng bài cần học.

## Tự thực hành
Viết một mục tiêu cho bài tiếp theo, ghi ba việc nhỏ và thời gian dự kiến. Nếu chưa hoàn thành, ghi rõ việc còn lại để tiếp tục thay vì đánh dấu đã xong.`),
      lesson('notes','Bài 2: Ghi chép để hiểu và nhớ','Chương 2 • Thực hành',
`# Ghi ý chính bằng lời của mình
Sau một đoạn ngắn, dừng lại và diễn đạt điều vừa đọc. Chép lại toàn bộ tài liệu thường không cho biết bạn đã hiểu hay chưa. Bản ghi ngắn nên giữ khái niệm chính, ví dụ và điểm cần hỏi.

## Mẫu ghi chép ba phần
- Ý chính: nội dung hoặc quy tắc cần nhớ.
- Ví dụ: một tình huống cho thấy cách áp dụng.
- Câu hỏi: điều còn chưa rõ hoặc cần kiểm tra lại.
Ví dụ với phần trăm: ý chính là “phần chia tổng rồi nhân 100”; ví dụ là “3/4 bài = 75%”; câu hỏi là “tổng bằng 0 thì xử lý thế nào?”.

## Kiểm tra cách hiểu
Đóng phần giải thích trong chốc lát và thử nói lại quy tắc. Sau đó mở bài để đối chiếu, sửa chỗ thiếu hoặc sai. Không cần nhớ đúng từng chữ nếu vẫn diễn đạt đúng ý.

## Sắp xếp ghi chép
Đặt tên ghi chú theo khóa học, tên bài và ngày học. Tách ví dụ đã hiểu với câu hỏi cần hỏi quản lý hoặc người phụ trách nội dung để lần ôn sau dễ tìm.

## Tự thực hành
Chọn một đoạn trong bài trước và ghi lại ba phần trên. Thêm một ví dụ do bạn tự nghĩ ra, rồi đối chiếu với quy tắc đã học.`),
      lesson('review','Bài 3: Tự kiểm tra và ôn tập sau bài học','Chương 2 • Thực hành',
`# Dùng luyện tập để phát hiện chỗ chưa hiểu
Sau khi đọc, hãy làm vài câu hỏi trước khi xem lời giải. Kết quả giúp xác định phần cần ôn, không chỉ để lấy một con số điểm.

## Xem lại câu trả lời sai
Với mỗi câu sai, ghi nguyên nhân: chưa hiểu khái niệm, đọc thiếu điều kiện hoặc tính toán nhầm. Mỗi nguyên nhân cần cách xử lý khác nhau.
Nếu chưa hiểu, đọc lại đoạn liên quan và làm một ví dụ khác. Nếu đọc thiếu, gạch chân điều kiện khi làm câu tiếp theo. Nếu tính nhầm, kiểm tra lại từng bước và đơn vị.

## Lập vòng ôn tập nhỏ
Chọn một hoặc hai điểm yếu, ôn lại và tự trả lời bằng ví dụ mới. Có thể xem lại ghi chú vào buổi học tiếp theo để kiểm tra mình còn nhớ cách áp dụng hay không.

## Theo dõi tiến bộ
Ghi nội dung đã nắm và việc cần làm tiếp. Điểm của một lần luyện tập không thay thế việc đọc bài và hiểu nội dung. Kết quả học tập cần thuộc đúng tài khoản của bạn.

## Tự thực hành
Làm bài luyện tập của khóa học này trong mục Kiểm tra. Với câu chưa đúng, đọc lời giải, quay lại bài liên quan rồi thử trả lời bằng lời của mình. Không cần học thuộc vị trí A, B, C, D vì thứ tự đáp án có thể thay đổi.`),
    ],
    questions:[
      question('Mục tiêu nào cụ thể nhất cho một buổi học?',['Học thật nhiều','Cố gắng hơn','Giải đúng ba ví dụ phần trăm trong 20 phút','Mở app cả ngày'],2,'Mục tiêu này nêu nội dung, kết quả và thời gian dự kiến.'),
      question('Trước khi bắt đầu, việc nào phù hợp?',['Dùng tài khoản của bạn khác','Kiểm tra đúng tài khoản, pin và kết nối','Mở nhiều thông báo hơn','Bỏ qua tên bài'],1,'Chuẩn bị tài khoản và thiết bị giúp buổi học thuận lợi, kết quả ghi đúng người.'),
      question('Bản ghi chép ba phần gồm những gì?',['Ý chính, ví dụ, câu hỏi','Mật khẩu, mã xác thực, điểm','Chỉ tên và ngày','Chép toàn bộ tài liệu'],0,'Ba phần giúp giữ ý cốt lõi, cách áp dụng và vấn đề cần làm rõ.'),
      question('Sau khi trả lời sai, bạn nên làm gì?',['Bỏ qua lời giải','Đổi sang tài khoản khác','Chỉ nhớ vị trí đáp án','Xác định nguyên nhân và ôn lại phần liên quan'],3,'Tìm nguyên nhân giúp chọn cách sửa phù hợp: đọc lại, đọc kỹ điều kiện hoặc tính lại.'),
      question('Vì sao cần hiểu nội dung thay vì thuộc vị trí đáp án?',['Vì câu hỏi không có lời giải','Vì thứ tự đáp án có thể thay đổi','Vì mọi đáp án đều đúng','Vì app không lưu kết quả'],1,'Khi đáp án được trộn, vị trí thay đổi nhưng kiến thức cần áp dụng vẫn giữ nguyên.'),
    ]},
];

export function sampleDocuments(actorId) {
  const result=[];
  for (const course of sampleCourses) {
    const {id,lessons,questions,...data}=course;
    result.push({path:`courses/${id}`,data:{...data,instructor:'Nội dung mẫu E09',
      published:true,deploymentMode:'manual',audience:'all',startsAt:null,endsAt:null,
      sampleData:true,sampleBatch:'20260914',updatedBy:actorId}});
    lessons.forEach(({id:lessonId,...value},index)=>result.push({path:`courses/${id}/lessons/${lessonId}`,
      data:{...value,order:index+1,type:'text',contentFormat:'rich_text_v1',url:'',coverUrl:data.coverUrl,
        sampleData:true,updatedBy:actorId}}));
    const examId=`${id}_practice`;
    result.push({path:`exams/${examId}`,data:{title:`[Mẫu] Luyện tập: ${data.subject}`,topic:data.subject,
      courseId:id,duration:'10 phút',durationMinutes:10,questions:questions.length,isOpen:true,
      maxAttempts:null,opensAt:null,closesAt:null,passScore:6,showSolutions:true,
      shuffleQuestions:true,shuffleAnswers:true,status:'Đang mở',sampleData:true,updatedBy:actorId}});
    questions.forEach((value,index)=>result.push({path:`exams/${examId}/questions/q${index+1}`,
      data:{...value,sampleData:true,updatedBy:actorId}}));
  }
  return result;
}
