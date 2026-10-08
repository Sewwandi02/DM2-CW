-- Run as a DBA after installing both SMART_MOVE PL/SQL packages.
-- This grants package execution only; it does not grant direct table access.
WHENEVER SQLERROR EXIT SQL.SQLCODE

ACCEPT smartmove_api_user CHAR PROMPT 'Existing dedicated backend Oracle username: '

DECLARE
    l_user VARCHAR2(128) := UPPER(TRIM('&smartmove_api_user'));
    l_count PLS_INTEGER;
BEGIN
    IF NOT REGEXP_LIKE(l_user, '^[A-Z][A-Z0-9_$#]{0,127}$') THEN
        RAISE_APPLICATION_ERROR(-20001, 'Enter a valid unquoted Oracle username');
    END IF;

    SELECT COUNT(*) INTO l_count FROM DBA_USERS WHERE USERNAME = l_user;
    IF l_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'The dedicated backend account does not exist');
    END IF;

    SELECT COUNT(*) INTO l_count FROM DBA_ROLES WHERE ROLE = 'SMARTMOVE_API_ROLE';
    IF l_count = 0 THEN
        EXECUTE IMMEDIATE 'CREATE ROLE SMARTMOVE_API_ROLE';
    END IF;

    FOR table_grant IN (
        SELECT TABLE_NAME, PRIVILEGE
        FROM DBA_TAB_PRIVS
        WHERE OWNER = 'SMART_MOVE'
          AND GRANTEE = 'SMARTMOVE_API_ROLE'
          AND PRIVILEGE IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
    ) LOOP
        EXECUTE IMMEDIATE
            'REVOKE ' || table_grant.PRIVILEGE
            || ' ON SMART_MOVE.' || DBMS_ASSERT.SIMPLE_SQL_NAME(table_grant.TABLE_NAME)
            || ' FROM SMARTMOVE_API_ROLE';
    END LOOP;

    FOR column_grant IN (
        SELECT TABLE_NAME, COLUMN_NAME, PRIVILEGE
        FROM DBA_COL_PRIVS
        WHERE OWNER = 'SMART_MOVE'
          AND GRANTEE = 'SMARTMOVE_API_ROLE'
          AND PRIVILEGE IN ('INSERT', 'UPDATE')
    ) LOOP
        EXECUTE IMMEDIATE
            'REVOKE ' || column_grant.PRIVILEGE
            || ' (' || DBMS_ASSERT.SIMPLE_SQL_NAME(column_grant.COLUMN_NAME) || ')'
            || ' ON SMART_MOVE.' || DBMS_ASSERT.SIMPLE_SQL_NAME(column_grant.TABLE_NAME)
            || ' FROM SMARTMOVE_API_ROLE';
    END LOOP;

    EXECUTE IMMEDIATE
        'GRANT EXECUTE ON SMART_MOVE.SMARTMOVE_API TO SMARTMOVE_API_ROLE';
    EXECUTE IMMEDIATE
        'GRANT EXECUTE ON SMART_MOVE.SMARTMOVE_REPORTS TO SMARTMOVE_API_ROLE';
    EXECUTE IMMEDIATE
        'GRANT SMARTMOVE_API_ROLE TO ' || DBMS_ASSERT.SIMPLE_SQL_NAME(l_user);
    EXECUTE IMMEDIATE
        'ALTER USER ' || DBMS_ASSERT.SIMPLE_SQL_NAME(l_user)
        || ' DEFAULT ROLE SMARTMOVE_API_ROLE';
END;
/

UNDEFINE smartmove_api_user
PROMPT Least-privilege PL/SQL package grants completed.
