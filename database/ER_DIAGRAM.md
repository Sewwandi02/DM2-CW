# SmartMove ER diagram

```mermaid
erDiagram
    ROLE ||--o{ USER_ROLE : grants
    APP_USER ||--o{ USER_ROLE : has
    APP_USER ||--o| PASSENGER : is
    APP_USER ||--o| DRIVER : is
    APP_USER ||--o| ADMIN : is
    ADMIN o|--o{ VEHICLE : manages
    ROUTE ||--o{ TRIP : schedules
    VEHICLE o|--o{ TRIP : assigned_to
    DRIVER o|--o{ TRIP : drives
    PASSENGER o|--o{ TRIP : assigned_to
    PASSENGER o|--o{ BOOKING : makes
    TRIP ||--o{ BOOKING : booked_for
    BOOKING o|--o{ PAYMENT : paid_by
    PASSENGER o|--o{ FEEDBACK : writes
    TRIP o|--o{ FEEDBACK : receives
    VEHICLE o|--o{ MAINTENANCE : serviced_by

    ROLE {
        NUMBER role_id PK
        VARCHAR2 role_name
    }
    APP_USER {
        NUMBER user_id PK
        VARCHAR2 f_name
        VARCHAR2 l_name
        VARCHAR2 email UK
        VARCHAR2 phone
        VARCHAR2 password
        TIMESTAMP created_at
    }
    USER_ROLE {
        NUMBER user_id PK,FK
        NUMBER role_id PK,FK
    }
    PASSENGER {
        NUMBER user_id PK,FK
    }
    DRIVER {
        NUMBER user_id PK,FK
        VARCHAR2 license
        VARCHAR2 status
    }
    ADMIN {
        NUMBER user_id PK,FK
    }
    VEHICLE {
        NUMBER vehicle_id PK
        VARCHAR2 reg_no UK
        VARCHAR2 vehicle_type
        NUMBER capacity
        VARCHAR2 status
        NUMBER admin_id FK
    }
    ROUTE {
        NUMBER route_id PK
        VARCHAR2 origin
        VARCHAR2 destination
        NUMBER distance
        VARCHAR2 est_du
    }
    TRIP {
        NUMBER trip_id PK
        TIMESTAMP departure_time
        TIMESTAMP arrival_time
        NUMBER fare
        VARCHAR2 status
        NUMBER route_id FK
        NUMBER vehicle_id FK
        NUMBER driver_id FK
        NUMBER passenger_id FK
    }
    BOOKING {
        NUMBER booking_id PK
        TIMESTAMP b_date
        VARCHAR2 seat_no
        NUMBER tot_am
        VARCHAR2 status
        NUMBER passenger_id FK
        NUMBER trip_id FK
    }
    PAYMENT {
        NUMBER payment_id PK
        NUMBER amount
        TIMESTAMP pay_date
        VARCHAR2 pay_method
        VARCHAR2 pay_status
        NUMBER booking_id FK
    }
    FEEDBACK {
        NUMBER feedback_id PK
        NUMBER rating
        CLOB comments
        TIMESTAMP feedback_date
        NUMBER passenger_id FK
        NUMBER trip_id FK
    }
    MAINTENANCE {
        NUMBER maintenance_id PK
        DATE maintenance_date
        CLOB description
        NUMBER cost
        VARCHAR2 status
        NUMBER vehicle_id FK
    }
```

MongoDB complements these normalized Oracle entities with flexible `vehicle_content`, `passenger_feedback`, `travel_announcements`, `user_notifications`, and `community_posts` collections. The new design and safe seed are documented in [`mongodb/seed.js`](./mongodb/seed.js) and [`README.md`](../README.md). The original `MongoDB/` coursework folder is not used by the application.
