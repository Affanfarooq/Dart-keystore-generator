import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const CREDENTIALS_FILE = 'credentials.json';
const SHEET_ID_FILE = 'sheet_id.txt';
const SHEET_NAME = 'Keystore Information';

// Global auth client to prevent multiple authentications
AutoRefreshingAuthClient? _cachedAuthClient;

void main(List<String> arguments) async {
  await executeKeystoreManager(arguments);
}

Future<void> executeKeystoreManager(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('markdown',
        abbr: 'm', negatable: false, help: 'Display output in Markdown format')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help message')
    ..addFlag('version',
        abbr: 'v', negatable: false, help: 'Show version number');

  try {
    final args = parser.parse(arguments);

    if (args['help']) {
      printUsage(parser);
      return;
    }

    if (args['version']) {
      print('Keystore Manager v1.0.0');
      return;
    }

    final isMarkdown = args['markdown'] as bool;

    stdout.writeln('Welcome to Keystore Manager CLI!');

    stdout.write('Enter Key Name: ');
    final keyName = stdin.readLineSync() ?? '';

    stdout.write('Enter Alias: ');
    final alias = stdin.readLineSync() ?? '';

    stdout.write('Enter Password: ');
    final password = stdin.readLineSync() ?? '';

    if (keyName.isEmpty || alias.isEmpty || password.isEmpty) {
      stderr.writeln('Error: All inputs are required.');
      exit(1);
    }

    final keystoreFile = await generateKeystore(keyName, alias, password);
    final driveUrl = await uploadToGoogleDrive(keystoreFile);
    await logKeystoreDetails(keyName, driveUrl, alias, password);

    displayOutput(keyName, driveUrl, alias, password, isMarkdown);

    await keystoreFile.delete();
    stdout.writeln('Temporary keystore file deleted.');
  } catch (e) {
    stderr.writeln('Error: $e');
    printUsage(parser);
    exit(1);
  }
}

void printUsage(ArgParser parser) {
  print('''
Keystore Manager CLI

Usage: keystore [options]

Options:
${parser.usage}

Example:
  keystore
  keystore --markdown
''');
}

Future<File> generateKeystore(
    String keyName, String alias, String password) async {
  final keystorePath = path.join(Directory.systemTemp.path, '$keyName.jks');
  final keystoreFile = File(keystorePath);

  final process = await Process.start(
    'keytool',
    [
      '-genkeypair',
      '-alias',
      alias,
      '-keyalg',
      'RSA',
      '-keysize',
      '2048',
      '-validity',
      '50',
      '-keystore',
      keystorePath,
      '-storepass',
      password,
      '-dname',
      'CN=vativeApps, OU=vativeApps, O=vativeApps, L=City, ST=State, C=Country'
    ],
  );

  await stdout.addStream(process.stdout);
  await stderr.addStream(process.stderr);
  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    throw Exception('Keystore generation failed.');
  }

  return keystoreFile;
}

Future<String> uploadToGoogleDrive(File keystoreFile) async {
  final authClient = await obtainAuthenticatedClient();
  final driveApi = drive.DriveApi(authClient);

  // Check if 'Keystores' folder exists
  final folderName = 'Keystores';
  final folderId = await getOrCreateFolderId(driveApi, folderName);

  // Upload file
  final media = drive.Media(keystoreFile.openRead(), keystoreFile.lengthSync());
  final file = drive.File()
    ..name = path.basename(keystoreFile.path)
    ..parents = [folderId];

  final uploadedFile = await driveApi.files.create(file, uploadMedia: media);

  // Log uploaded file details
  stdout.writeln('Uploaded file details: ${uploadedFile.toJson()}');

  // Grant public read permission to the file
  await driveApi.permissions.create(
    drive.Permission(type: 'anyone', role: 'reader'),
    uploadedFile.id!,
  );

  // Fetch the file details again to get the webViewLink
  final updatedFile =
      await driveApi.files.get(uploadedFile.id!, $fields: 'webViewLink');

  // Ensure the response is cast to `drive.File` to access webViewLink
  if (updatedFile is drive.File && updatedFile.webViewLink != null) {
    return updatedFile.webViewLink!;
  } else {
    // Fallback: return the file's download URL
    final downloadUrl = 'https://drive.google.com/uc?id=${uploadedFile.id}';
    return downloadUrl;
  }
}

void displayOutput(String keyName, String driveUrl, String alias,
    String password, bool isMarkdown) {
  final output = isMarkdown
      ? """
      ## Keystore Details

      - **Key Name**: $keyName
      - **Drive URL**: $driveUrl
      - **Alias**: $alias
      - **Password**: $password

      **Please keep these credentials secure and do not share them publicly.**
      """
      : """
      =========================
      Keystore Details
      ------------------
      Key Name: $keyName
      Drive URL: $driveUrl
      Alias: $alias
      Password: $password

      Please keep these credentials secure and do not share them publicly.
      =========================
      """;

  stdout.writeln(output);
}

Future<AutoRefreshingAuthClient> obtainAuthenticatedClient() async {
  // Check if we already have a cached client
  if (_cachedAuthClient != null) {
    return _cachedAuthClient!;
  }

  const scopes = [
    drive.DriveApi.driveFileScope,
    sheets.SheetsApi.spreadsheetsScope
  ];

  final clientId = ClientId(
    'use your client id',
    'use your client secret',
  );

  // Check if we have stored credentials
  if (await File(CREDENTIALS_FILE).exists()) {
    try {
      final credentialsJson = await File(CREDENTIALS_FILE).readAsString();
      final credentials =
          AccessCredentials.fromJson(json.decode(credentialsJson));
      _cachedAuthClient =
          await autoRefreshingClient(clientId, credentials, http.Client());
      return _cachedAuthClient!;
    } catch (e) {
      // If there's any error reading stored credentials, proceed with new authentication
      stderr.writeln('Error reading stored credentials: $e');
    }
  }

  // If no stored credentials or error occurred, authenticate and store credentials
  _cachedAuthClient = await clientViaUserConsent(clientId, scopes, (url) {
    stdout.writeln('Please visit the following URL to authorize this app:');
    stdout.writeln(url);
  });

  // Store the credentials
  await File(CREDENTIALS_FILE).writeAsString(
    json.encode(_cachedAuthClient!.credentials.toJson()),
  );

  return _cachedAuthClient!;
}

Future<String> getOrCreateFolderId(
    drive.DriveApi driveApi, String folderName) async {
  // Search for existing folder
  final query =
      "mimeType='application/vnd.google-apps.folder' and name='$folderName'";
  final fileList = await driveApi.files.list(q: query, spaces: 'drive');

  if (fileList.files != null && fileList.files!.isNotEmpty) {
    // Folder exists
    return fileList.files!.first.id!;
  } else {
    // Create new folder
    final folderMetadata = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final folder = await driveApi.files.create(folderMetadata);
    return folder.id!;
  }
}

Future<void> logKeystoreDetails(
    String keyName, String driveUrl, String alias, String password) async {
  final authClient = await obtainAuthenticatedClient();
  final sheetsApi = sheets.SheetsApi(authClient);

  final spreadsheetId = await getOrCreateSpreadsheetId(sheetsApi);
  await ensureHeadersExist(sheetsApi, spreadsheetId);

  final valueRange = sheets.ValueRange(values: [
    [keyName, driveUrl, alias, password, DateTime.now().toIso8601String()]
  ]);

  try {
    await sheetsApi.spreadsheets.values.append(
      valueRange,
      spreadsheetId,
      'Sheet1!A:E',
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
    );
    stdout.writeln('Keystore details logged in Google Sheets.');
  } catch (e) {
    stderr.writeln('Error logging details in Google Sheets: $e');
  }
}

Future<String> getOrCreateSpreadsheetId(sheets.SheetsApi sheetsApi) async {
  // First try to find existing spreadsheet with the name
  final existingId = await findExistingSpreadsheet(SHEET_NAME);
  if (existingId != null) {
    stdout.writeln('Using existing spreadsheet: $SHEET_NAME');
    return existingId;
  }

  // If no existing spreadsheet found, create new one
  final spreadsheet = await sheetsApi.spreadsheets.create(
    sheets.Spreadsheet()
      ..properties = (sheets.SpreadsheetProperties()..title = SHEET_NAME)
      ..sheets = [
        sheets.Sheet()
          ..properties = (sheets.SheetProperties()
            ..title = 'Sheet1'
            ..gridProperties = (sheets.GridProperties()
              ..frozenRowCount = 1
              ..columnCount = 5
              ..rowCount = 1000))
      ],
  );

  final newSheetId = spreadsheet.spreadsheetId!;

  // Store the sheet ID for future use
  await File(SHEET_ID_FILE).writeAsString(newSheetId);

  stdout.writeln('Created new spreadsheet: $SHEET_NAME');
  return newSheetId;
}

// Helper function to search for existing spreadsheet
Future<String?> findExistingSpreadsheet(String title) async {
  try {
    final driveApi = drive.DriveApi(await obtainAuthenticatedClient());

    // Search for spreadsheets with the exact name
    final query =
        "mimeType='application/vnd.google-apps.spreadsheet' and name='$title' and trashed=false";
    final response = await driveApi.files.list(q: query, spaces: 'drive');

    if (response.files != null && response.files!.isNotEmpty) {
      return response.files!.first.id;
    }
  } catch (e) {
    stderr.writeln('Error searching for spreadsheet: $e');
  }
  return null;
}

Future<void> ensureHeadersExist(
    sheets.SheetsApi sheetsApi, String spreadsheetId) async {
  try {
    // First get the sheet ID
    final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
    final sheetId = spreadsheet.sheets![0].properties!.sheetId;

    final headers = sheets.ValueRange(values: [
      ['Key Name', 'Drive URL', 'Alias', 'Password', 'Creation Date']
    ]);

    final response =
        await sheetsApi.spreadsheets.values.get(spreadsheetId, 'Sheet1!A1:E1');

    if (response.values == null || response.values!.isEmpty) {
      await sheetsApi.spreadsheets.values.update(
        headers,
        spreadsheetId,
        'Sheet1!A1:E1',
        valueInputOption: 'USER_ENTERED',
      );

      final requests = [
        sheets.Request(
          repeatCell: sheets.RepeatCellRequest(
            range: sheets.GridRange(
              sheetId: sheetId, // Use the correct sheet ID
              startRowIndex: 0,
              endRowIndex: 1,
              startColumnIndex: 0,
              endColumnIndex: 5,
            ),
            cell: sheets.CellData(
              userEnteredFormat: sheets.CellFormat(
                backgroundColor: sheets.Color(
                  red: 0.9,
                  green: 0.9,
                  blue: 0.9,
                ),
                textFormat: sheets.TextFormat(
                  bold: true,
                ),
              ),
            ),
            fields: 'userEnteredFormat(backgroundColor,textFormat)',
          ),
        ),
      ];

      final batchRequest =
          sheets.BatchUpdateSpreadsheetRequest(requests: requests);
      await sheetsApi.spreadsheets.batchUpdate(batchRequest, spreadsheetId);
    }
  } catch (e) {
    stderr.writeln('Error setting up headers: $e');
  }
}
