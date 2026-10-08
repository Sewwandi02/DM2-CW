# SmartMove Transport Solutions

## Advanced Database Management Systems — Coursework Project Report

**Hybrid Database Application: Oracle Database and MongoDB**

**Institution:** National Institute of Business Management  
**School:** School of Computing and Engineering  
**Module:** Data Management 2  
**Course / Batch:** [Insert course and batch]  
**Group:** [Insert group number]  
**Lecturer / Supervisor:** [Insert lecturer name]  
**Group members:** [Insert member names and student IDs]  
**Submission date:** [Insert submission date]

---

## Contents

1. Acknowledgment
2. Project Overview
3. System Architecture and Data Flow
4. Technology Stack
5. Requirements and Scope
6. Relational Data Model and ER Diagram
7. Oracle Database Implementation
8. Sample Data and SQL Operations
9. PL/SQL Programming and Business Reports
10. MongoDB Integration
11. Backend REST API
12. Flutter Frontend
13. Testing and Verification
14. Security, Limitations, and Future Improvements
15. Conclusion
16. References

---

## 1. Acknowledgment

We would like to express our appreciation to our lecturer and supervisor for the guidance provided during the planning and development of the SmartMove Transport Solutions coursework project. The coursework provided an opportunity to apply relational database design, SQL, PL/SQL, document databases, and application development to a transport-management scenario.

We also thank our group members for their contributions to reviewing the requirements, developing the application, and discussing the database design. The project was developed using the Oracle database environment, MongoDB, Spring Boot, Java, and Flutter.

*Edit this acknowledgment to accurately reflect the contributions and support received by your group.*

## 2. Project Overview

SmartMove Transport Solutions is a transport-management application developed to support common transport-service activities. These activities include managing vehicles, drivers, passengers, routes, trips, bookings, payments, maintenance records, and feedback.

The application uses a hybrid database design. Oracle stores structured operational data and enforces relationships between users, vehicles, trips, bookings, and payments. MongoDB stores flexible content such as vehicle media, passenger feedback, announcements, notifications, and community discussions. A Spring Boot REST API mediates application requests to both databases, while a Flutter application provides the user interface.

The implementation was designed around the existing Oracle schema supplied with the project. That schema was treated as fixed: the project does not change its tables, columns, constraints, or relationships. Additional PL/SQL report routines and sample data scripts are supplied separately.

### 2.1 Project objectives

The main objectives were to:

- model the transport-management entities and their relationships;
- use the supplied Oracle schema without modifying it;
- implement a Flutter application that can interact with transport data;
- expose database operations through a Spring Boot REST API;
- use MongoDB for flexible transport-related documents and multimedia;
- demonstrate MongoDB filtering and rating queries;
- provide business reports for route usage, revenue, and passenger history; and
- integrate Oracle and MongoDB data through the application layer.

## 3. System Architecture and Data Flow

The system follows a three-tier application architecture with two database technologies:

```text
Flutter application
        |
        | HTTP / JSON and multipart image uploads
        v
Spring Boot REST API
        |                         |
        | JDBC                    | MongoDB driver / GridFS
        v                         v
Oracle database              MongoDB database
```

The Flutter client communicates with the backend rather than connecting directly to either database. Oracle requests are used for relational transport operations and reports. MongoDB requests are used for flexible documents, feedback, announcements, notifications, community posts, and vehicle-image storage.

For vehicle creation, the backend inserts the vehicle into Oracle and returns its generated vehicle ID. The Flutter client then uploads the required image to the backend, which saves the image bytes in MongoDB GridFS and associates the image metadata with the Oracle vehicle ID. This ID provides a cross-database reference without introducing a cross-database foreign-key constraint.

The MongoDB screen refreshes its content when requested and periodically while the screen is active. This is request-based refreshing; the current implementation does not use a separate push-notification or streaming protocol.

## 4. Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| Frontend | Flutter and Dart | User interface for dashboard, operations, MongoDB content, and reports |
| Backend | Java and Spring Boot | REST API, request handling, database access, and application logic |
| Relational database | Oracle Database | Structured transport entities and transactional records |
| Relational connectivity | JDBC / Spring JDBC | Calling the Oracle PL/SQL API packages |
| Document database | MongoDB | Flexible transport content and community documents |
| Image storage | MongoDB GridFS | Storage and retrieval of vehicle image bytes |
| API data format | JSON and multipart form data | Exchange of records and uploaded image files |

The current application does not use Riverpod, GoRouter, Dio, JWT authentication, or Spring Data JPA. The backend uses JDBC to invoke Oracle stored program units; Oracle application data operations are implemented in PL/SQL. The Flutter application uses the `http` package for API communication.

## 5. Requirements and Scope

The project addresses the principal operational areas specified for the SmartMove scenario:

- vehicle, driver, passenger, and route management;
- trip scheduling;
- ticket booking and payment records;
- vehicle maintenance records;
- relational feedback records;
- PL/SQL business reports;
- MongoDB passenger feedback and keyword-based complaint search;
- MongoDB vehicle documents and multimedia;
- travel announcements and user notifications; and
- community discussion posts with replies.

The Flutter operations interface provides database record operations for the Oracle resources exposed by the backend. Passenger and driver creation also creates the associated `App_User` parent record as part of the same transaction. The vehicle-creation form does not request an administrator ID and requires a vehicle image.

This is a local coursework application rather than a production transport platform. It demonstrates database integration and application operations; it does not implement a complete commercial booking workflow, live vehicle tracking, payment-gateway integration, or production identity management.

## 6. Relational Data Model and ER Diagram

The Oracle model contains 13 related tables grouped into four functional areas.

### 6.1 User and role entities

- `Role` stores available role names.
- `App_User` stores user profile and account fields.
- `User_Role` associates users with roles.
- `Passenger`, `Driver`, and `Admin` represent user specializations.

Passenger, driver, and administrator rows use the corresponding user identifier as their primary key and as a foreign key to `App_User`. This enforces the parent-user relationship represented by the supplied schema.

### 6.2 Transport entities

- `Vehicle` stores registration, type, capacity, status, and an optional administrator reference.
- `Route` stores origin, destination, distance, and estimated duration.
- `Trip` stores scheduled trip times, fare, status, and references to its route, vehicle, driver, and optionally a passenger.

### 6.3 Transaction entities

- `Booking` stores booking date, seat, total amount, status, and passenger and trip references.
- `Payment` stores amount, payment date, payment method, status, and its booking reference.

### 6.4 Operational entities

- `Feedback` stores a relational rating, comments, date, and passenger and trip references.
- `Maintenance` stores a maintenance date, description, cost, status, and vehicle reference.

The full entity relationship diagram is included in [database/ER_DIAGRAM.md](database/ER_DIAGRAM.md). It documents the primary and foreign-key relationships represented by the existing schema. The implementation uses this supplied schema as its source of truth and does not apply schema changes.

## 7. Oracle Database Implementation

Oracle is used for the application's structured operational data. The provided schema defines primary keys, foreign keys, unique constraints, identity-generated identifiers, defaults, and a rating check constraint. These database constraints help preserve consistency for relational records.

The project keeps the original `schema.sql` unchanged. For an environment where this schema has already been created, it should not be run again. The backend connects to the existing schema using configuration in `backend/application-local.properties` or environment variables. The local properties file is based on the supplied example and is excluded from version control so database credentials are not committed.

The operations API exposes resources corresponding to the Oracle tables, including roles, users, user-role mappings, passengers, drivers, administrators, vehicles, routes, trips, bookings, payments, feedback, and maintenance. These Oracle reads and writes are executed by the `SMARTMOVE_API` PL/SQL package, rather than direct table SQL in the Spring controller.

### 7.1 Passenger and driver creation

The passenger and driver records depend on a matching row in `App_User`. To avoid the parent-key error that would occur if the subtype were inserted alone, the `SMARTMOVE_API.create_passenger_or_driver` PL/SQL procedure creates the `App_User` record and the selected `Passenger` or `Driver` record atomically. Oracle generates the user ID, which the procedure returns. Driver creation also requires a license value. Where a corresponding role exists, the procedure links it through `User_Role`.

The password submitted during account creation is hashed by the backend with PBKDF2-HMAC-SHA256 before being stored.

### 7.2 Administrator authentication

The Flutter application presents an administrator sign-in screen before exposing the operations interface. The backend checks the email against an `App_User` row linked to `Admin`, retrieves the stored hash through `SMARTMOVE_API.admin_password_hash`, and verifies PBKDF2-HMAC-SHA256 using a constant-time comparison. Successful sign-in issues a random in-memory bearer token; protected API calls require both that session and the configured local API key. Sessions expire after eight hours and are invalidated when the backend restarts or the administrator signs out. The initial administrator is provisioned manually in the existing schema using a generated password hash; the process is documented in the README. No schema changes are required.

### 7.3 Vehicle creation and image association

Oracle creates the vehicle record and generates its identifier. The API returns this identifier to the client. The client then uploads the required image to the MongoDB endpoint, where it is stored separately in GridFS. Metadata in the `vehicle_content` document associates the image with the Oracle vehicle ID.

Because the two databases do not share a transaction, the Oracle vehicle insert and MongoDB upload are separate operations. If image upload fails after the Oracle insert succeeds, the created vehicle ID is reported so the image can be retried.

## 8. Sample Data and SQL Operations

The project includes `database/sample_data.sql` to provide example rows for demonstration. These rows are intended to be adapted to the identifiers and constraints of the local Oracle database. The sample user password values are placeholders and must not be treated as production credentials.

The sample script and the API serve different purposes:

- the SQL script provides seed data for local testing and demonstration;
- the REST API provides application-level operations against the existing schema; and
- database constraints remain enforced by Oracle during inserts and updates.

Before running sample data, the operator should confirm that the referenced parent records exist and that unique values, such as email addresses and vehicle registration numbers, do not conflict with existing data.

## 9. PL/SQL Programming and Business Reports

The project provides two PL/SQL packages: `database/plsql/smartmove_api.sql` for operational calls and `database/plsql/smartmove_reports.sql` for reports. The packages demonstrate procedures, a function, output cursors, input validation, allowlisted operations, bind variables, deterministic report ordering, and exception handling. Spring Boot calls these Oracle stored program units; Oracle table operations are not implemented as direct SQL in the controller. Installing or replacing either package does not alter the table definitions in the supplied schema.

The generic operations package supports allowlisted resource listing, insert, update, and delete operations, together with passenger/driver account creation and dashboard metrics. It does not accept arbitrary table or column names from the client. JSON input fields are checked against resource-specific allowlists and values are bound as parameters. Oracle-generated identifiers are returned to the backend. Errors from constraints and unexpected Oracle failures are propagated with operation context rather than presented as successful results.

### 9.1 Frequently booked routes

The `frequent_routes` procedure joins routes to trips and bookings, groups results by route, counts bookings, and sorts routes by booking count. This report identifies routes with comparatively high booking activity.

### 9.2 Revenue by period

The `revenue_by_period` procedure accepts a start and end date and returns daily totals for payments whose status is `Paid`. It validates that the dates are supplied and that the end date is not earlier than the start date.

### 9.3 Passenger travel history

The `passenger_travel_history` procedure accepts a passenger ID and returns the passenger's bookings with trip and route information. The result includes booking details, trip status and times, and route origin and destination.

### 9.4 Vehicle maintenance summary

The `maintenance_summary` procedure returns all vehicles, including vehicles without maintenance records, with the number of maintenance records, accumulated costs, pending count, and latest maintenance date. Results are ordered by maintenance cost and vehicle ID.

### 9.5 Total revenue function

The `total_revenue` function calculates total paid revenue for a supplied date range. It returns zero when no matching paid amounts are found and validates the date range.

The package uses distinct application errors for invalid dates, missing passengers, and report failures. Expected application errors are preserved; unexpected Oracle errors are wrapped with the originating Oracle code and report context. The REST API invokes these routines for all four reports and combines the revenue cursor with the total-revenue function result.

## 10. MongoDB Integration

MongoDB is used for data whose shape is more flexible than the relational records. The collection design was created for this application and coursework requirements; the existing top-level `MongoDB/` folder is not used by the application.

### 10.1 Collections

| Collection | Purpose | Example information |
|---|---|---|
| `vehicle_content` | Flexible vehicle documents and image metadata | Oracle vehicle ID, registration number, type, document list, image references, metadata, update time |
| `passenger_feedback` | Passenger comments and ratings | Passenger, route, trip, vehicle or driver references; rating; category; comment; tags; replies |
| `travel_announcements` | Public or route-targeted service notices | Title, message, type, target routes, audience, active state, publication time |
| `user_notifications` | User-facing notifications | Optional recipient ID, title, message, type, read state, creation and read times |
| `community_posts` | Discussion threads for community interaction | Author, role, topic, message, replies, posting time |

Documents contain numeric Oracle IDs where a relationship to relational data is useful. These identifiers are application-level references; MongoDB does not enforce Oracle foreign keys.

### 10.2 Vehicle documents and multimedia

Vehicle content documents can contain document details and image metadata without changing the Oracle schema. Vehicle images are stored in GridFS. The accepted image formats are JPEG, PNG, WebP, and GIF, with a maximum upload size of 8 MB. The API provides an image retrieval endpoint and returns the image content type.

### 10.3 Feedback queries

The feedback API supports retrieving feedback associated with a route, calculating vehicle and driver rating summaries, and searching complaint text by a supplied keyword. Keyword searches are case-insensitive and use the provided text as a literal search term.

### 10.4 Announcements, notifications, and discussions

The application can list and publish travel announcements and change their active status. Notifications can be created and marked as read. Community posts can be created and replied to, with replies stored inside the corresponding document. Nested arrays and optional fields allow these content types to evolve without altering Oracle tables.

### 10.5 MongoDB seed data

•	MongoDB collections capture:
o	Vehicle images and documents. 
o	Passenger reviews and feedback comments.
o	Travel announcements and notifications.

## 11. Backend REST API

The backend is a Spring Boot application. Its controllers expose HTTP endpoints for Oracle resources, reports, and MongoDB content. The backend is responsible for validating requests, translating them into database operations, and returning results or errors to the Flutter application.

Representative endpoint groups include:

| Endpoint group | Purpose |
|---|---|
| `/api/dashboard` | Dashboard summary information |
| `/api/{resource}` | List and operate on supported Oracle resources |
| `/api/reports/frequent-routes` | Route booking report |
| `/api/reports/revenue` | Daily revenue breakdown and total for a date range |
| `/api/reports/passenger-history/{passengerId}` | Passenger travel history |
| `/api/reports/maintenance-summary` | Vehicle maintenance counts, cost totals, and pending work |
| `/api/mongo/vehicle-content` | Vehicle document and image metadata |
| `/api/mongo/feedback` | Passenger feedback operations and lookups |
| `/api/mongo/ratings/vehicles` and `/api/mongo/ratings/drivers` | Rating summaries |
| `/api/mongo/complaints` | Keyword search across complaint feedback |
| `/api/mongo/announcements` | Announcement operations |
| `/api/mongo/notifications` | Notification operations |
| `/api/mongo/community` | Community discussion operations |

Vehicle image upload uses multipart form data. Other API requests generally exchange JSON. Database exceptions are returned as API errors rather than being represented as successful operations.

The backend includes local development CORS settings for Flutter web origins. The default API port is 8081 and can be adjusted in local configuration.

## 12. Flutter Frontend

The Flutter application provides four main sections:

1. **Dashboard** — summary view of transport operations, with refresh and error-retry behavior.
2. **Operations** — interface for working with Oracle-backed resources.
3. **MongoDB** — interface for vehicle content, passenger feedback, ratings, complaint search, announcements, notifications, and community discussions.
4. **Reports** — interface for frequent routes, revenue by period, passenger history, and vehicle maintenance summaries.

The vehicle form requires an image when a vehicle is created and does not ask the user to supply an administrator ID. Passenger and driver forms collect the details needed to create both the user and specialization records. Errors returned by the backend are surfaced in the interface to assist with diagnosing invalid data or database constraints.

The web client defaults to the backend URL `http://localhost:8081`. The address can be changed in the application or supplied through the `SMARTMOVE_API_URL` build-time setting. Android emulator configurations may need a host address other than `localhost`.



## 14. Security, Limitations, and Future Improvements

### 14.1 Security measures

API requests require a privately configured shared API key of at least 32 characters. The backend compares it in constant time and rejects requests if it is missing or has not been configured. In addition, the administrator must sign in with an account in the `Admin` subtype; the password is verified against its PBKDF2-HMAC-SHA256 hash, and authenticated requests use an in-memory bearer session. Sessions expire after eight hours and are cleared on backend restart. The Flutter client keeps the API key and session token only in memory. Oracle credentials and keys belong in ignored local configuration or environment variables and must not be committed.

The project supplies a rerunnable Oracle role-grant script for a dedicated runtime user. It grants `EXECUTE` on the two PL/SQL packages and no direct table privileges. The app-user list endpoint explicitly omits the `APP_USER.PASSWORD` column. A MongoDB user-creation script grants the application access to its own database rather than requiring the application to connect as a MongoDB administrator. These scripts require explicit setup by a database administrator.

### 14.2 Backups

The Oracle RMAN script enables control-file autobackups, creates compressed database and archive-log backups, and configures a 14-day recovery window. The PowerShell MongoDB script creates timestamped compressed database archives without deleting earlier backups. Backup scheduling, separate/off-site copies, access protection, disk monitoring, and restoration drills must be configured and verified by the operator.

### 14.3 Current limitations and future improvements

The shared API key and administrator login provide local coursework access control, not a complete production identity or authorization system. The browser client must know the shared key to make requests, and local development uses HTTP; deploy only behind HTTPS with secure secret distribution, persistent/managed sessions, and appropriate account protections. Oracle application operations are routed through the `SMARTMOVE_API` and `SMARTMOVE_REPORTS` packages, while JDBC is used only to communicate with those PL/SQL program units. The package-based grants limit the runtime account to executing those packages rather than directly manipulating tables.

The backup scripts have not been run against the local Oracle or MongoDB installations, and recovery has not been tested. The operator must configure and test them against the installed database versions. Future work includes testing the PL/SQL packages on the target Oracle version, strengthening production account controls, and performing scheduled restore drills.

## 15. Conclusion

SmartMove demonstrates a hybrid database application for a transport-management scenario. Oracle provides the structured relational foundation for users, vehicles, routes, trips, bookings, payments, feedback, and maintenance. MongoDB complements it with flexible content, image metadata, feedback discussions, announcements, notifications, and community posts.

The Spring Boot API provides an integration layer between these databases and the Flutter application. The project also includes a relational ER diagram, sample Oracle data, MongoDB seed data, and PL/SQL API and reporting packages. The existing Oracle schema has been preserved unchanged, as required for integration with the already-created local database.

## 16. References

- SmartMove coursework assessment brief, Data Management 2.
- Supplied Oracle schema: `schema.sql`.
- SmartMove project documentation: `README.md`.
- Oracle entity relationship diagram: `database/ER_DIAGRAM.md`.
- PL/SQL operations package: `database/plsql/smartmove_api.sql`.
- PL/SQL reporting package: `database/plsql/smartmove_reports.sql`.
- PL/SQL package installer: `database/plsql/install_smartmove_packages.sql`.
- Oracle sample data: `database/sample_data.sql`.
- MongoDB seed script: `database/mongodb/seed.js`.
