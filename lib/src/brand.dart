// The program's name and version. The version comes from the release tag (the release build
// passes --dart-define=PFM_VERSION=7.0.1); a build without it says 7.0.0. Its own name, not
// APP_VERSION: inside the Survey Toolkit that one is the Toolkit's version.
const appName = 'Project Folder Manager';
const appVersion = String.fromEnvironment('PFM_VERSION', defaultValue: '7.0.0');
const appTagline = 'Survey & Engineering Document Control';
const appPage = 'https://www.exceltokml.com/project-folder-manager';
