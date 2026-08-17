/// Deep link that Supabase auth emails (signup confirmation, password
/// recovery) send the user back to, instead of the project's Site URL.
///
/// Must be listed under Authentication → URL Configuration → Redirect URLs
/// in the Supabase dashboard, and matches the URL scheme registered in
/// ios/Runner/Info.plist and android/app/src/main/AndroidManifest.xml.
const authRedirectUrl = 'com.techgetafrica.yournotalone://auth-callback/';
