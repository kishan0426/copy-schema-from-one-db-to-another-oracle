CREATE OR REPLACE PROCEDURE COPY_SCHEMA
(
    P_SOURCE_SCHEMA IN VARCHAR2,
    P_TARGET_SCHEMA IN VARCHAR2,
    P_DB_LINK       IN VARCHAR2,
    P_PARALLEL      IN NUMBER DEFAULT 4,
    P_NOLOGGING     IN VARCHAR2 DEFAULT 'Y'
)
AS
    V_SQL       VARCHAR2(32767);
    V_CURSOR    SYS_REFCURSOR;
    V_TABLE     VARCHAR2(128);
    V_COUNT     NUMBER;
    V_COPIED    NUMBER := 0;
    V_SKIPPED   NUMBER := 0;
    V_FAILED    NUMBER := 0;
    V_LOGGING   VARCHAR2(20);
BEGIN

    IF P_PARALLEL < 1 OR P_PARALLEL > 64 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Invalid parallel degree');
    END IF;

    IF UPPER(P_NOLOGGING) NOT IN ('Y','N') THEN
        RAISE_APPLICATION_ERROR(-20002, 'Invalid NOLOGGING option');
    END IF;

    V_LOGGING :=
        CASE
            WHEN UPPER(P_NOLOGGING) = 'Y'
            THEN 'NOLOGGING'
            ELSE 'LOGGING'
        END;

    DBMS_OUTPUT.PUT_LINE('STARTING SCHEMA COPY');
    DBMS_OUTPUT.PUT_LINE('SOURCE: ' || P_SOURCE_SCHEMA);
    DBMS_OUTPUT.PUT_LINE('TARGET: ' || P_TARGET_SCHEMA);

    -- Get source tables through DB LINK
    V_SQL :=
        'SELECT TABLE_NAME FROM ALL_TABLES@' ||
        DBMS_ASSERT.SIMPLE_SQL_NAME(P_DB_LINK) ||
        ' WHERE OWNER = :1 ORDER BY TABLE_NAME';

    OPEN V_CURSOR FOR V_SQL
        USING UPPER(P_SOURCE_SCHEMA);

    LOOP

        FETCH V_CURSOR INTO V_TABLE;
        EXIT WHEN V_CURSOR%NOTFOUND;

        BEGIN

            -- Check whether table exists in target schema
            SELECT COUNT(*)
            INTO V_COUNT
            FROM ALL_TABLES
            WHERE OWNER = UPPER(P_TARGET_SCHEMA)
            AND TABLE_NAME = V_TABLE;

            IF V_COUNT > 0 THEN

                V_SKIPPED := V_SKIPPED + 1;

                DBMS_OUTPUT.PUT_LINE(
                    'SKIPPED: ' || V_TABLE
                );

            ELSE

                -- Create table and copy source data
                V_SQL :=
                    'CREATE TABLE ' ||
                    DBMS_ASSERT.SCHEMA_NAME(UPPER(P_TARGET_SCHEMA)) ||
                    '."' || V_TABLE || '" ' ||
                    V_LOGGING ||
                    ' PARALLEL ' || TO_CHAR(P_PARALLEL) ||
                    ' AS SELECT * FROM ' ||
                    DBMS_ASSERT.SCHEMA_NAME(UPPER(P_SOURCE_SCHEMA)) ||
                    '."' || V_TABLE || '"@' ||
                    DBMS_ASSERT.SIMPLE_SQL_NAME(P_DB_LINK);

                EXECUTE IMMEDIATE V_SQL;

                V_COPIED := V_COPIED + 1;

                DBMS_OUTPUT.PUT_LINE(
                    'COPIED: ' || V_TABLE
                );

            END IF;

        EXCEPTION
            WHEN OTHERS THEN

                V_FAILED := V_FAILED + 1;

                DBMS_OUTPUT.PUT_LINE(
                    'FAILED: ' || V_TABLE ||
                    ' ERROR: ' || SQLERRM
                );

        END;

    END LOOP;

    CLOSE V_CURSOR;

    DBMS_OUTPUT.PUT_LINE('================================');
    DBMS_OUTPUT.PUT_LINE('TOTAL COPIED  : ' || V_COPIED);
    DBMS_OUTPUT.PUT_LINE('TOTAL SKIPPED : ' || V_SKIPPED);
    DBMS_OUTPUT.PUT_LINE('TOTAL FAILED  : ' || V_FAILED);
    DBMS_OUTPUT.PUT_LINE('SCHEMA COPY COMPLETED');
    DBMS_OUTPUT.PUT_LINE('================================');

EXCEPTION
    WHEN OTHERS THEN

        IF V_CURSOR%ISOPEN THEN
            CLOSE V_CURSOR;
        END IF;

        DBMS_OUTPUT.PUT_LINE('FATAL ERROR: ' || SQLERRM);
        RAISE;

END;
/
