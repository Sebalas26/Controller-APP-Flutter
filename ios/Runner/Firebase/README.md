Place Firebase iOS plist files here:

- GoogleService-Info-controller-courier.qa.plist
- GoogleService-Info-controller-user.qa.plist

The iOS build copies the file selected by `FIREBASE_CONFIGURATION` into the app bundle as `GoogleService-Info.plist`.

Default value:

```text
FIREBASE_CONFIGURATION=controller-courier.qa
```
