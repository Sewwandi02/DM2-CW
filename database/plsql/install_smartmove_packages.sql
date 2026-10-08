-- Run while connected as the SMART_MOVE schema owner.
-- Installs stored code only; it does not change the supplied table schema.
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET DEFINE OFF
SET SERVEROUTPUT ON

@@smartmove_api.sql
@@smartmove_reports.sql

DECLARE
    l_error_count PLS_INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO l_error_count
    FROM USER_ERRORS
    WHERE NAME IN ('SMARTMOVE_API', 'SMARTMOVE_REPORTS')
      AND ATTRIBUTE = 'ERROR';

    IF l_error_count > 0 THEN
        FOR error_row IN (
            SELECT NAME, TYPE, LINE, POSITION, TEXT
            FROM USER_ERRORS
            WHERE NAME IN ('SMARTMOVE_API', 'SMARTMOVE_REPORTS')
              AND ATTRIBUTE = 'ERROR'
            ORDER BY NAME, TYPE, SEQUENCE
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(
                error_row.NAME || ' ' || error_row.TYPE || ' '
                || error_row.LINE || ':' || error_row.POSITION || ' '
                || error_row.TEXT);
        END LOOP;
        RAISE_APPLICATION_ERROR(-20001, 'One or more SmartMove PL/SQL units did not compile');
    END IF;
END;
/

PROMPT SmartMove PL/SQL packages installed.
