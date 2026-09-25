# Seer — Provider

تطبيق مقدم الخدمة. آخر نسخة أساس لهذا الربط: `origin/reemaz-branch` عند `cfa759b`.

## مسار الحساب

- يبدأ التطبيق من `AuthGate`: غير المسجل يرى شاشة الدخول ورابط إنشاء الحساب.
- التسجيل ينشئ حساب Firebase Auth ويحفظ بياناته في `providers/{uid}` بحالة `pending`، ثم يسجل الخروج ويعرض نجاح إرسال الطلب.
- الإدارة تستخدم نفس المستند وتغير `status` إلى `approved` أو `rejected`. الدخول متاح للحساب المعتمد فقط؛ الطلب المعلق أو المرفوض يظهر رسالة واضحة.
- فشل إرسال رسالة تفعيل البريد لا يلغي طلبًا حُفظ بنجاح. فشل حفظ الطلب يحاول حذف حساب Auth الجديد حتى يمكن إعادة التسجيل.
- جلسة التطبيق تراقب حالة الحساب، وتزيل صفحات الحساب والإشعارات المفتوحة عند الخروج أو سحب الموافقة. الملف الشخصي يقرأ ويعدل UID المستخدم الحالي.

## التشغيل والتحقق

من مجلد `provider`، مع Flutter SDK على PATH:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run -d <android-device-id>
```

إعداد Firebase المرفق بالتطبيق مخصص لـ Android. اختبار المتصفح أدناه يستخدم إعدادًا تجريبيًا مستقلًا.

## اختبار Firebase محليًا

يتطلب Chrome وNode وJava متوافقًا مع Firebase Emulator Suite. الاختبارات لا تستخدم إعداد Firebase الفعلي ولا تنشئ حسابات في المشروع الحقيقي.

شغل المحاكيات في نافذة طرفية من مجلد `provider`:

```sh
npx firebase-tools@14.27.0 emulators:start --only auth,firestore --project demo-seer-provider --config test/emulators/firebase.json
```

ثم شغل الاختبارات في نافذة أخرى:

```sh
flutter test --platform chrome --dart-define=RUN_FIREBASE_EMULATOR_TESTS=true test/firebase_emulator_test.dart
```

الاختبارات تغطي التسجيل وحفظ الطلب، تكرار البريد، موافقة ورفض الإدارة، كلمة المرور الخاطئة، الحساب بلا ملف مقدم خدمة، الدخول والخروج وعزل بيانات الحسابات. تحذف حساباتها التجريبية بعد الانتهاء. التشغيل العادي لـ `flutter test` يتجاوز هذا الملف إلى أن يُفعّل الخيار أعلاه.

ملف `test/emulators/firestore.rules` مخصص للاختبار المحلي فقط. قواعد المشروع الفعلي ليست ضمن المستودع، لذلك التحقق المحلي لا يثبت إعداد صلاحيات Firebase المنشورة. يجب أن تمنع تلك القواعد مقدم الخدمة من تغيير حالة الموافقة أو الوصول إلى مستندات الآخرين.

مرجع: [ربط Firebase Authentication بالمحاكي](https://firebase.google.com/docs/emulator-suite/connect_auth).
