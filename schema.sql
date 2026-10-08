-- Reference copy of the finalized SmartMove Oracle schema.
CREATE TABLE Role (
    role_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_name VARCHAR2(50) NOT NULL
);

CREATE TABLE App_User (
    user_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    f_name VARCHAR2(50) NOT NULL,
    l_name VARCHAR2(50) NOT NULL,
    email VARCHAR2(100) UNIQUE NOT NULL,
    phone VARCHAR2(20),
    password VARCHAR2(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE User_Role (
    user_id NUMBER,
    role_id NUMBER,
    CONSTRAINT pk_user_role PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_ur_user FOREIGN KEY (user_id) REFERENCES App_User(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_ur_role FOREIGN KEY (role_id) REFERENCES Role(role_id) ON DELETE CASCADE
);

CREATE TABLE Passenger (
    user_id NUMBER PRIMARY KEY,
    CONSTRAINT fk_passenger_user FOREIGN KEY (user_id) REFERENCES App_User(user_id) ON DELETE CASCADE
);

CREATE TABLE Driver (
    user_id NUMBER PRIMARY KEY,
    license VARCHAR2(50) NOT NULL,
    status VARCHAR2(20) DEFAULT 'Active',
    CONSTRAINT fk_driver_user FOREIGN KEY (user_id) REFERENCES App_User(user_id) ON DELETE CASCADE
);

CREATE TABLE Admin (
    user_id NUMBER PRIMARY KEY,
    CONSTRAINT fk_admin_user FOREIGN KEY (user_id) REFERENCES App_User(user_id) ON DELETE CASCADE
);

CREATE TABLE Vehicle (
    vehicle_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reg_no VARCHAR2(20) UNIQUE NOT NULL,
    vehicle_type VARCHAR2(50) NOT NULL,
    capacity NUMBER(5) NOT NULL,
    status VARCHAR2(20) DEFAULT 'Available',
    admin_id NUMBER,
    CONSTRAINT fk_vehicle_admin FOREIGN KEY (admin_id) REFERENCES Admin(user_id) ON DELETE SET NULL
);

CREATE TABLE Route (
    route_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    origin VARCHAR2(100) NOT NULL,
    destination VARCHAR2(100) NOT NULL,
    distance NUMBER(8, 2) NOT NULL,
    est_du VARCHAR2(50)
);

CREATE TABLE Trip (
    trip_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    departure_time TIMESTAMP NOT NULL,
    arrival_time TIMESTAMP,
    fare NUMBER(10, 2) NOT NULL,
    status VARCHAR2(20) DEFAULT 'Scheduled',
    route_id NUMBER,
    vehicle_id NUMBER,
    driver_id NUMBER,
    passenger_id NUMBER,
    CONSTRAINT fk_trip_route FOREIGN KEY (route_id) REFERENCES Route(route_id) ON DELETE CASCADE,
    CONSTRAINT fk_trip_vehicle FOREIGN KEY (vehicle_id) REFERENCES Vehicle(vehicle_id) ON DELETE SET NULL,
    CONSTRAINT fk_trip_driver FOREIGN KEY (driver_id) REFERENCES Driver(user_id) ON DELETE SET NULL,
    CONSTRAINT fk_trip_passenger FOREIGN KEY (passenger_id) REFERENCES Passenger(user_id) ON DELETE SET NULL
);

CREATE TABLE Booking (
    booking_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    b_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    seat_no VARCHAR2(10),
    tot_am NUMBER(10, 2) NOT NULL,
    status VARCHAR2(20) DEFAULT 'Confirmed',
    passenger_id NUMBER,
    trip_id NUMBER,
    CONSTRAINT fk_booking_passenger FOREIGN KEY (passenger_id) REFERENCES Passenger(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_booking_trip FOREIGN KEY (trip_id) REFERENCES Trip(trip_id) ON DELETE CASCADE
);

CREATE TABLE Payment (
    payment_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    amount NUMBER(10, 2) NOT NULL,
    pay_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    pay_method VARCHAR2(50) NOT NULL,
    pay_status VARCHAR2(20) DEFAULT 'Pending',
    booking_id NUMBER,
    CONSTRAINT fk_payment_booking FOREIGN KEY (booking_id) REFERENCES Booking(booking_id) ON DELETE CASCADE
);

CREATE TABLE Feedback (
    feedback_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rating NUMBER(1) CHECK (rating BETWEEN 1 AND 5),
    comments CLOB,
    feedback_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    passenger_id NUMBER,
    trip_id NUMBER,
    CONSTRAINT fk_feedback_passenger FOREIGN KEY (passenger_id) REFERENCES Passenger(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_feedback_trip FOREIGN KEY (trip_id) REFERENCES Trip(trip_id) ON DELETE CASCADE
);

CREATE TABLE Maintenance (
    maintenance_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    maintenance_date DATE NOT NULL,
    description CLOB,
    cost NUMBER(10, 2) NOT NULL,
    status VARCHAR2(20) DEFAULT 'Pending',
    vehicle_id NUMBER,
    CONSTRAINT fk_maint_vehicle FOREIGN KEY (vehicle_id) REFERENCES Vehicle(vehicle_id) ON DELETE CASCADE
);
