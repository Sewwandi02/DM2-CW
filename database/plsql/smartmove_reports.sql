CREATE OR REPLACE PACKAGE smartmove_reports AS
    PROCEDURE frequent_routes(p_result OUT SYS_REFCURSOR);
    PROCEDURE revenue_by_period(
        p_from IN DATE,
        p_to IN DATE,
        p_result OUT SYS_REFCURSOR
    );
    PROCEDURE passenger_travel_history(
        p_passenger_id IN NUMBER,
        p_result OUT SYS_REFCURSOR
    );
    PROCEDURE maintenance_summary(p_result OUT SYS_REFCURSOR);
    FUNCTION total_revenue(p_from IN DATE, p_to IN DATE) RETURN NUMBER;
END smartmove_reports;
/

CREATE OR REPLACE PACKAGE BODY smartmove_reports AS
    PROCEDURE validate_date_range(p_from IN DATE, p_to IN DATE) IS
    BEGIN
        IF p_from IS NULL OR p_to IS NULL THEN
            RAISE_APPLICATION_ERROR(-20010, 'Both start and end dates are required');
        ELSIF TRUNC(p_to) < TRUNC(p_from) THEN
            RAISE_APPLICATION_ERROR(-20011, 'End date must be on or after start date');
        END IF;
    END validate_date_range;

    PROCEDURE frequent_routes(p_result OUT SYS_REFCURSOR) IS
    BEGIN
        OPEN p_result FOR
            SELECT r.route_id, r.origin, r.destination, COUNT(b.booking_id) AS booking_count
            FROM Route r
            JOIN Trip t ON t.route_id = r.route_id
            JOIN Booking b ON b.trip_id = t.trip_id
            GROUP BY r.route_id, r.origin, r.destination
            ORDER BY booking_count DESC, r.route_id;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE BETWEEN -20099 AND -20000 THEN
                RAISE;
            END IF;
            RAISE_APPLICATION_ERROR(-20001,
                'Unable to generate frequent-routes report (Oracle ' || SQLCODE || '): ' || SQLERRM,
                TRUE);
    END frequent_routes;

    PROCEDURE revenue_by_period(
        p_from IN DATE,
        p_to IN DATE,
        p_result OUT SYS_REFCURSOR
    ) IS
    BEGIN
        validate_date_range(p_from, p_to);

        OPEN p_result FOR
            SELECT TRUNC(pay_date) AS revenue_date, SUM(amount) AS total_revenue
            FROM Payment
            WHERE pay_status = 'Paid'
              AND pay_date >= TRUNC(p_from)
              AND pay_date < TRUNC(p_to) + 1
            GROUP BY TRUNC(pay_date)
            ORDER BY revenue_date;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE BETWEEN -20099 AND -20000 THEN
                RAISE;
            END IF;
            RAISE_APPLICATION_ERROR(-20012,
                'Unable to generate revenue-by-period report (Oracle ' || SQLCODE || '): ' || SQLERRM,
                TRUE);
    END revenue_by_period;

    PROCEDURE passenger_travel_history(
        p_passenger_id IN NUMBER,
        p_result OUT SYS_REFCURSOR
    ) IS
        l_passenger_id Passenger.user_id%TYPE;
    BEGIN
        IF p_passenger_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20004, 'Passenger ID is required');
        END IF;

        BEGIN
            SELECT user_id
            INTO l_passenger_id
            FROM Passenger
            WHERE user_id = p_passenger_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20005, 'Passenger does not exist');
            WHEN TOO_MANY_ROWS THEN
                RAISE_APPLICATION_ERROR(-20006, 'Passenger identifier is not unique');
        END;

        OPEN p_result FOR
            SELECT b.booking_id, b.b_date, b.seat_no, b.tot_am, b.status AS booking_status,
                   t.trip_id, t.departure_time, t.arrival_time, t.status AS trip_status,
                   r.origin, r.destination
            FROM Booking b
            JOIN Trip t ON t.trip_id = b.trip_id
            JOIN Route r ON r.route_id = t.route_id
            WHERE b.passenger_id = l_passenger_id
            ORDER BY b.b_date DESC, b.booking_id DESC;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE BETWEEN -20099 AND -20000 THEN
                RAISE;
            END IF;
            RAISE_APPLICATION_ERROR(-20013,
                'Unable to generate passenger-history report (Oracle ' || SQLCODE || '): ' || SQLERRM,
                TRUE);
    END passenger_travel_history;

    PROCEDURE maintenance_summary(p_result OUT SYS_REFCURSOR) IS
    BEGIN
        OPEN p_result FOR
            SELECT v.vehicle_id,
                   v.reg_no,
                   v.vehicle_type,
                   COUNT(m.maintenance_id) AS maintenance_count,
                   NVL(SUM(m.cost), 0) AS total_maintenance_cost,
                   SUM(CASE WHEN UPPER(m.status) = 'PENDING' THEN 1 ELSE 0 END) AS pending_count,
                   MAX(m.maintenance_date) AS last_maintenance_date
            FROM Vehicle v
            LEFT JOIN Maintenance m ON m.vehicle_id = v.vehicle_id
            GROUP BY v.vehicle_id, v.reg_no, v.vehicle_type
            ORDER BY total_maintenance_cost DESC, v.vehicle_id;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE BETWEEN -20099 AND -20000 THEN
                RAISE;
            END IF;
            RAISE_APPLICATION_ERROR(-20014,
                'Unable to generate vehicle-maintenance summary (Oracle ' || SQLCODE || '): ' || SQLERRM,
                TRUE);
    END maintenance_summary;

    FUNCTION total_revenue(p_from IN DATE, p_to IN DATE) RETURN NUMBER IS
        l_total NUMBER(12, 2);
    BEGIN
        validate_date_range(p_from, p_to);

        SELECT NVL(SUM(amount), 0)
        INTO l_total
        FROM Payment
        WHERE pay_status = 'Paid'
          AND pay_date >= TRUNC(p_from)
          AND pay_date < TRUNC(p_to) + 1;

        RETURN l_total;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE BETWEEN -20099 AND -20000 THEN
                RAISE;
            END IF;
            RAISE_APPLICATION_ERROR(-20015,
                'Unable to calculate total revenue (Oracle ' || SQLCODE || '): ' || SQLERRM,
                TRUE);
    END total_revenue;
END smartmove_reports;
/
