# Keystore Manager CLI

A command-line interface tool for generating Android keystores, uploading them to Google Drive, and logging their details in Google Sheets.

## Features

- Generate Android keystores using keytool
- Automatically upload keystores to Google Drive
- Store keystore information in Google Sheets
- Support for Markdown output format
- Secure credential management
- Automatic folder creation in Google Drive
- Organized spreadsheet logging

## Prerequisites

Before you begin, ensure you have the following installed:
- Dart SDK (version 2.12 or higher)
- Java Development Kit (JDK) for keytool
- Google Cloud Project with Drive and Sheets APIs enabled

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/keystore_manager.git
cd keystore_manager
```

2. Install dependencies:
```bash
dart pub get
```

3. Activate the package globally:
```bash
dart pub global activate --source path .
```

## Google Cloud Setup

1. Create a project in Google Cloud Console
2. Enable the following APIs:
   - Google Drive API
   - Google Sheets API
3. Create OAuth 2.0 credentials
4. Download the credentials and save them as `credentials.json` in the project directory

## Usage

### Basic Usage

Run the tool using:
```bash
keystore
```

You will be prompted to enter:
- Key Name
- Alias
- Password

### Command Line Options

```bash
keystore [options]

Options:
  -m, --markdown    Display output in Markdown format
  -h, --help       Show help message
  -v, --version    Show version number
```

### Example Output

Standard format:
```
=========================
Keystore Details
------------------
Key Name: my_app_key
Drive URL: https://drive.google.com/file/d/xxx/view
Alias: my_alias
Password: my_password

Please keep these credentials secure and do not share them publicly.
=========================
```

Markdown format:
```markdown
## Keystore Details

- **Key Name**: my_app_key
- **Drive URL**: https://drive.google.com/file/d/xxx/view
- **Alias**: my_alias
- **Password**: my_password

**Please keep these credentials secure and do not share them publicly.**
```

## File Structure

```
keystore_manager/
├── bin/
│   └── keystore.dart
├── lib/
│   └── src/
│       ├── commands/
│       └── utils/
├── credentials.json
├── pubspec.yaml
└── README.md
```

## Google Integration

### Google Drive
- Keystores are automatically uploaded to a "Keystores" folder
- Files are shared with "anyone with the link" for easy access
- Each keystore gets a unique shareable link

### Google Sheets
- Information is logged in a spreadsheet named "Keystore Information"
- Includes columns for:
  - Key Name
  - Drive URL
  - Alias
  - Password
  - Creation Date
- Headers are automatically formatted for readability

## Security Notes

- Credential files are stored locally
- OAuth 2.0 is used for Google API authentication
- Passwords are stored in Google Sheets - ensure proper access controls
- Keep your `credentials.json` file secure

## Development

### Building

```bash
dart compile exe bin/keystore.dart -o keystore
```

### Running Tests

```bash
dart test
```

## Troubleshooting

1. **Authentication Issues**
   - Ensure `credentials.json` is present in the project directory
   - Follow the OAuth flow when prompted
   - Check Google Cloud Console for API enablement

2. **Keystore Generation Errors**
   - Verify JDK installation
   - Check if keytool is in system PATH
   - Ensure valid input parameters

3. **Google API Errors**
   - Verify API enablement in Google Cloud Console
   - Check API quotas
   - Ensure proper OAuth scopes

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Google Drive API
- Google Sheets API
- Dart team for excellent CLI support
- Java keytool documentation

## Contact

Your Name - [your.email@example.com](mailto:your.email@example.com)
Project Link: [https://github.com/yourusername/keystore_manager](https://github.com/yourusername/keystore_manager)