-- Run this after schema.sql has already been applied to the SmartMove Oracle schema.
-- The MERGE statements make the sample rows safe to run more than once.

MERGE INTO Role target
USING (SELECT 'Passenger' role_name FROM dual UNION ALL
       SELECT 'Driver' FROM dual UNION ALL
       SELECT 'Admin' FROM dual)
source
ON (target.role_name = source.role_name)
WHEN NOT MATCHED THEN INSERT (role_name) VALUES (source.role_name);

MERGE INTO App_User target
USING (
    SELECT 'Ravi' f_name, 'Perera' l_name, 'ravi.demo@smartmove.local' email, '0770000101' phone,
           'REPLACE_WITH_A_VALID_PASSWORD_HASH' password FROM dual UNION ALL
    SELECT 'Nimali', 'Silva', 'nimali.demo@smartmove.local', '0770000102',
           'REPLACE_WITH_A_VALID_PASSWORD_HASH' FROM dual UNION ALL
    SELECT 'Kasun', 'Fernando', 'kasun.demo@smartmove.local', '0770000201',
           'REPLACE_WITH_A_VALID_PASSWORD_HASH' FROM dual UNION ALL
    SELECT 'Admin', 'Demo', 'admin.demo@smartmove.local', '0770000001',
           'REPLACE_WITH_A_VALID_PASSWORD_HASH' FROM dual
) source
ON (target.email = source.email)
WHEN NOT MATCHED THEN
    INSERT (f_name, l_name, email, phone, password)
    VALUES (source.f_name, source.l_name, source.email, source.phone, source.password);

INSERT INTO Passenger (user_id)
SELECT u.user_id FROM App_User u
WHERE u.email IN ('ravi.demo@smartmove.local', 'nimali.demo@smartmove.local')
  AND NOT EXISTS (SELECT 1 FROM Passenger p WHERE p.user_id = u.user_id);

INSERT INTO Driver (user_id, license, status)
SELECT u.user_id,
       CASE u.email WHEN 'kasun.demo@smartmove.local' THEN 'B1234567' ELSE 'B7654321' END,
       'Active'
FROM App_User u
WHERE u.email IN ('kasun.demo@smartmove.local', 'nimali.demo@smartmove.local')
  AND NOT EXISTS (SELECT 1 FROM Driver d WHERE d.user_id = u.user_id);

INSERT INTO Admin (user_id)
SELECT u.user_id FROM App_User u
WHERE u.email = 'admin.demo@smartmove.local'
  AND NOT EXISTS (SELECT 1 FROM Admin a WHERE a.user_id = u.user_id);

INSERT INTO User_Role (user_id, role_id)
SELECT u.user_id, r.role_id FROM App_User u CROSS JOIN Role r
WHERE (u.email IN ('ravi.demo@smartmove.local', 'nimali.demo@smartmove.local') AND r.role_name = 'Passenger'
    OR u.email IN ('kasun.demo@smartmove.local', 'nimali.demo@smartmove.local') AND r.role_name = 'Driver'
    OR u.email = 'admin.demo@smartmove.local' AND r.role_name = 'Admin')
  AND NOT EXISTS (
      SELECT 1 FROM User_Role ur WHERE ur.user_id = u.user_id AND ur.role_id = r.role_id
  );

INSERT INTO Vehicle (reg_no, vehicle_type, capacity, status, admin_id)
SELECT 'ND-4521', 'Bus', 40, 'Available', a.user_id
FROM Admin a
WHERE NOT EXISTS (SELECT 1 FROM Vehicle v WHERE v.reg_no = 'ND-4521');

INSERT INTO Vehicle (reg_no, vehicle_type, capacity, status, admin_id)
SELECT 'WP-6720', 'Van', 12, 'Available', a.user_id
FROM Admin a
WHERE NOT EXISTS (SELECT 1 FROM Vehicle v WHERE v.reg_no = 'WP-6720');

INSERT INTO Route (origin, destination, distance, est_du)
SELECT 'Colombo', 'Kandy', 115, '3 hours 30 minutes' FROM dual
WHERE NOT EXISTS (SELECT 1 FROM Route WHERE origin = 'Colombo' AND destination = 'Kandy');

INSERT INTO Route (origin, destination, distance, est_du)
SELECT 'Galle', 'Colombo', 125, '2 hours 30 minutes' FROM dual
WHERE NOT EXISTS (SELECT 1 FROM Route WHERE origin = 'Galle' AND destination = 'Colombo');

INSERT INTO Route (origin, destination, distance, est_du)
SELECT 'Matara', 'Colombo', 160, '3 hours' FROM dual
WHERE NOT EXISTS (SELECT 1 FROM Route WHERE origin = 'Matara' AND destination = 'Colombo');

INSERT INTO Trip (departure_time, arrival_time, fare, status, route_id, vehicle_id, driver_id)
SELECT TIMESTAMP '2027-01-15 08:00:00', TIMESTAMP '2027-01-15 11:30:00', 1500, 'Scheduled',
       r.route_id, v.vehicle_id, d.user_id
FROM Route r, Vehicle v, Driver d, App_User u
WHERE r.origin = 'Colombo' AND r.destination = 'Kandy'
  AND v.reg_no = 'ND-4521' AND d.user_id = u.user_id AND u.email = 'kasun.demo@smartmove.local'
  AND NOT EXISTS (
      SELECT 1 FROM Trip t WHERE t.route_id = r.route_id AND t.departure_time = TIMESTAMP '2027-01-15 08:00:00'
  );

INSERT INTO Trip (departure_time, arrival_time, fare, status, route_id, vehicle_id, driver_id)
SELECT TIMESTAMP '2027-01-15 09:00:00', TIMESTAMP '2027-01-15 11:30:00', 1200, 'Scheduled',
       r.route_id, v.vehicle_id, d.user_id
FROM Route r, Vehicle v, Driver d, App_User u
WHERE r.origin = 'Galle' AND r.destination = 'Colombo'
  AND v.reg_no = 'WP-6720' AND d.user_id = u.user_id AND u.email = 'kasun.demo@smartmove.local'
  AND NOT EXISTS (
      SELECT 1 FROM Trip t WHERE t.route_id = r.route_id AND t.departure_time = TIMESTAMP '2027-01-15 09:00:00'
  );

INSERT INTO Booking (seat_no, tot_am, status, passenger_id, trip_id)
SELECT 'A1', 1500, 'Confirmed', p.user_id, t.trip_id
FROM Passenger p, App_User u, Trip t, Route r
WHERE p.user_id = u.user_id AND u.email = 'ravi.demo@smartmove.local'
  AND t.route_id = r.route_id AND r.origin = 'Colombo' AND r.destination = 'Kandy'
  AND NOT EXISTS (SELECT 1 FROM Booking b WHERE b.passenger_id = p.user_id AND b.trip_id = t.trip_id);

INSERT INTO Booking (seat_no, tot_am, status, passenger_id, trip_id)
SELECT 'A2', 1500, 'Confirmed', p.user_id, t.trip_id
FROM Passenger p, App_User u, Trip t, Route r
WHERE p.user_id = u.user_id AND u.email = 'nimali.demo@smartmove.local'
  AND t.route_id = r.route_id AND r.origin = 'Colombo' AND r.destination = 'Kandy'
  AND NOT EXISTS (SELECT 1 FROM Booking b WHERE b.passenger_id = p.user_id AND b.trip_id = t.trip_id);

INSERT INTO Payment (amount, pay_method, pay_status, booking_id)
SELECT b.tot_am, 'Card', 'Paid', b.booking_id FROM Booking b
WHERE b.seat_no IN ('A1', 'A2')
  AND NOT EXISTS (SELECT 1 FROM Payment p WHERE p.booking_id = b.booking_id);

INSERT INTO Maintenance (maintenance_date, description, cost, status, vehicle_id)
SELECT DATE '2026-09-01', 'Scheduled engine inspection', 12500, 'Pending', v.vehicle_id
FROM Vehicle v
WHERE v.reg_no = 'ND-4521'
  AND NOT EXISTS (SELECT 1 FROM Maintenance m WHERE m.vehicle_id = v.vehicle_id
                  AND m.description = 'Scheduled engine inspection');

INSERT INTO Feedback (rating, comments, passenger_id, trip_id)
SELECT 5, 'Punctual departure and a comfortable journey.', p.user_id, t.trip_id
FROM Passenger p, App_User u, Trip t, Route r
WHERE p.user_id = u.user_id AND u.email = 'ravi.demo@smartmove.local'
  AND t.route_id = r.route_id AND r.origin = 'Colombo' AND r.destination = 'Kandy'
  AND NOT EXISTS (SELECT 1 FROM Feedback f WHERE f.passenger_id = p.user_id AND f.trip_id = t.trip_id);

COMMIT;
