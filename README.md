# SmartMove Transport Solutions

SmartMove is a Flutter client backed by a Spring Boot REST API. Oracle stores relational transport operations using the supplied schema exactly as provided. A separately designed MongoDB layer stores flexible vehicle media/documents, passenger feedback, travel announcements, and community discussions.

## Project layout

- `schema.sql` — the original Oracle schema reference. Do not rerun or edit it if your database is already created.
- `database/sample_data.sql` — repeatable example rows for the existing Oracle schema.
- `database/plsql/smartmove_api.sql` — allowlisted PL/SQL API for Oracle reads, writes, deletes, and dashboard metrics.
- `database/plsql/smartmove_reports.sql` — PL/SQL package with report cursors, a revenue function, and exception handling.
- `database/plsql/install_smartmove_packages.sql` — installs/replaces both PL/SQL packages without changing tables.
- `database/security/least_privilege_setup.sql` — rerunnable package-only grants for a dedicated runtime account.
- `database/backup/smartmove_oracle_backup.rman` — Oracle RMAN full backup and retention script.
- `database/backup/backup_mongodb.ps1` — timestamped compressed MongoDB backup script.
- `database/ER_DIAGRAM.md` — ER diagram for the Oracle entities.
- `MongoDB/` — legacy coursework folder, excluded from the GitHub repository and not used by the application.
- `database/mongodb/seed.js` — safe, repeatable seed data for the new MongoDB document design.
- `backend/` — Spring Boot REST API for Oracle and MongoDB.
- `frontend/` — Flutter application.

## Existing database setup

1. Do **not** run `schema.sql` again if the existing database has already been created. No project setup step alters its tables or constraints.
2. Connect to the existing `SMART_MOVE` schema owner in SQL*Plus/SQLcl and install the stored code:

   ```sql
   @database/plsql/install_smartmove_packages.sql
   ```

   This creates/replaces only the `SMARTMOVE_API` and `SMARTMOVE_REPORTS` packages. Use the matching Oracle service/PDB where your schema exists.
3. As a DBA, create a dedicated Oracle runtime account and grant it session access. Substitute your own username and securely chosen password:

   ```sql
   CREATE USER SMARTMOVE_APP IDENTIFIED BY "<choose-a-private-password>";
   GRANT CREATE SESSION TO SMARTMOVE_APP;
   ```

   Then, still connected with DBA privileges, run:

   ```sql
   @database/security/least_privilege_setup.sql
   ```

   Enter `SMARTMOVE_APP` when prompted. This grants the runtime role `EXECUTE` on the two PL/SQL packages, revokes old table DML grants made directly to that role, and does not change schema objects. It is safe to rerun. If the account received table privileges directly or through some other role, a DBA should review and remove those separately.
4. Set the backend Oracle username/password to the dedicated account. The `SMART_MOVE` schema owner is only needed for installing/replacing package code. If your owner name differs from `SMART_MOVE`, update the owner-qualified grants in the security script to the actual schema owner; do not edit or recreate the schema.
5. Optionally run `database/sample_data.sql` as the schema owner only if demo rows are wanted and its placeholder values are appropriate for this database. It is seed SQL, not part of normal application operations.
6. Start MongoDB and optionally run `mongosh "mongodb://localhost:27017/smartmove_db" database/mongodb/seed.js`. This seed script does not drop collections. Its demo Oracle IDs are placeholders; replace them with IDs in your Oracle database to demonstrate cross-database relationships.

The Oracle owner/user must have access to the tables in `schema.sql` and permission to create a package. To configure database connections in a project-local file instead of environment variables:

```powershell
Copy-Item backend/application-local.example.properties backend/application-local.properties
```

Edit `backend/application-local.properties` with the Oracle URL, Oracle runtime username/password, MongoDB connection settings, and a private random `smartmove.security.api-key` of at least 32 characters. Configure the same API key in the Flutter app using the connection settings button. The key stays in browser memory only and must be entered again after a page reload. Generate a key in PowerShell with:

```powershell
$random = [Security.Cryptography.RandomNumberGenerator]::Create()
$keyBytes = New-Object byte[] 48
$random.GetBytes($keyBytes)
[Convert]::ToBase64String($keyBytes)
$random.Dispose()
```

Spring Boot loads the local file automatically when started from `backend/`. The file is excluded from Git. Environment variables such as `ORACLE_URL` and `SMARTMOVE_API_KEY` override the local file settings. Every `/api/` request requires the configured key in `X-SmartMove-API-Key`; after sign-in, it also requires a valid administrator session. The shared key is an additional local coursework guard, not a replacement for administrator authentication or a production security boundary. Do not expose the HTTP development server or embed a real shared secret in a publicly distributed web build. Production deployment requires HTTPS and appropriate account/session controls.

### Create the first administrator

Login requires a row in both `App_User` and `Admin`. Because no administrator can sign in before the first account exists, provision the first administrator once as the schema owner. Generate a compatible password hash locally in PowerShell (the password is entered as a secure prompt and is not printed):

```powershell
$securePassword = Read-Host 'Choose the first administrator password' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    $salt = New-Object byte[] 16
    $random.GetBytes($salt)
    $random.Dispose()
    $derive = [Security.Cryptography.Rfc2898DeriveBytes]::new(
        $password, $salt, 120000, [Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
        $hash = $derive.GetBytes(32)
        $encodedHash = 'pbkdf2_sha256$120000${0}${1}' -f `
            [Convert]::ToBase64String($salt), [Convert]::ToBase64String($hash)
        $encodedHash
    } finally {
        $derive.Dispose()
    }
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    $securePassword.Dispose()
}
```

Copy the printed hash into the following SQL block, replace the example profile values, and execute it **once** in SQL Developer while connected as `SMART_MOVE`. The password column must contain the complete generated hash, not the plaintext password:

```sql
DECLARE
    l_user_id NUMBER;
BEGIN
    INSERT INTO App_User (f_name, l_name, email, password)
    VALUES ('System', 'Administrator', 'admin@example.com',
            'PASTE_THE_GENERATED_HASH_HERE')
    RETURNING user_id INTO l_user_id;

    INSERT INTO Admin (user_id) VALUES (l_user_id);
    COMMIT;
END;
/
```

After installing the backend and entering the API URL and shared access key with the settings button, sign in using that email and the original password. The browser keeps the session token only in memory; it expires after eight hours or when the backend restarts. Once signed in, additional admin accounts can be created by adding a user through Operations (which hashes the password) and adding that user's ID to the Admin resource. Do not create an administrator by storing a plaintext password.

All Oracle application reads, inserts, updates, deletes, account creation, dashboard counts, and business reports are invoked through the `SMARTMOVE_API` or `SMARTMOVE_REPORTS` PL/SQL package. Spring JDBC is only the transport used to call those stored program units; the REST controller does not issue table CRUD SQL. The API package uses resource and field allowlists, bind variables, scalar JSON validation, and contextual Oracle exceptions. The app-user list endpoint explicitly omits the password column. For Oracle runtime access, use the dedicated account and package-only grants described above; do not connect the backend as the schema owner or run the grant script as an untrusted user.

For MongoDB, enable authorization on the server and create the application user while authenticated as a database administrator by running `database/security/create_mongodb_app_user.js` in `mongosh`. Use that user's URI in the private backend properties, including `authSource=smartmove_db`; do not use an administrator account in the backend. For example, the URI format is `mongodb://smartmove_app:<URL-ENCODED-PASSWORD>@localhost:27017/smartmove_db?authSource=smartmove_db`. Replace the placeholder with the generated password and URL-encode reserved characters.

## Backups and recovery

The Oracle backup script is `database/backup/smartmove_oracle_backup.rman`. Create `D:\SmartMoveBackups\Oracle`, ensure the database is in ARCHIVELOG mode, and run the script with RMAN while connected with the required backup privileges. It enables control-file autobackups, creates compressed database and archived-log backups, and applies a 14-day recovery window. Confirm Oracle edition/licensing and available disk capacity for your installation. Schedule it using Windows Task Scheduler and regularly test restoration to a separate database; an untested backup is not a verified recovery plan.

For MongoDB, set `MONGODB_URI` and `MONGODB_DATABASE` in the PowerShell session and run `database/backup/backup_mongodb.ps1`. It creates a timestamped compressed archive and does not remove older backups. Protect backup folders as sensitive data, copy backups to separate storage, define an appropriate retention policy, and periodically test restoration with MongoDB Database Tools.

## Run the backend

After installing both PL/SQL packages, provisioning an initial administrator, and editing `application-local.properties`, run from `backend/`:

```powershell
mvn spring-boot:run
```

The API listens on port `8081` by default. Main endpoints:

- `GET /api/dashboard`
- `POST /api/auth/login` and `POST /api/auth/logout` (administrator session)
- CRUD `GET`, `POST`, `PUT`, and `DELETE /api/{resource}[/{id}]` for users, roles, user roles, passengers, drivers, admins, vehicles, routes, trips, bookings, payments, feedback, and maintenance.
- `GET /api/reports/frequent-routes`
- `GET /api/reports/revenue?from=2026-01-01&to=2026-12-31`
- `GET /api/reports/passenger-history/{passengerId}`
- `GET /api/reports/maintenance-summary`
- `GET /api/mongo/feedback?routeId=123`
- `GET /api/mongo/ratings/vehicles` and `/api/mongo/ratings/drivers`
- `GET /api/mongo/complaints?keyword=delay`
- `GET /api/mongo/vehicle-content[/{vehicleId}]`; `PUT /api/mongo/vehicle-content/{vehicleId}`
- `POST /api/mongo/vehicle-content/{vehicleId}/image` (multipart field `image`, plus `registrationNumber` and `vehicleType`); `GET /api/mongo/vehicle-content/images/{imageId}`
- `POST /api/mongo/vehicle-content/{vehicleId}/image` (multipart field `image`); `GET /api/mongo/vehicle-content/images/{imageId}`
- `GET` and `POST /api/mongo/announcements`; `PATCH /api/mongo/announcements/{mongoDocumentId}/active`
- `GET` and `POST /api/mongo/notifications`; `PATCH /api/mongo/notifications/{mongoDocumentId}/read`
- `POST /api/mongo/feedback` and `/api/mongo/feedback/{mongoDocumentId}/replies`
- `GET` and `POST /api/mongo/community`; `POST /api/mongo/community/{mongoDocumentId}/replies`

Oracle generic-resource request bodies use the lowercase column names from the supplied schema, for example:

```json
{"origin":"Colombo","destination":"Kandy","distance":115,"est_du":"3 hours 30 minutes"}
```

IDs generated by Oracle are omitted when creating records. Creating a passenger or driver through the operations UI creates its `App_User` row and the corresponding `Passenger` or `Driver` row together in one transaction; the user ID is generated by Oracle, and a matching role is linked when that role exists. The driver form also collects its required license. Other foreign-key values must refer to existing rows. ISO date/time inputs use `YYYY-MM-DD` and `YYYY-MM-DDTHH:mm:ss` formats. Oracle errors are returned as API errors rather than treated as successful operations.

## Run the Flutter app

From `frontend/`, run on Chrome:

```powershell
flutter pub get
flutter run -d chrome
```

The Flutter app defaults to `http://localhost:8081`, matching the backend's default. If you change `server.port` in `backend/application-local.properties`, update the Spring Boot API URL in the app settings too. Android emulator clients generally need the host machine's emulator-accessible address instead of `localhost`. The app includes an Oracle operations console, MongoDB vehicle media, passenger feedback/ratings/complaints, announcements, notifications, student/instructor discussion threads, and business reports. Local Flutter web origins on `localhost` and `127.0.0.1` are enabled in the backend for development.

The Android development client permits cleartext HTTP to connect to a local Spring Boot server. The shared API key and administrator login are intended for trusted local coursework demonstrations, not as a production authentication deployment. Use HTTPS and additional protections before exposing the service publicly.

## Reports and coursework coverage

The `SMARTMOVE_API` package implements generic resource listing, creation, update and deletion; transactional passenger/driver parent-and-subtype creation; composite user-role deletion; and dashboard metrics. The `SMARTMOVE_REPORTS` package provides frequently booked routes, revenue by date range, passenger travel history, vehicle maintenance summaries, and the `total_revenue` function. Spring Boot invokes these stored procedures/functions; it does not perform direct SQL CRUD. Both packages use validation and contextual error handling. Run `database/plsql/install_smartmove_packages.sql` as `SMART_MOVE` after a package change and before starting the backend. This script adds/replaces stored program units only; it never modifies the supplied tables or constraints. PL/SQL compile and runtime compatibility must be confirmed in the Oracle version installed on the target machine.

MongoDB collections are designed specifically for the coursework and are not based on the files in `MongoDB/`:

- `vehicle_content`: `{ vehicle_id, registration_number, vehicle_type, documents: [{ document_type, document_number, expiry_date, status, ... }], images: [{ image_id, image_url, file_name, content_type, size_bytes, uploaded_at }], metadata, updated_at }`. Vehicle content is upserted by its Oracle vehicle ID. Adding a vehicle in Flutter requires choosing an image; Oracle returns the generated vehicle ID, and the image bytes are stored in MongoDB GridFS against that ID. Images must be JPEG, PNG, WebP, or GIF and no larger than 8 MB. If the Oracle insert succeeds but the MongoDB image upload fails, the UI reports the created vehicle ID so the image upload can be retried by editing that vehicle.
- `passenger_feedback`: `{ passenger_id, route_id, trip_id?, vehicle_id?, driver_id?, rating, category, comment, tags?, replies: [{ author_name, author_role, message, posted_at }], posted_at }`. Numeric Oracle IDs provide cross-database references. The API supports route feedback, average ratings by vehicle/driver, and literal case-insensitive complaint searches.
- `travel_announcements`: `{ title, message, type, target_route_ids?, audience?, active, published_at }`. The application lists announcements and lets users publish or activate/deactivate them.
- `user_notifications`: `{ recipient_id?, title, message, type, read, created_at, read_at? }`. Notifications can target an Oracle user and can be marked read.
- `community_posts`: `{ author_name, author_role, topic, message, replies: [{ author_name, author_role, message, posted_at }], posted_at }`. Students and instructors can start and reply to discussion threads.

Nested documents, arrays, and optional metadata can evolve without changing the Oracle schema. Content refreshes on demand and automatically every 15 seconds while the MongoDB screen is open; updates are request-based rather than pushed over a separate messaging protocol.

The sample SQL intentionally uses placeholder password values; those sample users are not valid administrator credentials. Provision administrator accounts with PBKDF2 password hashes as described above.
