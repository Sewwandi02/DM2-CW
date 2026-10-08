CREATE OR REPLACE PACKAGE smartmove_api AS
    PROCEDURE list_records(
        p_resource IN VARCHAR2,
        p_result OUT SYS_REFCURSOR
    );
    PROCEDURE create_record(
        p_resource IN VARCHAR2,
        p_data IN CLOB,
        p_generated_id OUT NUMBER
    );
    PROCEDURE create_passenger_or_driver(
        p_is_driver IN NUMBER,
        p_data IN CLOB,
        p_user_id OUT NUMBER
    );
    PROCEDURE admin_password_hash(
        p_email IN VARCHAR2,
        p_password_hash OUT VARCHAR2
    );
    PROCEDURE update_record(
        p_resource IN VARCHAR2,
        p_id IN NUMBER,
        p_data IN CLOB
    );
    PROCEDURE delete_record(
        p_resource IN VARCHAR2,
        p_id IN NUMBER,
        p_secondary_id IN NUMBER DEFAULT NULL
    );
    PROCEDURE dashboard(p_result OUT SYS_REFCURSOR);
END smartmove_api;
/

CREATE OR REPLACE PACKAGE BODY smartmove_api AS
    FUNCTION table_for(p_resource IN VARCHAR2) RETURN VARCHAR2 IS
        l_resource VARCHAR2(40) := LOWER(TRIM(p_resource));
    BEGIN
        RETURN CASE l_resource
            WHEN 'roles' THEN 'ROLE'
            WHEN 'user-roles' THEN 'USER_ROLE'
            WHEN 'app-users' THEN 'APP_USER'
            WHEN 'passengers' THEN 'PASSENGER'
            WHEN 'drivers' THEN 'DRIVER'
            WHEN 'admins' THEN 'ADMIN'
            WHEN 'vehicles' THEN 'VEHICLE'
            WHEN 'routes' THEN 'ROUTE'
            WHEN 'trips' THEN 'TRIP'
            WHEN 'bookings' THEN 'BOOKING'
            WHEN 'payments' THEN 'PAYMENT'
            WHEN 'feedback' THEN 'FEEDBACK'
            WHEN 'maintenance' THEN 'MAINTENANCE'
            ELSE NULL
        END;
    END table_for;

    FUNCTION id_for(p_resource IN VARCHAR2) RETURN VARCHAR2 IS
        l_resource VARCHAR2(40) := LOWER(TRIM(p_resource));
    BEGIN
        RETURN CASE l_resource
            WHEN 'roles' THEN 'ROLE_ID'
            WHEN 'user-roles' THEN 'USER_ID'
            WHEN 'app-users' THEN 'USER_ID'
            WHEN 'passengers' THEN 'USER_ID'
            WHEN 'drivers' THEN 'USER_ID'
            WHEN 'admins' THEN 'USER_ID'
            WHEN 'vehicles' THEN 'VEHICLE_ID'
            WHEN 'routes' THEN 'ROUTE_ID'
            WHEN 'trips' THEN 'TRIP_ID'
            WHEN 'bookings' THEN 'BOOKING_ID'
            WHEN 'payments' THEN 'PAYMENT_ID'
            WHEN 'feedback' THEN 'FEEDBACK_ID'
            WHEN 'maintenance' THEN 'MAINTENANCE_ID'
            ELSE NULL
        END;
    END id_for;

    FUNCTION field_allowed(
        p_resource IN VARCHAR2,
        p_field IN VARCHAR2,
        p_for_update IN BOOLEAN DEFAULT FALSE
    ) RETURN BOOLEAN IS
        l_resource VARCHAR2(40) := LOWER(TRIM(p_resource));
        l_field VARCHAR2(40) := LOWER(TRIM(p_field));
    BEGIN
        IF p_for_update AND l_field = LOWER(id_for(l_resource)) THEN
            RETURN FALSE;
        END IF;

        CASE l_resource
            WHEN 'roles' THEN RETURN l_field IN ('role_name');
            WHEN 'user-roles' THEN RETURN l_field IN ('user_id', 'role_id') AND NOT p_for_update;
            WHEN 'app-users' THEN RETURN l_field IN ('f_name', 'l_name', 'email', 'phone', 'password');
            WHEN 'passengers' THEN RETURN l_field IN ('user_id');
            WHEN 'drivers' THEN RETURN l_field IN ('user_id', 'license', 'status');
            WHEN 'admins' THEN RETURN l_field IN ('user_id');
            WHEN 'vehicles' THEN RETURN l_field IN ('reg_no', 'vehicle_type', 'capacity', 'status', 'admin_id');
            WHEN 'routes' THEN RETURN l_field IN ('origin', 'destination', 'distance', 'est_du');
            WHEN 'trips' THEN RETURN l_field IN (
                'departure_time', 'arrival_time', 'fare', 'status', 'route_id',
                'vehicle_id', 'driver_id', 'passenger_id');
            WHEN 'bookings' THEN RETURN l_field IN (
                'b_date', 'seat_no', 'tot_am', 'status', 'passenger_id', 'trip_id');
            WHEN 'payments' THEN RETURN l_field IN (
                'amount', 'pay_date', 'pay_method', 'pay_status', 'booking_id');
            WHEN 'feedback' THEN RETURN l_field IN (
                'rating', 'comments', 'feedback_date', 'passenger_id', 'trip_id');
            WHEN 'maintenance' THEN RETURN l_field IN (
                'maintenance_date', 'description', 'cost', 'status', 'vehicle_id');
            ELSE RETURN FALSE;
        END CASE;
    END field_allowed;

    FUNCTION bind_expression(p_field IN VARCHAR2) RETURN VARCHAR2 IS
        l_field VARCHAR2(40) := LOWER(p_field);
    BEGIN
        IF l_field IN ('departure_time', 'arrival_time', 'b_date', 'pay_date', 'feedback_date') THEN
            RETURN 'TO_TIMESTAMP(:b%d, ''YYYY-MM-DD"T"HH24:MI:SS'')';
        ELSIF l_field = 'maintenance_date' THEN
            RETURN 'TO_DATE(:b%d, ''YYYY-MM-DD'')';
        ELSIF l_field IN (
            'distance', 'capacity', 'admin_id', 'fare', 'route_id',
            'vehicle_id', 'driver_id', 'passenger_id', 'tot_am',
            'booking_id', 'rating', 'cost', 'user_id', 'role_id') THEN
            RETURN 'TO_NUMBER(:b%d, ''S99999999999999999999999999999999999999D99999999999999999999'', ''NLS_NUMERIC_CHARACTERS=''''.,'''''')';
        ELSIF l_field IN ('comments', 'description') THEN
            RETURN 'TO_CLOB(:b%d)';
        ELSE
            RETURN ':b%d';
        END IF;
    END bind_expression;

    FUNCTION scalar_text(
        p_object IN JSON_OBJECT_T,
        p_key IN VARCHAR2
    ) RETURN VARCHAR2 IS
        l_element JSON_ELEMENT_T;
    BEGIN
        l_element := p_object.GET(p_key);
        IF l_element IS NULL OR l_element.IS_NULL THEN
            RETURN NULL;
        ELSIF l_element.IS_STRING THEN
            RETURN l_element.GET_STRING;
        ELSIF l_element.IS_NUMBER THEN
            RETURN TO_CHAR(
                l_element.TO_NUMBER,
                'TM9',
                'NLS_NUMERIC_CHARACTERS=''.,''');
        ELSIF l_element.IS_BOOLEAN THEN
            RETURN CASE WHEN l_element.GET_BOOLEAN THEN 'true' ELSE 'false' END;
        END IF;
        RAISE_APPLICATION_ERROR(-20115, p_key || ' must be a scalar JSON value');
    END scalar_text;

    PROCEDURE assert_resource(p_resource IN VARCHAR2) IS
    BEGIN
        IF table_for(p_resource) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20100, 'Unsupported Oracle resource');
        END IF;
    END assert_resource;

    PROCEDURE list_records(
        p_resource IN VARCHAR2,
        p_result OUT SYS_REFCURSOR
    ) IS
        l_table VARCHAR2(30);
        l_id VARCHAR2(30);
        l_columns VARCHAR2(1000);
    BEGIN
        assert_resource(p_resource);
        l_table := table_for(p_resource);
        l_id := id_for(p_resource);
        l_columns := CASE WHEN l_table = 'APP_USER'
            THEN 'USER_ID, F_NAME, L_NAME, EMAIL, PHONE, CREATED_AT'
            ELSE '*'
        END;
        OPEN p_result FOR
            'SELECT ' || l_columns || ' FROM ' || l_table || ' ORDER BY ' || l_id;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE BETWEEN -20199 AND -20100 THEN RAISE; END IF;
            RAISE_APPLICATION_ERROR(-20101,
                'Unable to list ' || p_resource || ' (Oracle ' || SQLCODE || '): ' || SQLERRM,
                TRUE);
    END list_records;

    PROCEDURE create_record(
        p_resource IN VARCHAR2,
        p_data IN CLOB,
        p_generated_id OUT NUMBER
    ) IS
        l_resource VARCHAR2(40) := LOWER(TRIM(p_resource));
        l_table VARCHAR2(30);
        l_id_column VARCHAR2(30);
        l_keys JSON_KEY_LIST;
        l_object JSON_OBJECT_T;
        l_column_list VARCHAR2(4000);
        l_value_list VARCHAR2(8000);
        l_sql VARCHAR2(12000);
        l_cursor INTEGER;
        l_rows INTEGER;
        l_field VARCHAR2(128);
        l_value VARCHAR2(32767);
        l_generated_id NUMBER;
        l_bind_index PLS_INTEGER := 0;
        l_has_identity BOOLEAN;
    BEGIN
        assert_resource(l_resource);
        l_table := table_for(l_resource);
        l_id_column := id_for(l_resource);
        l_object := JSON_OBJECT_T.PARSE(p_data);
        l_keys := l_object.GET_KEYS;
        l_column_list := '';
        l_value_list := '';
        p_generated_id := NULL;

        FOR i IN 1 .. l_keys.COUNT LOOP
            l_field := LOWER(l_keys(i));
            IF NOT field_allowed(l_resource, l_field) THEN
                RAISE_APPLICATION_ERROR(-20102, 'Unsupported field ' || l_field || ' for ' || l_resource);
            END IF;
            IF l_field = LOWER(l_id_column)
               AND l_resource NOT IN ('user-roles', 'passengers', 'drivers', 'admins') THEN
                CONTINUE;
            END IF;
            l_bind_index := l_bind_index + 1;
            l_column_list := l_column_list
                || CASE WHEN l_column_list IS NULL THEN '' ELSE ', ' END
                || UPPER(l_field);
            l_value_list := l_value_list
                || CASE WHEN l_value_list IS NULL THEN '' ELSE ', ' END
                || REPLACE(bind_expression(l_field), '%d', TO_CHAR(l_bind_index));
        END LOOP;

        IF l_bind_index = 0 THEN
            RAISE_APPLICATION_ERROR(-20103, 'At least one editable field is required');
        END IF;

        l_has_identity := l_resource NOT IN ('user-roles', 'passengers', 'drivers', 'admins');
        l_sql := 'INSERT INTO ' || l_table || ' (' || l_column_list || ') VALUES ('
            || l_value_list || ')';
        IF l_has_identity THEN
            l_sql := l_sql || ' RETURNING ' || l_id_column || ' INTO :generated_id';
        END IF;

        l_cursor := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(l_cursor, l_sql, DBMS_SQL.NATIVE);
        l_bind_index := 0;
        FOR i IN 1 .. l_keys.COUNT LOOP
            l_field := LOWER(l_keys(i));
            IF NOT field_allowed(l_resource, l_field)
               OR (l_field = LOWER(l_id_column)
                   AND l_resource NOT IN ('user-roles', 'passengers', 'drivers', 'admins')) THEN
                CONTINUE;
            END IF;
            l_bind_index := l_bind_index + 1;
            l_value := scalar_text(l_object, l_keys(i));
            DBMS_SQL.BIND_VARIABLE(l_cursor, ':b' || l_bind_index, l_value);
        END LOOP;
        IF l_has_identity THEN
            DBMS_SQL.BIND_VARIABLE(l_cursor, ':generated_id', l_generated_id);
        END IF;
        l_rows := DBMS_SQL.EXECUTE(l_cursor);
        IF l_has_identity THEN
            DBMS_SQL.VARIABLE_VALUE(l_cursor, ':generated_id', l_generated_id);
            p_generated_id := l_generated_id;
        END IF;
        DBMS_SQL.CLOSE_CURSOR(l_cursor);
    EXCEPTION
        WHEN OTHERS THEN
            IF l_cursor IS NOT NULL AND DBMS_SQL.IS_OPEN(l_cursor) THEN
                DBMS_SQL.CLOSE_CURSOR(l_cursor);
            END IF;
            IF SQLCODE BETWEEN -20199 AND -20100 THEN RAISE; END IF;
            RAISE_APPLICATION_ERROR(-20104,
                'Unable to create ' || p_resource || ' (Oracle ' || SQLCODE || '): ' || SQLERRM,
                TRUE);
    END create_record;

    PROCEDURE create_passenger_or_driver(
        p_is_driver IN NUMBER,
        p_data IN CLOB,
        p_user_id OUT NUMBER
    ) IS
        l_object JSON_OBJECT_T;
        l_first_name VARCHAR2(50);
        l_last_name VARCHAR2(50);
        l_email VARCHAR2(100);
        l_phone VARCHAR2(20);
        l_password VARCHAR2(255);
        l_license VARCHAR2(50);
        l_status VARCHAR2(20);
        l_role_id NUMBER;
    BEGIN
        IF p_is_driver NOT IN (0, 1) THEN
            RAISE_APPLICATION_ERROR(-20105, 'Account type must be passenger or driver');
        END IF;
        l_object := JSON_OBJECT_T.PARSE(p_data);
        l_first_name := TRIM(scalar_text(l_object, 'f_name'));
        l_last_name := TRIM(scalar_text(l_object, 'l_name'));
        l_email := TRIM(scalar_text(l_object, 'email'));
        l_phone := TRIM(scalar_text(l_object, 'phone'));
        l_password := scalar_text(l_object, 'password');
        l_license := TRIM(scalar_text(l_object, 'license'));
        l_status := NVL(TRIM(scalar_text(l_object, 'status')), 'Active');
        IF l_first_name IS NULL OR l_last_name IS NULL OR l_email IS NULL OR l_password IS NULL THEN
            RAISE_APPLICATION_ERROR(-20106, 'Name, email, and password are required');
        END IF;
        IF p_is_driver = 1 AND l_license IS NULL THEN
            RAISE_APPLICATION_ERROR(-20107, 'Driver license is required');
        END IF;

        INSERT INTO App_User (f_name, l_name, email, phone, password)
        VALUES (l_first_name, l_last_name, l_email, l_phone, l_password)
        RETURNING user_id INTO p_user_id;

        IF p_is_driver = 1 THEN
            INSERT INTO Driver (user_id, license, status)
            VALUES (p_user_id, l_license, l_status);
        ELSE
            INSERT INTO Passenger (user_id) VALUES (p_user_id);
        END IF;

        BEGIN
            SELECT role_id INTO l_role_id
            FROM Role
            WHERE UPPER(role_name) = CASE WHEN p_is_driver = 1 THEN 'DRIVER' ELSE 'PASSENGER' END
            ORDER BY role_id
            FETCH FIRST 1 ROW ONLY;
            INSERT INTO User_Role (user_id, role_id) VALUES (p_user_id, l_role_id);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN NULL;
        END;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE BETWEEN -20199 AND -20100 THEN RAISE; END IF;
            RAISE_APPLICATION_ERROR(-20108,
                'Unable to create passenger/driver account (Oracle ' || SQLCODE || '): ' || SQLERRM,
                TRUE);
    END create_passenger_or_driver;

    PROCEDURE admin_password_hash(
        p_email IN VARCHAR2,
        p_password_hash OUT VARCHAR2
    ) IS
    BEGIN
        SELECT app_user.password
        INTO p_password_hash
        FROM App_User app_user
        JOIN Admin admin_user ON admin_user.user_id = app_user.user_id
        WHERE LOWER(app_user.email) = LOWER(TRIM(p_email));
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_password_hash := NULL;
        WHEN TOO_MANY_ROWS THEN
            p_password_hash := NULL;
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20116,
                'Unable to validate administrator credentials (Oracle '
                || SQLCODE || '): ' || SQLERRM,
                TRUE);
    END admin_password_hash;

    PROCEDURE update_record(
        p_resource IN VARCHAR2,
        p_id IN NUMBER,
        p_data IN CLOB
    ) IS
        l_resource VARCHAR2(40) := LOWER(TRIM(p_resource));
        l_table VARCHAR2(30);
        l_id_column VARCHAR2(30);
        l_keys JSON_KEY_LIST;
        l_object JSON_OBJECT_T;
        l_assignments VARCHAR2(8000);
        l_sql VARCHAR2(12000);
        l_cursor INTEGER;
        l_rows INTEGER;
        l_field VARCHAR2(128);
        l_value VARCHAR2(32767);
        l_bind_index PLS_INTEGER := 0;
    BEGIN
        assert_resource(l_resource);
        IF l_resource = 'user-roles' THEN
            RAISE_APPLICATION_ERROR(-20109, 'User-role links are keyed by user_id and role_id');
        END IF;
        l_table := table_for(l_resource);
        l_id_column := id_for(l_resource);
        l_object := JSON_OBJECT_T.PARSE(p_data);
        l_keys := l_object.GET_KEYS;
        l_assignments := '';
        FOR i IN 1 .. l_keys.COUNT LOOP
            l_field := LOWER(l_keys(i));
            IF NOT field_allowed(l_resource, l_field, TRUE) THEN
                RAISE_APPLICATION_ERROR(-20102, 'Unsupported field ' || l_field || ' for update');
            END IF;
            l_bind_index := l_bind_index + 1;
            l_assignments := l_assignments
                || CASE WHEN l_assignments IS NULL THEN '' ELSE ', ' END
                || UPPER(l_field) || ' = '
                || REPLACE(bind_expression(l_field), '%d', TO_CHAR(l_bind_index));
        END LOOP;
        IF l_bind_index = 0 THEN
            RAISE_APPLICATION_ERROR(-20103, 'At least one editable field is required');
        END IF;
        l_sql := 'UPDATE ' || l_table || ' SET ' || l_assignments
            || ' WHERE ' || l_id_column || ' = :record_id';
        l_cursor := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(l_cursor, l_sql, DBMS_SQL.NATIVE);
        l_bind_index := 0;
        FOR i IN 1 .. l_keys.COUNT LOOP
            l_field := LOWER(l_keys(i));
            l_bind_index := l_bind_index + 1;
            l_value := scalar_text(l_object, l_keys(i));
            DBMS_SQL.BIND_VARIABLE(l_cursor, ':b' || l_bind_index, l_value);
        END LOOP;
        DBMS_SQL.BIND_VARIABLE(l_cursor, ':record_id', p_id);
        l_rows := DBMS_SQL.EXECUTE(l_cursor);
        DBMS_SQL.CLOSE_CURSOR(l_cursor);
        IF l_rows = 0 THEN
            RAISE_APPLICATION_ERROR(-20110, 'Record not found');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            IF l_cursor IS NOT NULL AND DBMS_SQL.IS_OPEN(l_cursor) THEN
                DBMS_SQL.CLOSE_CURSOR(l_cursor);
            END IF;
            IF SQLCODE BETWEEN -20199 AND -20100 THEN RAISE; END IF;
            RAISE_APPLICATION_ERROR(-20111,
                'Unable to update ' || p_resource || ' (Oracle ' || SQLCODE || '): ' || SQLERRM,
                TRUE);
    END update_record;

    PROCEDURE delete_record(
        p_resource IN VARCHAR2,
        p_id IN NUMBER,
        p_secondary_id IN NUMBER DEFAULT NULL
    ) IS
        l_resource VARCHAR2(40) := LOWER(TRIM(p_resource));
        l_table VARCHAR2(30);
        l_id_column VARCHAR2(30);
        l_sql VARCHAR2(1000);
        l_rows PLS_INTEGER;
    BEGIN
        assert_resource(l_resource);
        l_table := table_for(l_resource);
        l_id_column := id_for(l_resource);
        IF l_resource = 'user-roles' THEN
            IF p_secondary_id IS NULL THEN
                RAISE_APPLICATION_ERROR(-20112, 'role_id is required to delete a user-role link');
            END IF;
            l_sql := 'DELETE FROM USER_ROLE WHERE USER_ID = :1 AND ROLE_ID = :2';
            EXECUTE IMMEDIATE l_sql USING p_id, p_secondary_id;
        ELSE
            l_sql := 'DELETE FROM ' || l_table || ' WHERE ' || l_id_column || ' = :1';
            EXECUTE IMMEDIATE l_sql USING p_id;
        END IF;
        l_rows := SQL%ROWCOUNT;
        IF l_rows = 0 THEN
            RAISE_APPLICATION_ERROR(-20110, 'Record not found');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE BETWEEN -20199 AND -20100 THEN RAISE; END IF;
            RAISE_APPLICATION_ERROR(-20113,
                'Unable to delete ' || p_resource || ' (Oracle ' || SQLCODE || '): ' || SQLERRM,
                TRUE);
    END delete_record;

    PROCEDURE dashboard(p_result OUT SYS_REFCURSOR) IS
    BEGIN
        OPEN p_result FOR
            SELECT
                (SELECT COUNT(*) FROM Route) AS routes,
                (SELECT COUNT(*) FROM Vehicle) AS vehicles,
                (SELECT COUNT(*) FROM Driver) AS drivers,
                (SELECT COUNT(*) FROM Passenger) AS passengers,
                (SELECT COUNT(*) FROM Trip) AS trips,
                (SELECT COUNT(*) FROM Booking) AS bookings,
                (SELECT NVL(SUM(amount), 0) FROM Payment WHERE pay_status = 'Paid') AS revenue
            FROM DUAL;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20114,
                'Unable to load dashboard (Oracle ' || SQLCODE || '): ' || SQLERRM,
                TRUE);
    END dashboard;
END smartmove_api;
/
