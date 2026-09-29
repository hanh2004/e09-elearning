import 'dart:io';
import 'dart:typed_data';

import 'package:e09_elearning/models/du_lieu_nhap_hoc_vien.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:e09_elearning/services/ket_noi_api/api_tai_khoan.dart';
import 'package:e09_elearning/services/tep/nhap_hoc_vien_tu_excel.dart';
import 'package:excel/excel.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

List<CellValue?> cells(List<String> values) =>
    values.map(TextCellValue.new).toList();
final header = cells(UserExcelImport.headers);
UserImportRow account(String username, {String? userCodeSuffix}) =>
    UserImportRow(
      rowNumber: 2,
      name: 'Nguyễn Văn An',
      username: username,
      password: 'Password01!',
      userCodeSuffix: userCodeSuffix,
    );

void main() {
  final parser = UserExcelImport();

  test('shipped workbook decodes and has no sample accounts to import', () {
    final bytes = File(UserExcelImport.templateAsset).readAsBytesSync();
    final workbook = parser.decode(bytes);
    expect(
      workbook.tables['Users']!.rows.first.every(
        (cell) => cell?.value is TextCellValue,
      ),
      isTrue,
    );
    final result = parser.parse(bytes);
    expect(result.rows, isEmpty);
    expect(result.errors.single, contains('Chưa có học viên'));
    expect(workbook.tables.keys, containsAll(['Users', 'HuongDan']));
    expect(
      workbook.tables['Users']!.rows.first.map(
        (cell) => cell?.value.toString(),
      ),
      UserExcelImport.headers,
    );
    final example = workbook.tables['HuongDan']!.rows[13]
        .map((cell) => cell?.value)
        .toList();
    final examplePreview = parser.parseRows([header, example]);
    expect(examplePreview.canImport, isTrue);
    expect(examplePreview.rows.single.username, 'hv001234');
    expect(examplePreview.rows.single.userCodeSuffix, '001234');
  });

  test(
    'valid text, leading zero identifiers, Vietnamese names and blank rows',
    () {
      final result = parser.parseRows([
        header,
        cells([' Nguyễn Văn An ', '001234', '01234567']),
        [null, null, null],
        cells(['Trần Thị Bình', 'hocvien02', 'Password02!']),
      ]);
      expect(result.canImport, isTrue);
      expect(result.rows.length, 2);
      expect(result.rows.first.name, 'Nguyễn Văn An');
      expect(result.rows.first.username, '001234');
      expect(result.rows.first.password, '01234567');
      expect(result.rows.last.rowNumber, 4);
    },
  );

  test('English headers supported; role columns rejected', () {
    expect(
      parser.parseRows([
        cells(['name', 'username', 'password']),
        cells(['An', 'user01', 'secret01']),
      ]).canImport,
      isTrue,
    );
    expect(
      parser.parseRows([
        cells(['name', 'username', 'password', 'role']),
        cells(['An', 'user01', 'secret01', 'admin']),
      ]).canImport,
      isFalse,
    );
    expect(
      parser
          .parseRows([
            header,
            cells(['An', 'user01', 'secret01', '001', 'admin']),
          ])
          .rows
          .single
          .errors,
      contains('Có dữ liệu ngoài 4 cột cho phép.'),
    );
  });

  test('optional user code suffix is text and retains leading zeros', () {
    final result = parser.parseRows([
      header,
      cells(['Nguyễn Văn An', 'hv001234', 'Password01!', '001234']),
    ]);
    expect(result.canImport, isTrue);
    expect(result.rows.single.userCodeSuffix, '001234');

    final invalid = parser.parseRows([
      header,
      [
        TextCellValue('An'),
        TextCellValue('user01'),
        TextCellValue('Password01!'),
        IntCellValue(1234),
      ],
    ]);
    expect(invalid.canImport, isFalse);
    expect(invalid.rows.single.errors.single, 'Mã người dùng phải là Text.');
  });

  test('rejects corrupt, empty and oversized files', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([1, 2, 3]),
      Uint8List(UserExcelImport.maxFileBytes + 1),
    ]) {
      expect(parser.parse(bytes).canImport, isFalse);
    }
    expect(parser.parseRows([]).canImport, isFalse);
    expect(parser.parseRows([header]).canImport, isFalse);
  });

  test('reports missing cells without disclosing passwords', () {
    final result = parser.parseRows([
      header,
      cells(['', 'validuser', 'secretValue']),
      cells(['An', 'otheruser', '']),
    ]);
    expect(result.canImport, isFalse);
    expect(result.rows.first.errors.single, contains('họ và tên'));
    expect(result.rows.last.errors.single, contains('mật khẩu'));
    expect(
      result.rows.expand((row) => row.errors).join(),
      isNot(contains('secretValue')),
    );
  });

  test(
    'numeric, date and formula credentials are rejected, never evaluated',
    () {
      for (final value in <CellValue>[
        IntCellValue(1234),
        DoubleCellValue(1234),
        FormulaCellValue('1+1'),
        DateCellValue(year: 2026, month: 9, day: 3),
        BoolCellValue(true),
      ]) {
        final result = parser.parseRows([
          header,
          [TextCellValue('An'), value, TextCellValue('Password01')],
        ]);
        expect(result.canImport, isFalse);
        expect(result.rows.single.errors.join(), contains('phải là Text'));
      }
    },
  );

  test('duplicates in file and existing accounts are case insensitive', () {
    final duplicates = parser.parseRows([
      header,
      cells(['An', 'USER01', 'Password01']),
      cells(['Bình', 'user01', 'Password02']),
    ]);
    expect(
      duplicates.rows.every(
        (row) => row.errors.contains('Tên đăng nhập bị trùng trong file.'),
      ),
      isTrue,
    );
    final existing = parser
        .parseRows([
          header,
          cells(['An', 'user01', 'Password01']),
        ])
        .checkExisting([' USER01 ']);
    expect(existing.canImport, isFalse);
    expect(existing.rows.single.errors.single, 'Tên đăng nhập đã tồn tại.');
  });

  test('validates limits and disallows invalid username characters', () {
    expect(
      parser
          .parseRows([
            header,
            cells(['An', 'user/01', '123']),
          ])
          .rows
          .single
          .errors
          .length,
      2,
    );
    expect(
      parser
          .parseRows([
            header,
            ...List.generate(201, (i) => cells(['An', 'user$i', 'Password01'])),
          ])
          .errors
          .single,
      contains('200'),
    );
    expect(
      parser.parseRows([
        header,
        ...List.generate(200, (i) => cells(['An', 'user$i', 'Password01'])),
      ]).canImport,
      isTrue,
    );
  });

  group('account backend boundary', () {
    test(
      'completed imports use a fresh operation ID for the next import',
      () async {
        final calls = <Map<String, dynamic>>[];
        final db = FakeFirebaseFirestore();
        final service = FirestoreService(
          firestore: db,
          accounts: AccountApi(
            transport: (method, data) async {
              expect(method, 'accountImportUsers');
              calls.add(data);
              return {'count': 1};
            },
          ),
        );
        await service.importUsers([account('user01')]);
        await service.importUsers([account('user01')]);
        expect(calls.length, 2);
        expect(calls.first['operationId'], isNot(calls.last['operationId']));
        final row = (calls.first['rows'] as List).single as Map;
        expect(row.containsKey('role'), isFalse);
        expect(row.containsKey('createdBy'), isFalse);
        expect((await db.collection('users').get()).docs, isEmpty);
      },
    );
    test('optional code suffix is forwarded without its unit prefix', () async {
      final db = FakeFirebaseFirestore();
      final service = FirestoreService(
        firestore: db,
        accounts: AccountApi(
          transport: (method, data) async {
            expect(method, 'accountImportUsers');
            final row = (data['rows'] as List).single as Map;
            expect(row['code'], '001234');
            expect(row.containsKey('role'), isFalse);
            return {'count': 1};
          },
        ),
      );
      await service.importUsers([
        account('hv001234', userCodeSuffix: '001234'),
      ]);
      expect((await db.collection('users').get()).docs, isEmpty);
    });
    test(
      'invalid input and direct admin creation never reach backend',
      () async {
        var calls = 0;
        final service = FirestoreService(
          firestore: FakeFirebaseFirestore(),
          accounts: AccountApi(
            transport: (_, _) async {
              calls++;
              return {};
            },
          ),
        );
        await expectLater(service.importUsers([]), throwsArgumentError);
        await expectLater(
          service.importUsers([account('bad/name')]),
          throwsArgumentError,
        );
        await expectLater(
          service.importUsers([account('abc'), account('ABC')]),
          throwsArgumentError,
        );
        await expectLater(
          service.addUser(
            name: 'An',
            username: 'an01',
            password: '123456',
            role: 'admin',
          ),
          throwsArgumentError,
        );
        await expectLater(
          service.addUser(
            name: 'An',
            username: 'an01',
            password: '123456',
            role: 'Giáo viên',
          ),
          throwsArgumentError,
        );
        expect(calls, 0);
      },
    );
    test('updates never send role, creator or username changes', () async {
      final service = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        accounts: AccountApi(
          transport: (method, data) async {
            expect(method, 'accountUpdateUser');
            expect(data, {'userId': 'existing', 'name': 'New name'});
            return {'updated': true};
          },
        ),
      );
      await service.updateUser(
        docId: 'existing',
        name: 'New name',
        username: 'ignored',
        password: '',
        role: 'user',
      );
    });
  });
}
