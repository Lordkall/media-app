with open('frontend_flutter/android/app/src/main/AndroidManifest.xml', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''</intent-filter>
            <!-- Deep linking for saludnow.site -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="saludnow.site" />
                <data android:scheme="http" android:host="saludnow.site" />
            </intent-filter>
        </activity>'''

content = content.replace('</intent-filter>\r\n        </activity>', replacement)
content = content.replace('</intent-filter>\n        </activity>', replacement)

with open('frontend_flutter/android/app/src/main/AndroidManifest.xml', 'w', encoding='utf-8') as f:
    f.write(content)
